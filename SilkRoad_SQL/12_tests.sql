
-- A. KIỂM TRA DỮ LIỆU SAU IMPORT
-- 1. Kiểm tra số lượng dữ liệu trong các bảng chính
SELECT 'PRODUCT_CATEGORY' AS table_name, COUNT(*) AS total FROM PRODUCT_CATEGORY
UNION ALL
SELECT 'PRODUCT', COUNT(*) FROM PRODUCT
UNION ALL
SELECT 'ATTRIBUTE', COUNT(*) FROM ATTRIBUTE
UNION ALL
SELECT 'PRODUCT_VARIANT', COUNT(*) FROM PRODUCT_VARIANT
UNION ALL
SELECT 'PRODUCT_IMAGE', COUNT(*) FROM PRODUCT_IMAGE
UNION ALL
SELECT 'BRANCH', COUNT(*) FROM BRANCH
UNION ALL
SELECT 'SUPPLIER', COUNT(*) FROM SUPPLIER
UNION ALL
SELECT 'SUPPLIER_PRODUCT', COUNT(*) FROM SUPPLIER_PRODUCT
UNION ALL
SELECT 'STOCK', COUNT(*) FROM STOCK
UNION ALL
SELECT 'SALES_CHANNEL', COUNT(*) FROM SALES_CHANNEL
UNION ALL
SELECT 'CHANNEL_PRICE', COUNT(*) FROM CHANNEL_PRICE
ORDER BY table_name;

-- 2. Danh sách sản phẩm, biến thể, size và màu
SELECT
    p.ProductName,
    pc.CategoryName,
    p.Brand,
    p.Gender,
    pv.SKU,
    size_attr.Value AS Size,
    color_attr.Value AS Color,
    pv.CostPrice,
    pv.SellingPrice,
    pv.Status
FROM PRODUCT_VARIANT pv
JOIN PRODUCT p
    ON p.ProductID = pv.ProductID
JOIN PRODUCT_CATEGORY pc
    ON pc.CategoryID = p.CategoryID
LEFT JOIN ATTRIBUTE size_attr
    ON size_attr.AttributeID = pv.SizeAttributeID
LEFT JOIN ATTRIBUTE color_attr
    ON color_attr.AttributeID = pv.ColorAttributeID
ORDER BY p.ProductName, pv.SKU
LIMIT 20;

-- 3. Tồn kho theo chi nhánh
SELECT
    b.BranchName,
    p.ProductName,
    pv.SKU,
    size_attr.Value AS Size,
    color_attr.Value AS Color,
    s.Quantity AS TonVatLy,
    s.ReservedQuantity AS DaGiu,
    s.AvailableQuantity AS CoTheBan,
    s.MinStockLevel,
    s.MaxStockLevel
FROM STOCK s
JOIN BRANCH b
    ON b.BranchID = s.BranchID
JOIN PRODUCT_VARIANT pv
    ON pv.VariantID = s.VariantID
JOIN PRODUCT p
    ON p.ProductID = pv.ProductID
LEFT JOIN ATTRIBUTE size_attr
    ON size_attr.AttributeID = pv.SizeAttributeID
LEFT JOIN ATTRIBUTE color_attr
    ON color_attr.AttributeID = pv.ColorAttributeID
ORDER BY b.BranchName, p.ProductName, pv.SKU
LIMIT 30;

-- 4. Cảnh báo tồn kho thấp
SELECT
    b.BranchName,
    p.ProductName,
    pv.SKU,
    s.Quantity,
    s.ReservedQuantity,
    s.AvailableQuantity,
    s.MinStockLevel,
    CASE
        WHEN s.AvailableQuantity <= s.MinStockLevel THEN 'Cần nhập thêm'
        ELSE 'Đủ tồn'
    END AS StockWarning
FROM STOCK s
JOIN BRANCH b
    ON b.BranchID = s.BranchID
JOIN PRODUCT_VARIANT pv
    ON pv.VariantID = s.VariantID
JOIN PRODUCT p
    ON p.ProductID = pv.ProductID
WHERE s.AvailableQuantity <= s.MinStockLevel
ORDER BY s.AvailableQuantity ASC, p.ProductName;

-- 5. Giá bán theo từng kênh
SELECT
    pv.SKU,
    p.ProductName,
    sc.ChannelName,
    sc.ChannelType,
    pv.SellingPrice AS GiaMacDinh,
    cp.SellingPrice AS GiaTheoKenh
FROM CHANNEL_PRICE cp
JOIN SALES_CHANNEL sc
    ON sc.ChannelID = cp.ChannelID
