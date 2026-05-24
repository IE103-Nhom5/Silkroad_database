# Tổng quan cơ sở dữ liệu SilkRoad

## Nhóm bảng chính

| Nhóm | Bảng |
|---|---|
| Product | `PRODUCT_CATEGORY`, `PRODUCT`, `ATTRIBUTE`, `PRODUCT_VARIANT`, `PRODUCT_IMAGE` |
| Branches & Suppliers | `BRANCH`, `SUPPLIER`, `SUPPLIER_PRODUCT` |
| Inventory | `STOCK`, `STOCK_HISTORY`, `INVENTORY_ALLOCATION`, `PURCHASE_ORDER`, `PURCHASE_ORDER_DETAIL`, `TRANSFER_ORDER`, `TRANSFER_ORDER_DETAIL`, `STOCK_ADJUSTMENT`, `STOCK_ADJUSTMENT_DETAIL` |
| Sales Channels | `SALES_CHANNEL`, `CHANNEL_PRICE`, `CHANNEL_SYNC_LOG` |
| Sales | `CUSTOMER`, `ORDERS`, `ORDER_DETAIL`, `PAYMENT`, `RETURN_ORDER`, `RETURN_DETAIL` |
| Authorization | `ROLE`, `USERS` |

## Nguyên tắc thiết kế

1. Dữ liệu nghiệp vụ lõi được lưu bằng bảng quan hệ.
2. JSONB chỉ dùng cho dữ liệu mở rộng hoặc dữ liệu đến từ nền tảng bên ngoài.
3. Tồn kho hiện tại và lịch sử biến động tồn kho được tách riêng.
4. Các bảng giao dịch dùng khóa ngoại và ràng buộc `CHECK` để hạn chế dữ liệu sai.
5. `ORDERS` và `USERS` được dùng thay cho `ORDER` và `USER` để tránh trùng từ khóa SQL.
