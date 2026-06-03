# Database Optimization Audit

Tài liệu này ghi lại kết luận sau khi rà các file SQL cũ của SilkRoad. Mục tiêu là biết chỗ nào nên tối ưu bằng index, view, RPC, keyset pagination; chỗ nào không nên thêm cursor tường minh để tránh làm hệ thống khó bảo trì.

## Tóm tắt

- Không cần thêm `DECLARE CURSOR` cho các procedure hiện tại.
- Các procedure như xác nhận đơn, nhập kho, chuyển kho, kiểm kho và đổi trả đang xử lý từng dòng chi tiết để khóa tồn kho bằng `FOR UPDATE`, kiểm tra nghiệp vụ và ghi `STOCK_HISTORY`. Đây là luồng transaction, không phải luồng đọc danh sách dài.
- Với frontend/web app, nên dùng keyset pagination, còn gọi là cursor pagination ở tầng UI/API, thay vì mở database cursor tường minh.
- File tối ưu mới là `sql/12_optimize_database.sql`. File này chỉ thêm extension, index, view, function đọc nhanh và không xóa dữ liệu.

## Cursor: dùng hay không?

### Không thêm database cursor cho procedure giao dịch

Các procedure trong `sql/07_create_procedures.sql` có dạng:

- `sp_confirm_order`
- `sp_confirm_purchase_order`
- `sp_ship_transfer_order`
- `sp_receive_transfer_order`
- `sp_complete_stock_adjustment`
- `sp_complete_return_order`

Những procedure này đang dùng `FOR rec IN SELECT ... LOOP`. Trong PostgreSQL, đây đã là vòng lặp server-side phù hợp cho PL/pgSQL. Thêm `DECLARE CURSOR` ở đây không làm nghiệp vụ nhanh hơn rõ rệt, nhưng sẽ làm code dài hơn và dễ lỗi hơn.

Lý do nên giữ:

- Cần khóa dòng tồn kho bằng `FOR UPDATE`.
- Cần dừng ngay khi không đủ tồn, thiếu allocation hoặc refund vượt giới hạn.
- Cần ghi audit log cho từng biến thể vào `STOCK_HISTORY`.
- Số dòng chi tiết trong một đơn/phiếu thường nhỏ, không phải hàng chục nghìn dòng.

### Dùng keyset pagination cho danh sách dài

Các bảng có khả năng lớn nhanh:

- `ORDERS`
- `STOCK_HISTORY`
- `CHANNEL_SYNC_LOG`

Với những bảng này, dùng `OFFSET` lớn sẽ chậm dần vì database vẫn phải bỏ qua nhiều dòng. Vì vậy `sql/12_optimize_database.sql` đã thêm index và RPC theo kiểu keyset/cursor pagination:

- `fn_orders_page_app(p_limit, p_before_order_date, p_before_order_id)`
- `fn_stock_history_page_app(p_limit, p_before_timestamp, p_before_history_id)`
- `fn_channel_sync_log_page_app(p_limit, p_before_received_at, p_before_log_id)`

Frontend lấy trang đầu với cursor rỗng. Trang sau dùng `NextCursor...` của dòng cuối trang trước.

Ví dụ ý tưởng:

```js
// Trang đầu
await supabase.rpc("fn_orders_page_app", { p_limit: 50 });

// Trang tiếp theo
await supabase.rpc("fn_orders_page_app", {
  p_limit: 50,
  p_before_order_date: lastRow.NextCursorDate,
  p_before_order_id: lastRow.NextCursorID,
});
```

## Index đã bổ sung

### Auth/RBAC

- `idx_users_email_lower`
- `idx_users_role_status`
- `idx_users_branch_status`

Mục đích: login/profile theo email, lọc user theo role, trạng thái và chi nhánh.

### Product/POS search

- `idx_product_name_trgm`
- `idx_product_brand_trgm`
- `idx_variant_sku_trgm`
- `idx_variant_barcode_trgm`
- `idx_variant_status_product`
- `idx_product_image_primary_lookup`

Mục đích: tìm sản phẩm, biến thể, barcode, brand nhanh hơn khi POS/global search nhập từng ký tự.

### Inventory

- `idx_stock_branch_available`
- `idx_stock_low_stock`
- `idx_stock_last_updated`
- `idx_stock_history_time`
- `idx_stock_history_timestamp_id_desc`
- `idx_stock_history_variant_time`
- `idx_inventory_allocation_channel_available`

Mục đích: xem tồn theo chi nhánh, cảnh báo tồn thấp, lịch sử kho và tồn khả dụng theo kênh.

### Sales/reporting

- `idx_order_status_date`
- `idx_order_date_id_desc`
- `idx_order_payment_status_date`
- `idx_order_created_by_date`
- `idx_order_detail_variant`
- `idx_order_detail_variant_order`
- `idx_payment_order_status`
- `idx_payment_status_paid_at`
- `idx_return_status_date`
- `idx_return_branch_status_date`
- `idx_return_detail_variant`
- `idx_channel_sync_received_log_desc`

Mục đích: dashboard, báo cáo, đơn hàng, thanh toán, đổi trả và log đồng bộ.

## View/RPC nên dùng trong app

### POS và kho

Dùng `vw_pos_variant_stock_catalog` để lấy một lần:

- chi nhánh
- sản phẩm gốc
- biến thể
- size/màu
- giá bán
- tồn kho
- ảnh đại diện

Điều này giảm việc frontend phải join thủ công nhiều bảng hoặc kéo nhiều dataset rồi tự ghép.

### Search/catalog

Dùng `vw_product_search_catalog` cho danh sách sản phẩm gốc:

- tên sản phẩm
- brand
- danh mục
- số biến thể
- khoảng giá
- tổng tồn khả dụng
- ảnh đại diện

### Dashboard

Dùng `fn_dashboard_summary_app()` để lấy KPI tổng quan trong một RPC:

- sản phẩm gốc
- biến thể
- tồn thực
- tồn khả dụng
- sắp hết hàng
- đơn hàng hôm nay
- doanh thu hôm nay
- khách hàng
- thanh toán chờ xử lý

## Lộ trình tối ưu tiếp theo

1. App nên gọi `fn_dashboard_summary_app()` thay vì kéo nhiều bảng lớn để tự tính KPI.
2. Màn POS nên ưu tiên `vw_pos_variant_stock_catalog`, sau đó filter theo branch/search ở database.
3. Màn đơn hàng, lịch sử kho và log đồng bộ nên dùng các RPC keyset pagination mới.
4. Khi dữ liệu lớn hơn, chạy `EXPLAIN (ANALYZE, BUFFERS)` trên truy vấn thật để quyết định index tiếp theo.
5. Tránh thêm index tràn lan. Mỗi index giúp đọc nhanh hơn nhưng làm insert/update chậm hơn và tốn dung lượng.

## Kiểm tra khi áp dụng

Chạy tối ưu riêng:

```bash
psql -d silkroad -f sql/12_optimize_database.sql
```

Kiểm tra index/function đã tồn tại:

```sql
SELECT indexname FROM pg_indexes WHERE schemaname = 'public' ORDER BY indexname;
SELECT proname FROM pg_proc WHERE proname LIKE 'fn_%_page_app';
```

Sau khi import nhiều dữ liệu, chạy:

```sql
ANALYZE;
```

## Kết luận

Không cần bổ sung cursor tường minh vào các file SQL cũ. Phần đáng tối ưu là đường đọc dữ liệu cho app: index đúng hot path, view gom dữ liệu, RPC cho dashboard và keyset pagination cho bảng lớn.
