# Hệ Thống Quản Lý Hàng Hóa Đa Kênh — Chuỗi Thời Trang Bán Lẻ
> **Stack:** PostgreSQL · Relational + Document Hybrid
> **Phiên bản tối giản:** 28 bảng

---

## SECTION 1 — PRODUCT (5 bảng)

### 1.1 PRODUCT_CATEGORY (`NHOMHANG`)
*Phân loại sản phẩm. Hỗ trợ phân cấp: Áo → Áo thun → Áo thun oversize.*

| Cột | Kiểu | Ghi chú |
|---|---|---|
| **CategoryID** | `UUID` PK | DEFAULT `gen_random_uuid()` |
| **ParentCategoryID** | `UUID` FK → self | `NULL` = category gốc |
| **CategoryName** | `VARCHAR(100)` UNIQUE | |
| **Slug** | `VARCHAR(120)` UNIQUE | URL-friendly. VD: `ao-thun`, `quan-jeans` |
| **DisplayOrder** | `SMALLINT` | DEFAULT `0` |
| **Status** | `ENUM(active, inactive)` | |
| **CreatedAt** | `TIMESTAMP` | DEFAULT `NOW()` |
| **UpdatedAt** | `TIMESTAMP` | |

> ~~SizeGuideID~~ — đã bỏ cùng bảng SIZE_GUIDE.
> **Index:** `(ParentCategoryID)`.

---

### 1.2 PRODUCT (`SANPHAM`)
*Sản phẩm chủ. Template sinh ra các variant.*

| Cột | Kiểu | Ghi chú |
|---|---|---|
| **ProductID** | `UUID` PK | |
| **CategoryID** | `UUID` FK → `PRODUCT_CATEGORY` | |
| **ProductName** | `VARCHAR(150)` | |
| **Slug** | `VARCHAR(180)` UNIQUE | |
| **Brand** | `VARCHAR(100)` | Optional |
| **Gender** | `ENUM(male, female, unisex, kids)` | |
| **Description** | `TEXT` | Optional |
| **DefaultSellingPrice** | `DECIMAL(12,2)` | CHECK ≥ 0 |
| **Tags** | `TEXT[]` | VD: `{new-arrival, best-seller, sale}` |
| **CollectionName** | `VARCHAR(150)` | Optional. VD: "Thu Đông 2025" |
| **Status** | `ENUM(active, inactive, discontinued)` | |
| **DynamicAttributes** | `JSONB` | Thuộc tính đặc thù theo category |
| **CreatedAt** | `TIMESTAMP` | |
| **UpdatedAt** | `TIMESTAMP` | |

> **Index:** `GIN(DynamicAttributes)`, `GIN(Tags)`, `(CategoryID, Status, Gender)`.

---

### 1.3 ATTRIBUTE (`THUOCTINH`)
*Giá trị chuẩn hóa dùng để sinh variant.*

| Cột | Kiểu | Ghi chú |
|---|---|---|
| **AttributeID** | `UUID` PK | |
| **AttributeType** | `VARCHAR(50)` | `size`, `color` |
| **Value** | `VARCHAR(100)` | `XS`, `S`, `M`, `Navy`, `Sage Green`... |
| **DisplayValue** | `VARCHAR(100)` | Optional. VD: `Xanh Navy` |
| **HexCode** | `CHAR(7)` | Optional. Chỉ khi `color`. VD: `#1B3A6B` |
| **SortOrder** | `SMALLINT` | DEFAULT `0` |
| **Status** | `ENUM(active, inactive)` | |

> **Unique:** `(AttributeType, Value)`. **Index:** `(AttributeType, SortOrder)`.

---

### 1.4 PRODUCT_VARIANT (`BIENTHESANPHAM`)
*Cấp độ SKU. Đơn vị theo dõi tồn kho, bán hàng, và vận chuyển.*

