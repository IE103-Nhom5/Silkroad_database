CREATE OR REPLACE VIEW vw_product_variant_catalog AS
SELECT
    p.ProductID,
    p.ProductName,
    p.Brand,
    p.Gender,
    pc.CategoryName,
    pv.VariantID,
    pv.SKU,
    pv.Barcode,
    pv.SellingPrice,
    size_attr.Value AS SizeValue,
    color_attr.Value AS ColorValue,
    color_attr.HexCode,
    p.DynamicAttributes
FROM PRODUCT_VARIANT pv
JOIN PRODUCT p ON p.ProductID = pv.ProductID
JOIN PRODUCT_CATEGORY pc ON pc.CategoryID = p.CategoryID
LEFT JOIN ATTRIBUTE size_attr ON size_attr.AttributeID = pv.SizeAttributeID
LEFT JOIN ATTRIBUTE color_attr ON color_attr.AttributeID = pv.ColorAttributeID;

CREATE OR REPLACE VIEW vw_stock_by_branch AS
SELECT
    b.BranchID,
    b.BranchName,
    pv.VariantID,
    pv.SKU,
    p.ProductName,
    s.Quantity,
    s.ReservedQuantity,
    s.AvailableQuantity,
    s.MinStockLevel,
    s.MaxStockLevel,
    s.LastUpdated
FROM STOCK s
JOIN BRANCH b ON b.BranchID = s.BranchID
JOIN PRODUCT_VARIANT pv ON pv.VariantID = s.VariantID
JOIN PRODUCT p ON p.ProductID = pv.ProductID;

CREATE OR REPLACE VIEW vw_low_stock_alert AS
SELECT
    b.BranchName,
    pv.SKU,
    p.ProductName,
    s.Quantity,
    s.MinStockLevel,
    s.LastUpdated
FROM STOCK s
JOIN BRANCH b ON b.BranchID = s.BranchID
JOIN PRODUCT_VARIANT pv ON pv.VariantID = s.VariantID
JOIN PRODUCT p ON p.ProductID = pv.ProductID
WHERE s.Quantity <= s.MinStockLevel;

CREATE OR REPLACE VIEW vw_order_summary AS
SELECT
    o.OrderID,
    o.OrderDate,
    o.OrderStatus,
    o.PaymentStatus,
    o.TotalAmount,
    o.DiscountAmount,
    o.ShippingFee,
    o.FinalAmount,
    sc.ChannelName,
    sc.ChannelType,
    b.BranchName,
    c.FullName AS CustomerName,
    u.FullName AS CreatedByName
FROM ORDERS o
JOIN SALES_CHANNEL sc ON sc.ChannelID = o.ChannelID
JOIN BRANCH b ON b.BranchID = o.BranchID
LEFT JOIN CUSTOMER c ON c.CustomerID = o.CustomerID
JOIN USERS u ON u.UserID = o.CreatedBy;

CREATE OR REPLACE VIEW vw_revenue_by_channel AS
SELECT
    sc.ChannelID,
    sc.ChannelName,
    sc.ChannelType,
    COUNT(o.OrderID) AS TotalOrders,
    COALESCE(SUM(o.FinalAmount), 0) AS TotalRevenue,
    COALESCE(AVG(o.FinalAmount), 0) AS AverageOrderValue
FROM ORDERS o
JOIN SALES_CHANNEL sc ON sc.ChannelID = o.ChannelID
WHERE o.OrderStatus = 'delivered'
GROUP BY sc.ChannelID, sc.ChannelName, sc.ChannelType;

CREATE OR REPLACE VIEW vw_stock_movement_report AS
SELECT
    sh.HistoryID,
    b.BranchName,
    p.ProductName,
    pv.SKU,
    sh.TransactionType,
    sh.ReferenceType,
    sh.ReferenceID,
    sh.QuantityChange,
    sh.QuantityBefore,
    sh.QuantityAfter,
    u.FullName AS PerformedByName,
    sh.Timestamp
FROM STOCK_HISTORY sh
JOIN BRANCH b ON b.BranchID = sh.BranchID
JOIN PRODUCT_VARIANT pv ON pv.VariantID = sh.VariantID
JOIN PRODUCT p ON p.ProductID = pv.ProductID
LEFT JOIN USERS u ON u.UserID = sh.PerformedBy;
