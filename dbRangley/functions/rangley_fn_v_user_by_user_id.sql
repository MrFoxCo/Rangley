-- DROP FUNCTION IF EXISTS rangley.rangley_fn_v_user_by_user_id(bigint);

CREATE OR REPLACE FUNCTION rangley.rangley_fn_v_user_by_user_id(p_user_id bigint)
RETURNS table
(
   cognito_sub  text
  ,username     varchar(50)
  ,display_name varchar(50)
  ,cellphone    varchar(16)
  ,email        varchar(256)
)
LANGUAGE plpgsql
STABLE
AS $fn$
DECLARE
  v_rid uuid := gen_random_uuid(); -- for log correlation
BEGIN
  	-- validate input
  	IF p_user_id IS NULL OR p_user_id <= 0 THEN
    	RAISE LOG '[ERRO][rid=%] invalid user_id:[%]', v_rid, p_user_id;
    	RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='[ERRO] invalid user_id (must be positive)';
  	END IF;

  	-- validate existence (use the view to honor any filters/soft-deletes)
  	IF NOT EXISTS (SELECT 1 FROM rangley.vw_users v WHERE v.user_id = p_user_id) THEN
    	RAISE LOG '[ERRO][rid=%] user_id:[%] not found.', v_rid, p_user_id;
    	RAISE EXCEPTION USING ERRCODE='P0002', MESSAGE='[ERRO] user_id not found';
  	END IF;

  	-- return row
	RETURN QUERY
    	SELECT v.cognito_sub, v.username, v.display_name, v.cellphone, v.email
    	FROM rangley.vw_users v
    	WHERE v.user_id = p_user_id;

  	RAISE LOG '[INFO][rid=%] returned user_id:[%]', v_rid, p_user_id;
END;
$fn$;


select * from rangley.rangley_fn_v_user_by_user_id(4);