| Cột | Kiểu | Ghi chú |
|---|---|---|
| **VariantID** | `UUID` PK | |
| **ProductID** | `UUID` FK → `PRODUCT` | |
| **SizeAttributeID** | `UUID` FK → `ATTRIBUTE` | |
| **ColorAttributeID** | `UUID` FK → `ATTRIBUTE` | |
| **SKU** | `VARCHAR(30)` UNIQUE | Gợi ý: `{BRAND}-{CODE}-{COLOR}-{SIZE}` |
| **Barcode** | `VARCHAR(50)` UNIQUE | Optional. EAN-13 hoặc QR |
| **CostPrice** | `DECIMAL(12,2)` | CHECK ≥ 0 |
| **SellingPrice** | `DECIMAL(12,2)` | CHECK ≥ CostPrice |
| **Weight** | `DECIMAL(8,3)` | Optional. Gram — tính phí ship |
| **Status** | `ENUM(active, inactive, out_of_production)` | |
| **CreatedAt** | `TIMESTAMP` | |

> **Unique:** `(ProductID, SizeAttributeID, ColorAttributeID)`.

---

### 1.5 PRODUCT_IMAGE (`ANH_SANPHAM`)
*Gộp ảnh sản phẩm và ảnh variant vào một bảng. `VariantID NULL` = ảnh chung của sản phẩm.*

| Cột | Kiểu | Ghi chú |
|---|---|---|
| **ImageID** | `UUID` PK | |
| **ProductID** | `UUID` FK → `PRODUCT` | |
| **VariantID** | `UUID` FK → `PRODUCT_VARIANT` | Optional. `NULL` = ảnh sản phẩm chung |
| **ImageURL** | `TEXT` | |
| **AltText** | `VARCHAR(200)` | Optional |
| **SortOrder** | `SMALLINT` | `0` = ảnh đại diện chính |
| **CreatedAt** | `TIMESTAMP` | |

> **Index:** `(ProductID, VariantID, SortOrder ASC)`.
> Query ảnh sản phẩm: `WHERE ProductID = ? AND VariantID IS NULL`.
> Query ảnh variant: `WHERE VariantID = ?`.

---

## SECTION 2 — BRANCHES & SUPPLIERS (3 bảng)

### 2.1 BRANCH (`CHINHANH`)

| Cột | Kiểu | Ghi chú |
|---|---|---|
| **BranchID** | `UUID` PK | |
| **BranchName** | `VARCHAR(100)` UNIQUE | |
| **BranchType** | `ENUM(retail_store, central_warehouse, sub_warehouse)` | |
| **Address** | `VARCHAR(255)` | |
| **Province** | `VARCHAR(100)` | Nhóm theo khu vực báo cáo |
| **PhoneNumber** | `VARCHAR(15)` | |
| **Email** | `VARCHAR(100)` | Optional |
| **Coordinates** | `GEOGRAPHY(POINT)` | Optional |
| **OpenTime** | `TIME` | Optional |
| **CloseTime** | `TIME` | Optional |
| **Status** | `ENUM(active, inactive, renovating)` | |
| **CreatedAt** | `TIMESTAMP` | |

---

### 2.2 SUPPLIER (`NHACUNGCAP`)

| Cột | Kiểu | Ghi chú |
|---|---|---|
| **SupplierID** | `UUID` PK | |
| **SupplierName** | `VARCHAR(100)` | |
| **TaxCode** | `VARCHAR(20)` UNIQUE | Mã số thuế |
| **PhoneNumber** | `VARCHAR(15)` | |
| **Email** | `VARCHAR(100)` | |
| **Address** | `VARCHAR(255)` | |
| **PaymentTermDays** | `SMALLINT` | DEFAULT `0`. `0` = thanh toán ngay |
| **Status** | `ENUM(active, inactive)` | |
| **CreatedAt** | `TIMESTAMP` | |

---

### 2.3 SUPPLIER_PRODUCT (`NHACUNGCAP_SANPHAM`)
*Map nhà cung cấp — variant kèm giá hợp đồng.*

| Cột | Kiểu | Ghi chú |
|---|---|---|
| **SupplierID** | `UUID` PK FK → `SUPPLIER` | |
| **VariantID** | `UUID` PK FK → `PRODUCT_VARIANT` | |
| **SupplierSKU** | `VARCHAR(50)` | Optional |
| **ContractPrice** | `DECIMAL(12,2)` | CHECK ≥ 0 |
| **LeadTimeDays** | `SMALLINT` | |
| **MinOrderQuantity** | `INT` | DEFAULT `1` |
| **IsPreferred** | `BOOLEAN` | DEFAULT `FALSE` |
| **UpdatedAt** | `TIMESTAMP` | |

