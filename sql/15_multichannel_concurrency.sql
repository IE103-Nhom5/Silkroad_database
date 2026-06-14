-- =========================================================
-- SilkRoad multichannel concurrency and idempotency guards
-- Chay sau 14_auth_profile_and_business_guards.sql.
-- =========================================================

ALTER TABLE ORDERS ADD COLUMN IF NOT EXISTS IdempotencyKey TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS uq_orders_channel_idempotency
    ON ORDERS (ChannelID, IdempotencyKey)
    WHERE IdempotencyKey IS NOT NULL;

-- Phan bo phai so sanh phan CON LAI cua cac kenh voi ton kha dung.
-- Lock dong STOCK de hai nguoi khong the phan bo vuot ton cung luc.
CREATE OR REPLACE FUNCTION fn_check_inventory_allocation()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_other_available INT;
    v_stock_available INT;
BEGIN
    SELECT AvailableQuantity
    INTO v_stock_available
    FROM STOCK
    WHERE BranchID = NEW.BranchID
      AND VariantID = NEW.VariantID
    FOR UPDATE;

    IF v_stock_available IS NULL THEN
        RAISE EXCEPTION 'BUSINESS_STOCK_UNAVAILABLE';
    END IF;

    SELECT COALESCE(SUM(AvailableForChannel), 0)
    INTO v_other_available
    FROM INVENTORY_ALLOCATION
    WHERE BranchID = NEW.BranchID
      AND VariantID = NEW.VariantID
      AND ChannelID <> NEW.ChannelID;

    IF v_other_available + (NEW.AllocatedQuantity - NEW.SoldQuantity) > v_stock_available THEN
        RAISE EXCEPTION 'BUSINESS_CHANNEL_ALLOCATION_INSUFFICIENT';
    END IF;

    RETURN NEW;
END;
$$;

-- Xac nhan don atomic: lock don, lock STOCK, lock allocation theo tung SKU.
-- POS duoc tu tao/tang allocation dung phan can ban; kenh khac phai phan bo truoc.
CREATE OR REPLACE PROCEDURE sp_confirm_order(p_order_id UUID)
LANGUAGE plpgsql
AS $$
DECLARE
    v_branch_id UUID;
    v_channel_id UUID;
    v_channel_type channel_type;
    v_user_id UUID;
    v_order_status order_status;
    v_before_qty INT;
    v_stock_available INT;
    v_after_qty INT;
    v_allocated INT;
    v_sold INT;
    v_needed INT;
    rec RECORD;
BEGIN
    SELECT o.BranchID, o.ChannelID, sc.ChannelType, o.CreatedBy, o.OrderStatus
    INTO v_branch_id, v_channel_id, v_channel_type, v_user_id, v_order_status
    FROM ORDERS o
    JOIN SALES_CHANNEL sc ON sc.ChannelID = o.ChannelID
    WHERE o.OrderID = p_order_id
    FOR UPDATE OF o;

    IF v_branch_id IS NULL THEN
        RAISE EXCEPTION 'BUSINESS_ORDER_NOT_FOUND';
    END IF;
    IF v_order_status = 'confirmed' THEN
        RETURN;
    END IF;
    IF v_order_status <> 'new' THEN
        RAISE EXCEPTION 'BUSINESS_ORDER_STATUS_INVALID';
    END IF;

    FOR rec IN
        SELECT VariantID, Quantity
        FROM ORDER_DETAIL
        WHERE OrderID = p_order_id
        ORDER BY VariantID
    LOOP
        SELECT Quantity, AvailableQuantity
        INTO v_before_qty, v_stock_available
        FROM STOCK
        WHERE BranchID = v_branch_id
          AND VariantID = rec.VariantID
        FOR UPDATE;

        IF v_before_qty IS NULL OR v_stock_available < rec.Quantity THEN
            RAISE EXCEPTION 'BUSINESS_STOCK_UNAVAILABLE';
        END IF;

        SELECT AllocatedQuantity, SoldQuantity
        INTO v_allocated, v_sold
        FROM INVENTORY_ALLOCATION
        WHERE BranchID = v_branch_id
          AND VariantID = rec.VariantID
          AND ChannelID = v_channel_id
        FOR UPDATE;

        IF NOT FOUND THEN
            IF v_channel_type <> 'pos' THEN
                RAISE EXCEPTION 'BUSINESS_ALLOCATION_MISSING';
            END IF;
            INSERT INTO INVENTORY_ALLOCATION (
                BranchID, VariantID, ChannelID, AllocatedQuantity, SoldQuantity, UpdatedAt
            )
            VALUES (v_branch_id, rec.VariantID, v_channel_id, rec.Quantity, 0, NOW())
            ON CONFLICT (BranchID, VariantID, ChannelID) DO NOTHING;

            SELECT AllocatedQuantity, SoldQuantity
            INTO v_allocated, v_sold
            FROM INVENTORY_ALLOCATION
            WHERE BranchID = v_branch_id
              AND VariantID = rec.VariantID
              AND ChannelID = v_channel_id
            FOR UPDATE;
        END IF;

        v_needed := rec.Quantity - (v_allocated - v_sold);
        IF v_needed > 0 THEN
            IF v_channel_type <> 'pos' THEN
                RAISE EXCEPTION 'BUSINESS_CHANNEL_ALLOCATION_INSUFFICIENT';
            END IF;
            UPDATE INVENTORY_ALLOCATION
            SET AllocatedQuantity = AllocatedQuantity + v_needed,
                UpdatedAt = NOW()
            WHERE BranchID = v_branch_id
              AND VariantID = rec.VariantID
              AND ChannelID = v_channel_id;
        END IF;

        UPDATE INVENTORY_ALLOCATION
        SET SoldQuantity = SoldQuantity + rec.Quantity,
            UpdatedAt = NOW()
        WHERE BranchID = v_branch_id
          AND VariantID = rec.VariantID
          AND ChannelID = v_channel_id;

        v_after_qty := v_before_qty - rec.Quantity;
        UPDATE STOCK
        SET Quantity = v_after_qty,
            LastUpdated = NOW()
        WHERE BranchID = v_branch_id
          AND VariantID = rec.VariantID;

        INSERT INTO STOCK_HISTORY (
            HistoryID, BranchID, VariantID, TransactionType,
            ReferenceType, ReferenceID, QuantityChange,
            QuantityBefore, QuantityAfter, PerformedBy, Timestamp, Note
        )
        VALUES (
            gen_random_uuid(), v_branch_id, rec.VariantID, 'sales',
            'ORDERS', p_order_id, -rec.Quantity,
            v_before_qty, v_after_qty, v_user_id, NOW(),
            'Tru ton kho khi xac nhan don hang'
        );
    END LOOP;

    UPDATE ORDERS SET OrderStatus = 'confirmed' WHERE OrderID = p_order_id;
