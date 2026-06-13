-- =========================================================
-- SilkRoad production security and transactional API
-- Chay sau 12_optimize_database.sql.
-- =========================================================

ALTER TABLE USERS ADD COLUMN IF NOT EXISTS AuthUserID UUID UNIQUE;
ALTER TABLE USERS DROP CONSTRAINT IF EXISTS chk_password_hash_length;
ALTER TABLE USERS DROP COLUMN IF EXISTS PasswordHash;

DO $$
BEGIN
    IF to_regclass('auth.users') IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_users_auth_user') THEN
        ALTER TABLE USERS
            ADD CONSTRAINT fk_users_auth_user
            FOREIGN KEY (AuthUserID) REFERENCES auth.users(id) ON DELETE SET NULL;
    END IF;
END $$;

CREATE TABLE IF NOT EXISTS AUDIT_LOG (
    AuditID BIGSERIAL PRIMARY KEY,
    ActorUserID UUID REFERENCES USERS(UserID),
    Action VARCHAR(80) NOT NULL,
    EntityType VARCHAR(80) NOT NULL,
    EntityID TEXT,
    BeforeData JSONB,
    AfterData JSONB,
    RequestID UUID NOT NULL DEFAULT gen_random_uuid(),
    CreatedAt TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_audit_log_actor_created
    ON AUDIT_LOG (ActorUserID, CreatedAt DESC);
CREATE INDEX IF NOT EXISTS idx_audit_log_entity_created
    ON AUDIT_LOG (EntityType, EntityID, CreatedAt DESC);

-- Supabase/PostgREST dat JWT subject vao request.jwt.claim.sub. Cach nay cung
-- cho phep SQL CI local tao function ma khong can schema auth.
CREATE OR REPLACE FUNCTION current_auth_user_id()
RETURNS UUID
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_auth_user_id UUID;
BEGIN
    IF to_regprocedure('auth.uid()') IS NOT NULL THEN
        EXECUTE 'SELECT auth.uid()' INTO v_auth_user_id;
        RETURN v_auth_user_id;
    END IF;
    RETURN NULLIF(current_setting('request.jwt.claim.sub', TRUE), '')::UUID;
END;
$$;

CREATE OR REPLACE FUNCTION current_app_user_id()
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT UserID
    FROM USERS
    WHERE AuthUserID = current_auth_user_id()
      AND Status = 'active'
    LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION current_app_role()
RETURNS TEXT
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT r.RoleName
    FROM USERS u
    JOIN ROLE r ON r.RoleID = u.RoleID
    WHERE u.UserID = current_app_user_id()
    LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION current_app_branch_id()
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT BranchID FROM USERS WHERE UserID = current_app_user_id() LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION current_app_is_admin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT COALESCE(current_app_role() = 'admin', FALSE);
$$;

CREATE OR REPLACE FUNCTION current_app_has_permission(p_permission TEXT)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM USERS u
        JOIN ROLE r ON r.RoleID = u.RoleID
        WHERE u.UserID = current_app_user_id()
          AND p_permission = ANY(r.Permissions)
    );
$$;