> **Unique index:** `(VariantID) WHERE IsPreferred = TRUE`.

---

## SECTION 3 — INVENTORY (9 bảng)

### 3.1 STOCK (`TONKHO`)

| Cột | Kiểu | Ghi chú |
|---|---|---|
| **BranchID** | `UUID` PK FK → `BRANCH` | |
| **VariantID** | `UUID` PK FK → `PRODUCT_VARIANT` | |
| **Quantity** | `INT` | CHECK ≥ 0. Tổng tồn kho vật lý |
| **ReservedQuantity** | `INT` | DEFAULT `0`. Đã phân bổ cho các kênh |
| **AvailableQuantity** | `INT` GENERATED | `Quantity - ReservedQuantity` |
| **MinStockLevel** | `INT` | DEFAULT `0`. Ngưỡng cảnh báo |
| **MaxStockLevel** | `INT` | Optional |
| **LastUpdated** | `TIMESTAMP` | DEFAULT `NOW()` |

> **Check:** `ReservedQuantity <= Quantity`, `MinStockLevel < MaxStockLevel`.

---

### 3.2 STOCK_HISTORY (`LICHSUTONKHO`)
*Audit log bất biến. Không UPDATE, không DELETE.*

| Cột | Kiểu | Ghi chú |
|---|---|---|
| **HistoryID** | `UUID` PK | |
| **BranchID** | `UUID` FK → `BRANCH` | |
| **VariantID** | `UUID` FK → `PRODUCT_VARIANT` | |
| **TransactionType** | `ENUM` | `purchase`, `sales`, `transfer_in`, `transfer_out`, `adjustment`, `return`, `damage_write_off` |
| **ReferenceType** | `VARCHAR(30)` | `PURCHASE_ORDER`, `TRANSFER_ORDER`, `ORDER`, `RETURN_ORDER`, `STOCK_ADJUSTMENT` |
| **ReferenceID** | `UUID` | ID chứng từ gốc |
| **QuantityChange** | `INT` | Dương = nhập, âm = xuất |
| **QuantityBefore** | `INT` | |
| **QuantityAfter** | `INT` | CHECK ≥ 0 |
| **PerformedBy** | `UUID` FK → `USER` | |
| **Timestamp** | `TIMESTAMP` | DEFAULT `NOW()` |
| **Note** | `TEXT` | Optional |

> **Index:** `(BranchID, VariantID, Timestamp DESC)`, `(ReferenceType, ReferenceID)`.

---

### 3.3 INVENTORY_ALLOCATION (`PHANBOTONGKHO`)
*Phân bổ tồn kho theo kênh. Cơ chế chống oversell.*

| Cột | Kiểu | Ghi chú |
|---|---|---|
| **BranchID** | `UUID` PK FK → `BRANCH` | |
| **VariantID** | `UUID` PK FK → `PRODUCT_VARIANT` | |
| **ChannelID** | `UUID` PK FK → `SALES_CHANNEL` | |
| **AllocatedQuantity** | `INT` | CHECK ≥ 0 |
| **SoldQuantity** | `INT` | DEFAULT `0` |
| **AvailableForChannel** | `INT` GENERATED | `AllocatedQuantity - SoldQuantity` |
| **UpdatedAt** | `TIMESTAMP` | |

> **Check:** `SoldQuantity <= AllocatedQuantity`.
> **Trigger:** Tổng `AllocatedQuantity` của tất cả kênh ≤ `STOCK.Quantity`.

---

### 3.4 PURCHASE_ORDER (`PHIEUNHAP`)

| Cột | Kiểu | Ghi chú |
|---|---|---|
| **PurchaseOrderID** | `UUID` PK | |
| **SupplierID** | `UUID` FK → `SUPPLIER` | |
| **BranchID** | `UUID` FK → `BRANCH` | Kho nhận hàng |
| **CreatedBy** | `UUID` FK → `USER` | |
| **ApprovedBy** | `UUID` FK → `USER` | Optional |
| **ExpectedDate** | `DATE` | |
| **ArrivalDate** | `TIMESTAMP` | Optional |
| **Status** | `ENUM(draft, pending, approved, received, cancelled)` | |
| **TotalAmount** | `DECIMAL(14,2)` | DEFAULT `0` |
| **Note** | `TEXT` | Optional |
| **CreatedAt** | `TIMESTAMP` | |

