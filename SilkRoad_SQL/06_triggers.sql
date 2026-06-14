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
