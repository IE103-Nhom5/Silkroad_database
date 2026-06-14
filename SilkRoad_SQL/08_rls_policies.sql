-- 2. Hàm hỗ trợ xác định user hiện tại
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


-- 3. Bật Row Level Security cho các bảng nghiệp vụ chính
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


-- 4. Xóa policy cũ để file có thể chạy lại nhiều lần
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


-- 5. Policy: STOCK, STOCK_HISTORY, INVENTORY_ALLOCATION
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


-- 6. Policy: PURCHASE_ORDER và PURCHASE_ORDER_DETAIL
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


-- 7. Policy: TRANSFER_ORDER và TRANSFER_ORDER_DETAIL
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


-- 8. Policy: STOCK_ADJUSTMENT và STOCK_ADJUSTMENT_DETAIL
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


-- 9. Policy: ORDERS, ORDER_DETAIL, PAYMENT
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


-- 10. Policy: RETURN_ORDER và RETURN_DETAIL
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


-- 11. Query kiểm tra nhanh sau khi chạy file
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
