-- DANGER: chỉ dùng cho môi trường local/dev.
-- File này sẽ reset toàn bộ object trong schema public.

DROP SCHEMA IF EXISTS public CASCADE;
CREATE SCHEMA public;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO public;
