SILKROAD SQL - THỨ TỰ CHẠY

Thư mục này là bản SQL đã sắp xếp lại để nộp và trình bày đồ án.
Các file đều chứa SQL đầy đủ, không cần lấy thêm nội dung từ thư mục khác.

Thứ tự chạy:
01. drop_reset: xóa schema cũ để tạo lại từ đầu.
02. extensions_enums: tạo extension và các enum.
03. schema_tables_constraints: tạo bảng, khóa và ràng buộc.
04. indexes: tạo index.
05. functions_procedures: tạo function và procedure nghiệp vụ.
06. triggers: tạo trigger.
07. views: tạo view báo cáo và tra cứu.
08. rls_policies: tạo hàm phân quyền, RLS và policy.
09. seed_master_data: thêm dữ liệu nền như role, chi nhánh, danh mục, thuộc tính, kênh bán và nhà cung cấp.
10. seed_demo_data: thêm dữ liệu mẫu gồm sản phẩm, biến thể, tồn kho, đơn hàng và chứng từ.
11. grants_demo: cấp quyền demo và bổ sung các hàm nghiệp vụ còn lại.
12. tests: các câu lệnh kiểm tra sau khi dựng database.

Chạy toàn bộ database:
psql -v ON_ERROR_STOP=1 -d <ten_database> -f run_all.sql

Chạy test riêng:
psql -v ON_ERROR_STOP=1 -d <ten_database> -f 12_tests.sql

Lưu ý:
- run_all.sql không tự chạy 12_tests.sql.
- File 09 là dữ liệu nền cần có trước khi thêm dữ liệu demo.
- File 10 là dữ liệu mẫu để trình bày và kiểm tra báo cáo.
