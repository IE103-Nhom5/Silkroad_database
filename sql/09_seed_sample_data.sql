-- ROLE
INSERT INTO ROLE (RoleID, RoleName, Permissions, Description) VALUES
('00000000-0000-0000-0000-000000000101', 'admin',
 ARRAY['stock.view','stock.adjust','purchase_order.create','purchase_order.approve','transfer.create','transfer.approve','order.create','order.cancel','report.export','channel.manage','user.manage'],
 'Quản trị viên toàn hệ thống'),
('00000000-0000-0000-0000-000000000102', 'branch_manager',
 ARRAY['stock.view','stock.adjust','purchase_order.approve','transfer.approve','order.create','order.cancel','report.export'],
 'Quản lý chi nhánh'),
('00000000-0000-0000-0000-000000000103', 'warehouse_staff',
 ARRAY['stock.view','purchase_order.create','transfer.create'],
 'Nhân viên kho'),
('00000000-0000-0000-0000-000000000104', 'sales_staff',
 ARRAY['stock.view','order.create'],
 'Nhân viên bán hàng')
ON CONFLICT (RoleID) DO NOTHING;

-- BRANCH
INSERT INTO BRANCH (BranchID, BranchName, BranchType, Address, Province, PhoneNumber, Email, Status) VALUES
('00000000-0000-0000-0000-000000000201', 'Kho trung tâm SilkRoad', 'central_warehouse', 'Khu công nghiệp Tân Bình, TP.HCM', 'TP. Hồ Chí Minh', '0280000001', 'warehouse@silkroad.local', 'active'),
('00000000-0000-0000-0000-000000000202', 'Cửa hàng Quận 1', 'retail_store', 'Nguyễn Huệ, Quận 1, TP.HCM', 'TP. Hồ Chí Minh', '0280000002', 'q1@silkroad.local', 'active')
ON CONFLICT (BranchID) DO NOTHING;

-- USERS
INSERT INTO USERS (UserID, FullName, Username, PasswordHash, RoleID, BranchID, Status) VALUES
('00000000-0000-0000-0000-000000000301', 'Admin SilkRoad', 'admin', '$2b$12$examplebcryptpasswordhash0000000000000000000000000', '00000000-0000-0000-0000-000000000101', NULL, 'active'),
('00000000-0000-0000-0000-000000000302', 'Nguyễn Văn Kho', 'warehouse01', '$2b$12$examplebcryptpasswordhash0000000000000000000000001', '00000000-0000-0000-0000-000000000103', '00000000-0000-0000-0000-000000000201', 'active'),
('00000000-0000-0000-0000-000000000303', 'Trần Thị Bán Hàng', 'sales01', '$2b$12$examplebcryptpasswordhash0000000000000000000000002', '00000000-0000-0000-0000-000000000104', '00000000-0000-0000-0000-000000000202', 'active'),
('00000000-0000-0000-0000-000000000304', 'Marketplace System', 'system_marketplace', '$2b$12$examplebcryptpasswordhash0000000000000000000000003', '00000000-0000-0000-0000-000000000101', NULL, 'active')
ON CONFLICT (UserID) DO NOTHING;

-- PRODUCT CATEGORY
INSERT INTO PRODUCT_CATEGORY (CategoryID, ParentCategoryID, CategoryName, Slug, DisplayOrder, Status) VALUES
('00000000-0000-0000-0000-000000000401', NULL, 'Thời trang nữ', 'thoi-trang-nu', 1, 'active'),
('00000000-0000-0000-0000-000000000402', '00000000-0000-0000-0000-000000000401', 'Áo sơ mi nữ', 'ao-so-mi-nu', 1, 'active')
ON CONFLICT (CategoryID) DO NOTHING;

-- PRODUCT
INSERT INTO PRODUCT (
    ProductID, CategoryID, ProductName, Slug, Brand, Gender,
    Description, DefaultSellingPrice, Tags, CollectionName, Status, DynamicAttributes
) VALUES
('00000000-0000-0000-0000-000000000501',
 '00000000-0000-0000-0000-000000000402',
 'Áo Sơ Mi Lụa Cổ V Thanh Lịch',
 'ao-so-mi-lua-co-v-thanh-lich',
 'SilkRoad',
 'female',
 'Áo sơ mi lụa cổ V phù hợp môi trường công sở.',
 350000,
 ARRAY['new-arrival','best-seller'],
 'Thu Đông 2026',
 'active',
 '{"chat_lieu": "lụa", "kieu_co": "cổ V", "kieu_tay": "tay dài", "form_dang": "regular fit"}'::JSONB)
ON CONFLICT (ProductID) DO NOTHING;

