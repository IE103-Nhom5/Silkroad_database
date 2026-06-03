-- =========================================================
-- SilkRoad database performance optimization pack
-- Chay sau schema hien co. File nay chi them extension/index/view/function,
-- khong reset schema va khong drop du lieu.
-- =========================================================

-- pg_trgm giup search ILIKE/contains tren ten san pham, SKU, barcode nhanh hon.
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- =========================================================
-- 1. Auth/RBAC lookup
-- App dang login/profile theo email va loc user theo role/branch/status.
-- =========================================================
CREATE INDEX IF NOT EXISTS idx_users_email_lower
    ON USERS (LOWER(Email))
    WHERE Email IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_users_role_status
    ON USERS (RoleID, Status);

CREATE INDEX IF NOT EXISTS idx_users_branch_status
    ON USERS (BranchID, Status)
    WHERE BranchID IS NOT NULL;

-- =========================================================
-- 2. Product/POS search
-- POS va global search hay tim theo ten san pham, brand, SKU, barcode.
-- =========================================================
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

-- =========================================================
-- 3. Inventory hot paths
-- POS can check stock theo branch/variant; kho can loc low-stock va lich su moi.
-- =========================================================
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

-- =========================================================
-- 4. Purchase/transfer/adjustment lookup
-- Cac man van hanh hay loc theo status, branch, ngay tao.
-- =========================================================
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

-- =========================================================
-- 5. Sales/reporting lookup
-- Dashboard/report/POS can tong hop order, detail, payment, return nhanh hon.
-- =========================================================
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

-- =========================================================
-- 6. Optimized views for frontend
-- Gop san join san pham + bien the + ton kho de POS/stock doc nhe hon.
-- =========================================================
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

-- =========================================================
-- 7. Dashboard function
-- Cho phep frontend lay KPI tong quan bang mot RPC thay vi doc nhieu bang lon.
-- =========================================================
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

-- =========================================================
-- 8. Keyset/cursor pagination helpers
-- Khong dung DECLARE CURSOR cho web app. Keyset pagination on dinh hon voi
-- Supabase/PostgREST: lay trang tiep theo bang cap (timestamp, id).
-- =========================================================
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
