-- Extension sinh UUID.
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Extension PostGIS dùng cho cột BRANCH.Coordinates.
CREATE EXTENSION IF NOT EXISTS postgis;


-- Enum dùng để giới hạn giá trị của các cột trong bảng, giúp đảm bảo tính nhất quán và dễ dàng quản lý.

DO $$
BEGIN
    CREATE TYPE record_status AS ENUM ('active', 'inactive');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    CREATE TYPE product_status AS ENUM ('active', 'inactive', 'discontinued');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    CREATE TYPE product_gender AS ENUM ('male', 'female', 'unisex', 'kids');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    CREATE TYPE variant_status AS ENUM ('active', 'inactive', 'out_of_production');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    CREATE TYPE branch_type AS ENUM ('retail_store', 'central_warehouse', 'sub_warehouse');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    CREATE TYPE branch_status AS ENUM ('active', 'inactive', 'renovating');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    CREATE TYPE stock_transaction_type AS ENUM (
        'purchase', 'sales', 'transfer_in', 'transfer_out',
        'adjustment', 'return', 'damage_write_off'
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    CREATE TYPE purchase_order_status AS ENUM ('draft', 'pending', 'approved', 'received', 'cancelled');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    CREATE TYPE transfer_order_status AS ENUM ('draft', 'pending', 'approved', 'in_transit', 'received', 'cancelled');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    CREATE TYPE stock_adjustment_status AS ENUM ('draft', 'counting', 'pending_approval', 'completed', 'cancelled');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    CREATE TYPE channel_type AS ENUM ('pos', 'website', 'shopee', 'tiktok', 'facebook', 'lazada');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    CREATE TYPE sync_status AS ENUM ('pending', 'processed', 'failed', 'skipped');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    CREATE TYPE customer_gender AS ENUM ('male', 'female', 'other');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    CREATE TYPE customer_status AS ENUM ('active', 'inactive', 'blocked');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    CREATE TYPE order_status AS ENUM (
        'new', 'confirmed', 'processing', 'packed',
        'shipped', 'delivered', 'cancelled', 'return_requested'
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    CREATE TYPE order_payment_status AS ENUM ('unpaid', 'paid', 'refunded');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_type t
        JOIN pg_enum e ON e.enumtypid = t.oid
        WHERE t.typname = 'order_payment_status'
          AND e.enumlabel = 'partially_refunded'
    ) THEN
        ALTER TYPE order_payment_status ADD VALUE 'partially_refunded' AFTER 'paid';
    END IF;
END $$;

DO $$
BEGIN
    CREATE TYPE payment_method AS ENUM ('cash', 'card', 'momo', 'vnpay', 'zalopay', 'bank_transfer');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    CREATE TYPE payment_record_status AS ENUM ('pending', 'success', 'failed', 'refunded');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    CREATE TYPE return_action_type AS ENUM ('refund', 'exchange', 'restock_only');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    CREATE TYPE refund_method AS ENUM ('cash', 'bank_transfer', 'loyalty_points');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    CREATE TYPE return_status AS ENUM ('pending', 'completed', 'cancelled');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    CREATE TYPE return_condition AS ENUM ('new', 'good', 'damaged');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    CREATE TYPE user_status AS ENUM ('active', 'inactive', 'locked');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