---

### 3.5 PURCHASE_ORDER_DETAIL (`CT_PHIEUNHAP`)

| Cột | Kiểu | Ghi chú |
|---|---|---|
| **PurchaseOrderID** | `UUID` PK FK → `PURCHASE_ORDER` | |
| **VariantID** | `UUID` PK FK → `PRODUCT_VARIANT` | |
| **RequestedQuantity** | `INT` | CHECK > 0 |
| **ReceivedQuantity** | `INT` | DEFAULT `0` |
| **UnitPrice** | `DECIMAL(12,2)` | CHECK ≥ 0 |
| **SubTotal** | `DECIMAL(14,2)` GENERATED | `ReceivedQuantity * UnitPrice` |

> **Logic:** `received` → tăng `STOCK.Quantity`, ghi `STOCK_HISTORY(purchase)`.

---

### 3.6 TRANSFER_ORDER (`PHIEUCHUYEN`)

| Cột | Kiểu | Ghi chú |
|---|---|---|
| **TransferID** | `UUID` PK | |
| **FromBranchID** | `UUID` FK → `BRANCH` | |
| **ToBranchID** | `UUID` FK → `BRANCH` | |
| **CreatedBy** | `UUID` FK → `USER` | |
| **ApprovedBy** | `UUID` FK → `USER` | Optional |
| **ShipDate** | `TIMESTAMP` | Optional |
| **ReceiveDate** | `TIMESTAMP` | Optional |
| **Status** | `ENUM(draft, pending, approved, in_transit, received, cancelled)` | |
| **Note** | `TEXT` | Optional |
| **CreatedAt** | `TIMESTAMP` | |

> **Check:** `FromBranchID <> ToBranchID`.

---

### 3.7 TRANSFER_ORDER_DETAIL (`CT_PHIEUCHUYEN`)

| Cột | Kiểu | Ghi chú |
|---|---|---|
| **TransferID** | `UUID` PK FK → `TRANSFER_ORDER` | |
| **VariantID** | `UUID` PK FK → `PRODUCT_VARIANT` | |
| **RequestedQuantity** | `INT` | CHECK > 0 |
| **ActualQuantity** | `INT` | Optional |
| **Note** | `TEXT` | Optional |

> **Logic:** `in_transit` → trừ STOCK tại From, ghi `transfer_out`. `received` → cộng STOCK tại To, ghi `transfer_in`.

---

### 3.8 STOCK_ADJUSTMENT (`PHIEUKIEMKHO`)

| Cột | Kiểu | Ghi chú |
|---|---|---|
| **AdjustmentID** | `UUID` PK | |
| **BranchID** | `UUID` FK → `BRANCH` | |
| **CreatedBy** | `UUID` FK → `USER` | |
| **ApprovedBy** | `UUID` FK → `USER` | Optional |
| **Status** | `ENUM(draft, counting, pending_approval, completed, cancelled)` | |
| **Note** | `TEXT` | Optional |
| **CreatedAt** | `TIMESTAMP` | |
| **CompletedAt** | `TIMESTAMP` | Optional |

---

### 3.9 STOCK_ADJUSTMENT_DETAIL (`CT_PHIEUKIEMKHO`)

| Cột | Kiểu | Ghi chú |
|---|---|---|
| **AdjustmentID** | `UUID` PK FK → `STOCK_ADJUSTMENT` | |
| **VariantID** | `UUID` PK FK → `PRODUCT_VARIANT` | |
| **SystemQuantity** | `INT` | Tồn theo sách tại thời điểm mở phiếu |
| **ActualQuantity** | `INT` | CHECK ≥ 0 |
| **Discrepancy** | `INT` GENERATED | `ActualQuantity - SystemQuantity` |

> **Logic:** `completed` → cập nhật `STOCK.Quantity = ActualQuantity`, ghi `STOCK_HISTORY(adjustment)`.

---

## SECTION 4 — SALES CHANNELS (3 bảng)

### 4.1 SALES_CHANNEL (`KENHBANHANG`)

