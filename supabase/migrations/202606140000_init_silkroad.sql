-- ===== sql/01_create_extensions.sql =====
-- Extension sinh UUID.
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Extension PostGIS dùng cho cột BRANCH.Coordinates.
CREATE EXTENSION IF NOT EXISTS postgis;

-- ===== sql/02_create_types.sql =====
-- Enum dùng để giới hạn giá trị của các cột trong bảng, giúp đảm bảo tính nhất quán và dễ dàng quản lý.

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
    IF NOT EXISTS (
        SELECT 1
        FROM pg_type t
        JOIN pg_enum e ON e.enumtypid = t.oid
        WHERE t.typname = 'order_payment_status'
          AND e.enumlabel = 'partially_refunded'
    ) THEN
        ALTER TYPE order_payment_status ADD VALUE 'partially_refunded' AFTER 'paid';
    END IF;
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
    Latitude DECIMAL(10,7),
    Longitude DECIMAL(10,7),
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
    PhoneNumber VARCHAR(15),
    Email VARCHAR(100) UNIQUE,
    RoleID UUID NOT NULL REFERENCES ROLE(RoleID),
    BranchID UUID REFERENCES BRANCH(BranchID),
    Status user_status NOT NULL DEFAULT 'active',
    FailedLoginCount SMALLINT NOT NULL DEFAULT 0,
    LastLoginAt TIMESTAMP,
    CreatedAt TIMESTAMP NOT NULL DEFAULT NOW(),
    UpdatedAt TIMESTAMP,

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
-- 4.2.1 procedure xác nhận đơn hàng

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


-- 4.2.2 Procedure xác nhận phiếu nhập hàng
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

-- 4.2.3 Procedure xác nhận chuyển kho
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

-- 4.2.4 Procedure xác nhận nhận hàng chuyển kho
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


-- 4.2.5 Procedure hoàn tất điều chỉnh tồn kho
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


-- 4.2.6 Procedure hoàn tất đổi trả
CREATE OR REPLACE PROCEDURE sp_complete_return_order(p_return_id UUID)
LANGUAGE plpgsql
AS $$
DECLARE
    v_branch_id UUID;
    v_user_id UUID;
    v_order_id UUID;
    v_action_type return_action_type;
    v_refund_method refund_method;
    v_refund_amount DECIMAL(14,2);
    v_order_final_amount DECIMAL(14,2);
    v_existing_refund_amount DECIMAL(14,2);
    v_total_refund_amount DECIMAL(14,2);
    v_before_qty INT;
    v_after_qty INT;
    v_sold_qty INT;
    v_returned_qty INT;
    rec RECORD;
