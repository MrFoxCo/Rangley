CREATE OR REPLACE FUNCTION rangley.rangley_fn_valid_change_stamp_meet_status_id(p_meet_status_id bigint)
RETURNS integer
LANGUAGE plpgsql
AS $$
/*

VERY IMPROTANT WE ONLY INSERT Cancelled, Postponed, Or Deleted Meet_Status_ID's

THE MEET STATUS ID VALUES ARE
1	Active
2	Cancelled
3	Postponed
4	Completed
5	Draft
6	Full
7	Deleted


That is because Active, Completed, Draft, or Full can be inferred by SQL Queries
*/
BEGIN
  IF p_meet_status_id IS NULL THEN
    RAISE EXCEPTION 'meet_status_id cannot be NULL';
  END IF;

  -- If you want to validate against the view’s actual rows:
  PERFORM 1
  FROM rangley.vw_meet_status
  WHERE meet_status_id = p_meet_status_id
    AND meet_status_id IN (2,3,7)
  LIMIT 1;

  IF FOUND THEN
    RETURN 1;  -- valid
  END IF;

  RAISE EXCEPTION
    'Only Cancelled(2), Postponed(3), or Deleted(7) may be inserted (got %).',
    p_meet_status_id
    USING HINT = 'Active, Completed, Draft, and Full are inferred.';
END;
$$;
-- DROP FUNCTION rangley.rangley_fn_validate_user_id(int8);

CREATE OR REPLACE FUNCTION rangley.rangley_fn_validate_meet_coordinate_id
( 
	p_meet_coordinate_id int8
)
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
  FROM vw_meet_coordinates
  WHERE meet_coordinate_id = p_meet_coordinate_id;

  IF num_returned = 0 THEN
    RETURN -1;  -- error / not found
  END IF;

  RETURN 1;     -- success
END;
$function$
;

CREATE OR REPLACE PROCEDURE rangley.rangley_i_meet_change_stamp
(
   IN  meet_id         		bigint
  ,IN  meet_status_id  		int
  ,OUT new_change_stamp  	bigint
)
LANGUAGE plpgsql
AS $$
DECLARE
	error_code    int := -1;
	num_inserted  int := 0;
	meet_ok       int := -1;  -- 1 = exists
	status_ok     int := -1;  -- 1 = exists
BEGIN
  -- null guards
	IF p_meet_id IS NULL OR p_meet_status_id IS NULL THEN
		RETURN;  -- keep error_code = -1
  	END IF;

  -- validate meet
	SELECT rangley.rangley_fn_validate_meet_id(p_meet_id)
		INTO meet_ok;
	IF meet_ok <> 1 THEN
		RETURN;
	END IF;

  -- validate status
	SELECT rangley.rangley_fn_validate_meet_status_id(p_meet_status_id)
    	INTO status_ok;
	IF status_ok <> 1 THEN
		RETURN;
  	END IF;

  -- insert & return generated change_stamp
	INSERT INTO rangley.tb_meet_change_stamps
	VALUES
	(
		 meet_id
		,meet_status_id
	)
  	RETURNING change_stamp INTO new_change_stamp;

  GET DIAGNOSTICS num_inserted = ROW_COUNT;
  IF num_inserted = 0 THEN
    RETURN;
  END IF;

  error_code := 0;
END;
$$;

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
