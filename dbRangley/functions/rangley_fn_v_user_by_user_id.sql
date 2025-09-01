-- DROP FUNCTION rangley.rangley_fn_v_user(bigint);

CREATE OR REPLACE FUNCTION rangley.rangley_fn_v_user_by_user_id(p_user_id bigint)
RETURNS TABLE(
    username   text,
    first_name text,
    last_name  text,
    cellphone  text,
    email      text
)
LANGUAGE sql
AS $fn$;
    SELECT
        btrim(v.username),
        initcap(btrim(v.first_name)),
        initcap(btrim(v.last_name)),
        regexp_replace(coalesce(v.cellphone,''), '\D', '', 'g'),
        lower(btrim(v.email))
    FROM rangley.vw_users v
    WHERE v.user_id = p_user_id;
$fn$;