END;
$$;

-- Tao don co idempotency theo kenh. Request gui lai se tra ve cung OrderID.
CREATE OR REPLACE FUNCTION fn_create_order_app(p_payload JSONB)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_order_id UUID := gen_random_uuid();
    v_existing_order_id UUID;
    v_user_id UUID := current_app_user_id();
    v_line JSONB;
    v_channel_id UUID := (p_payload->>'channel_id')::UUID;
    v_branch_id UUID := (p_payload->>'branch_id')::UUID;
    v_idempotency_key TEXT := NULLIF(p_payload->>'idempotency_key', '');
    v_status order_status := COALESCE(NULLIF(p_payload->>'order_status', '')::order_status, 'confirmed');
    v_payment_status order_payment_status := COALESCE(NULLIF(p_payload->>'payment_status', '')::order_payment_status, 'paid');
    v_payment_method payment_method := COALESCE(NULLIF(p_payload->>'payment_method', '')::payment_method, 'cash');
    v_final DECIMAL(14,2);
BEGIN
    PERFORM assert_app_permission('order.create');
    IF v_idempotency_key IS NULL THEN
        RAISE EXCEPTION 'BUSINESS_IDEMPOTENCY_REQUIRED';
    END IF;
    IF jsonb_array_length(COALESCE(p_payload->'lines', '[]'::JSONB)) = 0 THEN
        RAISE EXCEPTION 'BUSINESS_ORDER_LINES_REQUIRED';
    END IF;

    PERFORM pg_advisory_xact_lock(hashtextextended(v_channel_id::TEXT || ':' || v_idempotency_key, 0));
    SELECT OrderID INTO v_existing_order_id
    FROM ORDERS
    WHERE ChannelID = v_channel_id
      AND IdempotencyKey = v_idempotency_key;
    IF v_existing_order_id IS NOT NULL THEN
        RETURN v_existing_order_id;
    END IF;

    INSERT INTO ORDERS (
        OrderID, ChannelID, BranchID, CustomerID, CreatedBy,
        OrderStatus, PaymentStatus, DiscountAmount, ShippingFee,
        ShippingName, ShippingPhone, ShippingAddress, ShippingProvince,
        Note, IdempotencyKey
    ) VALUES (
        v_order_id, v_channel_id, v_branch_id,
        NULLIF(p_payload->>'customer_id', '')::UUID, v_user_id,
        'new', v_payment_status,
        COALESCE((p_payload->>'discount_amount')::DECIMAL, 0),
        COALESCE((p_payload->>'shipping_fee')::DECIMAL, 0),
        NULLIF(p_payload->>'shipping_name', ''),
        NULLIF(p_payload->>'shipping_phone', ''),
        NULLIF(p_payload->>'shipping_address', ''),
        NULLIF(p_payload->>'shipping_province', ''),
        NULLIF(p_payload->>'note', ''), v_idempotency_key
    );

    FOR v_line IN SELECT value FROM jsonb_array_elements(p_payload->'lines')
    LOOP
        IF COALESCE((v_line->>'quantity')::INT, 0) <= 0 THEN
            RAISE EXCEPTION 'BUSINESS_QUANTITY_INVALID';
        END IF;
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
        INSERT INTO PAYMENT (PaymentID, OrderID, Method, Amount, Status, TransactionID, PaidAt)
        VALUES (gen_random_uuid(), v_order_id, v_payment_method, v_final, 'success', v_idempotency_key, NOW());
    END IF;
    PERFORM write_audit_log('order.create', 'orders', v_order_id::TEXT, NULL, p_payload);
    RETURN v_order_id;
