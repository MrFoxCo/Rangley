DO $$ DECLARE
    r RECORD;
BEGIN
    -- loop through all tables in your schema
    FOR r IN (SELECT tablename
              FROM pg_tables
              WHERE schemaname = 'rangley')  -- change schema if needed
    LOOP
        EXECUTE 'DROP TABLE IF EXISTS rangley.' || quote_ident(r.tablename) || ' CASCADE';
    END LOOP;
END $$;