| Cột | Kiểu | Ghi chú |
|---|---|---|
| **ChannelID** | `UUID` PK | |
| **ChannelName** | `VARCHAR(100)` UNIQUE | |
| **ChannelType** | `ENUM(pos, website, shopee, tiktok, facebook, lazada)` | |
| **Status** | `ENUM(active, inactive)` | |
| **ChannelConfig** | `JSONB` | Credentials và cấu hình theo platform |
| **CreatedAt** | `TIMESTAMP` | |

> `ChannelConfig` ví dụ:
> - *Shopee:* `{"shop_id": "123", "access_token": "...", "auto_sync_stock": true}`
> - *TikTok:* `{"app_key": "...", "app_secret": "...", "shop_cipher": "..."}`
> - *POS:* `{"branch_id": "uuid", "printer_ip": "192.168.1.10"}`

---

### 4.2 CHANNEL_PRICE (`GIA_KENH`)
*Giá bán riêng theo kênh. Gộp luôn `ExternalProductID` để theo dõi ID sản phẩm trên marketplace.*

| Cột | Kiểu | Ghi chú |
|---|---|---|
| **ChannelID** | `UUID` PK FK → `SALES_CHANNEL` | |
| **VariantID** | `UUID` PK FK → `PRODUCT_VARIANT` | |
| **ExternalProductID** | `VARCHAR(100)` | Optional. ID sản phẩm trên platform (Shopee item_id...) |
| **SellingPrice** | `DECIMAL(12,2)` | CHECK ≥ 0. Override `PRODUCT_VARIANT.SellingPrice` |
| **UpdatedAt** | `TIMESTAMP` | |

> **Logic giá:** Ưu tiên `CHANNEL_PRICE.SellingPrice` → fallback `PRODUCT_VARIANT.SellingPrice`.
> ~~CHANNEL_PRODUCT~~ — đã gộp `ExternalProductID` vào đây. Listing status quản lý ở application layer.

---

### 4.3 CHANNEL_SYNC_LOG (`LICHSU_DONGBO`)
*Log webhook từ marketplace. Lưu để debug và retry.*

| Cột | Kiểu | Ghi chú |
|---|---|---|
| **LogID** | `BIGSERIAL` PK | |
| **ChannelID** | `UUID` FK → `SALES_CHANNEL` | |
| **EventType** | `VARCHAR(50)` | VD: `order.created`, `order.cancelled`, `return.completed` |
| **ExternalOrderID** | `VARCHAR(100)` | Optional. Dùng cho idempotency check |
| **Payload** | `JSONB` | Raw webhook — lưu để replay |
| **Status** | `ENUM(pending, processed, failed, skipped)` | |
| **ProcessedAt** | `TIMESTAMP` | Optional |
| **ErrorMessage** | `TEXT` | Optional |
| **RetryCount** | `SMALLINT` | DEFAULT `0` |
| **ReceivedAt** | `TIMESTAMP` | DEFAULT `NOW()` |

> **Index:** `(ChannelID, Status, ReceivedAt DESC)`, `(ExternalOrderID)`.
> **Idempotency:** Kiểm tra `ExternalOrderID` đã `processed` chưa trước khi trừ kho.

---

## SECTION 5 — SALES (8 bảng)

> **Nguyên tắc:** Marketplace tự quản lý thanh toán, vận chuyển. Hệ thống chỉ cần đủ để **trừ tồn kho đúng** và **phân tích doanh thu**. `PAYMENT` chỉ dành cho kênh `pos` và `website`.

---

### 5.1 CUSTOMER (`KHACHHANG`)

| Cột | Kiểu | Ghi chú |
|---|---|---|
| **CustomerID** | `UUID` PK | |
| **FullName** | `VARCHAR(100)` | |
| **PhoneNumber** | `VARCHAR(15)` UNIQUE | Optional. Định danh chính đa kênh |
| **Email** | `VARCHAR(100)` UNIQUE | Optional |
| **Gender** | `ENUM(male, female, other)` | Optional |
| **DateOfBirth** | `DATE` | Optional |
| **LoyaltyPoints** | `INT` | DEFAULT `0`. CHECK ≥ 0 |
| **TotalSpent** | `DECIMAL(16,2)` | DEFAULT `0` |
| **Status** | `ENUM(active, inactive, blocked)` | |
| **CreatedAt** | `TIMESTAMP` | |
| **UpdatedAt** | `TIMESTAMP` | |

> **Index:** `(PhoneNumber)`, `(Email)`.