END;
$$;

-- Wrapper xac nhan idempotent: request lap khong cong/tru ton lan hai.
CREATE OR REPLACE FUNCTION fn_confirm_order_app(p_order_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_status order_status;
BEGIN
    PERFORM assert_app_permission('order.confirm');
    SELECT OrderStatus INTO v_status FROM ORDERS WHERE OrderID = p_order_id FOR UPDATE;
    IF v_status IS NULL THEN RAISE EXCEPTION 'BUSINESS_ORDER_NOT_FOUND'; END IF;
    IF v_status = 'confirmed' THEN RETURN TRUE; END IF;
    IF v_status <> 'new' THEN RAISE EXCEPTION 'BUSINESS_ORDER_STATUS_INVALID'; END IF;
    CALL sp_confirm_order(p_order_id);
    RETURN TRUE;
END;
$$;

CREATE OR REPLACE FUNCTION fn_confirm_purchase_order_app(p_purchase_order_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_status purchase_order_status;
BEGIN
    PERFORM assert_app_permission('purchase_order.approve');
    SELECT Status INTO v_status FROM PURCHASE_ORDER WHERE PurchaseOrderID = p_purchase_order_id FOR UPDATE;
    IF v_status IS NULL THEN RAISE EXCEPTION 'BUSINESS_PURCHASE_NOT_FOUND'; END IF;
    IF v_status = 'received' THEN RETURN TRUE; END IF;
    IF v_status = 'cancelled' THEN RAISE EXCEPTION 'BUSINESS_PURCHASE_STATUS_INVALID'; END IF;
    CALL sp_confirm_purchase_order(p_purchase_order_id);
    RETURN TRUE;
END;
$$;

CREATE OR REPLACE FUNCTION fn_ship_transfer_order_app(p_transfer_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_status transfer_order_status;
BEGIN
    PERFORM assert_app_permission('transfer_order.approve');
    SELECT Status INTO v_status FROM TRANSFER_ORDER WHERE TransferID = p_transfer_id FOR UPDATE;
    IF v_status IS NULL THEN RAISE EXCEPTION 'BUSINESS_TRANSFER_NOT_FOUND'; END IF;
    IF v_status IN ('in_transit', 'received') THEN RETURN TRUE; END IF;
    IF v_status = 'cancelled' THEN RAISE EXCEPTION 'BUSINESS_TRANSFER_STATUS_INVALID'; END IF;
    CALL sp_ship_transfer_order(p_transfer_id);
    RETURN TRUE;
END;
$$;

CREATE OR REPLACE FUNCTION fn_receive_transfer_order_app(p_transfer_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_status transfer_order_status;
BEGIN
    PERFORM assert_app_permission('transfer_order.approve');
    SELECT Status INTO v_status FROM TRANSFER_ORDER WHERE TransferID = p_transfer_id FOR UPDATE;
    IF v_status IS NULL THEN RAISE EXCEPTION 'BUSINESS_TRANSFER_NOT_FOUND'; END IF;
    IF v_status = 'received' THEN RETURN TRUE; END IF;
    IF v_status <> 'in_transit' THEN RAISE EXCEPTION 'BUSINESS_TRANSFER_NOT_SHIPPED'; END IF;
    CALL sp_receive_transfer_order(p_transfer_id);
    RETURN TRUE;
END;
$$;

CREATE OR REPLACE FUNCTION fn_complete_stock_adjustment_app(p_adjustment_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_status stock_adjustment_status;
BEGIN
    PERFORM assert_app_permission('stock_adjustment.approve');
    SELECT Status INTO v_status FROM STOCK_ADJUSTMENT WHERE AdjustmentID = p_adjustment_id FOR UPDATE;
    IF v_status IS NULL THEN RAISE EXCEPTION 'BUSINESS_ADJUSTMENT_NOT_FOUND'; END IF;
    IF v_status = 'completed' THEN RETURN TRUE; END IF;
    IF v_status = 'cancelled' THEN RAISE EXCEPTION 'BUSINESS_ADJUSTMENT_STATUS_INVALID'; END IF;
    CALL sp_complete_stock_adjustment(p_adjustment_id);
    RETURN TRUE;
END;
$$;

CREATE OR REPLACE FUNCTION fn_complete_return_order_app(p_return_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_status return_status;
BEGIN
    PERFORM assert_app_permission('return_order.approve');
    SELECT Status INTO v_status FROM RETURN_ORDER WHERE ReturnID = p_return_id FOR UPDATE;
    IF v_status IS NULL THEN RAISE EXCEPTION 'BUSINESS_RETURN_NOT_FOUND'; END IF;
    IF v_status = 'completed' THEN RETURN TRUE; END IF;
    IF v_status = 'cancelled' THEN RAISE EXCEPTION 'BUSINESS_RETURN_STATUS_INVALID'; END IF;
    CALL sp_complete_return_order(p_return_id);
    RETURN TRUE;
END;
$$;

-- Cap nhat phan bo kenh qua mot transaction co lock STOCK va allocation.
CREATE OR REPLACE FUNCTION fn_set_inventory_allocation_app(p_payload JSONB)
RETURNS BOOLEAN
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
    v_branch_id UUID := (p_payload->>'branch_id')::UUID;
    v_variant_id UUID := (p_payload->>'variant_id')::UUID;
    v_channel_id UUID := (p_payload->>'channel_id')::UUID;
    v_allocated INT := COALESCE((p_payload->>'allocated_quantity')::INT, -1);
    v_sold INT;
BEGIN
    PERFORM assert_app_permission('inventory_allocation.update');
    IF v_allocated < 0 THEN RAISE EXCEPTION 'BUSINESS_QUANTITY_INVALID'; END IF;

    PERFORM 1 FROM STOCK
    WHERE BranchID = v_branch_id AND VariantID = v_variant_id
    FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'BUSINESS_STOCK_UNAVAILABLE'; END IF;

    SELECT SoldQuantity INTO v_sold
    FROM INVENTORY_ALLOCATION
    WHERE BranchID = v_branch_id AND VariantID = v_variant_id AND ChannelID = v_channel_id
    FOR UPDATE;
    v_sold := COALESCE(v_sold, 0);
    IF v_allocated < v_sold THEN RAISE EXCEPTION 'BUSINESS_ALLOCATION_BELOW_SOLD'; END IF;

    INSERT INTO INVENTORY_ALLOCATION (BranchID, VariantID, ChannelID, AllocatedQuantity, SoldQuantity, UpdatedAt)
    VALUES (v_branch_id, v_variant_id, v_channel_id, v_allocated, v_sold, NOW())
    ON CONFLICT (BranchID, VariantID, ChannelID)
    DO UPDATE SET AllocatedQuantity = EXCLUDED.AllocatedQuantity, UpdatedAt = NOW();

    PERFORM write_audit_log(
        'inventory_allocation.update', 'inventory_allocation',
        v_branch_id::TEXT || ':' || v_variant_id::TEXT || ':' || v_channel_id::TEXT,
        NULL, p_payload
    );
    RETURN TRUE;
END;
$$;

REVOKE ALL ON PROCEDURE sp_confirm_order(UUID) FROM PUBLIC;
REVOKE ALL ON PROCEDURE sp_confirm_purchase_order(UUID) FROM PUBLIC;
REVOKE ALL ON PROCEDURE sp_ship_transfer_order(UUID) FROM PUBLIC;
REVOKE ALL ON PROCEDURE sp_receive_transfer_order(UUID) FROM PUBLIC;
REVOKE ALL ON PROCEDURE sp_complete_stock_adjustment(UUID) FROM PUBLIC;
REVOKE ALL ON PROCEDURE sp_complete_return_order(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION fn_create_order_app(JSONB) FROM PUBLIC;
REVOKE ALL ON FUNCTION fn_set_inventory_allocation_app(JSONB) FROM PUBLIC;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
        GRANT EXECUTE ON FUNCTION fn_create_order_app(JSONB) TO authenticated;
        GRANT EXECUTE ON FUNCTION fn_confirm_order_app(UUID) TO authenticated;
        GRANT EXECUTE ON FUNCTION fn_confirm_purchase_order_app(UUID) TO authenticated;
        GRANT EXECUTE ON FUNCTION fn_ship_transfer_order_app(UUID) TO authenticated;
        GRANT EXECUTE ON FUNCTION fn_receive_transfer_order_app(UUID) TO authenticated;
        GRANT EXECUTE ON FUNCTION fn_complete_stock_adjustment_app(UUID) TO authenticated;
        GRANT EXECUTE ON FUNCTION fn_complete_return_order_app(UUID) TO authenticated;
        GRANT EXECUTE ON FUNCTION fn_set_inventory_allocation_app(JSONB) TO authenticated;
    END IF;
END $$;