JOIN PRODUCT_VARIANT pv
    ON pv.VariantID = cp.VariantID
JOIN PRODUCT p
    ON p.ProductID = pv.ProductID
ORDER BY pv.SKU, sc.ChannelName
LIMIT 40;

-- B. DEMO JSONB VÀ DỮ LIỆU MỞ RỘNG
-- 6. Dữ liệu JSONB trong bảng PRODUCT
SELECT
    ProductName,
    Brand,
    DynamicAttributes,
    DynamicAttributes ->> 'ma_san_pham' AS MaSanPham,
    DynamicAttributes ->> 'chat_lieu' AS ChatLieu,
    DynamicAttributes ->> 'don_vi_tinh' AS DonViTinh,
    DynamicAttributes ->> 'nguon_du_lieu' AS NguonDuLieu
FROM PRODUCT
ORDER BY ProductName;

-- 7. Tìm sản phẩm có thuộc tính chất liệu trong JSONB
SELECT
    ProductName,
    Brand,
    DynamicAttributes ->> 'chat_lieu' AS ChatLieu,
    DefaultSellingPrice
FROM PRODUCT
WHERE DynamicAttributes ? 'chat_lieu'
ORDER BY ProductName;

-- 8. Lọc sản phẩm theo chất liệu cụ thể trong JSONB
SELECT
    ProductName,
    Brand,
    DynamicAttributes ->> 'chat_lieu' AS ChatLieu
FROM PRODUCT
WHERE DynamicAttributes ->> 'chat_lieu' ILIKE '%cotton%';

-- C. NHÀ CUNG CẤP, NHẬP HÀNG VÀ TỒN KHO
-- 9. Nhà cung cấp và biến thể được cung ứng
SELECT
    s.SupplierName,
    s.TaxCode AS SupplierCode,
    p.ProductName,
    pv.SKU,
    sp.SupplierSKU,
    sp.ContractPrice,
    sp.LeadTimeDays,
    sp.MinOrderQuantity,
    sp.IsPreferred
FROM SUPPLIER_PRODUCT sp
JOIN SUPPLIER s
    ON s.SupplierID = sp.SupplierID
JOIN PRODUCT_VARIANT pv
    ON pv.VariantID = sp.VariantID
JOIN PRODUCT p
    ON p.ProductID = pv.ProductID
ORDER BY s.SupplierName, p.ProductName, pv.SKU
LIMIT 30;

-- 10. Phiếu nhập hàng và chi tiết phiếu nhập
SELECT
    po.PurchaseOrderID,
    sup.SupplierName,
    b.BranchName,
    po.ExpectedDate,
    po.ArrivalDate,
    po.Status,
    pv.SKU,
    p.ProductName,
    pod.RequestedQuantity,
    pod.ReceivedQuantity,
    pod.UnitPrice,
    pod.SubTotal
FROM PURCHASE_ORDER po
JOIN SUPPLIER sup
    ON sup.SupplierID = po.SupplierID
JOIN BRANCH b
    ON b.BranchID = po.BranchID
JOIN PURCHASE_ORDER_DETAIL pod
    ON pod.PurchaseOrderID = po.PurchaseOrderID
JOIN PRODUCT_VARIANT pv
    ON pv.VariantID = pod.VariantID
JOIN PRODUCT p
    ON p.ProductID = pv.ProductID
ORDER BY po.CreatedAt DESC, p.ProductName
LIMIT 30;

-- 11. Lịch sử biến động tồn kho
SELECT
    sh.Timestamp,
    b.BranchName,
    p.ProductName,
    pv.SKU,
    sh.TransactionType,
    sh.ReferenceType,
    sh.QuantityBefore,
    sh.QuantityChange,
    sh.QuantityAfter,
    u.FullName AS PerformedBy,
    sh.Note
FROM STOCK_HISTORY sh
JOIN BRANCH b
    ON b.BranchID = sh.BranchID
JOIN PRODUCT_VARIANT pv
    ON pv.VariantID = sh.VariantID
JOIN PRODUCT p
    ON p.ProductID = pv.ProductID
LEFT JOIN USERS u
    ON u.UserID = sh.PerformedBy
ORDER BY sh.Timestamp DESC
LIMIT 30;

-- D. ĐƠN HÀNG VÀ DOANH THU ĐA KÊNH
-- 12. Đơn hàng theo kênh bán
SELECT
    o.OrderID,
    o.OrderDate,
    sc.ChannelName,
    sc.ChannelType,
    b.BranchName,
    c.FullName AS CustomerName,
    o.OrderStatus,
    o.PaymentStatus,
    o.TotalAmount,
    o.DiscountAmount,
    o.ShippingFee,
    o.FinalAmount
