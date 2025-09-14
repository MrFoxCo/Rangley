-- DROP FUNCTION rangley.rangley_fn_v_user_id_by_cognito_sub(text);

CREATE OR REPLACE FUNCTION rangley.rangley_fn_v_user_id_by_cognito_sub(p_cognito_sub text)
 RETURNS TABLE(user_id bigint)
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
    v_rid uuid := gen_random_uuid(); -- for log correlation
BEGIN
    -- validate input
    IF p_cognito_sub IS NULL OR trim(p_cognito_sub) = '' THEN
        RAISE LOG '[ERRO][rid=%] invalid cognito_sub:[%]', v_rid, p_cognito_sub;
        RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='[ERRO] invalid cognito_sub (cannot be null or empty)';
    END IF;

    -- validate existence (use the view to honor any filters/soft-deletes)
    IF NOT EXISTS (SELECT 1 FROM rangley.vw_users v WHERE v.cognito_sub = p_cognito_sub) THEN
        RAISE LOG '[ERRO][rid=%] cognito_sub:[%] not found.', v_rid, p_cognito_sub;
        RAISE EXCEPTION USING ERRCODE='P0002', MESSAGE='[ERRO] cognito_sub not found';
    END IF;

    -- return row
    RETURN QUERY
    SELECT
        v.user_id
    FROM rangley.vw_users v
    WHERE v.cognito_sub = p_cognito_sub;

    RAISE LOG '[INFO][rid=%] returned cognito_sub:[%]', v_rid, p_cognito_sub;
END;
$function$
;