CREATE OR REPLACE FUNCTION write_audit_log(
    p_action TEXT,
    p_entity_type TEXT,
    p_entity_id TEXT DEFAULT NULL,
    p_before JSONB DEFAULT NULL,
    p_after JSONB DEFAULT NULL
)
RETURNS BIGINT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_id BIGINT;
BEGIN
    INSERT INTO AUDIT_LOG (ActorUserID, Action, EntityType, EntityID, BeforeData, AfterData)
    VALUES (current_app_user_id(), p_action, p_entity_type, p_entity_id, p_before, p_after)
    RETURNING AuditID INTO v_id;
    RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION assert_app_permission(p_permission TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF current_app_user_id() IS NULL THEN
        RAISE EXCEPTION 'Unauthenticated or inactive application user';
    END IF;
    IF NOT current_app_has_permission(p_permission) THEN
        RAISE EXCEPTION 'Permission denied: %', p_permission;
    END IF;
END;
$$;

-- Atomic order creation. Frontend sends one JSON payload and never updates
-- stock/order_detail/payment directly.
CREATE OR REPLACE FUNCTION fn_create_order_app(p_payload JSONB)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_order_id UUID := gen_random_uuid();
    v_user_id UUID := current_app_user_id();
    v_line JSONB;
    v_status order_status := COALESCE(NULLIF(p_payload->>'order_status', '')::order_status, 'confirmed');
    v_payment_status order_payment_status := COALESCE(NULLIF(p_payload->>'payment_status', '')::order_payment_status, 'paid');
    v_payment_method payment_method := COALESCE(NULLIF(p_payload->>'payment_method', '')::payment_method, 'cash');
    v_final DECIMAL(14,2);
BEGIN
    PERFORM assert_app_permission('order.create');
    IF jsonb_array_length(COALESCE(p_payload->'lines', '[]'::JSONB)) = 0 THEN
        RAISE EXCEPTION 'Order requires at least one line';
    END IF;

    INSERT INTO ORDERS (
        OrderID, ChannelID, BranchID, CustomerID, CreatedBy,
        OrderStatus, PaymentStatus, DiscountAmount, ShippingFee,
        ShippingName, ShippingPhone, ShippingAddress, ShippingProvince, Note
    ) VALUES (
        v_order_id,
        (p_payload->>'channel_id')::UUID,
        (p_payload->>'branch_id')::UUID,
        NULLIF(p_payload->>'customer_id', '')::UUID,
        v_user_id,
        'new',
        v_payment_status,
        COALESCE((p_payload->>'discount_amount')::DECIMAL, 0),
        COALESCE((p_payload->>'shipping_fee')::DECIMAL, 0),
        NULLIF(p_payload->>'shipping_name', ''),
        NULLIF(p_payload->>'shipping_phone', ''),
        NULLIF(p_payload->>'shipping_address', ''),
        NULLIF(p_payload->>'shipping_province', ''),
        NULLIF(p_payload->>'note', '')
    );

    FOR v_line IN SELECT value FROM jsonb_array_elements(p_payload->'lines')
    LOOP
        INSERT INTO ORDER_DETAIL (OrderID, VariantID, Quantity, UnitPrice)
        VALUES (
            v_order_id,
            (v_line->>'variant_id')::UUID,
            (v_line->>'quantity')::INT,
            (v_line->>'unit_price')::DECIMAL
        );
    END LOOP;

    IF v_status <> 'new' THEN
        CALL sp_confirm_order(v_order_id);
    END IF;

    SELECT FinalAmount INTO v_final FROM ORDERS WHERE OrderID = v_order_id;
    IF v_payment_status = 'paid' THEN
        INSERT INTO PAYMENT (PaymentID, OrderID, Method, Amount, Status, PaidAt)
        VALUES (gen_random_uuid(), v_order_id, v_payment_method, v_final, 'success', NOW());
    END IF;
    PERFORM write_audit_log('order.create', 'orders', v_order_id::TEXT, NULL, p_payload);
    RETURN v_order_id;
END;
$$;

CREATE OR REPLACE FUNCTION fn_create_purchase_order_app(p_payload JSONB)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_id UUID := gen_random_uuid();
    v_line JSONB;
BEGIN
    PERFORM assert_app_permission('purchase_order.create');
    INSERT INTO PURCHASE_ORDER (PurchaseOrderID, SupplierID, BranchID, CreatedBy, ExpectedDate, Status, Note)
    VALUES (v_id, (p_payload->>'supplier_id')::UUID, (p_payload->>'branch_id')::UUID, current_app_user_id(),
            COALESCE((p_payload->>'expected_date')::DATE, CURRENT_DATE), 'draft', NULLIF(p_payload->>'note', ''));
    FOR v_line IN SELECT value FROM jsonb_array_elements(COALESCE(p_payload->'lines', '[]'::JSONB))
    LOOP
        INSERT INTO PURCHASE_ORDER_DETAIL (PurchaseOrderID, VariantID, RequestedQuantity, ReceivedQuantity, UnitPrice)
        VALUES (v_id, (v_line->>'variant_id')::UUID, (v_line->>'quantity')::INT, 0, (v_line->>'unit_price')::DECIMAL);
    END LOOP;
    PERFORM write_audit_log('purchase_order.create', 'purchase_order', v_id::TEXT, NULL, p_payload);
    RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION fn_create_transfer_app(p_payload JSONB)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_id UUID := gen_random_uuid();
    v_line JSONB;
BEGIN
    PERFORM assert_app_permission('transfer_order.create');
    INSERT INTO TRANSFER_ORDER (TransferID, FromBranchID, ToBranchID, CreatedBy, Status, Note)
    VALUES (v_id, (p_payload->>'from_branch_id')::UUID, (p_payload->>'to_branch_id')::UUID, current_app_user_id(), 'draft', NULLIF(p_payload->>'note', ''));
    FOR v_line IN SELECT value FROM jsonb_array_elements(COALESCE(p_payload->'lines', '[]'::JSONB))
    LOOP
        INSERT INTO TRANSFER_ORDER_DETAIL (TransferID, VariantID, RequestedQuantity, Note)
        VALUES (v_id, (v_line->>'variant_id')::UUID, (v_line->>'quantity')::INT, NULLIF(v_line->>'note', ''));
    END LOOP;
    PERFORM write_audit_log('transfer_order.create', 'transfer_order', v_id::TEXT, NULL, p_payload);
    RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION fn_create_adjustment_app(p_payload JSONB)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_id UUID := gen_random_uuid();
    v_line JSONB;
    v_system INT;
BEGIN
    PERFORM assert_app_permission('stock_adjustment.create');
    INSERT INTO STOCK_ADJUSTMENT (AdjustmentID, BranchID, CreatedBy, Status, Note)
    VALUES (v_id, (p_payload->>'branch_id')::UUID, current_app_user_id(), 'draft', NULLIF(p_payload->>'note', ''));
    FOR v_line IN SELECT value FROM jsonb_array_elements(COALESCE(p_payload->'lines', '[]'::JSONB))
    LOOP
        SELECT Quantity INTO v_system FROM STOCK
        WHERE BranchID = (p_payload->>'branch_id')::UUID AND VariantID = (v_line->>'variant_id')::UUID;
        INSERT INTO STOCK_ADJUSTMENT_DETAIL (AdjustmentID, VariantID, SystemQuantity, ActualQuantity)
        VALUES (v_id, (v_line->>'variant_id')::UUID, COALESCE(v_system, 0), (v_line->>'actual_quantity')::INT);
    END LOOP;
    PERFORM write_audit_log('stock_adjustment.create', 'stock_adjustment', v_id::TEXT, NULL, p_payload);
    RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION fn_create_return_app(p_payload JSONB)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_id UUID := gen_random_uuid();
    v_line JSONB;
BEGIN
    PERFORM assert_app_permission('return_order.create');
    INSERT INTO RETURN_ORDER (ReturnID, OrderID, BranchID, CreatedBy, Reason, ActionType, RefundMethod, RefundAmount, Status, Note)
    VALUES (v_id, (p_payload->>'order_id')::UUID, (p_payload->>'branch_id')::UUID, current_app_user_id(),
            NULLIF(p_payload->>'reason', ''), (p_payload->>'action_type')::return_action_type,
            NULLIF(p_payload->>'refund_method', '')::refund_method, COALESCE((p_payload->>'refund_amount')::DECIMAL, 0),
            'pending', NULLIF(p_payload->>'note', ''));
    FOR v_line IN SELECT value FROM jsonb_array_elements(COALESCE(p_payload->'lines', '[]'::JSONB))
    LOOP
        INSERT INTO RETURN_DETAIL (ReturnID, VariantID, ReturnQuantity, Condition, RefundAmount)
        VALUES (v_id, (v_line->>'variant_id')::UUID, (v_line->>'quantity')::INT,
                (v_line->>'condition')::return_condition, NULLIF(v_line->>'refund_amount', '')::DECIMAL);
    END LOOP;
    PERFORM write_audit_log('return_order.create', 'return_order', v_id::TEXT, NULL, p_payload);
    RETURN v_id;
END;
$$;

ALTER TABLE PRODUCT ENABLE ROW LEVEL SECURITY;
ALTER TABLE PRODUCT_VARIANT ENABLE ROW LEVEL SECURITY;
ALTER TABLE PRODUCT_IMAGE ENABLE ROW LEVEL SECURITY;
ALTER TABLE PRODUCT_CATEGORY ENABLE ROW LEVEL SECURITY;
ALTER TABLE ATTRIBUTE ENABLE ROW LEVEL SECURITY;
ALTER TABLE BRANCH ENABLE ROW LEVEL SECURITY;
ALTER TABLE SUPPLIER ENABLE ROW LEVEL SECURITY;
ALTER TABLE SUPPLIER_PRODUCT ENABLE ROW LEVEL SECURITY;
ALTER TABLE SALES_CHANNEL ENABLE ROW LEVEL SECURITY;
ALTER TABLE CHANNEL_PRICE ENABLE ROW LEVEL SECURITY;
ALTER TABLE CHANNEL_SYNC_LOG ENABLE ROW LEVEL SECURITY;
ALTER TABLE CUSTOMER ENABLE ROW LEVEL SECURITY;
ALTER TABLE USERS ENABLE ROW LEVEL SECURITY;
ALTER TABLE ROLE ENABLE ROW LEVEL SECURITY;
ALTER TABLE AUDIT_LOG ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS authenticated_product_read ON PRODUCT;
DROP POLICY IF EXISTS authenticated_variant_read ON PRODUCT_VARIANT;
DROP POLICY IF EXISTS authenticated_image_read ON PRODUCT_IMAGE;
DROP POLICY IF EXISTS authenticated_category_read ON PRODUCT_CATEGORY;
DROP POLICY IF EXISTS authenticated_attribute_read ON ATTRIBUTE;
DROP POLICY IF EXISTS permitted_branch_read ON BRANCH;
DROP POLICY IF EXISTS permitted_supplier_read ON SUPPLIER;
DROP POLICY IF EXISTS permitted_supplier_product_read ON SUPPLIER_PRODUCT;
DROP POLICY IF EXISTS permitted_sales_channel_read ON SALES_CHANNEL;
DROP POLICY IF EXISTS permitted_channel_price_read ON CHANNEL_PRICE;
DROP POLICY IF EXISTS permitted_channel_sync_log_read ON CHANNEL_SYNC_LOG;
DROP POLICY IF EXISTS permitted_customer_access ON CUSTOMER;
DROP POLICY IF EXISTS permitted_user_read ON USERS;
DROP POLICY IF EXISTS permitted_role_read ON ROLE;
DROP POLICY IF EXISTS permitted_audit_read ON AUDIT_LOG;

CREATE POLICY authenticated_product_read ON PRODUCT FOR SELECT USING (current_app_user_id() IS NOT NULL);
CREATE POLICY authenticated_variant_read ON PRODUCT_VARIANT FOR SELECT USING (current_app_user_id() IS NOT NULL);
CREATE POLICY authenticated_image_read ON PRODUCT_IMAGE FOR SELECT USING (current_app_user_id() IS NOT NULL);
CREATE POLICY authenticated_category_read ON PRODUCT_CATEGORY FOR SELECT USING (current_app_user_id() IS NOT NULL);
CREATE POLICY authenticated_attribute_read ON ATTRIBUTE FOR SELECT USING (current_app_user_id() IS NOT NULL);
CREATE POLICY permitted_branch_read ON BRANCH FOR SELECT USING (current_app_has_permission('branch.view'));
CREATE POLICY permitted_supplier_read ON SUPPLIER FOR SELECT USING (current_app_has_permission('supplier.view'));
CREATE POLICY permitted_supplier_product_read ON SUPPLIER_PRODUCT FOR SELECT USING (current_app_has_permission('supplier_product.view') OR current_app_has_permission('supplier.view'));
CREATE POLICY permitted_sales_channel_read ON SALES_CHANNEL FOR SELECT USING (current_app_has_permission('sales_channel.view'));
CREATE POLICY permitted_channel_price_read ON CHANNEL_PRICE FOR SELECT USING (current_app_has_permission('channel_price.view'));
CREATE POLICY permitted_channel_sync_log_read ON CHANNEL_SYNC_LOG FOR SELECT USING (current_app_has_permission('channel_sync_log.view'));
CREATE POLICY permitted_customer_access ON CUSTOMER FOR SELECT USING (current_app_has_permission('customer.view'));
CREATE POLICY permitted_user_read ON USERS FOR SELECT USING (UserID = current_app_user_id() OR current_app_has_permission('user.view'));
CREATE POLICY permitted_role_read ON ROLE FOR SELECT USING (current_app_user_id() IS NOT NULL);
CREATE POLICY permitted_audit_read ON AUDIT_LOG FOR SELECT USING (current_app_is_admin());

ALTER VIEW vw_pos_variant_stock_catalog SET (security_invoker = true);
ALTER VIEW vw_product_search_catalog SET (security_invoker = true);
ALTER VIEW vw_stock_by_branch SET (security_invoker = true);
ALTER VIEW vw_order_summary SET (security_invoker = true);
ALTER VIEW vw_revenue_by_channel SET (security_invoker = true);

REVOKE EXECUTE ON FUNCTION fn_dashboard_summary_app() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION fn_create_order_app(JSONB) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION fn_create_purchase_order_app(JSONB) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION fn_create_transfer_app(JSONB) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION fn_create_adjustment_app(JSONB) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION fn_create_return_app(JSONB) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION fn_confirm_order_app(UUID) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION fn_confirm_purchase_order_app(UUID) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION fn_ship_transfer_order_app(UUID) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION fn_receive_transfer_order_app(UUID) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION fn_complete_stock_adjustment_app(UUID) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION fn_complete_return_order_app(UUID) FROM PUBLIC;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
        REVOKE ALL ON ALL TABLES IN SCHEMA public FROM anon;
        REVOKE EXECUTE ON FUNCTION fn_confirm_order_app(UUID) FROM anon;
        REVOKE EXECUTE ON FUNCTION fn_confirm_purchase_order_app(UUID) FROM anon;
        REVOKE EXECUTE ON FUNCTION fn_ship_transfer_order_app(UUID) FROM anon;
        REVOKE EXECUTE ON FUNCTION fn_receive_transfer_order_app(UUID) FROM anon;
        REVOKE EXECUTE ON FUNCTION fn_complete_stock_adjustment_app(UUID) FROM anon;
        REVOKE EXECUTE ON FUNCTION fn_complete_return_order_app(UUID) FROM anon;
    END IF;
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
        REVOKE ALL ON ALL TABLES IN SCHEMA public FROM authenticated;
        GRANT SELECT ON
            PRODUCT, PRODUCT_VARIANT, PRODUCT_IMAGE, PRODUCT_CATEGORY, ATTRIBUTE,
            BRANCH, SUPPLIER, SUPPLIER_PRODUCT, SALES_CHANNEL, CHANNEL_PRICE, CHANNEL_SYNC_LOG,
            STOCK, STOCK_HISTORY, INVENTORY_ALLOCATION,
            PURCHASE_ORDER, PURCHASE_ORDER_DETAIL, TRANSFER_ORDER, TRANSFER_ORDER_DETAIL,
            STOCK_ADJUSTMENT, STOCK_ADJUSTMENT_DETAIL,
            CUSTOMER, ORDERS, ORDER_DETAIL, PAYMENT, RETURN_ORDER, RETURN_DETAIL,
            USERS, ROLE, AUDIT_LOG
        TO authenticated;
        GRANT SELECT ON
            vw_pos_variant_stock_catalog, vw_product_search_catalog,
            vw_stock_by_branch, vw_order_summary, vw_revenue_by_channel
        TO authenticated;
        GRANT EXECUTE ON FUNCTION fn_dashboard_summary_app() TO authenticated;
        GRANT EXECUTE ON FUNCTION fn_create_order_app(JSONB) TO authenticated;
        GRANT EXECUTE ON FUNCTION fn_create_purchase_order_app(JSONB) TO authenticated;
        GRANT EXECUTE ON FUNCTION fn_create_transfer_app(JSONB) TO authenticated;
        GRANT EXECUTE ON FUNCTION fn_create_adjustment_app(JSONB) TO authenticated;
        GRANT EXECUTE ON FUNCTION fn_create_return_app(JSONB) TO authenticated;
    END IF;
END $$;
