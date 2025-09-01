CREATE OR REPLACE FUNCTION rangley.rangley_fn_validate_user_id(p_user_id bigint)
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
/*
SELECT rangley_fn_validate_user_id(3);


*/


DECLARE
  num_returned int := 0;
BEGIN
  SELECT COUNT(*) INTO num_returned
  FROM rangley.vw_users
  WHERE user_id = p_user_id;

  IF num_returned = 0 THEN
    RETURN -1;  -- error / not found
  END IF;

  RETURN 1;     -- success
END;
$function$;
