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
