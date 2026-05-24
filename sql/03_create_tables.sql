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
