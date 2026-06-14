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
