-- =========================================================
-- SilkRoad auth profile provisioning and business guards
-- Chay sau 13_production_security.sql.
-- =========================================================

CREATE OR REPLACE FUNCTION handle_new_auth_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_role_id UUID;
    v_base_username TEXT;
    v_username TEXT;
    v_suffix INT := 0;
BEGIN
    IF EXISTS (SELECT 1 FROM USERS WHERE AuthUserID = NEW.id) THEN
        RETURN NEW;
    END IF;

    SELECT RoleID INTO v_role_id
    FROM ROLE
    WHERE RoleName = 'sales_staff'
    LIMIT 1;

    IF v_role_id IS NULL THEN
        RAISE EXCEPTION 'Default role sales_staff is missing';
    END IF;

    IF NEW.email IS NOT NULL AND EXISTS (
        SELECT 1 FROM USERS WHERE Email = NEW.email AND AuthUserID IS NULL
    ) THEN
        UPDATE USERS
        SET AuthUserID = NEW.id,
            FullName = COALESCE(NULLIF(NEW.raw_user_meta_data->>'full_name', ''), FullName),
            UpdatedAt = NOW()
        WHERE Email = NEW.email
          AND AuthUserID IS NULL;
        RETURN NEW;
    END IF;

    v_base_username := LOWER(REGEXP_REPLACE(
        COALESCE(
            NULLIF(NEW.raw_user_meta_data->>'username', ''),
            SPLIT_PART(COALESCE(NEW.email, NEW.id::TEXT), '@', 1)
        ),
        '[^a-z0-9_]+',
        '_',
        'g'
    ));
    v_base_username := TRIM(BOTH '_' FROM v_base_username);
    IF v_base_username = '' THEN
        v_base_username := 'user';
    END IF;

    v_username := LEFT(v_base_username, 50);
    WHILE EXISTS (SELECT 1 FROM USERS WHERE Username = v_username) LOOP
        v_suffix := v_suffix + 1;
        v_username := LEFT(v_base_username, 43) || '_' || v_suffix::TEXT;
    END LOOP;

    INSERT INTO USERS (AuthUserID, FullName, Username, Email, RoleID, Status)
    VALUES (
        NEW.id,
        COALESCE(NULLIF(NEW.raw_user_meta_data->>'full_name', ''), NEW.email, v_username),
        v_username,
        NEW.email,
        v_role_id,
        'active'
    );

    RETURN NEW;
END;
$$;

DO $$
BEGIN
    IF to_regclass('auth.users') IS NOT NULL THEN
        DROP TRIGGER IF EXISTS on_auth_user_created_create_profile ON auth.users;
        CREATE TRIGGER on_auth_user_created_create_profile
            AFTER INSERT ON auth.users
            FOR EACH ROW EXECUTE FUNCTION handle_new_auth_user();
    END IF;
END $$;

CREATE OR REPLACE FUNCTION guard_order_line_price()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
    v_cost_price DECIMAL(12,2);
BEGIN
    SELECT CostPrice INTO v_cost_price
    FROM PRODUCT_VARIANT
    WHERE VariantID = NEW.VariantID;

    IF v_cost_price IS NULL THEN
        RAISE EXCEPTION 'Product variant does not exist';
    END IF;
    IF NEW.UnitPrice < v_cost_price THEN
        RAISE EXCEPTION 'Selling price cannot be lower than cost price';
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_guard_order_line_price ON ORDER_DETAIL;
CREATE TRIGGER trg_guard_order_line_price
    BEFORE INSERT OR UPDATE OF UnitPrice, VariantID ON ORDER_DETAIL
    FOR EACH ROW EXECUTE FUNCTION guard_order_line_price();

CREATE OR REPLACE FUNCTION guard_return_quantity()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
    v_order_id UUID;
    v_sold_quantity INT;
    v_returned_quantity INT;
BEGIN
    SELECT OrderID INTO v_order_id
    FROM RETURN_ORDER
    WHERE ReturnID = NEW.ReturnID;

    SELECT Quantity INTO v_sold_quantity
    FROM ORDER_DETAIL
    WHERE OrderID = v_order_id
      AND VariantID = NEW.VariantID;

    IF v_sold_quantity IS NULL THEN
        RAISE EXCEPTION 'Returned variant was not sold in the original order';
    END IF;

    SELECT COALESCE(SUM(rd.ReturnQuantity), 0)::INT INTO v_returned_quantity
    FROM RETURN_DETAIL rd
    JOIN RETURN_ORDER ro ON ro.ReturnID = rd.ReturnID
    WHERE ro.OrderID = v_order_id
      AND rd.VariantID = NEW.VariantID
      AND (rd.ReturnID <> NEW.ReturnID OR rd.VariantID <> NEW.VariantID);

    IF v_returned_quantity + NEW.ReturnQuantity > v_sold_quantity THEN
        RAISE EXCEPTION 'Return quantity exceeds sold quantity';
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_guard_return_quantity ON RETURN_DETAIL;
CREATE TRIGGER trg_guard_return_quantity
    BEFORE INSERT OR UPDATE OF ReturnQuantity, VariantID ON RETURN_DETAIL
    FOR EACH ROW EXECUTE FUNCTION guard_return_quantity();

REVOKE ALL ON FUNCTION handle_new_auth_user() FROM PUBLIC;
REVOKE ALL ON FUNCTION guard_order_line_price() FROM PUBLIC;
REVOKE ALL ON FUNCTION guard_return_quantity() FROM PUBLIC;