FROM ORDERS o
JOIN SALES_CHANNEL sc
    ON sc.ChannelID = o.ChannelID
JOIN BRANCH b
    ON b.BranchID = o.BranchID
LEFT JOIN CUSTOMER c
    ON c.CustomerID = o.CustomerID
ORDER BY o.OrderDate DESC
LIMIT 20;

-- 13. Chi tiết đơn hàng
SELECT
    o.OrderID,
    o.OrderDate,
    sc.ChannelName,
    p.ProductName,
    pv.SKU,
    od.Quantity,
    od.UnitPrice,
    od.SubTotal
FROM ORDER_DETAIL od
JOIN ORDERS o
    ON o.OrderID = od.OrderID
JOIN SALES_CHANNEL sc
    ON sc.ChannelID = o.ChannelID
JOIN PRODUCT_VARIANT pv
    ON pv.VariantID = od.VariantID
JOIN PRODUCT p
    ON p.ProductID = pv.ProductID
ORDER BY o.OrderDate DESC, p.ProductName
LIMIT 30;

-- 14. Doanh thu theo kênh bán
SELECT
    sc.ChannelName,
    sc.ChannelType,
    COUNT(o.OrderID) AS TotalOrders,
    SUM(o.FinalAmount) AS TotalRevenue,
    ROUND(AVG(o.FinalAmount), 2) AS AverageOrderValue
FROM ORDERS o
JOIN SALES_CHANNEL sc
    ON sc.ChannelID = o.ChannelID
WHERE o.OrderStatus IN ('confirmed', 'processing', 'packed', 'shipped', 'delivered')
GROUP BY sc.ChannelName, sc.ChannelType
ORDER BY TotalRevenue DESC;

-- E. KIỂM TRA TOÀN VẸN DỮ LIỆU
-- 15. Kiểm tra dữ liệu tồn kho sai sau import
-- Kết quả mong đợi: không có dòng nào.
SELECT
    b.BranchName,
    p.ProductName,
    pv.SKU,
    s.Quantity,
    s.ReservedQuantity,
    s.AvailableQuantity
FROM STOCK s
JOIN BRANCH b
    ON b.BranchID = s.BranchID
JOIN PRODUCT_VARIANT pv
    ON pv.VariantID = s.VariantID
JOIN PRODUCT p
    ON p.ProductID = pv.ProductID
WHERE s.Quantity < 0
   OR s.ReservedQuantity < 0
   OR s.ReservedQuantity > s.Quantity;

-- 16. Kiểm tra SKU trùng
-- Kết quả mong đợi: không có dòng nào.
SELECT
    SKU,
    COUNT(*) AS SoLanXuatHien
FROM PRODUCT_VARIANT
GROUP BY SKU
HAVING COUNT(*) > 1;

-- 17. Kiểm tra sản phẩm chưa có biến thể
-- Kết quả mong đợi: không có dòng nào nếu dữ liệu đầy đủ.
SELECT
    p.ProductID,
    p.ProductName
FROM PRODUCT p
LEFT JOIN PRODUCT_VARIANT pv
    ON pv.ProductID = p.ProductID
WHERE pv.VariantID IS NULL;

-- 18. Kiểm tra biến thể chưa có tồn kho
-- Kết quả mong đợi: không có dòng nào nếu dữ liệu nhập mẫu đầy đủ.
SELECT
    p.ProductName,
    pv.SKU
FROM PRODUCT_VARIANT pv
JOIN PRODUCT p
    ON p.ProductID = pv.ProductID
LEFT JOIN STOCK s
    ON s.VariantID = pv.VariantID
WHERE s.VariantID IS NULL;

-- F. DEMO VIEW BÁO CÁO
-- 19. View tồn kho theo chi nhánh
SELECT *
FROM vw_stock_by_branch
ORDER BY BranchName, ProductName, SKU
LIMIT 30;

-- 20. View tổng hợp đơn hàng
SELECT *
FROM vw_order_summary
ORDER BY OrderDate DESC
LIMIT 20;

-- 21. View doanh thu theo kênh
SELECT *
FROM vw_revenue_by_channel
ORDER BY TotalRevenue DESC;

-- 22. View lịch sử biến động tồn kho
SELECT *
FROM vw_stock_movement_report
ORDER BY Timestamp DESC
LIMIT 30;

-- G. DEMO FUNCTION VÀ CURSOR
-- 23. Function lấy tồn kho khả dụng
SELECT
    b.BranchName,
    p.ProductName,
    pv.SKU,
    fn_get_available_stock(s.BranchID, s.VariantID) AS AvailableStock
