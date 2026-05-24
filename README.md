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
│   └── run_all.sql
├── docs/
│   ├── database_overview.md
│   └── github_section_for_report.md
├── scripts/
│   └── import_excel_to_postgres.py
├── import/
│   └── import_template.md
├── backup/
│   └── backup_restore_guide.md
├── supabase/
│   └── migrations/
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

## 3. Chạy trên Supabase

Có hai cách:

### Cách 1: SQL Editor

Mở Supabase Dashboard → SQL Editor → chạy lần lượt các file:

1. `01_create_extensions.sql`
2. `02_create_types.sql`
3. `03_create_tables.sql`
4. `04_create_indexes.sql`
5. `05_create_functions.sql`
6. `06_create_triggers.sql`
7. `07_create_procedures.sql`
8. `08_create_views.sql`
9. `09_seed_sample_data.sql` nếu cần dữ liệu mẫu

### Cách 2: Supabase migration

Dùng file migration trong:

```text
supabase/migrations/20260524000000_init_silkroad.sql
```

## 4. Lưu ý bảo mật

Không đưa các thông tin sau lên GitHub:

- Mật khẩu database thật
- Supabase connection string thật
- Access token của marketplace
- API key thanh toán
- Dữ liệu khách hàng thật

Chỉ dùng `.env.example` để mô tả biến môi trường cần có.

## 5. Gợi ý đưa vào báo cáo

Phần giải thích cách quản lý code bằng GitHub có sẵn tại:

```text
docs/github_section_for_report.md
```