-- ATTRIBUTE
INSERT INTO ATTRIBUTE (AttributeID, AttributeType, Value, DisplayValue, HexCode, SortOrder, Status) VALUES
('00000000-0000-0000-0000-000000000601', 'size', 'S', 'Size S', NULL, 1, 'active'),
('00000000-0000-0000-0000-000000000602', 'size', 'M', 'Size M', NULL, 2, 'active'),
('00000000-0000-0000-0000-000000000603', 'color', 'WHITE', 'Trắng', '#FFFFFF', 1, 'active'),
('00000000-0000-0000-0000-000000000604', 'color', 'NAVY', 'Xanh navy', '#1B3A6B', 2, 'active')
ON CONFLICT (AttributeID) DO NOTHING;

-- PRODUCT VARIANT
INSERT INTO PRODUCT_VARIANT (
    VariantID, ProductID, SizeAttributeID, ColorAttributeID, SKU, Barcode,
    CostPrice, SellingPrice, Weight, Status
) VALUES
('00000000-0000-0000-0000-000000000701',
 '00000000-0000-0000-0000-000000000501',
 '00000000-0000-0000-0000-000000000601',
 '00000000-0000-0000-0000-000000000603',
 'SR-SML-WHT-S',
 '893000000001',
 150000,
 350000,
 0.250,
 'active'),
('00000000-0000-0000-0000-000000000702',
 '00000000-0000-0000-0000-000000000501',
 '00000000-0000-0000-0000-000000000602',
 '00000000-0000-0000-0000-000000000604',
 'SR-SML-NVY-M',
 '893000000002',
 150000,
 350000,
 0.260,
 'active')
ON CONFLICT (VariantID) DO NOTHING;

-- SUPPLIER
INSERT INTO SUPPLIER (SupplierID, SupplierName, TaxCode, PhoneNumber, Email, Address, PaymentTermDays, Status) VALUES
('00000000-0000-0000-0000-000000000801', 'Công ty May Lụa Việt', '0310000001', '0900000001', 'contact@luaviet.local', 'TP.HCM', 15, 'active')
ON CONFLICT (SupplierID) DO NOTHING;

INSERT INTO SUPPLIER_PRODUCT (SupplierID, VariantID, SupplierSKU, ContractPrice, LeadTimeDays, MinOrderQuantity, IsPreferred) VALUES
('00000000-0000-0000-0000-000000000801', '00000000-0000-0000-0000-000000000701', 'LV-SML-WHT-S', 150000, 7, 20, TRUE),
('00000000-0000-0000-0000-000000000801', '00000000-0000-0000-0000-000000000702', 'LV-SML-NVY-M', 150000, 7, 20, TRUE)
ON CONFLICT (SupplierID, VariantID) DO NOTHING;

-- SALES CHANNEL
INSERT INTO SALES_CHANNEL (ChannelID, ChannelName, ChannelType, Status, ChannelConfig) VALUES
('00000000-0000-0000-0000-000000000901', 'POS Quận 1', 'pos', 'active', '{"branch_id": "00000000-0000-0000-0000-000000000202"}'::JSONB),
('00000000-0000-0000-0000-000000000902', 'Website SilkRoad', 'website', 'active', '{"auto_sync_stock": true}'::JSONB),
('00000000-0000-0000-0000-000000000903', 'Shopee Official Store', 'shopee', 'active', '{"shop_id": "demo_shop", "auto_sync_stock": true}'::JSONB)
ON CONFLICT (ChannelID) DO NOTHING;

-- STOCK
INSERT INTO STOCK (BranchID, VariantID, Quantity, ReservedQuantity, MinStockLevel, MaxStockLevel) VALUES
('00000000-0000-0000-0000-000000000201', '00000000-0000-0000-0000-000000000701', 100, 0, 10, 200),
('00000000-0000-0000-0000-000000000201', '00000000-0000-0000-0000-000000000702', 80, 0, 10, 200),
('00000000-0000-0000-0000-000000000202', '00000000-0000-0000-0000-000000000701', 20, 0, 5, 60),
('00000000-0000-0000-0000-000000000202', '00000000-0000-0000-0000-000000000702', 15, 0, 5, 60)
ON CONFLICT (BranchID, VariantID) DO NOTHING;

-- INVENTORY ALLOCATION
INSERT INTO INVENTORY_ALLOCATION (BranchID, VariantID, ChannelID, AllocatedQuantity, SoldQuantity) VALUES
('00000000-0000-0000-0000-000000000202', '00000000-0000-0000-0000-000000000701', '00000000-0000-0000-0000-000000000901', 10, 0),
('00000000-0000-0000-0000-000000000202', '00000000-0000-0000-0000-000000000701', '00000000-0000-0000-0000-000000000902', 5, 0),
('00000000-0000-0000-0000-000000000202', '00000000-0000-0000-0000-000000000701', '00000000-0000-0000-0000-000000000903', 5, 0),
('00000000-0000-0000-0000-000000000202', '00000000-0000-0000-0000-000000000702', '00000000-0000-0000-0000-000000000901', 8, 0),
('00000000-0000-0000-0000-000000000202', '00000000-0000-0000-0000-000000000702', '00000000-0000-0000-0000-000000000902', 4, 0)
ON CONFLICT (BranchID, VariantID, ChannelID) DO NOTHING;

