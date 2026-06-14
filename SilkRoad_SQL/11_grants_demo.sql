
-- 1. Cập nhật danh sách permission theo vai trò
UPDATE ROLE
SET Permissions = ARRAY[
    'dashboard.view',
    'product.create','product.view','product.update','product.delete',
    'product_variant.create','product_variant.view','product_variant.update','product_variant.delete',
    'attribute.create','attribute.view','attribute.update','attribute.delete',
    'branch.create','branch.view','branch.update','branch.delete',
    'supplier.create','supplier.view','supplier.update','supplier.delete',
    'stock.view','stock.update','stock.adjust','stock_history.view',
    'inventory_allocation.create','inventory_allocation.view','inventory_allocation.update','inventory_allocation.delete',
    'purchase_order.create','purchase_order.view','purchase_order.update','purchase_order.approve','purchase_order.cancel',
    'transfer_order.create','transfer_order.view','transfer_order.update','transfer_order.approve','transfer_order.cancel',
    'stock_adjustment.create','stock_adjustment.view','stock_adjustment.update','stock_adjustment.approve','stock_adjustment.cancel',
    'sales_channel.create','sales_channel.view','sales_channel.update','sales_channel.delete',
    'channel_price.create','channel_price.view','channel_price.update','channel_price.delete',
    'channel_sync_log.view','channel_sync_log.retry',
    'customer.create','customer.view','customer.update','customer.delete',
    'order.create','order.view','order.update','order.confirm','order.cancel',
    'payment.create','payment.view','payment.update','payment.refund',
    'return_order.create','return_order.view','return_order.update','return_order.approve',
    'report.view','report.export',
    'user.create','user.view','user.update','user.delete',
    'role.create','role.view','role.update','role.delete',
    'permission.manage','backup.create','backup.restore','import.run','export.run'
]
WHERE RoleName = 'admin';

UPDATE ROLE
SET Permissions = ARRAY[
    'dashboard.view',
    'product.view','product_variant.view','attribute.view',
    'branch.view','supplier.view','supplier_product.view',
    'stock.view','stock.update','stock.adjust','stock_history.view',
    'inventory_allocation.view','inventory_allocation.update',
    'purchase_order.view','purchase_order.approve','purchase_order.cancel',
    'transfer_order.view','transfer_order.approve','transfer_order.cancel',
    'stock_adjustment.create','stock_adjustment.view','stock_adjustment.update','stock_adjustment.approve','stock_adjustment.cancel',
    'sales_channel.view','channel_price.view','channel_sync_log.view',
    'customer.view','order.view','order.update','order.cancel','payment.view','return_order.view','return_order.approve',
    'report.view','report.export','user.view'
]
WHERE RoleName = 'branch_manager';

UPDATE ROLE
SET Permissions = ARRAY[
    'dashboard.view',
    'product.view','product_variant.view','attribute.view',
    'branch.view','supplier.view','supplier_product.view',
    'stock.view','stock.update','stock.adjust','stock_history.view','inventory_allocation.view',
    'purchase_order.create','purchase_order.view','purchase_order.update',
    'transfer_order.create','transfer_order.view','transfer_order.update',
    'stock_adjustment.create','stock_adjustment.view','stock_adjustment.update',
    'return_order.view','report.view'
]
WHERE RoleName = 'warehouse_staff';

UPDATE ROLE
SET Permissions = ARRAY[
    'dashboard.view',
    'product.view','product_variant.view','attribute.view',
    'branch.view','stock.view','inventory_allocation.view',
    'sales_channel.view','channel_price.view',
    'customer.create','customer.view','customer.update',
    'order.create','order.view','order.update','order.confirm','payment.create','payment.view',
    'return_order.create','return_order.view','report.view'
]
WHERE RoleName = 'sales_staff';


-- SilkRoad database performance optimization pack
-- Chay sau schema hien co. File nay chi them extension/index/view/function,
-- khong reset schema va khong drop du lieu.
-- pg_trgm giup search ILIKE/contains tren ten san pham, SKU, barcode nhanh hon.
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- 1. Auth/RBAC lookup
-- App dang login/profile theo email va loc user theo role/branch/status.
CREATE INDEX IF NOT EXISTS idx_users_email_lower
    ON USERS (LOWER(Email))
    WHERE Email IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_users_role_status
    ON USERS (RoleID, Status);

