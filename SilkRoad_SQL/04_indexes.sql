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