---

### 5.2 ORDER (`DONHANG`)
*Địa chỉ giao hàng lưu trực tiếp — không cần bảng CUSTOMER_ADDRESS riêng.*

| Cột | Kiểu | Ghi chú |
|---|---|---|
| **OrderID** | `UUID` PK | |
| **ChannelID** | `UUID` FK → `SALES_CHANNEL` | |
| **BranchID** | `UUID` FK → `BRANCH` | Chi nhánh xử lý / xuất kho |
| **CustomerID** | `UUID` FK → `CUSTOMER` | Optional. `NULL` = khách vãng lai |
| **CreatedBy** | `UUID` FK → `USER` | Marketplace = user hệ thống |
| **OrderDate** | `TIMESTAMP` | DEFAULT `NOW()` |
| **OrderStatus** | `ENUM(new, confirmed, processing, packed, shipped, delivered, cancelled, return_requested)` | |
| **PaymentStatus** | `ENUM(unpaid, paid, refunded)` | |
| **TotalAmount** | `DECIMAL(14,2)` | |
| **DiscountAmount** | `DECIMAL(14,2)` | DEFAULT `0`. Nhập tay hoặc từ marketplace |
| **ShippingFee** | `DECIMAL(10,2)` | DEFAULT `0` |
| **FinalAmount** | `DECIMAL(14,2)` GENERATED | `TotalAmount - DiscountAmount + ShippingFee` |
| **ShippingName** | `VARCHAR(100)` | Optional. Tên người nhận |
| **ShippingPhone** | `VARCHAR(15)` | Optional |
| **ShippingAddress** | `TEXT` | Optional. `NULL` = mua tại quầy POS |
| **ShippingProvince** | `VARCHAR(100)` | Optional |
| **ChannelMetadata** | `JSONB` | Raw data marketplace — tracking, platform order ID... |
| **Note** | `TEXT` | Optional |

> `ChannelMetadata` ví dụ:
> - *Shopee:* `{"order_sn": "250312...", "tracking_number": "SEA123", "logistics_status": "PICKUP_DONE"}`
> - *TikTok:* `{"order_id": "...", "delivery_option": "standard"}`

> **Index:** `(ChannelID, OrderDate DESC)`, `(BranchID, OrderDate DESC)`, `(CustomerID)`.

---

### 5.3 ORDER_DETAIL (`CT_DONHANG`)
*Snapshot giá tại thời điểm mua. Không cập nhật sau khi tạo.*

| Cột | Kiểu | Ghi chú |
|---|---|---|
| **OrderID** | `UUID` PK FK → `ORDER` | |
| **VariantID** | `UUID` PK FK → `PRODUCT_VARIANT` | |
| **Quantity** | `INT` | CHECK > 0 |
| **UnitPrice** | `DECIMAL(12,2)` | Snapshot giá độc lập |
| **SubTotal** | `DECIMAL(14,2)` GENERATED | `Quantity * UnitPrice` |

> **Logic:** `ORDER.Status` → `confirmed`: trừ `STOCK.Quantity`, tăng `INVENTORY_ALLOCATION.SoldQuantity`, ghi `STOCK_HISTORY(sales)`.

---

### 5.4 PAYMENT (`THANHTOAN`)
*Chỉ dành cho kênh `pos` và `website`.*

| Cột | Kiểu | Ghi chú |
|---|---|---|
| **PaymentID** | `UUID` PK | |
| **OrderID** | `UUID` FK → `ORDER` | |
| **Method** | `ENUM(cash, card, momo, vnpay, zalopay, bank_transfer)` | |
| **Amount** | `DECIMAL(14,2)` | CHECK > 0 |
| **Status** | `ENUM(pending, success, failed, refunded)` | |
| **TransactionID** | `VARCHAR(100)` | Optional. ID từ payment gateway |
| **GatewayRef** | `JSONB` | Raw response từ gateway |
| **PaidAt** | `TIMESTAMP` | Optional |
| **CreatedAt** | `TIMESTAMP` | |

---

### 5.5 RETURN_ORDER (`PHIEU_TRA_HANG`)
*Marketplace: chỉ ghi kết quả cuối cùng.*

