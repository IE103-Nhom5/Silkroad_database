-- =========================================================
-- PostgreSQL cursor demo for the SilkRoad graduation project.
-- Runtime web pagination continues to use keyset pagination.
-- =========================================================

CREATE OR REPLACE FUNCTION fn_cursor_low_stock_report_app(
    p_branch_id UUID DEFAULT NULL,
    p_limit INTEGER DEFAULT 100
)
RETURNS TABLE (
    branch_id UUID,
    branch_name TEXT,
    variant_id UUID,
    sku TEXT,
    product_name TEXT,
    available_quantity INTEGER,
    min_stock_level INTEGER,
    suggested_reorder_quantity INTEGER
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    low_stock_cursor CURSOR FOR
        SELECT
            b.BranchID,
            b.BranchName::TEXT,
            pv.VariantID,
            pv.SKU::TEXT,
            p.ProductName::TEXT,
            s.AvailableQuantity,
            s.MinStockLevel,
            GREATEST(s.MinStockLevel - s.AvailableQuantity, 0) AS SuggestedReorderQuantity
        FROM STOCK s
        JOIN BRANCH b ON b.BranchID = s.BranchID
        JOIN PRODUCT_VARIANT pv ON pv.VariantID = s.VariantID
        JOIN PRODUCT p ON p.ProductID = pv.ProductID
        WHERE (p_branch_id IS NULL OR s.BranchID = p_branch_id)
          AND s.AvailableQuantity <= s.MinStockLevel
        ORDER BY s.AvailableQuantity ASC, b.BranchName, pv.SKU
        LIMIT LEAST(GREATEST(COALESCE(p_limit, 100), 1), 500);
    v_row RECORD;
BEGIN
    OPEN low_stock_cursor;
    LOOP
        FETCH low_stock_cursor INTO v_row;
        EXIT WHEN NOT FOUND;

        branch_id := v_row.BranchID;
        branch_name := v_row.BranchName;
        variant_id := v_row.VariantID;
        sku := v_row.SKU;
        product_name := v_row.ProductName;
        available_quantity := v_row.AvailableQuantity;
        min_stock_level := v_row.MinStockLevel;
        suggested_reorder_quantity := v_row.SuggestedReorderQuantity;
        RETURN NEXT;
    END LOOP;
    CLOSE low_stock_cursor;
END;
$$;

REVOKE ALL ON FUNCTION fn_cursor_low_stock_report_app(UUID, INTEGER) FROM PUBLIC;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
        GRANT EXECUTE ON FUNCTION fn_cursor_low_stock_report_app(UUID, INTEGER) TO authenticated;
    END IF;
END $$;