BEGIN
    SELECT BranchID, CreatedBy, OrderID, ActionType, RefundMethod, RefundAmount
    INTO v_branch_id, v_user_id, v_order_id, v_action_type, v_refund_method, v_refund_amount
    FROM RETURN_ORDER
    WHERE ReturnID = p_return_id
    FOR UPDATE;

    IF v_branch_id IS NULL THEN
        RAISE EXCEPTION 'Return order % does not exist', p_return_id;
    END IF;

    IF v_action_type = 'refund' AND v_refund_amount > 0 THEN
        SELECT FinalAmount
        INTO v_order_final_amount
        FROM ORDERS
        WHERE OrderID = v_order_id
        FOR UPDATE;

        SELECT COALESCE(SUM(RefundAmount), 0)
        INTO v_existing_refund_amount
        FROM RETURN_ORDER
        WHERE OrderID = v_order_id
          AND ReturnID <> p_return_id
          AND ActionType = 'refund'
          AND Status = 'completed';

        IF v_existing_refund_amount + v_refund_amount > v_order_final_amount THEN
            RAISE EXCEPTION 'Refund amount exceeds order final amount for order %', v_order_id;
        END IF;
    END IF;

    FOR rec IN
        SELECT VariantID, ReturnQuantity, Condition
        FROM RETURN_DETAIL
        WHERE ReturnID = p_return_id
    LOOP
        SELECT Quantity
        INTO v_sold_qty
        FROM ORDER_DETAIL
        WHERE OrderID = v_order_id
          AND VariantID = rec.VariantID;

        IF v_sold_qty IS NULL THEN
            RAISE EXCEPTION 'Variant % is not part of order %', rec.VariantID, v_order_id;
        END IF;

        SELECT COALESCE(SUM(rd.ReturnQuantity), 0)
        INTO v_returned_qty
        FROM RETURN_DETAIL rd
        JOIN RETURN_ORDER ro ON ro.ReturnID = rd.ReturnID
        WHERE ro.OrderID = v_order_id
          AND rd.VariantID = rec.VariantID
          AND ro.ReturnID <> p_return_id
          AND ro.Status <> 'cancelled';

        IF v_returned_qty + rec.ReturnQuantity > v_sold_qty THEN
            RAISE EXCEPTION 'Returned quantity exceeds sold quantity for variant %', rec.VariantID;
        END IF;

        IF rec.Condition <> 'damaged' THEN
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

            v_after_qty := v_before_qty + rec.ReturnQuantity;

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
                gen_random_uuid(), v_branch_id, rec.VariantID, 'return',
                'RETURN_ORDER', p_return_id, rec.ReturnQuantity,
                v_before_qty, v_after_qty, v_user_id,
                NOW(), 'Hoàn kho từ phiếu đổi trả'
            );
        ELSE
            INSERT INTO STOCK_HISTORY (
                HistoryID, BranchID, VariantID, TransactionType,
                ReferenceType, ReferenceID, QuantityChange,
                QuantityBefore, QuantityAfter, PerformedBy,
                Timestamp, Note
            )
            VALUES (
                gen_random_uuid(), v_branch_id, rec.VariantID, 'damage_write_off',
                'RETURN_ORDER', p_return_id, 0,
                0, 0, v_user_id,
                NOW(), 'Hàng trả bị hỏng, không hoàn kho'
            );
        END IF;
    END LOOP;

    UPDATE RETURN_ORDER
    SET Status = 'completed'
    WHERE ReturnID = p_return_id;

    IF v_action_type = 'refund' AND v_refund_amount > 0 THEN
        v_total_refund_amount := v_existing_refund_amount + v_refund_amount;

        UPDATE ORDERS
        SET PaymentStatus = CASE
            WHEN v_total_refund_amount >= v_order_final_amount THEN 'refunded'::order_payment_status
            ELSE 'partially_refunded'::order_payment_status
        END
        WHERE OrderID = v_order_id;

        IF v_refund_method IN ('cash', 'bank_transfer') THEN
            INSERT INTO PAYMENT (
                PaymentID, OrderID, Method, Amount, Status,
                TransactionID, GatewayRef, PaidAt, CreatedAt
            )
            VALUES (
                gen_random_uuid(), v_order_id, v_refund_method::TEXT::payment_method,
                v_refund_amount, 'refunded',
                'RETURN-' || p_return_id::TEXT,
                jsonb_build_object('return_id', p_return_id, 'source', 'return_order'),
                NOW(), NOW()
            );
        END IF;
    END IF;
END;
$$;


