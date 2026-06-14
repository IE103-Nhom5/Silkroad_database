\set ON_ERROR_STOP on
\echo 'Bat dau dung database SilkRoad'

\ir 01_drop_reset.sql
\ir 02_extensions_enums.sql
\ir 03_schema_tables_constraints.sql
\ir 04_indexes.sql
\ir 05_functions_procedures.sql
\ir 06_triggers.sql
\ir 07_views.sql
\ir 08_rls_policies.sql
\ir 09_seed_master_data.sql
\ir 10_seed_demo_data.sql
\ir 11_grants_demo.sql

\echo 'Da dung xong database SilkRoad'