-- CUSTOMER
INSERT INTO CUSTOMER (CustomerID, FullName, PhoneNumber, Email, Gender, LoyaltyPoints, TotalSpent, Status) VALUES
('00000000-0000-0000-0000-000000001101', 'Nguyễn Thị Hoa', '0901234567', 'hoa@example.local', 'female', 0, 0, 'active')
ON CONFLICT (CustomerID) DO NOTHING;

-- ORDER + DETAIL
INSERT INTO ORDERS (
    OrderID, ChannelID, BranchID, CustomerID, CreatedBy,
    OrderStatus, PaymentStatus, DiscountAmount, ShippingFee, Note
) VALUES
('00000000-0000-0000-0000-000000001201',
 '00000000-0000-0000-0000-000000000901',
 '00000000-0000-0000-0000-000000000202',
 '00000000-0000-0000-0000-000000001101',
 '00000000-0000-0000-0000-000000000303',
 'new',
 'paid',
 0,
 0,
 'Đơn hàng mẫu để kiểm thử sp_confirm_order')
ON CONFLICT (OrderID) DO NOTHING;

INSERT INTO ORDER_DETAIL (OrderID, VariantID, Quantity, UnitPrice) VALUES
('00000000-0000-0000-0000-000000001201', '00000000-0000-0000-0000-000000000701', 2, 350000)
ON CONFLICT (OrderID, VariantID) DO NOTHING;

INSERT INTO PAYMENT (PaymentID, OrderID, Method, Amount, Status, PaidAt) VALUES
('00000000-0000-0000-0000-000000001301',
 '00000000-0000-0000-0000-000000001201',
 'cash',
 700000,
 'success',
 NOW())
ON CONFLICT (PaymentID) DO NOTHING;

-- PURCHASE ORDER
INSERT INTO PURCHASE_ORDER (
    PurchaseOrderID, SupplierID, BranchID, CreatedBy, ExpectedDate, Status, Note
) VALUES
('00000000-0000-0000-0000-000000001401',
 '00000000-0000-0000-0000-000000000801',
 '00000000-0000-0000-0000-000000000201',
 '00000000-0000-0000-0000-000000000302',
 CURRENT_DATE + INTERVAL '7 days',
 'approved',
 'Phiếu nhập mẫu')
ON CONFLICT (PurchaseOrderID) DO NOTHING;

INSERT INTO PURCHASE_ORDER_DETAIL (
    PurchaseOrderID, VariantID, RequestedQuantity, ReceivedQuantity, UnitPrice
) VALUES
('00000000-0000-0000-0000-000000001401', '00000000-0000-0000-0000-000000000701', 30, 30, 150000)
ON CONFLICT (PurchaseOrderID, VariantID) DO NOTHING;

-- TRANSFER ORDER
INSERT INTO TRANSFER_ORDER (
    TransferID, FromBranchID, ToBranchID, CreatedBy, Status, Note
) VALUES
('00000000-0000-0000-0000-000000001501',
 '00000000-0000-0000-0000-000000000201',
 '00000000-0000-0000-0000-000000000202',
 '00000000-0000-0000-0000-000000000302',
 'approved',
 'Phiếu chuyển mẫu')
ON CONFLICT (TransferID) DO NOTHING;

INSERT INTO TRANSFER_ORDER_DETAIL (TransferID, VariantID, RequestedQuantity, ActualQuantity) VALUES
('00000000-0000-0000-0000-000000001501', '00000000-0000-0000-0000-000000000702', 5, 5)
ON CONFLICT (TransferID, VariantID) DO NOTHING;

-- STOCK ADJUSTMENT
INSERT INTO STOCK_ADJUSTMENT (AdjustmentID, BranchID, CreatedBy, Status, Note) VALUES
('00000000-0000-0000-0000-000000001601',
 '00000000-0000-0000-0000-000000000202',
 '00000000-0000-0000-0000-000000000302',
 'pending_approval',
 'Phiếu kiểm kho mẫu')
ON CONFLICT (AdjustmentID) DO NOTHING;

INSERT INTO STOCK_ADJUSTMENT_DETAIL (AdjustmentID, VariantID, SystemQuantity, ActualQuantity) VALUES
('00000000-0000-0000-0000-000000001601', '00000000-0000-0000-0000-000000000701', 20, 19)
ON CONFLICT (AdjustmentID, VariantID) DO NOTHING;