FROM STOCK s
JOIN BRANCH b
    ON b.BranchID = s.BranchID
JOIN PRODUCT_VARIANT pv
    ON pv.VariantID = s.VariantID
JOIN PRODUCT p
    ON p.ProductID = pv.ProductID
ORDER BY AvailableStock ASC
LIMIT 20;

-- 24. Function tính tổng tiền đơn hàng
SELECT
    o.OrderID,
    o.TotalAmount AS TotalAmountInTable,
    fn_calculate_order_total(o.OrderID) AS TotalAmountCalculated,
    o.FinalAmount
FROM ORDERS o
ORDER BY o.OrderDate DESC
LIMIT 20;

-- 25. Function lấy lịch sử biến động tồn kho
WITH sample_stock AS (
    SELECT BranchID, VariantID
    FROM STOCK
    LIMIT 1
)
SELECT gsm.*
FROM sample_stock ss,
LATERAL fn_get_stock_movement(ss.BranchID, ss.VariantID) gsm;

-- 26. Cursor tồn kho thấp
-- Dùng PostgreSQL cursor thật trong fn_cursor_low_stock_report_app().
SELECT
    branch_name,
    sku,
    product_name,
    available_quantity,
    min_stock_level,
    suggested_reorder_quantity
FROM fn_cursor_low_stock_report_app(NULL, 20);

-- 26b. Contract bắt buộc giữa frontend và database
DO $$
DECLARE
    v_missing TEXT[];
BEGIN
    SELECT ARRAY_AGG(required_name)
    INTO v_missing
    FROM UNNEST(ARRAY[
        'vw_product_search_catalog',
        'vw_pos_variant_stock_catalog',
        'vw_product_variant_catalog',
        'vw_stock_by_branch',
        'vw_order_summary',
        'vw_revenue_by_channel'
    ]) AS required_name
    WHERE to_regclass('public.' || required_name) IS NULL;

    IF v_missing IS NOT NULL THEN
        RAISE EXCEPTION 'Missing required frontend views: %', v_missing;
    END IF;

    SELECT ARRAY_AGG(required_name)
    INTO v_missing
    FROM UNNEST(ARRAY[
        'fn_create_order_app(jsonb)',
        'fn_create_purchase_order_app(jsonb)',
        'fn_create_transfer_app(jsonb)',
        'fn_create_adjustment_app(jsonb)',
        'fn_create_return_app(jsonb)',
        'fn_set_inventory_allocation_app(jsonb)',
        'fn_cursor_low_stock_report_app(uuid,integer)'
    ]) AS required_name
    WHERE to_regprocedure('public.' || required_name) IS NULL;

    IF v_missing IS NOT NULL THEN
        RAISE EXCEPTION 'Missing required frontend RPC: %', v_missing;
    END IF;
END $$;

-- 27. Query hỗ trợ nếu cursor tồn kho thấp không trả dòng nào
SELECT
    b.BranchName,
    p.ProductName,
    pv.SKU,
    s.Quantity,
    s.MinStockLevel
FROM STOCK s
JOIN BRANCH b
    ON b.BranchID = s.BranchID
JOIN PRODUCT_VARIANT pv
    ON pv.VariantID = s.VariantID
JOIN PRODUCT p
    ON p.ProductID = pv.ProductID
ORDER BY s.Quantity ASC
LIMIT 10;

-- H. DEMO TRIGGER
-- 28. Demo trigger cập nhật tổng tiền đơn hàng
-- Chạy trong transaction để demo xong không làm thay đổi dữ liệu thật.
BEGIN;

WITH sample_order AS (
    SELECT OrderID
    FROM ORDERS
    LIMIT 1
),
sample_variant AS (
    SELECT VariantID, SellingPrice
    FROM PRODUCT_VARIANT
    LIMIT 1
)
INSERT INTO ORDER_DETAIL (
    OrderID,
    VariantID,
    Quantity,
    UnitPrice
)
SELECT
    sample_order.OrderID,
    sample_variant.VariantID,
    2,
    sample_variant.SellingPrice
FROM sample_order, sample_variant
ON CONFLICT (OrderID, VariantID) DO UPDATE SET
    Quantity = EXCLUDED.Quantity,
    UnitPrice = EXCLUDED.UnitPrice;

SELECT
    o.OrderID,
    o.TotalAmount,
    fn_calculate_order_total(o.OrderID) AS CalculatedTotal
FROM ORDERS o
WHERE o.OrderID = (
    SELECT OrderID
    FROM ORDERS
    LIMIT 1
);

