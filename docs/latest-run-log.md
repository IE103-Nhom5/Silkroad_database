# Nhật ký chạy mới nhất

## Ngày 14/06/2026 - Đồng bộ canonical SQL và Supabase migrations

### Trạng thái

**CHƯA HOÀN TẤT.** SQL và migration đã đồng bộ tĩnh, nhưng chưa thể chứng minh database dựng sạch vì máy chưa có Docker Desktop/Docker daemon. Không có thao tác nào được chạy trên production.

### Commit gốc

- Database HEAD trước khi sửa: `c932cf5ffb64336a59892c24c61e30f2ec13905a`.
- Remote: `https://github.com/IE103-Nhom5/Silkroad_database.git`.
- `git fetch origin` xác nhận local HEAD và `origin/main` không lệch (`0 0`).

### Thay đổi đã thực hiện

- Thêm `supabase/config.toml`, bật migration và seed local.
- Tạo baseline migration `supabase/migrations/202606140000_init_silkroad.sql` từ canonical SQL.
- Lưu migration legacy tại `supabase/archive/init_silkroad_legacy.sql`, chưa xóa.
- Đồng bộ migration cho SQL `14`, `15` và cursor `16`.
- Thêm `sql/16_cursor_low_stock_report.sql` và migration tương ứng.
- Sửa `sql/10_test_queries.sql` gọi `fn_cursor_low_stock_report_app(NULL, 20)` và kiểm tra contract bắt buộc.
- Thêm `scripts/check_sql_sync.py` để kiểm tra `run_all.sql`, baseline, incremental migrations và contract frontend.
- Cập nhật `sql/run_all.sql`, README, tài liệu tối ưu database và PostgreSQL CI.
- Bỏ `PasswordHash` và dummy password khỏi schema/seed công khai.

### PostgreSQL cursor thật

Function: `fn_cursor_low_stock_report_app(UUID, INTEGER)`.

Kiểm tra tĩnh bằng `rg -n "CURSOR|OPEN|FETCH|CLOSE" sql supabase/migrations` đã tìm thấy đầy đủ:

- `DECLARE ... CURSOR FOR`: dòng 26.
- `OPEN`: dòng 46.
- `FETCH`: dòng 48.
- `CLOSE`: dòng 61.

Cursor chưa được gọi trên database thật vì gate local bị chặn.

### Contract đã tìm thấy tĩnh trong SQL/migration

Views:

- `vw_product_search_catalog`
- `vw_pos_variant_stock_catalog`
- `vw_product_variant_catalog`
- `vw_stock_by_branch`
- `vw_order_summary`
- `vw_revenue_by_channel`

RPC:

- `fn_create_order_app`
- `fn_create_purchase_order_app`
- `fn_create_transfer_app`
- `fn_create_adjustment_app`
- `fn_create_return_app`
- `fn_set_inventory_allocation_app`
- `fn_cursor_low_stock_report_app`

### Kết quả lệnh database

| Lệnh | Exit code | Kết quả |
| --- | ---: | --- |
| `python scripts/check_sql_sync.py` | 0 | Pass: canonical SQL, `run_all.sql` và migrations đồng bộ |
| `git diff --check` | 0 | Pass, chỉ có cảnh báo chuyển LF/CRLF |
| `supabase --version` | 0 | `2.78.1` |
| `docker version` | 1 | Không tìm thấy lệnh Docker |
| `supabase start` | 1 | Fail: Docker Desktop là prerequisite |
| `supabase db reset --local` lần 1 | 1 | Fail: không có Docker daemon |
| `supabase db reset --local` lần 2 | 1 | Fail: không có Docker daemon |
| `supabase migration list --local` | 1 | Fail: không có Postgres Supabase tại `127.0.0.1:54322` |
| `supabase db lint --local` | 1 | Fail: không có Postgres Supabase tại `127.0.0.1:54322` |
| `supabase status` | 1 | Fail: không có Docker daemon |
| PostgreSQL 18 `psql -w` | 1 | Fail: local user `postgres` yêu cầu mật khẩu |
| PostgreSQL 18 chạy `sql/run_all.sql` lần 1 | 1 | Không chạy được vì local user `postgres` yêu cầu mật khẩu |
| PostgreSQL 18 chạy `sql/run_all.sql` lần 2 | 1 | Không chạy được vì local user `postgres` yêu cầu mật khẩu |
| PostgreSQL 18 chạy `sql/10_test_queries.sql` | 1 | Không chạy được vì local user `postgres` yêu cầu mật khẩu |

### Môi trường local đã xác minh

- PostgreSQL 18 service đang chạy.
- `psql.exe` và `createdb.exe` tồn tại.
- PostgreSQL 18 local không có `postgis.control`.
- Không dùng mật khẩu đoán, không ghi mật khẩu vào repo hoặc log.
- Không track `.env` thật hoặc `supabase/.temp`; quét source không phát hiện secret hard-code.
- Không reset production.

### Blocker bắt buộc trước khi kết luận hoàn tất

1. Cài và chạy Docker Desktop.
2. Chạy `supabase start`.
3. Chạy `supabase db reset --local` pass hai lần liên tiếp.
4. Chạy `sql/10_test_queries.sql` trên Postgres container với `ON_ERROR_STOP=1`.
5. Gọi cursor và truy vấn kiểm tra toàn bộ view/RPC bắt buộc.
6. Chạy `supabase migration list --local` và `supabase db lint --local`.

Cho tới khi các bước trên pass, trạng thái database vẫn là **chưa hoàn tất**.