CREATE INDEX IF NOT EXISTS idx_users_branch_status
    ON USERS (BranchID, Status)
    WHERE BranchID IS NOT NULL;

-- 2. Product/POS search
-- POS va global search hay tim theo ten san pham, brand, SKU, barcode.
CREATE INDEX IF NOT EXISTS idx_product_name_trgm
    ON PRODUCT USING GIN (LOWER(ProductName) gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_product_brand_trgm
    ON PRODUCT USING GIN (LOWER(Brand) gin_trgm_ops)
    WHERE Brand IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_product_status_created
    ON PRODUCT (Status, CreatedAt DESC);

CREATE INDEX IF NOT EXISTS idx_variant_sku_trgm
    ON PRODUCT_VARIANT USING GIN (LOWER(SKU) gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_variant_barcode_trgm
    ON PRODUCT_VARIANT USING GIN (LOWER(Barcode) gin_trgm_ops)
    WHERE Barcode IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_variant_status_product
    ON PRODUCT_VARIANT (Status, ProductID);

CREATE INDEX IF NOT EXISTS idx_product_image_primary_lookup
    ON PRODUCT_IMAGE (ProductID, VariantID, SortOrder, CreatedAt DESC);

-- 3. Inventory hot paths
-- POS can check stock theo branch/variant; kho can loc low-stock va lich su moi.
CREATE INDEX IF NOT EXISTS idx_stock_branch_available
    ON STOCK (BranchID, AvailableQuantity DESC);

CREATE INDEX IF NOT EXISTS idx_stock_low_stock
    ON STOCK (BranchID, LastUpdated DESC)
    WHERE Quantity <= MinStockLevel;

CREATE INDEX IF NOT EXISTS idx_stock_last_updated
    ON STOCK (LastUpdated DESC);

CREATE INDEX IF NOT EXISTS idx_stock_history_time
    ON STOCK_HISTORY (Timestamp DESC);

CREATE INDEX IF NOT EXISTS idx_stock_history_timestamp_id_desc
    ON STOCK_HISTORY (Timestamp DESC, HistoryID DESC);

CREATE INDEX IF NOT EXISTS idx_stock_history_variant_time
    ON STOCK_HISTORY (VariantID, Timestamp DESC);

CREATE INDEX IF NOT EXISTS idx_inventory_allocation_channel_available
    ON INVENTORY_ALLOCATION (ChannelID, BranchID, AvailableForChannel DESC);

-- 4. Purchase/transfer/adjustment lookup
-- Cac man van hanh hay loc theo status, branch, ngay tao.
CREATE INDEX IF NOT EXISTS idx_purchase_order_branch_status_created
    ON PURCHASE_ORDER (BranchID, Status, CreatedAt DESC);

CREATE INDEX IF NOT EXISTS idx_purchase_order_supplier_created
    ON PURCHASE_ORDER (SupplierID, CreatedAt DESC);

CREATE INDEX IF NOT EXISTS idx_purchase_detail_variant
    ON PURCHASE_ORDER_DETAIL (VariantID);

CREATE INDEX IF NOT EXISTS idx_transfer_order_from_status_created
    ON TRANSFER_ORDER (FromBranchID, Status, CreatedAt DESC);

CREATE INDEX IF NOT EXISTS idx_transfer_order_to_status_created
    ON TRANSFER_ORDER (ToBranchID, Status, CreatedAt DESC);

CREATE INDEX IF NOT EXISTS idx_transfer_detail_variant
    ON TRANSFER_ORDER_DETAIL (VariantID);

CREATE INDEX IF NOT EXISTS idx_adjustment_branch_status_created
    ON STOCK_ADJUSTMENT (BranchID, Status, CreatedAt DESC);

CREATE INDEX IF NOT EXISTS idx_adjustment_detail_variant
    ON STOCK_ADJUSTMENT_DETAIL (VariantID);

-- 5. Sales/reporting lookup
-- Dashboard/report/POS can tong hop order, detail, payment, return nhanh hon.
CREATE INDEX IF NOT EXISTS idx_order_status_date
    ON ORDERS (OrderStatus, OrderDate DESC);

CREATE INDEX IF NOT EXISTS idx_order_date_id_desc
    ON ORDERS (OrderDate DESC, OrderID DESC);

CREATE INDEX IF NOT EXISTS idx_order_payment_status_date
    ON ORDERS (PaymentStatus, OrderDate DESC);

CREATE INDEX IF NOT EXISTS idx_order_created_by_date
    ON ORDERS (CreatedBy, OrderDate DESC);

CREATE INDEX IF NOT EXISTS idx_order_detail_variant
    ON ORDER_DETAIL (VariantID);

CREATE INDEX IF NOT EXISTS idx_order_detail_variant_order
    ON ORDER_DETAIL (VariantID, OrderID);

CREATE INDEX IF NOT EXISTS idx_payment_order_status
    ON PAYMENT (OrderID, Status);

CREATE INDEX IF NOT EXISTS idx_payment_status_paid_at
    ON PAYMENT (Status, PaidAt DESC)
    WHERE PaidAt IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_return_status_date
    ON RETURN_ORDER (Status, ReturnDate DESC);

CREATE INDEX IF NOT EXISTS idx_return_branch_status_date
    ON RETURN_ORDER (BranchID, Status, ReturnDate DESC);

CREATE INDEX IF NOT EXISTS idx_return_detail_variant
    ON RETURN_DETAIL (VariantID);

CREATE INDEX IF NOT EXISTS idx_channel_sync_received_log_desc
    ON CHANNEL_SYNC_LOG (ReceivedAt DESC, LogID DESC);

-- 6. Optimized views for frontend
-- Gop san join san pham + bien the + ton kho de POS/stock doc nhe hon.
CREATE OR REPLACE VIEW vw_pos_variant_stock_catalog AS
SELECT
    b.BranchID,
    b.BranchName,
    p.ProductID,
    p.ProductName,
    p.Brand,
    p.Gender,
    p.Status AS ProductStatus,
    pc.CategoryID,
    pc.CategoryName,
    pv.VariantID,
    pv.SKU,
    pv.Barcode,
    pv.Status AS VariantStatus,
    pv.CostPrice,
    pv.SellingPrice,
    size_attr.Value AS SizeValue,
    color_attr.Value AS ColorValue,
    color_attr.HexCode,
    s.Quantity,
    s.ReservedQuantity,
    s.AvailableQuantity,
    s.MinStockLevel,
    s.LastUpdated,
    COALESCE(variant_img.ImageURL, product_img.ImageURL) AS ImageURL,
    COALESCE(variant_img.AltText, product_img.AltText, p.ProductName) AS ImageAlt
FROM STOCK s
JOIN BRANCH b ON b.BranchID = s.BranchID
JOIN PRODUCT_VARIANT pv ON pv.VariantID = s.VariantID
JOIN PRODUCT p ON p.ProductID = pv.ProductID
JOIN PRODUCT_CATEGORY pc ON pc.CategoryID = p.CategoryID
LEFT JOIN ATTRIBUTE size_attr ON size_attr.AttributeID = pv.SizeAttributeID
LEFT JOIN ATTRIBUTE color_attr ON color_attr.AttributeID = pv.ColorAttributeID
LEFT JOIN LATERAL (
    SELECT pi.ImageURL, pi.AltText
    FROM PRODUCT_IMAGE pi
    WHERE pi.ProductID = p.ProductID
      AND pi.VariantID = pv.VariantID
    ORDER BY pi.SortOrder, pi.CreatedAt DESC
    LIMIT 1
) variant_img ON TRUE
LEFT JOIN LATERAL (
    SELECT pi.ImageURL, pi.AltText
    FROM PRODUCT_IMAGE pi
    WHERE pi.ProductID = p.ProductID
      AND pi.VariantID IS NULL
    ORDER BY pi.SortOrder, pi.CreatedAt DESC
    LIMIT 1
) product_img ON TRUE;

CREATE OR REPLACE VIEW vw_product_search_catalog AS
SELECT
    p.ProductID,
    p.ProductName,
    p.Brand,
    p.Gender,
    p.Status AS ProductStatus,
    pc.CategoryName,
    COUNT(pv.VariantID) AS VariantCount,
    MIN(pv.SellingPrice) AS MinSellingPrice,
    MAX(pv.SellingPrice) AS MaxSellingPrice,
    COALESCE(SUM(s.AvailableQuantity), 0) AS TotalAvailableQuantity,
    primary_img.ImageURL,
    primary_img.AltText AS ImageAlt
FROM PRODUCT p
JOIN PRODUCT_CATEGORY pc ON pc.CategoryID = p.CategoryID
LEFT JOIN PRODUCT_VARIANT pv ON pv.ProductID = p.ProductID
LEFT JOIN STOCK s ON s.VariantID = pv.VariantID
LEFT JOIN LATERAL (
    SELECT pi.ImageURL, pi.AltText
    FROM PRODUCT_IMAGE pi
    WHERE pi.ProductID = p.ProductID
    ORDER BY
        CASE WHEN pi.VariantID IS NULL THEN 0 ELSE 1 END,
        pi.SortOrder,
        pi.CreatedAt DESC
    LIMIT 1
) primary_img ON TRUE
GROUP BY
    p.ProductID, p.ProductName, p.Brand, p.Gender, p.Status,
    pc.CategoryName, primary_img.ImageURL, primary_img.AltText;

-- 7. Dashboard function
-- Cho phep frontend lay KPI tong quan bang mot RPC thay vi doc nhieu bang lon.
CREATE OR REPLACE FUNCTION fn_dashboard_summary_app()
RETURNS TABLE (
    Metric TEXT,
    ValueText TEXT,
    RawValue NUMERIC,
    GroupName TEXT,
    Detail TEXT
)
LANGUAGE sql
STABLE
AS $$
    SELECT 'Sản phẩm gốc', COUNT(*)::TEXT, COUNT(*)::NUMERIC, 'Hàng hóa', 'Tổng sản phẩm đang quản lý'
    FROM PRODUCT
    UNION ALL
    SELECT 'Biến thể', COUNT(*)::TEXT, COUNT(*)::NUMERIC, 'Hàng hóa', 'Tổng biến thể đang quản lý'
    FROM PRODUCT_VARIANT
    UNION ALL
    SELECT 'Tồn thực', COALESCE(SUM(Quantity), 0)::TEXT, COALESCE(SUM(Quantity), 0)::NUMERIC, 'Kho', 'Tổng số lượng vật lý'
    FROM STOCK
    UNION ALL
    SELECT 'Tồn khả dụng', COALESCE(SUM(AvailableQuantity), 0)::TEXT, COALESCE(SUM(AvailableQuantity), 0)::NUMERIC, 'Kho', 'Tồn thực trừ giữ chỗ'
    FROM STOCK
    UNION ALL
    SELECT 'Sắp hết hàng', COUNT(*)::TEXT, COUNT(*)::NUMERIC, 'Kho', 'Dòng tồn dưới hoặc bằng mức tối thiểu'
    FROM STOCK
    WHERE Quantity <= MinStockLevel
    UNION ALL
    SELECT 'Đơn hàng hôm nay', COUNT(*)::TEXT, COUNT(*)::NUMERIC, 'Bán hàng', 'Số đơn phát sinh trong ngày hiện tại'
    FROM ORDERS
    WHERE OrderDate >= CURRENT_DATE
      AND OrderDate < CURRENT_DATE + INTERVAL '1 day'
    UNION ALL
    SELECT 'Doanh thu hôm nay',
           COALESCE(SUM(FinalAmount), 0)::TEXT,
           COALESCE(SUM(FinalAmount), 0)::NUMERIC,
           'Bán hàng',
           'Tổng final amount đơn trong ngày'
    FROM ORDERS
    WHERE OrderDate >= CURRENT_DATE
      AND OrderDate < CURRENT_DATE + INTERVAL '1 day'
      AND OrderStatus <> 'cancelled'
    UNION ALL
    SELECT 'Khách hàng', COUNT(*)::TEXT, COUNT(*)::NUMERIC, 'CRM', 'Tổng hồ sơ khách hàng'
    FROM CUSTOMER
    UNION ALL
    SELECT 'Thanh toán chờ xử lý', COUNT(*)::TEXT, COUNT(*)::NUMERIC, 'Thanh toán', 'Payment pending'
    FROM PAYMENT
    WHERE Status = 'pending';
$$;

-- 8. Keyset/cursor pagination helpers
-- Khong dung DECLARE CURSOR cho web app. Keyset pagination on dinh hon voi
-- Supabase/PostgREST: lay trang tiep theo bang cap (timestamp, id).
CREATE OR REPLACE FUNCTION fn_orders_page_app(
    p_limit INT DEFAULT 50,
    p_before_order_date TIMESTAMP DEFAULT NULL,
    p_before_order_id UUID DEFAULT NULL
)
RETURNS TABLE (
    OrderID UUID,
    OrderDate TIMESTAMP,
    OrderStatus order_status,
    PaymentStatus order_payment_status,
    FinalAmount DECIMAL(14,2),
    ChannelID UUID,
    BranchID UUID,
    CustomerID UUID,
    CreatedBy UUID,
    NextCursorDate TIMESTAMP,
    NextCursorID UUID
)
LANGUAGE sql
STABLE
AS $$
    SELECT
        o.OrderID,
        o.OrderDate,
        o.OrderStatus,
        o.PaymentStatus,
        o.FinalAmount,
        o.ChannelID,
        o.BranchID,
        o.CustomerID,
        o.CreatedBy,
        o.OrderDate AS NextCursorDate,
        o.OrderID AS NextCursorID
    FROM ORDERS o
    WHERE
        p_before_order_date IS NULL
        OR o.OrderDate < p_before_order_date
        OR (
            p_before_order_id IS NOT NULL
            AND o.OrderDate = p_before_order_date
            AND o.OrderID < p_before_order_id
        )
    ORDER BY o.OrderDate DESC, o.OrderID DESC
    LIMIT LEAST(GREATEST(COALESCE(p_limit, 50), 1), 200);
$$;

CREATE OR REPLACE FUNCTION fn_stock_history_page_app(
    p_limit INT DEFAULT 100,
    p_before_timestamp TIMESTAMP DEFAULT NULL,
    p_before_history_id UUID DEFAULT NULL
)
RETURNS TABLE (
    HistoryID UUID,
    BranchID UUID,
    VariantID UUID,
    TransactionType stock_transaction_type,
    ReferenceType VARCHAR(30),
    ReferenceID UUID,
    QuantityChange INT,
    QuantityBefore INT,
    QuantityAfter INT,
    PerformedBy UUID,
    CreatedTime TIMESTAMP,
    Note TEXT,
    NextCursorTime TIMESTAMP,
    NextCursorID UUID
)
LANGUAGE sql
STABLE
AS $$
    SELECT
        sh.HistoryID,
        sh.BranchID,
        sh.VariantID,
        sh.TransactionType,
        sh.ReferenceType,
        sh.ReferenceID,
        sh.QuantityChange,
        sh.QuantityBefore,
        sh.QuantityAfter,
        sh.PerformedBy,
        sh.Timestamp AS CreatedTime,
        sh.Note,
        sh.Timestamp AS NextCursorTime,
        sh.HistoryID AS NextCursorID
    FROM STOCK_HISTORY sh
    WHERE
        p_before_timestamp IS NULL
        OR sh.Timestamp < p_before_timestamp
        OR (
            p_before_history_id IS NOT NULL
            AND sh.Timestamp = p_before_timestamp
            AND sh.HistoryID < p_before_history_id
        )
    ORDER BY sh.Timestamp DESC, sh.HistoryID DESC
    LIMIT LEAST(GREATEST(COALESCE(p_limit, 100), 1), 500);
$$;

CREATE OR REPLACE FUNCTION fn_channel_sync_log_page_app(
    p_limit INT DEFAULT 100,
    p_before_received_at TIMESTAMP DEFAULT NULL,
    p_before_log_id BIGINT DEFAULT NULL
)
RETURNS TABLE (
    LogID BIGINT,
    ChannelID UUID,
    EventType VARCHAR(50),
    ExternalOrderID VARCHAR(100),
    Status sync_status,
    RetryCount SMALLINT,
    ReceivedAt TIMESTAMP,
    ProcessedAt TIMESTAMP,
    ErrorMessage TEXT,
    NextCursorTime TIMESTAMP,
    NextCursorID BIGINT
)
LANGUAGE sql
STABLE
AS $$
    SELECT
        csl.LogID,
        csl.ChannelID,
        csl.EventType,
        csl.ExternalOrderID,
        csl.Status,
        csl.RetryCount,
        csl.ReceivedAt,
        csl.ProcessedAt,
        csl.ErrorMessage,
        csl.ReceivedAt AS NextCursorTime,
        csl.LogID AS NextCursorID
    FROM CHANNEL_SYNC_LOG csl
    WHERE
        p_before_received_at IS NULL
        OR csl.ReceivedAt < p_before_received_at
        OR (
            p_before_log_id IS NOT NULL
            AND csl.ReceivedAt = p_before_received_at
            AND csl.LogID < p_before_log_id
        )
    ORDER BY csl.ReceivedAt DESC, csl.LogID DESC
    LIMIT LEAST(GREATEST(COALESCE(p_limit, 100), 1), 500);
$$;

-- Supabase/PostgREST roles: cap quyen neu roles ton tai.
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
        GRANT SELECT ON vw_pos_variant_stock_catalog TO anon;
        GRANT SELECT ON vw_product_search_catalog TO anon;
        GRANT EXECUTE ON FUNCTION fn_dashboard_summary_app() TO anon;
        GRANT EXECUTE ON FUNCTION fn_orders_page_app(INT, TIMESTAMP, UUID) TO anon;
        GRANT EXECUTE ON FUNCTION fn_stock_history_page_app(INT, TIMESTAMP, UUID) TO anon;
        GRANT EXECUTE ON FUNCTION fn_channel_sync_log_page_app(INT, TIMESTAMP, BIGINT) TO anon;
    END IF;

    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
        GRANT SELECT ON vw_pos_variant_stock_catalog TO authenticated;
        GRANT SELECT ON vw_product_search_catalog TO authenticated;
        GRANT EXECUTE ON FUNCTION fn_dashboard_summary_app() TO authenticated;
        GRANT EXECUTE ON FUNCTION fn_orders_page_app(INT, TIMESTAMP, UUID) TO authenticated;
        GRANT EXECUTE ON FUNCTION fn_stock_history_page_app(INT, TIMESTAMP, UUID) TO authenticated;
        GRANT EXECUTE ON FUNCTION fn_channel_sync_log_page_app(INT, TIMESTAMP, BIGINT) TO authenticated;
    END IF;
END $$;

-- Cap nhat planner statistics sau khi them index/view/function.
ANALYZE;


-- SilkRoad production security and transactional API
-- Chay sau 12_optimize_database.sql.
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


-- SilkRoad auth profile provisioning and business guards
-- Chay sau 13_production_security.sql.
CREATE OR REPLACE FUNCTION handle_new_auth_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_role_id UUID;
    v_base_username TEXT;
    v_username TEXT;
    v_suffix INT := 0;
BEGIN
    IF EXISTS (SELECT 1 FROM USERS WHERE AuthUserID = NEW.id) THEN
        RETURN NEW;
    END IF;

    SELECT RoleID INTO v_role_id
    FROM ROLE
    WHERE RoleName = 'sales_staff'
    LIMIT 1;

    IF v_role_id IS NULL THEN
        RAISE EXCEPTION 'Default role sales_staff is missing';
    END IF;

    IF NEW.email IS NOT NULL AND EXISTS (
        SELECT 1 FROM USERS WHERE Email = NEW.email AND AuthUserID IS NULL
    ) THEN
        UPDATE USERS
        SET AuthUserID = NEW.id,
            FullName = COALESCE(NULLIF(NEW.raw_user_meta_data->>'full_name', ''), FullName),
            UpdatedAt = NOW()
        WHERE Email = NEW.email
          AND AuthUserID IS NULL;
        RETURN NEW;
    END IF;

    v_base_username := LOWER(REGEXP_REPLACE(
        COALESCE(
            NULLIF(NEW.raw_user_meta_data->>'username', ''),
            SPLIT_PART(COALESCE(NEW.email, NEW.id::TEXT), '@', 1)
        ),
        '[^a-z0-9_]+',
        '_',
        'g'
    ));
    v_base_username := TRIM(BOTH '_' FROM v_base_username);
    IF v_base_username = '' THEN
        v_base_username := 'user';
    END IF;

    v_username := LEFT(v_base_username, 50);
    WHILE EXISTS (SELECT 1 FROM USERS WHERE Username = v_username) LOOP
        v_suffix := v_suffix + 1;
        v_username := LEFT(v_base_username, 43) || '_' || v_suffix::TEXT;
    END LOOP;

    INSERT INTO USERS (AuthUserID, FullName, Username, Email, RoleID, Status)
    VALUES (
        NEW.id,
        COALESCE(NULLIF(NEW.raw_user_meta_data->>'full_name', ''), NEW.email, v_username),
        v_username,
        NEW.email,
        v_role_id,
        'active'
    );

    RETURN NEW;
END;
$$;

DO $$
BEGIN
    IF to_regclass('auth.users') IS NOT NULL THEN
        DROP TRIGGER IF EXISTS on_auth_user_created_create_profile ON auth.users;
        CREATE TRIGGER on_auth_user_created_create_profile
            AFTER INSERT ON auth.users
            FOR EACH ROW EXECUTE FUNCTION handle_new_auth_user();
    END IF;
END $$;

CREATE OR REPLACE FUNCTION guard_order_line_price()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
    v_cost_price DECIMAL(12,2);
BEGIN
    SELECT CostPrice INTO v_cost_price
    FROM PRODUCT_VARIANT
    WHERE VariantID = NEW.VariantID;

    IF v_cost_price IS NULL THEN
        RAISE EXCEPTION 'Product variant does not exist';
    END IF;
    IF NEW.UnitPrice < v_cost_price THEN
        RAISE EXCEPTION 'Selling price cannot be lower than cost price';
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_guard_order_line_price ON ORDER_DETAIL;
CREATE TRIGGER trg_guard_order_line_price
    BEFORE INSERT OR UPDATE OF UnitPrice, VariantID ON ORDER_DETAIL
    FOR EACH ROW EXECUTE FUNCTION guard_order_line_price();

CREATE OR REPLACE FUNCTION guard_return_quantity()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
    v_order_id UUID;
    v_sold_quantity INT;
    v_returned_quantity INT;
BEGIN
    SELECT OrderID INTO v_order_id
    FROM RETURN_ORDER
    WHERE ReturnID = NEW.ReturnID;

    SELECT Quantity INTO v_sold_quantity
    FROM ORDER_DETAIL
    WHERE OrderID = v_order_id
      AND VariantID = NEW.VariantID;

    IF v_sold_quantity IS NULL THEN
        RAISE EXCEPTION 'Returned variant was not sold in the original order';
    END IF;

    SELECT COALESCE(SUM(rd.ReturnQuantity), 0)::INT INTO v_returned_quantity
    FROM RETURN_DETAIL rd
    JOIN RETURN_ORDER ro ON ro.ReturnID = rd.ReturnID
    WHERE ro.OrderID = v_order_id
      AND rd.VariantID = NEW.VariantID
      AND (rd.ReturnID <> NEW.ReturnID OR rd.VariantID <> NEW.VariantID);

    IF v_returned_quantity + NEW.ReturnQuantity > v_sold_quantity THEN
        RAISE EXCEPTION 'Return quantity exceeds sold quantity';
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_guard_return_quantity ON RETURN_DETAIL;
CREATE TRIGGER trg_guard_return_quantity
    BEFORE INSERT OR UPDATE OF ReturnQuantity, VariantID ON RETURN_DETAIL
    FOR EACH ROW EXECUTE FUNCTION guard_return_quantity();

REVOKE ALL ON FUNCTION handle_new_auth_user() FROM PUBLIC;
REVOKE ALL ON FUNCTION guard_order_line_price() FROM PUBLIC;
REVOKE ALL ON FUNCTION guard_return_quantity() FROM PUBLIC;


-- SilkRoad multichannel concurrency and idempotency guards
-- Chay sau 14_auth_profile_and_business_guards.sql.
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


-- PostgreSQL cursor demo for the SilkRoad graduation project.
-- Runtime web pagination continues to use keyset pagination.
CREATE OR REPLACE FUNCTION fn_cursor_low_stock_report_app(
    p_branch_id UUID DEFAULT NULL,
    p_limit INTEGER DEFAULT 100
)
RETURNS TABLE (
    branch_id UUID,
    branch_name TEXT,
    variant_id UUID,
    sku TEXT,
    product_name TEXT,
    available_quantity INTEGER,
    min_stock_level INTEGER,
    suggested_reorder_quantity INTEGER
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    low_stock_cursor CURSOR FOR
        SELECT
            b.BranchID,
            b.BranchName::TEXT,
            pv.VariantID,
            pv.SKU::TEXT,
            p.ProductName::TEXT,
            s.AvailableQuantity,
            s.MinStockLevel,
            GREATEST(s.MinStockLevel - s.AvailableQuantity, 0) AS SuggestedReorderQuantity
        FROM STOCK s
        JOIN BRANCH b ON b.BranchID = s.BranchID
        JOIN PRODUCT_VARIANT pv ON pv.VariantID = s.VariantID
        JOIN PRODUCT p ON p.ProductID = pv.ProductID
        WHERE (p_branch_id IS NULL OR s.BranchID = p_branch_id)
          AND s.AvailableQuantity <= s.MinStockLevel
        ORDER BY s.AvailableQuantity ASC, b.BranchName, pv.SKU
        LIMIT LEAST(GREATEST(COALESCE(p_limit, 100), 1), 500);
    v_row RECORD;
BEGIN
    OPEN low_stock_cursor;
    LOOP
        FETCH low_stock_cursor INTO v_row;
        EXIT WHEN NOT FOUND;

        branch_id := v_row.BranchID;
        branch_name := v_row.BranchName;
        variant_id := v_row.VariantID;
        sku := v_row.SKU;
        product_name := v_row.ProductName;
        available_quantity := v_row.AvailableQuantity;
        min_stock_level := v_row.MinStockLevel;
        suggested_reorder_quantity := v_row.SuggestedReorderQuantity;
        RETURN NEXT;
    END LOOP;
    CLOSE low_stock_cursor;
END;
$$;

REVOKE ALL ON FUNCTION fn_cursor_low_stock_report_app(UUID, INTEGER) FROM PUBLIC;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
        GRANT EXECUTE ON FUNCTION fn_cursor_low_stock_report_app(UUID, INTEGER) TO authenticated;
    END IF;
END $$;


-- SilkRoad active-admin permission bypass and demo grants
-- RLS policies and SECURITY DEFINER permission checks remain authoritative.
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
          AND u.Status = 'active'
          AND (LOWER(r.RoleName) = 'admin' OR p_permission = ANY(r.Permissions))
    );
$$;

-- App purchase flow can explicitly mark quantities received, then atomically
-- confirm the document through fn_confirm_purchase_order_app.
CREATE OR REPLACE FUNCTION fn_create_purchase_order_app(p_payload JSONB)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_id UUID := gen_random_uuid();
    v_line JSONB;
    v_quantity INT;
    v_received_quantity INT;
BEGIN
    PERFORM assert_app_permission('purchase_order.create');
    IF jsonb_array_length(COALESCE(p_payload->'lines', '[]'::JSONB)) = 0 THEN
        RAISE EXCEPTION 'BUSINESS_PURCHASE_LINES_REQUIRED';
    END IF;

    INSERT INTO PURCHASE_ORDER (PurchaseOrderID, SupplierID, BranchID, CreatedBy, ExpectedDate, Status, Note)
    VALUES (
        v_id,
        (p_payload->>'supplier_id')::UUID,
        (p_payload->>'branch_id')::UUID,
        current_app_user_id(),
        COALESCE((p_payload->>'expected_date')::DATE, CURRENT_DATE),
        'draft',
        NULLIF(p_payload->>'note', '')
    );

    FOR v_line IN SELECT value FROM jsonb_array_elements(p_payload->'lines')
    LOOP
        v_quantity := COALESCE((v_line->>'quantity')::INT, 0);
        v_received_quantity := COALESCE((v_line->>'received_quantity')::INT, 0);
        IF v_quantity <= 0 OR v_received_quantity < 0 OR v_received_quantity > v_quantity THEN
            RAISE EXCEPTION 'BUSINESS_QUANTITY_INVALID';
        END IF;

        INSERT INTO PURCHASE_ORDER_DETAIL (
            PurchaseOrderID, VariantID, RequestedQuantity, ReceivedQuantity, UnitPrice
        )
        VALUES (
            v_id,
            (v_line->>'variant_id')::UUID,
            v_quantity,
            v_received_quantity,
            COALESCE((v_line->>'unit_price')::DECIMAL, (v_line->>'unit_cost')::DECIMAL, 0)
        );
    END LOOP;

    PERFORM write_audit_log('purchase_order.create', 'purchase_order', v_id::TEXT, NULL, p_payload);
    RETURN v_id;
END;
$$;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
        GRANT USAGE ON SCHEMA public TO authenticated;
        GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO authenticated;
        GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated;
        GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO authenticated;
    END IF;
END $$;