ROLLBACK;

-- 29. Demo kiểm tra trigger chống sửa/xóa STOCK_HISTORY
-- Chạy trong transaction để an toàn. Nếu trigger hoạt động, câu UPDATE sẽ báo lỗi.
-- Lưu ý: Nếu chạy cả file một lần, có thể comment block này để tránh dừng file khi lỗi phát sinh.
-- BEGIN;
-- UPDATE STOCK_HISTORY
-- SET Note = 'Thử sửa lịch sử tồn kho'
-- WHERE HistoryID = (
--     SELECT HistoryID
--     FROM STOCK_HISTORY
--     LIMIT 1
-- );
-- ROLLBACK;

-- I. PHÂN BỔ TỒN KHO THEO KÊNH VÀ CHỐNG OVERSELL
-- 30. Phân bổ tồn kho theo kênh
SELECT
    b.BranchName,
    p.ProductName,
    pv.SKU,
    sc.ChannelName,
    ia.AllocatedQuantity,
    ia.SoldQuantity,
    ia.AvailableForChannel,
    s.Quantity AS StockQuantity
FROM INVENTORY_ALLOCATION ia
JOIN BRANCH b
    ON b.BranchID = ia.BranchID
JOIN PRODUCT_VARIANT pv
    ON pv.VariantID = ia.VariantID
JOIN PRODUCT p
    ON p.ProductID = pv.ProductID
JOIN SALES_CHANNEL sc
    ON sc.ChannelID = ia.ChannelID
JOIN STOCK s
    ON s.BranchID = ia.BranchID
   AND s.VariantID = ia.VariantID
ORDER BY b.BranchName, pv.SKU, sc.ChannelName
LIMIT 40;

-- 31. Kiểm tra tổng phân bổ có vượt tồn không
SELECT
    b.BranchName,
    p.ProductName,
    pv.SKU,
    s.Quantity AS StockQuantity,
    COALESCE(SUM(ia.AllocatedQuantity), 0) AS TotalAllocated,
    s.Quantity - COALESCE(SUM(ia.AllocatedQuantity), 0) AS RemainingUnallocated
FROM STOCK s
JOIN BRANCH b
    ON b.BranchID = s.BranchID
JOIN PRODUCT_VARIANT pv
    ON pv.VariantID = s.VariantID
JOIN PRODUCT p
    ON p.ProductID = pv.ProductID
LEFT JOIN INVENTORY_ALLOCATION ia
    ON ia.BranchID = s.BranchID
   AND ia.VariantID = s.VariantID
GROUP BY
    b.BranchName,
    p.ProductName,
    pv.SKU,
    s.Quantity
ORDER BY RemainingUnallocated ASC;

-- J. ĐỒNG BỘ KÊNH BÁN, WEBHOOK VÀ JSONB PAYLOAD
-- 32. Channel Sync Log / JSONB webhook
SELECT
    csl.LogID,
    sc.ChannelName,
    csl.EventType,
    csl.ExternalOrderID,
    csl.Status,
    csl.RetryCount,
    csl.Payload,
    csl.ReceivedAt
FROM CHANNEL_SYNC_LOG csl
JOIN SALES_CHANNEL sc
    ON sc.ChannelID = csl.ChannelID
ORDER BY csl.ReceivedAt DESC
LIMIT 20;

-- 33. Lấy trường cụ thể trong payload JSONB
SELECT
    csl.ExternalOrderID,
    csl.EventType,
    csl.Payload ->> 'order_status' AS OrderStatusFromPayload,
    csl.Payload ->> 'tracking_number' AS TrackingNumber
FROM CHANNEL_SYNC_LOG csl
WHERE csl.Payload IS NOT NULL
LIMIT 20;

-- K. NGƯỜI DÙNG, VAI TRÒ VÀ CHI NHÁNH
-- 34. Danh sách người dùng, vai trò và chi nhánh
SELECT
    u.FullName,
    u.Username,
    r.RoleName,
    b.BranchName,
    u.Status,
    u.LastLoginAt
FROM USERS u
JOIN ROLE r
    ON r.RoleID = u.RoleID
LEFT JOIN BRANCH b
    ON b.BranchID = u.BranchID
ORDER BY r.RoleName, u.Username;

-- 35. Kiểm tra quyền trong mảng Permissions của ROLE
SELECT
    RoleName,
    Permissions,
    CASE
        WHEN 'stock.view' = ANY(Permissions) THEN 'Có quyền xem tồn kho'
        ELSE 'Không có quyền xem tồn kho'
    END AS StockPermission
FROM ROLE
ORDER BY RoleName;
