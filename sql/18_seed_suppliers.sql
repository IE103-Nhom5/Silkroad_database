-- Nhà cung cấp mẫu phục vụ quy trình nhập hàng.
-- Điều kiện NOT EXISTS giúp script an toàn khi chạy lại trên local hoặc Supabase web.
INSERT INTO public.supplier (
    supplierid,
    suppliername,
    taxcode,
    phonenumber,
    email,
    address,
    paymenttermdays,
    status
)
SELECT
    v.supplierid,
    v.suppliername,
    v.taxcode,
    v.phonenumber,
    v.email,
    v.address,
    v.paymenttermdays,
    v.status
FROM (
    VALUES
        (gen_random_uuid(), 'Công ty TNHH Dệt May An Phú', '0312456789', '0909123456', 'contact@anphutextile.vn', '12 Nguyễn Văn Linh, Quận 7, TP.HCM', 30, 'active'::record_status),
        (gen_random_uuid(), 'Xưởng May Lụa Đông Á', '0319876543', '0918222333', 'sales@dongasilk.vn', '45 Lê Văn Việt, TP. Thủ Đức, TP.HCM', 15, 'active'::record_status),
        (gen_random_uuid(), 'Nhà cung cấp Vải Cotton Việt', '0104567891', '0987654321', 'cottonviet@supplier.vn', '88 Phố Huế, Hai Bà Trưng, Hà Nội', 30, 'active'::record_status),
        (gen_random_uuid(), 'Công ty Phụ Kiện Thời Trang Minh Khang', '0311122334', '0933444555', 'minhkhang.accessories@gmail.com', '21 Cách Mạng Tháng 8, Quận 3, TP.HCM', 20, 'active'::record_status),
        (gen_random_uuid(), 'Xưởng Gia Công Premium Wear', '3709988776', '0977111222', 'order@premiumwear.vn', 'KCN Sóng Thần, Dĩ An, Bình Dương', 45, 'active'::record_status),
        (gen_random_uuid(), 'Công ty TNHH Vải Linen Mộc', '0102233445', '0966555444', 'linenmoc@fabric.vn', '16 Trần Duy Hưng, Cầu Giấy, Hà Nội', 30, 'active'::record_status),
        (gen_random_uuid(), 'Nhà cung cấp Denim Saigon', '0316677889', '0944888999', 'denimsaigon@supplier.vn', '102 Âu Cơ, Tân Bình, TP.HCM', 25, 'active'::record_status),
        (gen_random_uuid(), 'Công ty Bao Bì Nhãn Mác Hoàng Gia', '0315566778', '0922333444', 'label@hoanggia.vn', '5 Nguyễn Oanh, Gò Vấp, TP.HCM', 15, 'active'::record_status)
) AS v(
    supplierid,
    suppliername,
    taxcode,
    phonenumber,
    email,
    address,
    paymenttermdays,
    status
)
WHERE NOT EXISTS (
    SELECT 1
    FROM public.supplier AS s
    WHERE lower(trim(s.suppliername)) = lower(trim(v.suppliername))
);