| Cột | Kiểu | Ghi chú |
|---|---|---|
| **ReturnID** | `UUID` PK | |
| **OrderID** | `UUID` FK → `ORDER` | |
| **BranchID** | `UUID` FK → `BRANCH` | Chi nhánh nhận hàng trả |
| **CreatedBy** | `UUID` FK → `USER` | |
| **ReturnDate** | `TIMESTAMP` | DEFAULT `NOW()` |
| **Reason** | `TEXT` | Optional |
| **ActionType** | `ENUM(refund, exchange, restock_only)` | |
| **RefundMethod** | `ENUM(cash, bank_transfer, loyalty_points)` | Optional |
| **RefundAmount** | `DECIMAL(14,2)` | DEFAULT `0` |
| **Status** | `ENUM(pending, completed, cancelled)` | |
| **ChannelReturnID** | `VARCHAR(100)` | Optional. ID phiếu trả của marketplace |
| **Note** | `TEXT` | Optional |

> **Logic:** `completed` → tăng `STOCK.Quantity`, ghi `STOCK_HISTORY(return)`.

---

### 5.6 RETURN_DETAIL (`CT_PHIEU_TRA`)

| Cột | Kiểu | Ghi chú |
|---|---|---|
| **ReturnID** | `UUID` PK FK → `RETURN_ORDER` | |
| **VariantID** | `UUID` PK FK → `PRODUCT_VARIANT` | |
| **ReturnQuantity** | `INT` | CHECK > 0 |
| **Condition** | `ENUM(new, good, damaged)` | Quyết định có nhập lại kho không |
| **RefundAmount** | `DECIMAL(12,2)` | Optional |

---

## SECTION 6 — AUTHORIZATION (3 bảng)

### 6.1 ROLE (`VAITRO`)

| Cột | Kiểu | Ghi chú |
|---|---|---|
| **RoleID** | `UUID` PK | |
| **RoleName** | `VARCHAR(50)` UNIQUE | `admin`, `branch_manager`, `warehouse_staff`, `sales_staff`, `accountant` |
| **Permissions** | `TEXT[]` | VD: `{stock.view, stock.adjust, order.create}` |
| **Description** | `TEXT` | Optional |

> **Quy ước permission:** `resource.action` — enforce tại application layer.
> Các permission: `stock.view`, `stock.adjust`, `purchase_order.create`, `purchase_order.approve`, `transfer.create`, `transfer.approve`, `order.create`, `order.cancel`, `report.export`, `channel.manage`, `user.manage`.

---

### 6.2 USER (`NGUOIDUNG`)

| Cột | Kiểu | Ghi chú |
|---|---|---|
| **UserID** | `UUID` PK | |
| **FullName** | `VARCHAR(100)` | |
| **Username** | `VARCHAR(50)` UNIQUE | |
| **Password** | `VARCHAR(255)` | Bcrypt hash. CHECK LENGTH ≥ 59 |
| **PhoneNumber** | `VARCHAR(15)` | Optional |
| **Email** | `VARCHAR(100)` UNIQUE | Optional |
| **RoleID** | `UUID` FK → `ROLE` | |
| **BranchID** | `UUID` FK → `BRANCH` | `NULL` = admin (toàn chuỗi) |
| **Status** | `ENUM(active, inactive, locked)` | |
| **FailedLoginCount** | `SMALLINT` | DEFAULT `0` |
| **LastLoginAt** | `TIMESTAMP` | Optional |
| **CreatedAt** | `TIMESTAMP` | |
| **UpdatedAt** | `TIMESTAMP` | |

> ~~USER_BRANCH_ASSIGNMENT~~ — thay bằng cột `BranchID` trong USER. `NULL` = admin, truy cập toàn bộ chi nhánh.
> Nếu sau này cần 1 user quản nhiều chi nhánh → nâng cấp lại thành bảng riêng.

---

## PHỤ LỤC A — Tổng hợp 28 bảng

