CREATE OR REPLACE FUNCTION rangley.rangley_fn_validate_meet_status_id(p_meet_status_id bigint)
RETURNS int
LANGUAGE plpgsql
AS $$
DECLARE
  num_returned int := 0;
BEGIN
  SELECT COUNT(*) INTO num_returned
  FROM rangley.vw_meet_status
  WHERE meet_status_id = p_meet_status_id;

  IF num_returned = 0 THEN
    RETURN -1;            -- not found
  END IF;

  RETURN 1;               -- found
END;
$$;

-- DROP FUNCTION rangley.rangley_fn_validate_user_id(int4);

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
  FROM vw_users
  WHERE user_id = p_user_id;

  IF num_returned = 0 THEN
    RETURN -1;  -- error / not found
  END IF;

  RETURN 1;     -- success
END;
$function$;