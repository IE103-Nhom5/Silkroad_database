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