| # | Bảng | Section |
|---|---|---|
| 1 | PRODUCT_CATEGORY | Product |
| 2 | PRODUCT | Product |
| 3 | ATTRIBUTE | Product |
| 4 | PRODUCT_VARIANT | Product |
| 5 | PRODUCT_IMAGE | Product |
| 6 | BRANCH | Branch & Supplier |
| 7 | SUPPLIER | Branch & Supplier |
| 8 | SUPPLIER_PRODUCT | Branch & Supplier |
| 9 | STOCK | Inventory |
| 10 | STOCK_HISTORY | Inventory |
| 11 | INVENTORY_ALLOCATION | Inventory |
| 12 | PURCHASE_ORDER | Inventory |
| 13 | PURCHASE_ORDER_DETAIL | Inventory |
| 14 | TRANSFER_ORDER | Inventory |
| 15 | TRANSFER_ORDER_DETAIL | Inventory |
| 16 | STOCK_ADJUSTMENT | Inventory |
| 17 | STOCK_ADJUSTMENT_DETAIL | Inventory |
| 18 | SALES_CHANNEL | Channel |
| 19 | CHANNEL_PRICE | Channel |
| 20 | CHANNEL_SYNC_LOG | Channel |
| 21 | CUSTOMER | Sales |
| 22 | ORDER | Sales |
| 23 | ORDER_DETAIL | Sales |
| 24 | PAYMENT | Sales |
| 25 | RETURN_ORDER | Sales |
| 26 | RETURN_DETAIL | Sales |
| 27 | ROLE | Auth |
| 28 | USER | Auth |

---

## PHỤ LỤC B — Những gì đã bỏ và cách bù đắp

| Bảng bỏ | Thay thế |
|---|---|
| `SIZE_GUIDE` | Không có bảng size — bỏ hẳn |
| `VARIANT_IMAGE` | Gộp vào `PRODUCT_IMAGE` với cột `VariantID nullable` |
| `CUSTOMER_ADDRESS` | Địa chỉ lưu thẳng vào `ORDER` (ShippingName, ShippingPhone, ShippingAddress, ShippingProvince) |
| `PROMOTION` | `DiscountAmount` nhập tay trong `ORDER`. Marketplace tự quản lý khuyến mãi |
| `NOTIFICATION` | Xử lý ở application layer — gửi push/email không cần lưu DB |
| `CHANNEL_PRODUCT` | `ExternalProductID` gộp vào `CHANNEL_PRICE`. Listing status quản lý ở app layer |
| `USER_BRANCH_ASSIGNMENT` | Cột `BranchID` trong `USER`. `NULL` = admin toàn chuỗi |

---

## PHỤ LỤC C — Luồng tồn kho

```
                    SUPPLIER
                       │ PURCHASE_ORDER
                       ▼
              STOCK (BranchID + VariantID)
             /         │           \
    nhập kho      kiểm kê       chuyển kho
 PURCHASE_ORDER  STOCK_ADJUSTMENT  TRANSFER_ORDER
                       │
               STOCK_HISTORY (audit log)
                       │
              INVENTORY_ALLOCATION (chống oversell)
             /    |    |    \
           POS  Web  Shopee  TikTok
            └────┴──────┴───────┘
                    ORDER → ORDER_DETAIL
```

---

## PHỤ LỤC D — Trách nhiệm theo kênh

| Chức năng | POS | Website | Marketplace |
|---|:---:|:---:|:---:|
| Quản lý đơn hàng | Hệ thống | Hệ thống | Platform |
| Thanh toán | `PAYMENT` | `PAYMENT` | Platform |
| Vận chuyển | N/A | GHN/GHTK | Platform |
| Trả hàng | `RETURN_ORDER` | `RETURN_ORDER` | Chỉ ghi kết quả |
| Khuyến mãi | `DiscountAmount` tay | `DiscountAmount` tay | Platform |
| **Trừ tồn kho** | Trigger | Trigger | Webhook → CHANNEL_SYNC_LOG |
| **Phân tích DT** | `ORDER` | `ORDER` | `ORDER` (từ webhook) |

---

## PHỤ LỤC E — Quy ước JSONB

| Trường | Bảng | Lý do JSONB |
|---|---|---|
| `DynamicAttributes` | `PRODUCT` | Cấu trúc khác nhau theo category |
| `Tags` | `PRODUCT` | Array — GIN index để filter |
| `ChannelConfig` | `SALES_CHANNEL` | Credentials khác nhau theo platform |
| `ChannelMetadata` | `ORDER` | Raw data marketplace, chỉ đọc |
| `GatewayRef` | `PAYMENT` | Raw response gateway để debug |
| `Payload` | `CHANNEL_SYNC_LOG` | Raw webhook để replay |