-- 4.2.7 Function wrapper cho Supabase RPC
-- PostgREST/Supabase RPC expose FUNCTION ổn định hơn PROCEDURE. Các wrapper
-- này giữ nguyên logic procedure hiện có và trả TRUE khi hoàn tất.
CREATE OR REPLACE FUNCTION fn_confirm_order_app(p_order_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
BEGIN
    CALL sp_confirm_order(p_order_id);
    RETURN TRUE;
END;
$$;

CREATE OR REPLACE FUNCTION fn_confirm_purchase_order_app(p_purchase_order_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
BEGIN
    CALL sp_confirm_purchase_order(p_purchase_order_id);
    RETURN TRUE;
END;
$$;

CREATE OR REPLACE FUNCTION fn_ship_transfer_order_app(p_transfer_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
BEGIN
    CALL sp_ship_transfer_order(p_transfer_id);
    RETURN TRUE;
END;
$$;

CREATE OR REPLACE FUNCTION fn_receive_transfer_order_app(p_transfer_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
BEGIN
    CALL sp_receive_transfer_order(p_transfer_id);
    RETURN TRUE;
END;
$$;

CREATE OR REPLACE FUNCTION fn_complete_stock_adjustment_app(p_adjustment_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
BEGIN
    CALL sp_complete_stock_adjustment(p_adjustment_id);
    RETURN TRUE;
END;
$$;

CREATE OR REPLACE FUNCTION fn_complete_return_order_app(p_return_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
BEGIN
    CALL sp_complete_return_order(p_return_id);
    RETURN TRUE;
END;
$$;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
        GRANT EXECUTE ON FUNCTION fn_confirm_order_app(UUID) TO anon;
        GRANT EXECUTE ON FUNCTION fn_confirm_purchase_order_app(UUID) TO anon;
        GRANT EXECUTE ON FUNCTION fn_ship_transfer_order_app(UUID) TO anon;
        GRANT EXECUTE ON FUNCTION fn_receive_transfer_order_app(UUID) TO anon;
        GRANT EXECUTE ON FUNCTION fn_complete_stock_adjustment_app(UUID) TO anon;
        GRANT EXECUTE ON FUNCTION fn_complete_return_order_app(UUID) TO anon;
    END IF;

    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
        GRANT EXECUTE ON FUNCTION fn_confirm_order_app(UUID) TO authenticated;
        GRANT EXECUTE ON FUNCTION fn_confirm_purchase_order_app(UUID) TO authenticated;
        GRANT EXECUTE ON FUNCTION fn_ship_transfer_order_app(UUID) TO authenticated;
        GRANT EXECUTE ON FUNCTION fn_receive_transfer_order_app(UUID) TO authenticated;
        GRANT EXECUTE ON FUNCTION fn_complete_stock_adjustment_app(UUID) TO authenticated;
        GRANT EXECUTE ON FUNCTION fn_complete_return_order_app(UUID) TO authenticated;
    END IF;
END $$;

-- ===== sql/08_create_views.sql =====
-- View danh mục sản phẩm và biến thể
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

-- 4.6.1 View tồn kho theo chi nhánh
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

-- View cảnh báo tồn kho thấp
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

-- 4.6.2 View báo cáo chi tiết đơn hàng
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

-- 4.6.3 View báo cáo doanh thu theo kênh bán hàng
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

-- 4.6.4 View báo cáo biến động tồn kho
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

-- ===== sql/11_create_permissions.sql =====

-- =========================================================
-- 1. Cập nhật danh sách permission theo vai trò
-- =========================================================

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


-- =========================================================
-- 2. Hàm hỗ trợ xác định user hiện tại
-- =========================================================

CREATE OR REPLACE FUNCTION current_app_user_id()
RETURNS UUID
LANGUAGE SQL
STABLE
AS $$
    SELECT NULLIF(current_setting('app.current_user_id', TRUE), '')::UUID;
$$;

CREATE OR REPLACE FUNCTION current_app_role()
RETURNS TEXT
LANGUAGE SQL
STABLE
AS $$
    SELECT r.RoleName
    FROM USERS u
    JOIN ROLE r ON r.RoleID = u.RoleID
    WHERE u.UserID = current_app_user_id();
$$;

CREATE OR REPLACE FUNCTION current_app_branch_id()
RETURNS UUID
LANGUAGE SQL
STABLE
AS $$
    SELECT BranchID
    FROM USERS
    WHERE UserID = current_app_user_id();
$$;

CREATE OR REPLACE FUNCTION current_app_is_admin()
RETURNS BOOLEAN
LANGUAGE SQL
STABLE
AS $$
    SELECT current_app_role() = 'admin';
$$;

CREATE OR REPLACE FUNCTION current_app_has_permission(p_permission TEXT)
RETURNS BOOLEAN
LANGUAGE SQL
STABLE
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM USERS u
        JOIN ROLE r ON r.RoleID = u.RoleID
        WHERE u.UserID = current_app_user_id()
          AND p_permission = ANY(r.Permissions)
    );
$$;


-- =========================================================
-- 3. Bật Row Level Security cho các bảng nghiệp vụ chính
-- =========================================================

ALTER TABLE STOCK ENABLE ROW LEVEL SECURITY;
ALTER TABLE STOCK_HISTORY ENABLE ROW LEVEL SECURITY;
ALTER TABLE INVENTORY_ALLOCATION ENABLE ROW LEVEL SECURITY;
ALTER TABLE PURCHASE_ORDER ENABLE ROW LEVEL SECURITY;
ALTER TABLE PURCHASE_ORDER_DETAIL ENABLE ROW LEVEL SECURITY;
ALTER TABLE TRANSFER_ORDER ENABLE ROW LEVEL SECURITY;
ALTER TABLE TRANSFER_ORDER_DETAIL ENABLE ROW LEVEL SECURITY;
ALTER TABLE STOCK_ADJUSTMENT ENABLE ROW LEVEL SECURITY;
ALTER TABLE STOCK_ADJUSTMENT_DETAIL ENABLE ROW LEVEL SECURITY;
ALTER TABLE ORDERS ENABLE ROW LEVEL SECURITY;
ALTER TABLE ORDER_DETAIL ENABLE ROW LEVEL SECURITY;
ALTER TABLE PAYMENT ENABLE ROW LEVEL SECURITY;
ALTER TABLE RETURN_ORDER ENABLE ROW LEVEL SECURITY;
ALTER TABLE RETURN_DETAIL ENABLE ROW LEVEL SECURITY;


-- =========================================================
-- 4. Xóa policy cũ để file có thể chạy lại nhiều lần
-- =========================================================

DROP POLICY IF EXISTS stock_admin_all ON STOCK;
DROP POLICY IF EXISTS stock_branch_read ON STOCK;
DROP POLICY IF EXISTS stock_branch_update ON STOCK;

DROP POLICY IF EXISTS stock_history_admin_read ON STOCK_HISTORY;
DROP POLICY IF EXISTS stock_history_branch_read ON STOCK_HISTORY;

DROP POLICY IF EXISTS inventory_allocation_admin_all ON INVENTORY_ALLOCATION;
DROP POLICY IF EXISTS inventory_allocation_branch_read ON INVENTORY_ALLOCATION;
DROP POLICY IF EXISTS inventory_allocation_branch_update ON INVENTORY_ALLOCATION;

DROP POLICY IF EXISTS purchase_order_admin_all ON PURCHASE_ORDER;
DROP POLICY IF EXISTS purchase_order_branch_read ON PURCHASE_ORDER;
DROP POLICY IF EXISTS purchase_order_warehouse_insert ON PURCHASE_ORDER;
DROP POLICY IF EXISTS purchase_order_warehouse_update ON PURCHASE_ORDER;
DROP POLICY IF EXISTS purchase_order_manager_approve ON PURCHASE_ORDER;

DROP POLICY IF EXISTS purchase_order_detail_admin_all ON PURCHASE_ORDER_DETAIL;
DROP POLICY IF EXISTS purchase_order_detail_branch_read ON PURCHASE_ORDER_DETAIL;
DROP POLICY IF EXISTS purchase_order_detail_warehouse_write ON PURCHASE_ORDER_DETAIL;

DROP POLICY IF EXISTS transfer_order_admin_all ON TRANSFER_ORDER;
DROP POLICY IF EXISTS transfer_order_branch_read ON TRANSFER_ORDER;
DROP POLICY IF EXISTS transfer_order_warehouse_insert ON TRANSFER_ORDER;
DROP POLICY IF EXISTS transfer_order_warehouse_update ON TRANSFER_ORDER;
DROP POLICY IF EXISTS transfer_order_manager_approve ON TRANSFER_ORDER;

DROP POLICY IF EXISTS transfer_order_detail_admin_all ON TRANSFER_ORDER_DETAIL;
DROP POLICY IF EXISTS transfer_order_detail_branch_read ON TRANSFER_ORDER_DETAIL;
DROP POLICY IF EXISTS transfer_order_detail_warehouse_write ON TRANSFER_ORDER_DETAIL;

DROP POLICY IF EXISTS stock_adjustment_admin_all ON STOCK_ADJUSTMENT;
DROP POLICY IF EXISTS stock_adjustment_branch_read ON STOCK_ADJUSTMENT;
DROP POLICY IF EXISTS stock_adjustment_staff_insert ON STOCK_ADJUSTMENT;
DROP POLICY IF EXISTS stock_adjustment_warehouse_update ON STOCK_ADJUSTMENT;
DROP POLICY IF EXISTS stock_adjustment_manager_approve ON STOCK_ADJUSTMENT;

DROP POLICY IF EXISTS stock_adjustment_detail_admin_all ON STOCK_ADJUSTMENT_DETAIL;
DROP POLICY IF EXISTS stock_adjustment_detail_branch_read ON STOCK_ADJUSTMENT_DETAIL;
DROP POLICY IF EXISTS stock_adjustment_detail_warehouse_write ON STOCK_ADJUSTMENT_DETAIL;

DROP POLICY IF EXISTS orders_admin_all ON ORDERS;
DROP POLICY IF EXISTS orders_branch_read ON ORDERS;
DROP POLICY IF EXISTS orders_sales_insert ON ORDERS;
DROP POLICY IF EXISTS orders_sales_update ON ORDERS;
DROP POLICY IF EXISTS orders_manager_update ON ORDERS;

DROP POLICY IF EXISTS order_detail_admin_all ON ORDER_DETAIL;
DROP POLICY IF EXISTS order_detail_branch_read ON ORDER_DETAIL;
DROP POLICY IF EXISTS order_detail_sales_write ON ORDER_DETAIL;

DROP POLICY IF EXISTS payment_admin_all ON PAYMENT;
DROP POLICY IF EXISTS payment_branch_read ON PAYMENT;
DROP POLICY IF EXISTS payment_sales_insert ON PAYMENT;

DROP POLICY IF EXISTS return_order_admin_all ON RETURN_ORDER;
DROP POLICY IF EXISTS return_order_branch_read ON RETURN_ORDER;
DROP POLICY IF EXISTS return_order_sales_insert ON RETURN_ORDER;
DROP POLICY IF EXISTS return_order_manager_update ON RETURN_ORDER;

DROP POLICY IF EXISTS return_detail_admin_all ON RETURN_DETAIL;
DROP POLICY IF EXISTS return_detail_branch_read ON RETURN_DETAIL;
DROP POLICY IF EXISTS return_detail_sales_insert ON RETURN_DETAIL;


-- =========================================================
-- 5. Policy: STOCK, STOCK_HISTORY, INVENTORY_ALLOCATION
-- =========================================================

CREATE POLICY stock_admin_all ON STOCK
FOR ALL
USING (current_app_is_admin())
WITH CHECK (current_app_is_admin());

CREATE POLICY stock_branch_read ON STOCK
FOR SELECT
USING (
    current_app_role() IN ('branch_manager', 'warehouse_staff', 'sales_staff')
    AND BranchID = current_app_branch_id()
);

CREATE POLICY stock_branch_update ON STOCK
FOR UPDATE
USING (
    current_app_role() IN ('branch_manager', 'warehouse_staff')
    AND BranchID = current_app_branch_id()
)
WITH CHECK (
    current_app_role() IN ('branch_manager', 'warehouse_staff')
    AND BranchID = current_app_branch_id()
);

CREATE POLICY stock_history_admin_read ON STOCK_HISTORY
FOR SELECT
USING (current_app_is_admin());

CREATE POLICY stock_history_branch_read ON STOCK_HISTORY
FOR SELECT
USING (
    current_app_role() IN ('branch_manager', 'warehouse_staff')
    AND BranchID = current_app_branch_id()
);

CREATE POLICY inventory_allocation_admin_all ON INVENTORY_ALLOCATION
FOR ALL
USING (current_app_is_admin())
WITH CHECK (current_app_is_admin());

CREATE POLICY inventory_allocation_branch_read ON INVENTORY_ALLOCATION
FOR SELECT
USING (
    current_app_role() IN ('branch_manager', 'warehouse_staff', 'sales_staff')
    AND BranchID = current_app_branch_id()
);

CREATE POLICY inventory_allocation_branch_update ON INVENTORY_ALLOCATION
FOR UPDATE
USING (
    current_app_role() IN ('branch_manager', 'warehouse_staff')
    AND BranchID = current_app_branch_id()
)
WITH CHECK (
    current_app_role() IN ('branch_manager', 'warehouse_staff')
    AND BranchID = current_app_branch_id()
);


-- =========================================================
-- 6. Policy: PURCHASE_ORDER và PURCHASE_ORDER_DETAIL
-- =========================================================

CREATE POLICY purchase_order_admin_all ON PURCHASE_ORDER
FOR ALL
USING (current_app_is_admin())
WITH CHECK (current_app_is_admin());

CREATE POLICY purchase_order_branch_read ON PURCHASE_ORDER
FOR SELECT
USING (
    current_app_role() IN ('branch_manager', 'warehouse_staff')
    AND BranchID = current_app_branch_id()
);

CREATE POLICY purchase_order_warehouse_insert ON PURCHASE_ORDER
FOR INSERT
WITH CHECK (
    current_app_role() = 'warehouse_staff'
    AND BranchID = current_app_branch_id()
);

CREATE POLICY purchase_order_warehouse_update ON PURCHASE_ORDER
FOR UPDATE
USING (
    current_app_role() = 'warehouse_staff'
    AND BranchID = current_app_branch_id()
    AND Status IN ('draft', 'pending')
)
WITH CHECK (
    current_app_role() = 'warehouse_staff'
    AND BranchID = current_app_branch_id()
    AND Status IN ('draft', 'pending')
);

CREATE POLICY purchase_order_manager_approve ON PURCHASE_ORDER
FOR UPDATE
USING (
    current_app_role() = 'branch_manager'
    AND BranchID = current_app_branch_id()
    AND Status IN ('pending', 'approved')
)
WITH CHECK (
    current_app_role() = 'branch_manager'
    AND BranchID = current_app_branch_id()
    AND Status IN ('approved', 'received', 'cancelled')
);

CREATE POLICY purchase_order_detail_admin_all ON PURCHASE_ORDER_DETAIL
FOR ALL
USING (current_app_is_admin())
WITH CHECK (current_app_is_admin());

CREATE POLICY purchase_order_detail_branch_read ON PURCHASE_ORDER_DETAIL
FOR SELECT
USING (
    current_app_role() IN ('branch_manager', 'warehouse_staff')
    AND EXISTS (
        SELECT 1
        FROM PURCHASE_ORDER po
        WHERE po.PurchaseOrderID = PURCHASE_ORDER_DETAIL.PurchaseOrderID
          AND po.BranchID = current_app_branch_id()
    )
);

CREATE POLICY purchase_order_detail_warehouse_write ON PURCHASE_ORDER_DETAIL
FOR ALL
USING (
    current_app_role() = 'warehouse_staff'
    AND EXISTS (
        SELECT 1
        FROM PURCHASE_ORDER po
        WHERE po.PurchaseOrderID = PURCHASE_ORDER_DETAIL.PurchaseOrderID
          AND po.BranchID = current_app_branch_id()
          AND po.Status IN ('draft', 'pending')
    )
)
WITH CHECK (
    current_app_role() = 'warehouse_staff'
    AND EXISTS (
        SELECT 1
        FROM PURCHASE_ORDER po
        WHERE po.PurchaseOrderID = PURCHASE_ORDER_DETAIL.PurchaseOrderID
          AND po.BranchID = current_app_branch_id()
          AND po.Status IN ('draft', 'pending')
    )
);


-- =========================================================
-- 7. Policy: TRANSFER_ORDER và TRANSFER_ORDER_DETAIL
-- =========================================================

CREATE POLICY transfer_order_admin_all ON TRANSFER_ORDER
FOR ALL
USING (current_app_is_admin())
WITH CHECK (current_app_is_admin());

CREATE POLICY transfer_order_branch_read ON TRANSFER_ORDER
FOR SELECT
USING (
    current_app_role() IN ('branch_manager', 'warehouse_staff')
    AND (FromBranchID = current_app_branch_id() OR ToBranchID = current_app_branch_id())
);

CREATE POLICY transfer_order_warehouse_insert ON TRANSFER_ORDER
FOR INSERT
WITH CHECK (
    current_app_role() = 'warehouse_staff'
    AND FromBranchID = current_app_branch_id()
    AND FromBranchID <> ToBranchID
);

CREATE POLICY transfer_order_warehouse_update ON TRANSFER_ORDER
FOR UPDATE
USING (
    current_app_role() = 'warehouse_staff'
    AND FromBranchID = current_app_branch_id()
    AND Status IN ('draft', 'pending')
)
WITH CHECK (
    current_app_role() = 'warehouse_staff'
    AND FromBranchID = current_app_branch_id()
    AND Status IN ('draft', 'pending')
);

CREATE POLICY transfer_order_manager_approve ON TRANSFER_ORDER
FOR UPDATE
USING (
    current_app_role() = 'branch_manager'
    AND (FromBranchID = current_app_branch_id() OR ToBranchID = current_app_branch_id())
    AND Status IN ('pending', 'approved', 'in_transit')
)
WITH CHECK (
    current_app_role() = 'branch_manager'
    AND (FromBranchID = current_app_branch_id() OR ToBranchID = current_app_branch_id())
    AND Status IN ('approved', 'in_transit', 'received', 'cancelled')
);

CREATE POLICY transfer_order_detail_admin_all ON TRANSFER_ORDER_DETAIL
FOR ALL
USING (current_app_is_admin())
WITH CHECK (current_app_is_admin());

CREATE POLICY transfer_order_detail_branch_read ON TRANSFER_ORDER_DETAIL
FOR SELECT
USING (
    current_app_role() IN ('branch_manager', 'warehouse_staff')
    AND EXISTS (
        SELECT 1
        FROM TRANSFER_ORDER t
        WHERE t.TransferID = TRANSFER_ORDER_DETAIL.TransferID
          AND (t.FromBranchID = current_app_branch_id() OR t.ToBranchID = current_app_branch_id())
    )
);

CREATE POLICY transfer_order_detail_warehouse_write ON TRANSFER_ORDER_DETAIL
FOR ALL
USING (
    current_app_role() = 'warehouse_staff'
    AND EXISTS (
        SELECT 1
        FROM TRANSFER_ORDER t
        WHERE t.TransferID = TRANSFER_ORDER_DETAIL.TransferID
          AND t.FromBranchID = current_app_branch_id()
          AND t.Status IN ('draft', 'pending')
    )
)
WITH CHECK (
    current_app_role() = 'warehouse_staff'
    AND EXISTS (
        SELECT 1
        FROM TRANSFER_ORDER t
        WHERE t.TransferID = TRANSFER_ORDER_DETAIL.TransferID
          AND t.FromBranchID = current_app_branch_id()
          AND t.Status IN ('draft', 'pending')
    )
);


-- =========================================================
-- 8. Policy: STOCK_ADJUSTMENT và STOCK_ADJUSTMENT_DETAIL
-- =========================================================

CREATE POLICY stock_adjustment_admin_all ON STOCK_ADJUSTMENT
FOR ALL
USING (current_app_is_admin())
WITH CHECK (current_app_is_admin());

CREATE POLICY stock_adjustment_branch_read ON STOCK_ADJUSTMENT
FOR SELECT
USING (
    current_app_role() IN ('branch_manager', 'warehouse_staff')
    AND BranchID = current_app_branch_id()
);

CREATE POLICY stock_adjustment_staff_insert ON STOCK_ADJUSTMENT
FOR INSERT
WITH CHECK (
    current_app_role() IN ('branch_manager', 'warehouse_staff')
    AND BranchID = current_app_branch_id()
);

CREATE POLICY stock_adjustment_warehouse_update ON STOCK_ADJUSTMENT
FOR UPDATE
USING (
    current_app_role() = 'warehouse_staff'
    AND BranchID = current_app_branch_id()
    AND Status IN ('draft', 'counting')
)
WITH CHECK (
    current_app_role() = 'warehouse_staff'
    AND BranchID = current_app_branch_id()
    AND Status IN ('draft', 'counting', 'pending_approval')
);

CREATE POLICY stock_adjustment_manager_approve ON STOCK_ADJUSTMENT
FOR UPDATE
USING (
    current_app_role() = 'branch_manager'
    AND BranchID = current_app_branch_id()
    AND Status = 'pending_approval'
)
WITH CHECK (
    current_app_role() = 'branch_manager'
    AND BranchID = current_app_branch_id()
    AND Status IN ('completed', 'cancelled')
);

CREATE POLICY stock_adjustment_detail_admin_all ON STOCK_ADJUSTMENT_DETAIL
FOR ALL
USING (current_app_is_admin())
WITH CHECK (current_app_is_admin());

CREATE POLICY stock_adjustment_detail_branch_read ON STOCK_ADJUSTMENT_DETAIL
FOR SELECT
USING (
    current_app_role() IN ('branch_manager', 'warehouse_staff')
    AND EXISTS (
        SELECT 1
        FROM STOCK_ADJUSTMENT sa
        WHERE sa.AdjustmentID = STOCK_ADJUSTMENT_DETAIL.AdjustmentID
          AND sa.BranchID = current_app_branch_id()
    )
);

CREATE POLICY stock_adjustment_detail_warehouse_write ON STOCK_ADJUSTMENT_DETAIL
FOR ALL
USING (
    current_app_role() = 'warehouse_staff'
    AND EXISTS (
        SELECT 1
        FROM STOCK_ADJUSTMENT sa
        WHERE sa.AdjustmentID = STOCK_ADJUSTMENT_DETAIL.AdjustmentID
          AND sa.BranchID = current_app_branch_id()
          AND sa.Status IN ('draft', 'counting')
    )
)
WITH CHECK (
    current_app_role() = 'warehouse_staff'
    AND EXISTS (
        SELECT 1
        FROM STOCK_ADJUSTMENT sa
        WHERE sa.AdjustmentID = STOCK_ADJUSTMENT_DETAIL.AdjustmentID
          AND sa.BranchID = current_app_branch_id()
          AND sa.Status IN ('draft', 'counting')
    )
);


-- =========================================================
-- 9. Policy: ORDERS, ORDER_DETAIL, PAYMENT
-- =========================================================

CREATE POLICY orders_admin_all ON ORDERS
FOR ALL
USING (current_app_is_admin())
WITH CHECK (current_app_is_admin());

CREATE POLICY orders_branch_read ON ORDERS
FOR SELECT
USING (
    current_app_role() IN ('branch_manager', 'sales_staff')
    AND BranchID = current_app_branch_id()
);

CREATE POLICY orders_sales_insert ON ORDERS
FOR INSERT
WITH CHECK (
    current_app_role() = 'sales_staff'
    AND BranchID = current_app_branch_id()
);

CREATE POLICY orders_sales_update ON ORDERS
FOR UPDATE
USING (
    current_app_role() = 'sales_staff'
    AND BranchID = current_app_branch_id()
    AND OrderStatus IN ('new', 'confirmed')
)
WITH CHECK (
    current_app_role() = 'sales_staff'
    AND BranchID = current_app_branch_id()
    AND OrderStatus IN ('new', 'confirmed', 'processing', 'cancelled')
);

CREATE POLICY orders_manager_update ON ORDERS
FOR UPDATE
USING (
    current_app_role() = 'branch_manager'
    AND BranchID = current_app_branch_id()
)
WITH CHECK (
    current_app_role() = 'branch_manager'
    AND BranchID = current_app_branch_id()
);

CREATE POLICY order_detail_admin_all ON ORDER_DETAIL
FOR ALL
USING (current_app_is_admin())
WITH CHECK (current_app_is_admin());

CREATE POLICY order_detail_branch_read ON ORDER_DETAIL
FOR SELECT
USING (
    current_app_role() IN ('branch_manager', 'sales_staff')
    AND EXISTS (
        SELECT 1
        FROM ORDERS o
        WHERE o.OrderID = ORDER_DETAIL.OrderID
          AND o.BranchID = current_app_branch_id()
    )
);

CREATE POLICY order_detail_sales_write ON ORDER_DETAIL
FOR ALL
USING (
    current_app_role() = 'sales_staff'
    AND EXISTS (
        SELECT 1
        FROM ORDERS o
        WHERE o.OrderID = ORDER_DETAIL.OrderID
          AND o.BranchID = current_app_branch_id()
          AND o.OrderStatus = 'new'
    )
)
WITH CHECK (
    current_app_role() = 'sales_staff'
    AND EXISTS (
        SELECT 1
        FROM ORDERS o
        WHERE o.OrderID = ORDER_DETAIL.OrderID
          AND o.BranchID = current_app_branch_id()
          AND o.OrderStatus = 'new'
    )
);

CREATE POLICY payment_admin_all ON PAYMENT
FOR ALL
USING (current_app_is_admin())
WITH CHECK (current_app_is_admin());

CREATE POLICY payment_branch_read ON PAYMENT
FOR SELECT
USING (
    current_app_role() IN ('branch_manager', 'sales_staff')
    AND EXISTS (
        SELECT 1
        FROM ORDERS o
        WHERE o.OrderID = PAYMENT.OrderID
          AND o.BranchID = current_app_branch_id()
    )
);

CREATE POLICY payment_sales_insert ON PAYMENT
FOR INSERT
WITH CHECK (
    current_app_role() = 'sales_staff'
    AND EXISTS (
        SELECT 1
        FROM ORDERS o
        WHERE o.OrderID = PAYMENT.OrderID
          AND o.BranchID = current_app_branch_id()
    )
);


-- =========================================================
-- 10. Policy: RETURN_ORDER và RETURN_DETAIL
-- =========================================================

CREATE POLICY return_order_admin_all ON RETURN_ORDER
FOR ALL
USING (current_app_is_admin())
WITH CHECK (current_app_is_admin());

CREATE POLICY return_order_branch_read ON RETURN_ORDER
FOR SELECT
USING (
    current_app_role() IN ('branch_manager', 'sales_staff', 'warehouse_staff')
    AND BranchID = current_app_branch_id()
);

CREATE POLICY return_order_sales_insert ON RETURN_ORDER
FOR INSERT
WITH CHECK (
    current_app_role() = 'sales_staff'
    AND BranchID = current_app_branch_id()
);

CREATE POLICY return_order_manager_update ON RETURN_ORDER
FOR UPDATE
USING (
    current_app_role() = 'branch_manager'
    AND BranchID = current_app_branch_id()
)
WITH CHECK (
    current_app_role() = 'branch_manager'
    AND BranchID = current_app_branch_id()
);

CREATE POLICY return_detail_admin_all ON RETURN_DETAIL
FOR ALL
USING (current_app_is_admin())
WITH CHECK (current_app_is_admin());

CREATE POLICY return_detail_branch_read ON RETURN_DETAIL
FOR SELECT
USING (
    current_app_role() IN ('branch_manager', 'sales_staff', 'warehouse_staff')
    AND EXISTS (
        SELECT 1
        FROM RETURN_ORDER ro
        WHERE ro.ReturnID = RETURN_DETAIL.ReturnID
          AND ro.BranchID = current_app_branch_id()
    )
);

CREATE POLICY return_detail_sales_insert ON RETURN_DETAIL
FOR INSERT
WITH CHECK (
    current_app_role() = 'sales_staff'
    AND EXISTS (
        SELECT 1
        FROM RETURN_ORDER ro
        WHERE ro.ReturnID = RETURN_DETAIL.ReturnID
          AND ro.BranchID = current_app_branch_id()
          AND ro.Status = 'pending'
    )
);


-- =========================================================
-- 11. Query kiểm tra nhanh sau khi chạy file
-- =========================================================

-- Xem role và permission:
-- SELECT RoleName, Permissions FROM ROLE ORDER BY RoleName;

-- Kiểm tra bảng đã bật RLS:
-- SELECT tablename, rowsecurity
-- FROM pg_tables
-- WHERE schemaname = 'public'
--   AND tablename IN (
--       'stock','stock_history','inventory_allocation',
--       'purchase_order','purchase_order_detail',
--       'transfer_order','transfer_order_detail',
--       'stock_adjustment','stock_adjustment_detail',
--       'orders','order_detail','payment','return_order','return_detail'
--   )
-- ORDER BY tablename;

-- Kiểm tra policy đã tạo:
-- SELECT tablename, policyname, cmd
-- FROM pg_policies
-- WHERE schemaname = 'public'
-- ORDER BY tablename, policyname;

-- Mô phỏng user đang đăng nhập:
-- SELECT set_config(
--     'app.current_user_id',
--     (
--         SELECT UserID::TEXT
--         FROM USERS
--         WHERE Username = 'sales_q1'
--         LIMIT 1
--     ),
--     FALSE
-- );
--
-- SELECT
--     current_app_user_id() AS user_id,
--     current_app_role() AS role_name,
--     current_app_branch_id() AS branch_id;

-- ===== sql/12_optimize_database.sql =====
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

-- ===== sql/13_production_security.sql =====
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
