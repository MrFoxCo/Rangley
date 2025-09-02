CREATE OR REPLACE FUNCTION rangley.rangley_fn_validate_cog_sub(p_cog_sub text)
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
/*
SELECT rangley_fn_validate_cog_sub(3);


*/


DECLARE
  num_returned int := 0;
BEGIN
  SELECT COUNT(*) INTO num_returned
  FROM rangley.vw_users
  WHERE cog_sub = p_cog_sub;

  IF num_returned = 0 THEN
    RETURN -1;  -- error / not found
  END IF;

  RETURN 1;     -- success
END;
$function$;
