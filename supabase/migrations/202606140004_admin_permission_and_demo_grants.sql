-- =========================================================
-- SilkRoad active-admin permission bypass and demo grants
-- RLS policies and SECURITY DEFINER permission checks remain authoritative.
-- =========================================================

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
          AND u.Status = 'active'
          AND (LOWER(r.RoleName) = 'admin' OR p_permission = ANY(r.Permissions))
    );
$$;

-- App purchase flow can explicitly mark quantities received, then atomically
-- confirm the document through fn_confirm_purchase_order_app.
CREATE OR REPLACE FUNCTION fn_create_purchase_order_app(p_payload JSONB)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_id UUID := gen_random_uuid();
    v_line JSONB;
    v_quantity INT;
    v_received_quantity INT;
BEGIN
    PERFORM assert_app_permission('purchase_order.create');
    IF jsonb_array_length(COALESCE(p_payload->'lines', '[]'::JSONB)) = 0 THEN
        RAISE EXCEPTION 'BUSINESS_PURCHASE_LINES_REQUIRED';
    END IF;

    INSERT INTO PURCHASE_ORDER (PurchaseOrderID, SupplierID, BranchID, CreatedBy, ExpectedDate, Status, Note)
    VALUES (
        v_id,
        (p_payload->>'supplier_id')::UUID,
        (p_payload->>'branch_id')::UUID,
        current_app_user_id(),
        COALESCE((p_payload->>'expected_date')::DATE, CURRENT_DATE),
        'draft',
        NULLIF(p_payload->>'note', '')
    );

    FOR v_line IN SELECT value FROM jsonb_array_elements(p_payload->'lines')
    LOOP
        v_quantity := COALESCE((v_line->>'quantity')::INT, 0);
        v_received_quantity := COALESCE((v_line->>'received_quantity')::INT, 0);
        IF v_quantity <= 0 OR v_received_quantity < 0 OR v_received_quantity > v_quantity THEN
            RAISE EXCEPTION 'BUSINESS_QUANTITY_INVALID';
        END IF;

        INSERT INTO PURCHASE_ORDER_DETAIL (
            PurchaseOrderID, VariantID, RequestedQuantity, ReceivedQuantity, UnitPrice
        )
        VALUES (
            v_id,
            (v_line->>'variant_id')::UUID,
            v_quantity,
            v_received_quantity,
            COALESCE((v_line->>'unit_price')::DECIMAL, (v_line->>'unit_cost')::DECIMAL, 0)
        );
    END LOOP;

    PERFORM write_audit_log('purchase_order.create', 'purchase_order', v_id::TEXT, NULL, p_payload);
    RETURN v_id;
END;
$$;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
        GRANT USAGE ON SCHEMA public TO authenticated;
        GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO authenticated;
        GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated;
        GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO authenticated;
    END IF;
END $$;
