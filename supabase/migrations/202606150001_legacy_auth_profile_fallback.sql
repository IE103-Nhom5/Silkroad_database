-- Tài khoản tạo trước khi có AuthUserID vẫn có thể dùng nghiệp vụ bằng email trong JWT.
-- Chỉ fallback với hồ sơ chưa được liên kết để tránh nhận nhầm tài khoản đã có chủ.
DO $$
BEGIN
    IF to_regclass('auth.users') IS NOT NULL THEN
        UPDATE USERS u
        SET AuthUserID = a.id
        FROM auth.users a
        WHERE u.AuthUserID IS NULL
          AND u.Email IS NOT NULL
          AND a.email IS NOT NULL
          AND LOWER(TRIM(u.Email)) = LOWER(TRIM(a.email))
          AND NOT EXISTS (
              SELECT 1
              FROM USERS linked
              WHERE linked.AuthUserID = a.id
          );
    END IF;
END $$;

CREATE OR REPLACE FUNCTION current_auth_email()
RETURNS TEXT
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_email TEXT;
    v_claims TEXT;
BEGIN
    IF to_regprocedure('auth.jwt()') IS NOT NULL THEN
        EXECUTE 'SELECT auth.jwt() ->> ''email''' INTO v_email;
    END IF;

    IF NULLIF(v_email, '') IS NOT NULL THEN
        RETURN LOWER(TRIM(v_email));
    END IF;

    v_email := NULLIF(current_setting('request.jwt.claim.email', TRUE), '');
    IF v_email IS NOT NULL THEN
        RETURN LOWER(TRIM(v_email));
    END IF;

    v_claims := NULLIF(current_setting('request.jwt.claims', TRUE), '');
    IF v_claims IS NOT NULL THEN
        RETURN LOWER(TRIM(v_claims::JSONB ->> 'email'));
    END IF;

    RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION current_app_user_id()
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT u.UserID
    FROM USERS u
    WHERE u.Status = 'active'
      AND (
          u.AuthUserID = current_auth_user_id()
          OR (
              u.AuthUserID IS NULL
              AND current_auth_email() IS NOT NULL
              AND LOWER(TRIM(u.Email)) = current_auth_email()
          )
      )
    ORDER BY (u.AuthUserID = current_auth_user_id()) DESC
    LIMIT 1;
$$;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
        GRANT EXECUTE ON FUNCTION current_auth_email() TO authenticated;
        GRANT EXECUTE ON FUNCTION current_app_user_id() TO authenticated;
    END IF;
END $$;
