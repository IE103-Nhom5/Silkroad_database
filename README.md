# SilkRoad Database

Kho mã nguồn cơ sở dữ liệu cho đề tài **Hệ thống quản lý hàng hóa đa kênh cho chuỗi cửa hàng thời trang bán lẻ**.

- Hệ quản trị CSDL: PostgreSQL
- Định hướng thiết kế: mô hình quan hệ kết hợp JSONB
- Phạm vi: sản phẩm, biến thể thời trang, tồn kho theo chi nhánh, nhập hàng, chuyển kho, kiểm kho, đơn hàng đa kênh, phân quyền và báo cáo

## 1. Cấu trúc thư mục

```text
silkroad-database/
├── sql/
│   ├── 00_reset_schema.sql
│   ├── 01_create_extensions.sql
│   ├── 02_create_types.sql
│   ├── 03_create_tables.sql
│   ├── 04_create_indexes.sql
│   ├── 05_create_functions.sql
│   ├── 06_create_triggers.sql
│   ├── 07_create_procedures.sql
│   ├── 08_create_views.sql
│   ├── 09_seed_sample_data.sql
│   ├── 10_test_queries.sql
│   ├── 11_create_permissions.sql
│   ├── 12_optimize_database.sql
│   ├── 13_production_security.sql
│   └── run_all.sql
├── docs/
│   ├── database_overview.md
│   ├── database_optimization_audit.md
│   └── schema-28-tables.md
├── scripts/
│   └── import_excel_to_postgres.py
├── import/
│   └── import_template.md
├── backup/
│   └── backup_restore_guide.md
├── supabase/
│   ├── migrations/
│   └── functions/
├── .github/
│   └── workflows/
├── .env.example
├── .gitignore
└── README.md
```

## 2. Chạy local bằng PostgreSQL

Tạo database:

```bash
createdb silkroad
```

Chạy toàn bộ script:

```bash
psql -d silkroad -f sql/run_all.sql
```

Kiểm thử nhanh:

```bash
psql -d silkroad -f sql/10_test_queries.sql
```

Tối ưu database sau khi schema đã có sẵn:

```bash
psql -d silkroad -f sql/12_optimize_database.sql
```

File `12_optimize_database.sql` chỉ thêm extension, index, view và function hỗ trợ đọc dữ liệu nhanh hơn. File này không reset schema và không xóa dữ liệu.

File `13_production_security.sql` liên kết profile với Supabase Auth, loại bỏ password giả khỏi bảng công khai, thêm audit log, RLS và các RPC transaction dùng cho frontend production.

Deploy Edge Functions sau khi cấu hình Supabase project:

```bash
supabase functions deploy admin-invite-user
supabase functions deploy admin-update-user-status
supabase functions deploy import-catalog
supabase functions deploy gemini-chat
```

`gemini-chat` chủ động trả trạng thái disabled cho tới khi API secret được cấp và phần xử lý backend được phê duyệt.

Ghi chú rà soát cursor/index/view nằm ở `docs/database_optimization_audit.md`.

```
