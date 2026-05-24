-- Extension sinh UUID.
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Extension PostGIS dùng cho cột BRANCH.Coordinates.
-- Nếu môi trường không hỗ trợ PostGIS, có thể thay Coordinates bằng Latitude/Longitude.
CREATE EXTENSION IF NOT EXISTS postgis;
