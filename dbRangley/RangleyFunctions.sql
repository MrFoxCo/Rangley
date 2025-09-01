
CREATE OR REPLACE FUNCTION rangley.rangley_fn_v_meet_categories()
 RETURNS TABLE(meet_category_id smallint, name character varying)
 LANGUAGE sql
AS $function$
	select
		 meet_category_id
		,name
	from rangley.vw_meet_category
$function$
;


CREATE OR REPLACE FUNCTION rangley.rangley_fn_v_meets()
RETURNS TABLE
(
	 meet_id            int8
	,change_stamp       int8
	,meet_status_id     int2
	,latitude           float8
	,longitude          float8
	,region_latitude    float8
	,region_longitude   float8
	,region_radius	    float8
	,dttm_start_utc     timestamptz
	,dttm_end_utc       timestamptz
	,name               varchar(50)
	,category_name      varchar(50)
	,description        varchar(50)
	,max_capacity       int4
	,created_by_user_id int4
	,first_name         varchar(50)
	,last_name          varchar(50)
)
LANGUAGE sql
AS $function$
	select
		 meet_id
		,change_stamp
		,meet_status_id
		,latitude
		,longitude
		,region_latitude
		,region_longitude
		,region_radius
		,dttm_start_utc
		,dttm_end_utc
		,name
		,category_name
		,description
		,max_capacity
		,created_by_user_id
		,first_name
		,last_name
	from rangley.vw_meet_card_data
$function$;


CREATE OR REPLACE FUNCTION rangley.rangley_fn_v_user_by_user_id(p_user_id bigint)
RETURNS TABLE(
    username   text,
    first_name text,
    last_name  text,
    cellphone  text,
    email      text
)
LANGUAGE sql
AS $$
    SELECT
        btrim(v.username),
        initcap(btrim(v.first_name)),
        initcap(btrim(v.last_name)),
        regexp_replace(coalesce(v.cellphone,''), '\D', '', 'g'),
        lower(btrim(v.email))
    FROM rangley.vw_users v
    WHERE v.user_id = p_user_id;
$$;


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

-- DROP FUNCTION rangley.rangley_fn_v_meet_categories();
