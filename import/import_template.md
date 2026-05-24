# Mẫu dữ liệu import

Có thể tạo file Excel/CSV với các sheet sau:

## Sheet `products`

| category_slug | product_name | slug | brand | gender | default_selling_price | tags | collection_name | dynamic_attributes |
|---|---|---|---|---|---:|---|---|---|
| ao-so-mi-nu | Áo Sơ Mi Lụa Cổ V | ao-so-mi-lua-co-v | SilkRoad | female | 350000 | new-arrival,best-seller | Thu Đông 2026 | {"chat_lieu":"lụa","kieu_co":"cổ V"} |

## Sheet `variants`

| product_slug | size | color | sku | barcode | cost_price | selling_price | weight |
|---|---|---|---|---|---:|---:|---:|
| ao-so-mi-lua-co-v | S | WHITE | SR-SML-WHT-S | 893000000001 | 150000 | 350000 | 0.25 |

## Sheet `stock`

| branch_name | sku | quantity | reserved_quantity | min_stock_level | max_stock_level |
|---|---|---:|---:|---:|---:|
| Cửa hàng Quận 1 | SR-SML-WHT-S | 20 | 0 | 5 | 60 |
