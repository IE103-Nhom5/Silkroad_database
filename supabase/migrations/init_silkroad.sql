-- ===== sql/01_create_extensions.sql =====
-- Extension sinh UUID.
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Extension PostGIS dùng cho cột BRANCH.Coordinates.
-- Nếu môi trường không hỗ trợ PostGIS, có thể thay Coordinates bằng Latitude/Longitude.
CREATE EXTENSION IF NOT EXISTS postgis;


-- ===== sql/02_create_types.sql =====
DO $$
BEGIN
    CREATE TYPE record_status AS ENUM ('active', 'inactive');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    CREATE TYPE product_status AS ENUM ('active', 'inactive', 'discontinued');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    CREATE TYPE product_gender AS ENUM ('male', 'female', 'unisex', 'kids');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    CREATE TYPE variant_status AS ENUM ('active', 'inactive', 'out_of_production');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    CREATE TYPE branch_type AS ENUM ('retail_store', 'central_warehouse', 'sub_warehouse');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    CREATE TYPE branch_status AS ENUM ('active', 'inactive', 'renovating');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    CREATE TYPE stock_transaction_type AS ENUM (
        'purchase', 'sales', 'transfer_in', 'transfer_out',
        'adjustment', 'return', 'damage_write_off'
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    CREATE TYPE purchase_order_status AS ENUM ('draft', 'pending', 'approved', 'received', 'cancelled');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    CREATE TYPE transfer_order_status AS ENUM ('draft', 'pending', 'approved', 'in_transit', 'received', 'cancelled');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    CREATE TYPE stock_adjustment_status AS ENUM ('draft', 'counting', 'pending_approval', 'completed', 'cancelled');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    CREATE TYPE channel_type AS ENUM ('pos', 'website', 'shopee', 'tiktok', 'facebook', 'lazada');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    CREATE TYPE sync_status AS ENUM ('pending', 'processed', 'failed', 'skipped');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    CREATE TYPE customer_gender AS ENUM ('male', 'female', 'other');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    CREATE TYPE customer_status AS ENUM ('active', 'inactive', 'blocked');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    CREATE TYPE order_status AS ENUM (
        'new', 'confirmed', 'processing', 'packed',
        'shipped', 'delivered', 'cancelled', 'return_requested'
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    CREATE TYPE order_payment_status AS ENUM ('unpaid', 'paid', 'refunded');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    CREATE TYPE payment_method AS ENUM ('cash', 'card', 'momo', 'vnpay', 'zalopay', 'bank_transfer');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    CREATE TYPE payment_record_status AS ENUM ('pending', 'success', 'failed', 'refunded');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    CREATE TYPE return_action_type AS ENUM ('refund', 'exchange', 'restock_only');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    CREATE TYPE refund_method AS ENUM ('cash', 'bank_transfer', 'loyalty_points');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    CREATE TYPE return_status AS ENUM ('pending', 'completed', 'cancelled');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    CREATE TYPE return_condition AS ENUM ('new', 'good', 'damaged');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    CREATE TYPE user_status AS ENUM ('active', 'inactive', 'locked');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;


-- ===== sql/03_create_tables.sql =====
CREATE TABLE IF NOT EXISTS ROLE (
    RoleID UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    RoleName VARCHAR(50) UNIQUE NOT NULL,
    Permissions TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
    Description TEXT
);

CREATE TABLE IF NOT EXISTS BRANCH (
    BranchID UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    BranchName VARCHAR(100) UNIQUE NOT NULL,
    BranchType branch_type NOT NULL,
    Address VARCHAR(255) NOT NULL,
    Province VARCHAR(100) NOT NULL,
    PhoneNumber VARCHAR(15),
    Email VARCHAR(100),
    Coordinates GEOGRAPHY(POINT, 4326),
    OpenTime TIME,
    CloseTime TIME,
    Status branch_status NOT NULL DEFAULT 'active',
    CreatedAt TIMESTAMP NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_branch_time
        CHECK (OpenTime IS NULL OR CloseTime IS NULL OR OpenTime < CloseTime)
);

CREATE TABLE IF NOT EXISTS USERS (
    UserID UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    FullName VARCHAR(100) NOT NULL,
    Username VARCHAR(50) UNIQUE NOT NULL,
    PasswordHash VARCHAR(255) NOT NULL,
    PhoneNumber VARCHAR(15),
    Email VARCHAR(100) UNIQUE,
    RoleID UUID NOT NULL REFERENCES ROLE(RoleID),
    BranchID UUID REFERENCES BRANCH(BranchID),
    Status user_status NOT NULL DEFAULT 'active',
    FailedLoginCount SMALLINT NOT NULL DEFAULT 0,
    LastLoginAt TIMESTAMP,
    CreatedAt TIMESTAMP NOT NULL DEFAULT NOW(),
    UpdatedAt TIMESTAMP,

    CONSTRAINT chk_password_hash_length CHECK (LENGTH(PasswordHash) >= 20),
    CONSTRAINT chk_failed_login_count CHECK (FailedLoginCount >= 0)
);

CREATE TABLE IF NOT EXISTS PRODUCT_CATEGORY (
    CategoryID UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ParentCategoryID UUID REFERENCES PRODUCT_CATEGORY(CategoryID),
    CategoryName VARCHAR(100) UNIQUE NOT NULL,
    Slug VARCHAR(120) UNIQUE NOT NULL,
    DisplayOrder SMALLINT NOT NULL DEFAULT 0,
    Status record_status NOT NULL DEFAULT 'active',
    CreatedAt TIMESTAMP NOT NULL DEFAULT NOW(),
    UpdatedAt TIMESTAMP
);

CREATE TABLE IF NOT EXISTS PRODUCT (
    ProductID UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    CategoryID UUID NOT NULL REFERENCES PRODUCT_CATEGORY(CategoryID),
    ProductName VARCHAR(150) NOT NULL,
    Slug VARCHAR(180) UNIQUE NOT NULL,
    Brand VARCHAR(100),
    Gender product_gender,
    Description TEXT,
    DefaultSellingPrice DECIMAL(12,2) NOT NULL DEFAULT 0,
    Tags TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
    CollectionName VARCHAR(150),
    Status product_status NOT NULL DEFAULT 'active',
    DynamicAttributes JSONB NOT NULL DEFAULT '{}'::JSONB,
    CreatedAt TIMESTAMP NOT NULL DEFAULT NOW(),
    UpdatedAt TIMESTAMP,

    CONSTRAINT chk_product_price CHECK (DefaultSellingPrice >= 0)
);

CREATE TABLE IF NOT EXISTS ATTRIBUTE (
    AttributeID UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    AttributeType VARCHAR(50) NOT NULL,
    Value VARCHAR(100) NOT NULL,
    DisplayValue VARCHAR(100),
    HexCode CHAR(7),
    SortOrder SMALLINT NOT NULL DEFAULT 0,
    Status record_status NOT NULL DEFAULT 'active',

    CONSTRAINT uq_attribute_type_value UNIQUE (AttributeType, Value),
    CONSTRAINT chk_attribute_type CHECK (AttributeType IN ('size', 'color')),
    CONSTRAINT chk_color_hex CHECK (
        HexCode IS NULL OR HexCode ~ '^#[0-9A-Fa-f]{6}$'
    )
);

CREATE TABLE IF NOT EXISTS PRODUCT_VARIANT (
    VariantID UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ProductID UUID NOT NULL REFERENCES PRODUCT(ProductID),
    SizeAttributeID UUID REFERENCES ATTRIBUTE(AttributeID),
    ColorAttributeID UUID REFERENCES ATTRIBUTE(AttributeID),
    SKU VARCHAR(30) UNIQUE NOT NULL,
    Barcode VARCHAR(50) UNIQUE,
    CostPrice DECIMAL(12,2) NOT NULL DEFAULT 0,
    SellingPrice DECIMAL(12,2) NOT NULL DEFAULT 0,
    Weight DECIMAL(8,3),
    Status variant_status NOT NULL DEFAULT 'active',
    CreatedAt TIMESTAMP NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_variant_product_size_color
        UNIQUE (ProductID, SizeAttributeID, ColorAttributeID),
    CONSTRAINT chk_variant_price
        CHECK (CostPrice >= 0 AND SellingPrice >= CostPrice),
    CONSTRAINT chk_variant_weight
        CHECK (Weight IS NULL OR Weight >= 0)
);

CREATE TABLE IF NOT EXISTS PRODUCT_IMAGE (
    ImageID UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ProductID UUID NOT NULL REFERENCES PRODUCT(ProductID) ON DELETE CASCADE,
    VariantID UUID REFERENCES PRODUCT_VARIANT(VariantID) ON DELETE CASCADE,
    ImageURL TEXT NOT NULL,
    AltText VARCHAR(200),
    SortOrder SMALLINT NOT NULL DEFAULT 0,
    CreatedAt TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS SUPPLIER (
    SupplierID UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    SupplierName VARCHAR(100) NOT NULL,
    TaxCode VARCHAR(20) UNIQUE,
    PhoneNumber VARCHAR(15),
    Email VARCHAR(100),
    Address VARCHAR(255),
    PaymentTermDays SMALLINT NOT NULL DEFAULT 0,
    Status record_status NOT NULL DEFAULT 'active',
    CreatedAt TIMESTAMP NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_payment_term CHECK (PaymentTermDays >= 0)
);

CREATE TABLE IF NOT EXISTS SUPPLIER_PRODUCT (
    SupplierID UUID NOT NULL REFERENCES SUPPLIER(SupplierID) ON DELETE CASCADE,
    VariantID UUID NOT NULL REFERENCES PRODUCT_VARIANT(VariantID) ON DELETE CASCADE,
    SupplierSKU VARCHAR(50),
    ContractPrice DECIMAL(12,2) NOT NULL DEFAULT 0,
    LeadTimeDays SMALLINT NOT NULL DEFAULT 0,
    MinOrderQuantity INT NOT NULL DEFAULT 1,
    IsPreferred BOOLEAN NOT NULL DEFAULT FALSE,
    UpdatedAt TIMESTAMP NOT NULL DEFAULT NOW(),

    CONSTRAINT pk_supplier_product PRIMARY KEY (SupplierID, VariantID),
    CONSTRAINT chk_supplier_contract_price CHECK (ContractPrice >= 0),
    CONSTRAINT chk_supplier_lead_time CHECK (LeadTimeDays >= 0),
    CONSTRAINT chk_supplier_moq CHECK (MinOrderQuantity > 0)
);

CREATE TABLE IF NOT EXISTS SALES_CHANNEL (
    ChannelID UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ChannelName VARCHAR(100) UNIQUE NOT NULL,
    ChannelType channel_type NOT NULL,
    Status record_status NOT NULL DEFAULT 'active',
    ChannelConfig JSONB NOT NULL DEFAULT '{}'::JSONB,
    CreatedAt TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS STOCK (
    BranchID UUID NOT NULL REFERENCES BRANCH(BranchID),
    VariantID UUID NOT NULL REFERENCES PRODUCT_VARIANT(VariantID),
    Quantity INT NOT NULL DEFAULT 0,
    ReservedQuantity INT NOT NULL DEFAULT 0,
    AvailableQuantity INT GENERATED ALWAYS AS (Quantity - ReservedQuantity) STORED,
    MinStockLevel INT NOT NULL DEFAULT 0,
    MaxStockLevel INT,
    LastUpdated TIMESTAMP NOT NULL DEFAULT NOW(),

    CONSTRAINT pk_stock PRIMARY KEY (BranchID, VariantID),
    CONSTRAINT chk_stock_quantity CHECK (Quantity >= 0),
    CONSTRAINT chk_stock_reserved CHECK (ReservedQuantity >= 0 AND ReservedQuantity <= Quantity),
    CONSTRAINT chk_stock_level CHECK (MaxStockLevel IS NULL OR MinStockLevel < MaxStockLevel)
);

CREATE TABLE IF NOT EXISTS STOCK_HISTORY (
    HistoryID UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    BranchID UUID NOT NULL REFERENCES BRANCH(BranchID),
    VariantID UUID NOT NULL REFERENCES PRODUCT_VARIANT(VariantID),
    TransactionType stock_transaction_type NOT NULL,
    ReferenceType VARCHAR(30) NOT NULL,
    ReferenceID UUID NOT NULL,
    QuantityChange INT NOT NULL,
    QuantityBefore INT NOT NULL,
    QuantityAfter INT NOT NULL,
    PerformedBy UUID REFERENCES USERS(UserID),
    Timestamp TIMESTAMP NOT NULL DEFAULT NOW(),
    Note TEXT,

    CONSTRAINT chk_stock_history_quantity_after CHECK (QuantityAfter >= 0)
);

CREATE TABLE IF NOT EXISTS INVENTORY_ALLOCATION (
    BranchID UUID NOT NULL,
    VariantID UUID NOT NULL,
    ChannelID UUID NOT NULL REFERENCES SALES_CHANNEL(ChannelID),
    AllocatedQuantity INT NOT NULL DEFAULT 0,
    SoldQuantity INT NOT NULL DEFAULT 0,
    AvailableForChannel INT GENERATED ALWAYS AS (AllocatedQuantity - SoldQuantity) STORED,
    UpdatedAt TIMESTAMP NOT NULL DEFAULT NOW(),

    CONSTRAINT pk_inventory_allocation PRIMARY KEY (BranchID, VariantID, ChannelID),
    CONSTRAINT fk_allocation_stock FOREIGN KEY (BranchID, VariantID) REFERENCES STOCK(BranchID, VariantID),
    CONSTRAINT chk_allocation_quantity CHECK (AllocatedQuantity >= 0),
    CONSTRAINT chk_allocation_sold CHECK (SoldQuantity >= 0 AND SoldQuantity <= AllocatedQuantity)
);

CREATE TABLE IF NOT EXISTS PURCHASE_ORDER (
    PurchaseOrderID UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    SupplierID UUID NOT NULL REFERENCES SUPPLIER(SupplierID),
    BranchID UUID NOT NULL REFERENCES BRANCH(BranchID),
    CreatedBy UUID NOT NULL REFERENCES USERS(UserID),
    ApprovedBy UUID REFERENCES USERS(UserID),
    ExpectedDate DATE NOT NULL,
    ArrivalDate TIMESTAMP,
    Status purchase_order_status NOT NULL DEFAULT 'draft',
    TotalAmount DECIMAL(14,2) NOT NULL DEFAULT 0,
    Note TEXT,
    CreatedAt TIMESTAMP NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_purchase_total CHECK (TotalAmount >= 0)
);

CREATE TABLE IF NOT EXISTS PURCHASE_ORDER_DETAIL (
    PurchaseOrderID UUID NOT NULL REFERENCES PURCHASE_ORDER(PurchaseOrderID) ON DELETE CASCADE,
    VariantID UUID NOT NULL REFERENCES PRODUCT_VARIANT(VariantID),
    RequestedQuantity INT NOT NULL,
    ReceivedQuantity INT NOT NULL DEFAULT 0,
    UnitPrice DECIMAL(12,2) NOT NULL DEFAULT 0,
    SubTotal DECIMAL(14,2) GENERATED ALWAYS AS (ReceivedQuantity * UnitPrice) STORED,

    CONSTRAINT pk_purchase_order_detail PRIMARY KEY (PurchaseOrderID, VariantID),
    CONSTRAINT chk_po_requested CHECK (RequestedQuantity > 0),
    CONSTRAINT chk_po_received CHECK (ReceivedQuantity >= 0 AND ReceivedQuantity <= RequestedQuantity),
    CONSTRAINT chk_po_unit_price CHECK (UnitPrice >= 0)
);

CREATE TABLE IF NOT EXISTS TRANSFER_ORDER (
    TransferID UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    FromBranchID UUID NOT NULL REFERENCES BRANCH(BranchID),
    ToBranchID UUID NOT NULL REFERENCES BRANCH(BranchID),
    CreatedBy UUID NOT NULL REFERENCES USERS(UserID),
    ApprovedBy UUID REFERENCES USERS(UserID),
    ShipDate TIMESTAMP,
    ReceiveDate TIMESTAMP,
    Status transfer_order_status NOT NULL DEFAULT 'draft',
    Note TEXT,
    CreatedAt TIMESTAMP NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_transfer_branch_different CHECK (FromBranchID <> ToBranchID),
    CONSTRAINT chk_transfer_receive_after_ship CHECK (ReceiveDate IS NULL OR ShipDate IS NULL OR ReceiveDate >= ShipDate)
);

CREATE TABLE IF NOT EXISTS TRANSFER_ORDER_DETAIL (
    TransferID UUID NOT NULL REFERENCES TRANSFER_ORDER(TransferID) ON DELETE CASCADE,
    VariantID UUID NOT NULL REFERENCES PRODUCT_VARIANT(VariantID),
    RequestedQuantity INT NOT NULL,
    ActualQuantity INT,
    Note TEXT,

    CONSTRAINT pk_transfer_order_detail PRIMARY KEY (TransferID, VariantID),
    CONSTRAINT chk_transfer_requested CHECK (RequestedQuantity > 0),
    CONSTRAINT chk_transfer_actual CHECK (ActualQuantity IS NULL OR ActualQuantity > 0)
);

CREATE TABLE IF NOT EXISTS STOCK_ADJUSTMENT (
    AdjustmentID UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    BranchID UUID NOT NULL REFERENCES BRANCH(BranchID),
    CreatedBy UUID NOT NULL REFERENCES USERS(UserID),
    ApprovedBy UUID REFERENCES USERS(UserID),
    Status stock_adjustment_status NOT NULL DEFAULT 'draft',
    Note TEXT,
    CreatedAt TIMESTAMP NOT NULL DEFAULT NOW(),
    CompletedAt TIMESTAMP
);

CREATE TABLE IF NOT EXISTS STOCK_ADJUSTMENT_DETAIL (
    AdjustmentID UUID NOT NULL REFERENCES STOCK_ADJUSTMENT(AdjustmentID) ON DELETE CASCADE,
    VariantID UUID NOT NULL REFERENCES PRODUCT_VARIANT(VariantID),
    SystemQuantity INT NOT NULL,
    ActualQuantity INT NOT NULL,
    Discrepancy INT GENERATED ALWAYS AS (ActualQuantity - SystemQuantity) STORED,

    CONSTRAINT pk_stock_adjustment_detail PRIMARY KEY (AdjustmentID, VariantID),
    CONSTRAINT chk_adjustment_system CHECK (SystemQuantity >= 0),
    CONSTRAINT chk_adjustment_actual CHECK (ActualQuantity >= 0)
);

CREATE TABLE IF NOT EXISTS CHANNEL_PRICE (
    ChannelID UUID NOT NULL REFERENCES SALES_CHANNEL(ChannelID) ON DELETE CASCADE,
    VariantID UUID NOT NULL REFERENCES PRODUCT_VARIANT(VariantID) ON DELETE CASCADE,
    ExternalProductID VARCHAR(100),
    SellingPrice DECIMAL(12,2) NOT NULL,
    UpdatedAt TIMESTAMP NOT NULL DEFAULT NOW(),

    CONSTRAINT pk_channel_price PRIMARY KEY (ChannelID, VariantID),
    CONSTRAINT chk_channel_price CHECK (SellingPrice >= 0)
);

CREATE TABLE IF NOT EXISTS CHANNEL_SYNC_LOG (
    LogID BIGSERIAL PRIMARY KEY,
    ChannelID UUID NOT NULL REFERENCES SALES_CHANNEL(ChannelID),
    EventType VARCHAR(50) NOT NULL,
    ExternalOrderID VARCHAR(100),
    Payload JSONB NOT NULL DEFAULT '{}'::JSONB,
    Status sync_status NOT NULL DEFAULT 'pending',
    ProcessedAt TIMESTAMP,
    ErrorMessage TEXT,
    RetryCount SMALLINT NOT NULL DEFAULT 0,
    ReceivedAt TIMESTAMP NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_sync_retry CHECK (RetryCount >= 0)
);

CREATE TABLE IF NOT EXISTS CUSTOMER (
    CustomerID UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    FullName VARCHAR(100) NOT NULL,
    PhoneNumber VARCHAR(15) UNIQUE,
    Email VARCHAR(100) UNIQUE,
    Gender customer_gender,
    DateOfBirth DATE,
    LoyaltyPoints INT NOT NULL DEFAULT 0,
    TotalSpent DECIMAL(16,2) NOT NULL DEFAULT 0,
    Status customer_status NOT NULL DEFAULT 'active',
    CreatedAt TIMESTAMP NOT NULL DEFAULT NOW(),
    UpdatedAt TIMESTAMP,

    CONSTRAINT chk_customer_points CHECK (LoyaltyPoints >= 0),
    CONSTRAINT chk_customer_total_spent CHECK (TotalSpent >= 0)
);

CREATE TABLE IF NOT EXISTS ORDERS (
    OrderID UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ChannelID UUID NOT NULL REFERENCES SALES_CHANNEL(ChannelID),
    BranchID UUID NOT NULL REFERENCES BRANCH(BranchID),
    CustomerID UUID REFERENCES CUSTOMER(CustomerID),
    CreatedBy UUID NOT NULL REFERENCES USERS(UserID),
    OrderDate TIMESTAMP NOT NULL DEFAULT NOW(),
    OrderStatus order_status NOT NULL DEFAULT 'new',
    PaymentStatus order_payment_status NOT NULL DEFAULT 'unpaid',
    TotalAmount DECIMAL(14,2) NOT NULL DEFAULT 0,
    DiscountAmount DECIMAL(14,2) NOT NULL DEFAULT 0,
    ShippingFee DECIMAL(10,2) NOT NULL DEFAULT 0,
    FinalAmount DECIMAL(14,2) GENERATED ALWAYS AS (TotalAmount - DiscountAmount + ShippingFee) STORED,
    ShippingName VARCHAR(100),
    ShippingPhone VARCHAR(15),
    ShippingAddress TEXT,
    ShippingProvince VARCHAR(100),
    ChannelMetadata JSONB NOT NULL DEFAULT '{}'::JSONB,
    Note TEXT,

    CONSTRAINT chk_order_amounts CHECK (TotalAmount >= 0 AND DiscountAmount >= 0 AND ShippingFee >= 0)
);

CREATE TABLE IF NOT EXISTS ORDER_DETAIL (
    OrderID UUID NOT NULL REFERENCES ORDERS(OrderID) ON DELETE CASCADE,
    VariantID UUID NOT NULL REFERENCES PRODUCT_VARIANT(VariantID),
    Quantity INT NOT NULL,
    UnitPrice DECIMAL(12,2) NOT NULL,
    SubTotal DECIMAL(14,2) GENERATED ALWAYS AS (Quantity * UnitPrice) STORED,

    CONSTRAINT pk_order_detail PRIMARY KEY (OrderID, VariantID),
    CONSTRAINT chk_order_detail_quantity CHECK (Quantity > 0),
    CONSTRAINT chk_order_detail_price CHECK (UnitPrice >= 0)
);

CREATE TABLE IF NOT EXISTS PAYMENT (
    PaymentID UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    OrderID UUID NOT NULL REFERENCES ORDERS(OrderID) ON DELETE CASCADE,
    Method payment_method NOT NULL,
    Amount DECIMAL(14,2) NOT NULL,
    Status payment_record_status NOT NULL DEFAULT 'pending',
    TransactionID VARCHAR(100),
    GatewayRef JSONB NOT NULL DEFAULT '{}'::JSONB,
    PaidAt TIMESTAMP,
    CreatedAt TIMESTAMP NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_payment_amount CHECK (Amount > 0)
);

CREATE TABLE IF NOT EXISTS RETURN_ORDER (
    ReturnID UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    OrderID UUID NOT NULL REFERENCES ORDERS(OrderID),
    BranchID UUID NOT NULL REFERENCES BRANCH(BranchID),
    CreatedBy UUID NOT NULL REFERENCES USERS(UserID),
    ReturnDate TIMESTAMP NOT NULL DEFAULT NOW(),
    Reason TEXT,
    ActionType return_action_type NOT NULL,
    RefundMethod refund_method,
    RefundAmount DECIMAL(14,2) NOT NULL DEFAULT 0,
    Status return_status NOT NULL DEFAULT 'pending',
    ChannelReturnID VARCHAR(100),
    Note TEXT,

    CONSTRAINT chk_return_refund CHECK (RefundAmount >= 0)
);

CREATE TABLE IF NOT EXISTS RETURN_DETAIL (
    ReturnID UUID NOT NULL REFERENCES RETURN_ORDER(ReturnID) ON DELETE CASCADE,
    VariantID UUID NOT NULL REFERENCES PRODUCT_VARIANT(VariantID),
    ReturnQuantity INT NOT NULL,
    Condition return_condition NOT NULL,
    RefundAmount DECIMAL(12,2),

    CONSTRAINT pk_return_detail PRIMARY KEY (ReturnID, VariantID),
    CONSTRAINT chk_return_quantity CHECK (ReturnQuantity > 0),
    CONSTRAINT chk_return_detail_refund CHECK (RefundAmount IS NULL OR RefundAmount >= 0)
);


-- ===== sql/04_create_indexes.sql =====
-- PRODUCT
CREATE INDEX IF NOT EXISTS idx_category_parent
    ON PRODUCT_CATEGORY(ParentCategoryID);

CREATE INDEX IF NOT EXISTS idx_product_category_status
    ON PRODUCT(CategoryID, Status, Gender);

CREATE INDEX IF NOT EXISTS idx_product_tags_gin
    ON PRODUCT USING GIN(Tags);

CREATE INDEX IF NOT EXISTS idx_product_dynamic_gin
    ON PRODUCT USING GIN(DynamicAttributes);

CREATE INDEX IF NOT EXISTS idx_attribute_type_sort
    ON ATTRIBUTE(AttributeType, SortOrder);

CREATE INDEX IF NOT EXISTS idx_variant_product
    ON PRODUCT_VARIANT(ProductID);

CREATE INDEX IF NOT EXISTS idx_image_product_variant
    ON PRODUCT_IMAGE(ProductID, VariantID, SortOrder);

-- SUPPLIER
CREATE UNIQUE INDEX IF NOT EXISTS idx_supplier_product_preferred
    ON SUPPLIER_PRODUCT(VariantID)
    WHERE IsPreferred = TRUE;

-- INVENTORY
CREATE INDEX IF NOT EXISTS idx_stock_variant
    ON STOCK(VariantID);

CREATE INDEX IF NOT EXISTS idx_stock_history_branch_variant_time
    ON STOCK_HISTORY(BranchID, VariantID, Timestamp DESC);

CREATE INDEX IF NOT EXISTS idx_stock_history_reference
    ON STOCK_HISTORY(ReferenceType, ReferenceID);

CREATE INDEX IF NOT EXISTS idx_purchase_order_status_pending
    ON PURCHASE_ORDER(Status)
    WHERE Status = 'pending';

CREATE INDEX IF NOT EXISTS idx_transfer_order_status_active
    ON TRANSFER_ORDER(Status)
    WHERE Status IN ('pending', 'in_transit');

-- CHANNEL
CREATE INDEX IF NOT EXISTS idx_channel_price_variant
    ON CHANNEL_PRICE(VariantID);

CREATE INDEX IF NOT EXISTS idx_channel_sync_status_time
    ON CHANNEL_SYNC_LOG(ChannelID, Status, ReceivedAt DESC);

CREATE INDEX IF NOT EXISTS idx_channel_sync_external
    ON CHANNEL_SYNC_LOG(ExternalOrderID)
    WHERE ExternalOrderID IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_channel_sync_payload_gin
    ON CHANNEL_SYNC_LOG USING GIN(Payload);

-- SALES
CREATE INDEX IF NOT EXISTS idx_customer_phone
    ON CUSTOMER(PhoneNumber)
    WHERE PhoneNumber IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_customer_email
    ON CUSTOMER(Email)
    WHERE Email IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_order_channel_date
    ON ORDERS(ChannelID, OrderDate DESC);

CREATE INDEX IF NOT EXISTS idx_order_branch_date
    ON ORDERS(BranchID, OrderDate DESC);

CREATE INDEX IF NOT EXISTS idx_order_customer
    ON ORDERS(CustomerID)
    WHERE CustomerID IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_order_metadata_gin
    ON ORDERS USING GIN(ChannelMetadata);

CREATE INDEX IF NOT EXISTS idx_return_order
    ON RETURN_ORDER(OrderID);


-- ===== sql/05_create_functions.sql =====
CREATE OR REPLACE FUNCTION fn_get_available_stock(
    p_branch_id UUID,
    p_variant_id UUID
)
RETURNS INT
LANGUAGE plpgsql
AS $$
DECLARE
    v_available INT;
BEGIN
    SELECT AvailableQuantity
    INTO v_available
    FROM STOCK
    WHERE BranchID = p_branch_id
      AND VariantID = p_variant_id;

    RETURN COALESCE(v_available, 0);
END;
$$;

CREATE OR REPLACE FUNCTION fn_calculate_order_total(p_order_id UUID)
RETURNS DECIMAL(14,2)
LANGUAGE plpgsql
AS $$
DECLARE
    v_total DECIMAL(14,2);
BEGIN
    SELECT COALESCE(SUM(SubTotal), 0)
    INTO v_total
    FROM ORDER_DETAIL
    WHERE OrderID = p_order_id;

    RETURN v_total;
END;
$$;

CREATE OR REPLACE FUNCTION fn_get_stock_movement(
    p_branch_id UUID,
    p_variant_id UUID
)
RETURNS TABLE (
    TransactionType TEXT,
    QuantityChange INT,
    QuantityBefore INT,
    QuantityAfter INT,
    ReferenceType VARCHAR(30),
    ReferenceID UUID,
    PerformedBy UUID,
    CreatedTime TIMESTAMP
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        sh.TransactionType::TEXT,
        sh.QuantityChange,
        sh.QuantityBefore,
        sh.QuantityAfter,
        sh.ReferenceType,
        sh.ReferenceID,
        sh.PerformedBy,
        sh.Timestamp
    FROM STOCK_HISTORY sh
    WHERE sh.BranchID = p_branch_id
      AND sh.VariantID = p_variant_id
    ORDER BY sh.Timestamp DESC;
END;
$$;

CREATE OR REPLACE FUNCTION fn_prevent_stock_history_change()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE EXCEPTION 'STOCK_HISTORY is an audit log and cannot be updated or deleted';
END;
$$;

CREATE OR REPLACE FUNCTION fn_check_inventory_allocation()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_total_allocated INT;
    v_stock_quantity INT;
BEGIN
    SELECT COALESCE(SUM(AllocatedQuantity), 0)
    INTO v_total_allocated
    FROM INVENTORY_ALLOCATION
    WHERE BranchID = NEW.BranchID
      AND VariantID = NEW.VariantID;

    SELECT Quantity
    INTO v_stock_quantity
    FROM STOCK
    WHERE BranchID = NEW.BranchID
      AND VariantID = NEW.VariantID;

    IF v_stock_quantity IS NOT NULL AND v_total_allocated > v_stock_quantity THEN
        RAISE EXCEPTION 'Allocated quantity exceeds stock quantity';
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION fn_update_order_total()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_order_id UUID;
BEGIN
    v_order_id := COALESCE(NEW.OrderID, OLD.OrderID);

    UPDATE ORDERS
    SET TotalAmount = (
        SELECT COALESCE(SUM(SubTotal), 0)
        FROM ORDER_DETAIL
        WHERE OrderID = v_order_id
    )
    WHERE OrderID = v_order_id;

    RETURN NULL;
END;
$$;


-- ===== sql/06_create_triggers.sql =====
DROP TRIGGER IF EXISTS trg_prevent_stock_history_update ON STOCK_HISTORY;
CREATE TRIGGER trg_prevent_stock_history_update
BEFORE UPDATE ON STOCK_HISTORY
FOR EACH ROW
EXECUTE FUNCTION fn_prevent_stock_history_change();

DROP TRIGGER IF EXISTS trg_prevent_stock_history_delete ON STOCK_HISTORY;
CREATE TRIGGER trg_prevent_stock_history_delete
BEFORE DELETE ON STOCK_HISTORY
FOR EACH ROW
EXECUTE FUNCTION fn_prevent_stock_history_change();

DROP TRIGGER IF EXISTS trg_check_inventory_allocation ON INVENTORY_ALLOCATION;
CREATE TRIGGER trg_check_inventory_allocation
AFTER INSERT OR UPDATE ON INVENTORY_ALLOCATION
FOR EACH ROW
EXECUTE FUNCTION fn_check_inventory_allocation();

DROP TRIGGER IF EXISTS trg_update_order_total ON ORDER_DETAIL;
CREATE TRIGGER trg_update_order_total
AFTER INSERT OR UPDATE OR DELETE ON ORDER_DETAIL
FOR EACH ROW
EXECUTE FUNCTION fn_update_order_total();


-- ===== sql/07_create_procedures.sql =====
CREATE OR REPLACE PROCEDURE sp_confirm_order(p_order_id UUID)
LANGUAGE plpgsql
AS $$
DECLARE
    v_branch_id UUID;
    v_channel_id UUID;
    v_user_id UUID;
    v_order_status order_status;
    v_before_qty INT;
    v_after_qty INT;
    v_rows INT;
    rec RECORD;
BEGIN
    SELECT BranchID, ChannelID, CreatedBy, OrderStatus
    INTO v_branch_id, v_channel_id, v_user_id, v_order_status
    FROM ORDERS
    WHERE OrderID = p_order_id
    FOR UPDATE;

    IF v_branch_id IS NULL THEN
        RAISE EXCEPTION 'Order % does not exist', p_order_id;
    END IF;

    IF v_order_status <> 'new' THEN
        RAISE EXCEPTION 'Order % cannot be confirmed because current status is %', p_order_id, v_order_status;
    END IF;

    FOR rec IN
        SELECT VariantID, Quantity
        FROM ORDER_DETAIL
        WHERE OrderID = p_order_id
    LOOP
        SELECT Quantity
        INTO v_before_qty
        FROM STOCK
        WHERE BranchID = v_branch_id
          AND VariantID = rec.VariantID
        FOR UPDATE;

        IF v_before_qty IS NULL THEN
            RAISE EXCEPTION 'Stock not found for variant % at branch %', rec.VariantID, v_branch_id;
        END IF;

        IF v_before_qty < rec.Quantity THEN
            RAISE EXCEPTION 'Not enough stock for variant %', rec.VariantID;
        END IF;

        v_after_qty := v_before_qty - rec.Quantity;

        UPDATE STOCK
        SET Quantity = v_after_qty,
            LastUpdated = NOW()
        WHERE BranchID = v_branch_id
          AND VariantID = rec.VariantID;

        UPDATE INVENTORY_ALLOCATION
        SET SoldQuantity = SoldQuantity + rec.Quantity,
            UpdatedAt = NOW()
        WHERE BranchID = v_branch_id
          AND VariantID = rec.VariantID
          AND ChannelID = v_channel_id;

        GET DIAGNOSTICS v_rows = ROW_COUNT;

        IF v_rows = 0 THEN
            RAISE EXCEPTION 'Inventory allocation not found for branch %, variant %, channel %',
                v_branch_id, rec.VariantID, v_channel_id;
        END IF;

        INSERT INTO STOCK_HISTORY (
            HistoryID, BranchID, VariantID, TransactionType,
            ReferenceType, ReferenceID, QuantityChange,
            QuantityBefore, QuantityAfter, PerformedBy,
            Timestamp, Note
        )
        VALUES (
            gen_random_uuid(), v_branch_id, rec.VariantID, 'sales',
            'ORDERS', p_order_id, -rec.Quantity,
            v_before_qty, v_after_qty, v_user_id,
            NOW(), 'Trừ tồn kho khi xác nhận đơn hàng'
        );
    END LOOP;

    UPDATE ORDERS
    SET OrderStatus = 'confirmed'
    WHERE OrderID = p_order_id;
END;
$$;

CREATE OR REPLACE PROCEDURE sp_confirm_purchase_order(p_purchase_order_id UUID)
LANGUAGE plpgsql
AS $$
DECLARE
    v_branch_id UUID;
    v_user_id UUID;
    v_before_qty INT;
    v_after_qty INT;
    rec RECORD;
BEGIN
    SELECT BranchID, CreatedBy
    INTO v_branch_id, v_user_id
    FROM PURCHASE_ORDER
    WHERE PurchaseOrderID = p_purchase_order_id
    FOR UPDATE;

    IF v_branch_id IS NULL THEN
        RAISE EXCEPTION 'Purchase order % does not exist', p_purchase_order_id;
    END IF;

    FOR rec IN
        SELECT VariantID, ReceivedQuantity
        FROM PURCHASE_ORDER_DETAIL
        WHERE PurchaseOrderID = p_purchase_order_id
          AND ReceivedQuantity > 0
    LOOP
        SELECT Quantity
        INTO v_before_qty
        FROM STOCK
        WHERE BranchID = v_branch_id
          AND VariantID = rec.VariantID
        FOR UPDATE;

        IF NOT FOUND THEN
            v_before_qty := 0;

            INSERT INTO STOCK (
                BranchID, VariantID, Quantity, ReservedQuantity, MinStockLevel, LastUpdated
            )
            VALUES (
                v_branch_id, rec.VariantID, 0, 0, 0, NOW()
            );
        END IF;

        v_after_qty := v_before_qty + rec.ReceivedQuantity;

        UPDATE STOCK
        SET Quantity = v_after_qty,
            LastUpdated = NOW()
        WHERE BranchID = v_branch_id
          AND VariantID = rec.VariantID;

        INSERT INTO STOCK_HISTORY (
            HistoryID, BranchID, VariantID, TransactionType,
            ReferenceType, ReferenceID, QuantityChange,
            QuantityBefore, QuantityAfter, PerformedBy,
            Timestamp, Note
        )
        VALUES (
            gen_random_uuid(), v_branch_id, rec.VariantID, 'purchase',
            'PURCHASE_ORDER', p_purchase_order_id, rec.ReceivedQuantity,
            v_before_qty, v_after_qty, v_user_id,
            NOW(), 'Cộng tồn kho khi xác nhận phiếu nhập'
        );
    END LOOP;

    UPDATE PURCHASE_ORDER
    SET Status = 'received',
        ArrivalDate = NOW()
    WHERE PurchaseOrderID = p_purchase_order_id;
END;
$$;

CREATE OR REPLACE PROCEDURE sp_ship_transfer_order(p_transfer_id UUID)
LANGUAGE plpgsql
AS $$
DECLARE
    v_from_branch UUID;
    v_user_id UUID;
    v_before_qty INT;
    v_after_qty INT;
    v_qty INT;
    rec RECORD;
BEGIN
    SELECT FromBranchID, CreatedBy
    INTO v_from_branch, v_user_id
    FROM TRANSFER_ORDER
    WHERE TransferID = p_transfer_id
    FOR UPDATE;

    IF v_from_branch IS NULL THEN
        RAISE EXCEPTION 'Transfer order % does not exist', p_transfer_id;
    END IF;

    FOR rec IN
        SELECT VariantID, COALESCE(ActualQuantity, RequestedQuantity) AS TransferQuantity
        FROM TRANSFER_ORDER_DETAIL
        WHERE TransferID = p_transfer_id
    LOOP
        v_qty := rec.TransferQuantity;

        SELECT Quantity
        INTO v_before_qty
        FROM STOCK
        WHERE BranchID = v_from_branch
          AND VariantID = rec.VariantID
        FOR UPDATE;

        IF v_before_qty IS NULL OR v_before_qty < v_qty THEN
            RAISE EXCEPTION 'Not enough stock to transfer variant %', rec.VariantID;
        END IF;

        v_after_qty := v_before_qty - v_qty;

        UPDATE STOCK
        SET Quantity = v_after_qty,
            LastUpdated = NOW()
        WHERE BranchID = v_from_branch
          AND VariantID = rec.VariantID;

        INSERT INTO STOCK_HISTORY (
            HistoryID, BranchID, VariantID, TransactionType,
            ReferenceType, ReferenceID, QuantityChange,
            QuantityBefore, QuantityAfter, PerformedBy,
            Timestamp, Note
        )
        VALUES (
            gen_random_uuid(), v_from_branch, rec.VariantID, 'transfer_out',
            'TRANSFER_ORDER', p_transfer_id, -v_qty,
            v_before_qty, v_after_qty, v_user_id,
            NOW(), 'Trừ tồn kho tại chi nhánh gửi khi chuyển kho'
        );
    END LOOP;

    UPDATE TRANSFER_ORDER
    SET Status = 'in_transit',
        ShipDate = NOW()
    WHERE TransferID = p_transfer_id;
END;
$$;

CREATE OR REPLACE PROCEDURE sp_receive_transfer_order(p_transfer_id UUID)
LANGUAGE plpgsql
AS $$
DECLARE
    v_to_branch UUID;
    v_user_id UUID;
    v_before_qty INT;
    v_after_qty INT;
    v_qty INT;
    rec RECORD;
BEGIN
    SELECT ToBranchID, CreatedBy
    INTO v_to_branch, v_user_id
    FROM TRANSFER_ORDER
    WHERE TransferID = p_transfer_id
    FOR UPDATE;

    IF v_to_branch IS NULL THEN
        RAISE EXCEPTION 'Transfer order % does not exist', p_transfer_id;
    END IF;

    FOR rec IN
        SELECT VariantID, COALESCE(ActualQuantity, RequestedQuantity) AS TransferQuantity
        FROM TRANSFER_ORDER_DETAIL
        WHERE TransferID = p_transfer_id
    LOOP
        v_qty := rec.TransferQuantity;

        SELECT Quantity
        INTO v_before_qty
        FROM STOCK
        WHERE BranchID = v_to_branch
          AND VariantID = rec.VariantID
        FOR UPDATE;

        IF NOT FOUND THEN
            v_before_qty := 0;

            INSERT INTO STOCK (
                BranchID, VariantID, Quantity, ReservedQuantity, MinStockLevel, LastUpdated
            )
            VALUES (
                v_to_branch, rec.VariantID, 0, 0, 0, NOW()
            );
        END IF;

        v_after_qty := v_before_qty + v_qty;

        UPDATE STOCK
        SET Quantity = v_after_qty,
            LastUpdated = NOW()
        WHERE BranchID = v_to_branch
          AND VariantID = rec.VariantID;

        INSERT INTO STOCK_HISTORY (
            HistoryID, BranchID, VariantID, TransactionType,
            ReferenceType, ReferenceID, QuantityChange,
            QuantityBefore, QuantityAfter, PerformedBy,
            Timestamp, Note
        )
        VALUES (
            gen_random_uuid(), v_to_branch, rec.VariantID, 'transfer_in',
            'TRANSFER_ORDER', p_transfer_id, v_qty,
            v_before_qty, v_after_qty, v_user_id,
            NOW(), 'Cộng tồn kho tại chi nhánh nhận khi hoàn tất chuyển kho'
        );
    END LOOP;

    UPDATE TRANSFER_ORDER
    SET Status = 'received',
        ReceiveDate = NOW()
    WHERE TransferID = p_transfer_id;
END;
$$;

CREATE OR REPLACE PROCEDURE sp_complete_stock_adjustment(p_adjustment_id UUID)
LANGUAGE plpgsql
AS $$
DECLARE
    v_branch_id UUID;
    v_user_id UUID;
    v_before_qty INT;
    v_after_qty INT;
    v_change INT;
    rec RECORD;
BEGIN
    SELECT BranchID, CreatedBy
    INTO v_branch_id, v_user_id
    FROM STOCK_ADJUSTMENT
    WHERE AdjustmentID = p_adjustment_id
    FOR UPDATE;

    IF v_branch_id IS NULL THEN
        RAISE EXCEPTION 'Stock adjustment % does not exist', p_adjustment_id;
    END IF;

    FOR rec IN
        SELECT VariantID, ActualQuantity
        FROM STOCK_ADJUSTMENT_DETAIL
        WHERE AdjustmentID = p_adjustment_id
    LOOP
        SELECT Quantity
        INTO v_before_qty
        FROM STOCK
        WHERE BranchID = v_branch_id
          AND VariantID = rec.VariantID
        FOR UPDATE;

        IF NOT FOUND THEN
            v_before_qty := 0;

            INSERT INTO STOCK (
                BranchID, VariantID, Quantity, ReservedQuantity, MinStockLevel, LastUpdated
            )
            VALUES (
                v_branch_id, rec.VariantID, 0, 0, 0, NOW()
            );
        END IF;

        v_after_qty := rec.ActualQuantity;
        v_change := v_after_qty - v_before_qty;

        UPDATE STOCK
        SET Quantity = v_after_qty,
            LastUpdated = NOW()
        WHERE BranchID = v_branch_id
          AND VariantID = rec.VariantID;

        INSERT INTO STOCK_HISTORY (
            HistoryID, BranchID, VariantID, TransactionType,
            ReferenceType, ReferenceID, QuantityChange,
            QuantityBefore, QuantityAfter, PerformedBy,
            Timestamp, Note
        )
        VALUES (
            gen_random_uuid(), v_branch_id, rec.VariantID, 'adjustment',
            'STOCK_ADJUSTMENT', p_adjustment_id, v_change,
            v_before_qty, v_after_qty, v_user_id,
            NOW(), 'Điều chỉnh tồn kho sau kiểm kê'
        );
    END LOOP;

    UPDATE STOCK_ADJUSTMENT
    SET Status = 'completed',
        CompletedAt = NOW()
    WHERE AdjustmentID = p_adjustment_id;
END;
$$;


-- ===== sql/08_create_views.sql =====
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


