# Backup và Restore PostgreSQL/Supabase

## 1. Backup local PostgreSQL

```bash
pg_dump -Fc -d silkroad -f backup/silkroad_$(date +%Y%m%d).dump
```

## 2. Restore local PostgreSQL

```bash
createdb silkroad_restore
pg_restore -d silkroad_restore backup/silkroad_YYYYMMDD.dump
```

## 3. Export SQL plain text

```bash
pg_dump -d silkroad -f backup/silkroad.sql
```

## 4. Supabase

Với Supabase, nên dùng:

- Supabase Dashboard → Database → Backups
- Hoặc dùng `pg_dump` với connection string từ Supabase Project Settings

Không đưa file backup có dữ liệu thật lên GitHub public.
