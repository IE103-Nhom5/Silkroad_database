-- 1. Kiểm tra tồn kho khả dụng
SELECT fn_get_available_stock(
    '00000000-0000-0000-0000-000000000202',
    '00000000-0000-0000-0000-000000000701'
) AS available_stock;

-- 2. Xác nhận đơn hàng mẫu: tồn kho giảm, SoldQuantity tăng, STOCK_HISTORY được ghi
CALL sp_confirm_order('00000000-0000-0000-0000-000000001201');

-- 3. Xem tồn kho theo chi nhánh sau khi xác nhận đơn
SELECT *
FROM vw_stock_by_branch
WHERE BranchID = '00000000-0000-0000-0000-000000000202'
ORDER BY SKU;

-- 4. Xem lịch sử biến động tồn kho
SELECT *
FROM vw_stock_movement_report
ORDER BY Timestamp DESC;

-- 5. Kiểm tra truy vấn JSONB
SELECT
    ProductName,
    DynamicAttributes->>'chat_lieu' AS ChatLieu,
    DynamicAttributes->>'kieu_co' AS KieuCo
FROM PRODUCT
WHERE DynamicAttributes @> '{"chat_lieu": "lụa"}';

-- 6. Xem tổng hợp đơn hàng
SELECT *
FROM vw_order_summary;
