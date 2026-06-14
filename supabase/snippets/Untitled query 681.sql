select 'product' as bang, count(*) from product
union all
select 'product_variant', count(*) from product_variant
union all
select 'stock', count(*) from stock
union all
select 'users', count(*) from users
union all
select 'role', count(*) from role
union all
select 'orders', count(*) from orders
union all
select 'inventory_allocation', count(*) from inventory_allocation;
