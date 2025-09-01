-- DROP PROCEDURE rangley.rangley_i_feature_id(int4, text);

CREATE OR REPLACE PROCEDURE rangley.rangley_i_feature_id(IN p_feature_id integer, IN p_name text)
 LANGUAGE sql
AS $procedure$
INSERT INTO rangley.td_features
(
	 feature_id
	,name
)
VALUES
(
	 p_feature_id
	,p_name
);
$procedure$
;
-- DROP PROCEDURE rangley.rangley_i_meet(out int4, in int8, in varchar, in timestamptz, in timestamptz, in varchar, in varchar, in int2, in int4);

CREATE OR REPLACE PROCEDURE rangley.rangley_i_meet(OUT num_inserted integer, IN p_meet_id bigint, IN p_name character varying, IN p_dttm_start_utc timestamp with time zone, IN p_dttm_end_utc timestamp with time zone, IN p_description character varying DEFAULT ''::character varying(50), IN p_change_reason character varying DEFAULT ''::character varying(50), IN p_meet_category_id smallint DEFAULT (1)::smallint, IN p_max_capacity integer DEFAULT 2)
 LANGUAGE plpgsql
AS $procedure$
-- TODO FIX THE ERROR MESSAGES MAKE THEM MORE HUMAN READABLE
DECLARE
	is_valid_meet_id int := 0;
	error_code       int := -1;
  	_state  text;
  	_msg    text;
  	_detail text;
  	_hint   text;
BEGIN
  	-- default result
	num_inserted := 0;


	  IF 	p_meet_id 		IS NULL
 		OR  p_name 			IS NULL
     	OR p_dttm_start_utc IS NULL
     	OR p_dttm_end_utc 	IS NULL THEN
    	
		RAISE NOTICE E'i_meet: null required param(s)
			(meet_id=%, name=%, start=%, end=%)',
	      	p_meet_id, p_name, p_dttm_start_utc, p_dttm_end_utc;
	    	
		RETURN;
	  
	END IF;

  	-- minimal guards
	SELECT rangley.rangley_fn_validate_meet_id(p_meet_id)
    	INTO is_valid_meet_id;

  IF is_valid_meet_id <> 1 THEN
    RAISE NOTICE 'i_meet: invalid meet_id %', p_meet_id;
	RETURN;

  END IF;


  -- time window (required → both present)
  IF p_dttm_start_utc >= p_dttm_end_utc THEN
    RAISE NOTICE 'i_updated_meet: start >= end (start=%, end=%)', 
				 p_dttm_start_utc, p_dttm_end_utc;
    RETURN;
  END IF;

  	INSERT INTO rangley.tb_meets
	(
		 meet_id
		,name
		,description
		,change_reason
		,meet_category_id
		,max_capacity
		,dttm_start_utc
		,dttm_end_utc
	)
  	VALUES
    (
 		 p_meet_id
      	,p_name
      	,p_description
      	,p_change_reason
      	,p_meet_category_id
      	,p_max_capacity
		,p_dttm_start_utc
		,p_dttm_end_utc
    );

	GET DIAGNOSTICS num_inserted = ROW_COUNT;

  IF num_inserted <> 1 THEN
    RAISE NOTICE 'i_meet: insert affected % rows (expected 1) for meet_id=%',
      num_inserted, p_meet_id;
  END IF;



EXCEPTION
  WHEN unique_violation THEN
    -- surface a stable OUT for callers (if you have one)
    num_inserted := 0;          -- or is_success := B'0';
    error_code   := -2;
    RAISE NOTICE 'i_meet: duplicate key [meet_id=%], error code [error_code=%]',
      p_meet_id, error_code;

  WHEN check_violation THEN
    num_inserted := 0;
    error_code   := -3;
    RAISE NOTICE 'i_meet: check constraint violated meet id [meet_id=%], error code [error_code=%]',
      p_meet_id, error_code;

  WHEN OTHERS THEN
    num_inserted := 0;
    error_code   := -99;
    GET STACKED DIAGNOSTICS
      _state  = RETURNED_SQLSTATE,
      _msg    = MESSAGE_TEXT,
      _detail = PG_EXCEPTION_DETAIL,
      _hint   = PG_EXCEPTION_HINT;
    RAISE NOTICE 'i_meet: unexpected error sqlstate=% msg=% | detail=% | hint=% (meet_id=%), error_code=%',
      _state, _msg, COALESCE(_detail,'(none)'), COALESCE(_hint,'(none)'), p_meet_id, error_code;

	
END;
$procedure$
;
-- DROP PROCEDURE rangley.rangley_i_meet_change_stamp(out int8, in int8, in int2);

CREATE OR REPLACE PROCEDURE rangley.rangley_i_meet_change_stamp(OUT new_change_stamp bigint, IN p_meet_id bigint, IN p_meet_status_id smallint DEFAULT (0)::smallint)
 LANGUAGE plpgsql
AS $procedure$
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

DECLARE
	is_valid_meet_id int;
  	is_valid_status  int;
BEGIN
  -- null guards
	IF p_meet_id IS NULL OR p_meet_status_id IS NULL THEN
    	RAISE EXCEPTION 'meet_id and meet_status_id cannot be NULL';
  	END IF;

  -- validate meet exists
	SELECT rangley.rangley_fn_validate_meet_id(p_meet_id)
    	INTO is_valid_meet_id;
  	
	IF is_valid_meet_id <> 1 THEN
    	RAISE EXCEPTION 'Meet ID % does not exist or is invalid.', p_meet_id;
  	END IF;

  -- validate status is one of (2,3,7) per your rule
	SELECT rangley.rangley_fn_valid_change_stamp_meet_status_id(p_meet_status_id)
    	INTO is_valid_status;
  
	IF is_valid_status <> 1 THEN
    	RAISE EXCEPTION 'Only Cancelled(2), Postponed(3), or Deleted(7) may be inserted (got %).',
      	p_meet_status_id
      	USING HINT = 'Active, Completed, Draft, and Full are inferred.';
  	END IF;

  -- insert & return generated change_stamp
	INSERT INTO rangley.tb_meet_change_stamps
	(
		 meet_id
		,meet_status_id
	)
	VALUES
	(
		 p_meet_id
		,p_meet_status_id
	)
  	RETURNING change_stamp INTO new_change_stamp;

	
	EXCEPTION
		WHEN unique_violation THEN
    		RAISE EXCEPTION 'Duplicate change-stamp insert blocked for meet_id % / status %.',
      		p_meet_id, p_meet_status_id
      		USING ERRCODE = '23505';
  		WHEN check_violation THEN
    		RAISE EXCEPTION 'Check constraint failed inserting change-stamp for meet_id % / status %.',
      		p_meet_id, p_meet_status_id
      		USING ERRCODE = '23514';
  		WHEN OTHERS THEN
    	RAISE; -- bubble up with original message/state
END;
$procedure$
;

-- DROP PROCEDURE rangley.rangley_i_meet_coordinate(in float8, in float8, in float8, in float8, in float8, out int8);

CREATE OR REPLACE PROCEDURE rangley.rangley_i_meet_coordinate(IN p_latitude double precision, IN p_longitude double precision, IN p_region_latitude double precision, IN p_region_longitude double precision, IN p_region_radius double precision, OUT new_meet_coordinate_id bigint)
 LANGUAGE plpgsql
AS $procedure$
-- TODO FIX THE ERROR MESSAGES MAKE THEM MORE HUMAN READABLE
DECLARE
  	error_code   int := -1;
  	_state  text;
  	_msg    text;
  	_detail text;
  	_hint   text;
BEGIN
	  -- basic null checks
  	IF 	    p_latitude 			IS NULL
	     OR p_longitude 		IS NULL
	     OR p_region_latitude 	IS NULL
	     OR p_region_longitude 	IS NULL
	     OR p_region_radius 	IS NULL
  	THEN
	    -- leave sentinel; optionally log
	    RAISE WARNING 'i_meet_coordinate: null param(s) [error_code=%]', error_code;
	    RETURN;
  	END IF;

	INSERT INTO rangley.tb_meet_coordinates
	(
       	 latitude
      	,longitude
      	,region_latitude
      	,region_longitude
      	,region_radius
  	)
  	VALUES 
	(
       	 p_latitude
      	,p_longitude
      	,p_region_latitude
      	,p_region_longitude
  		,p_region_radius
 	 )

	RETURNING meet_coordinate_id INTO new_meet_coordinate_id;

  IF new_meet_coordinate_id IS NULL THEN
    -- unexpected; keep sentinel and log
    RAISE WARNING 'i_meet_coordinate: INSERT returned NULL id [error_code=%]', error_code;
    RETURN;
  END IF;


EXCEPTION
  WHEN unique_violation THEN
    error_code := -2;
    new_meet_coordinate_id := -1;
    RAISE WARNING 'i_meet_coordinate failed [error_code=%]: duplicate key', error_code;

  WHEN check_violation THEN
    error_code := -3;
    new_meet_coordinate_id := -1;
    RAISE WARNING 'i_meet_coordinate failed [error_code=%]: check constraint violated', error_code;

  WHEN OTHERS THEN
    error_code := -99;
    new_meet_coordinate_id := -1;
    GET STACKED DIAGNOSTICS
      _state  = RETURNED_SQLSTATE,
      _msg    = MESSAGE_TEXT,
      _detail = PG_EXCEPTION_DETAIL,
      _hint   = PG_EXCEPTION_HINT;
    RAISE WARNING 'i_meet_coordinate failed [error_code=%]: % - % | detail: % | hint: %',
      error_code, _state, _msg, COALESCE(_detail,'(none)'), COALESCE(_hint,'(none)');
END;
$procedure$
;

-- DROP PROCEDURE rangley.rangley_i_meet_id(in int8, in int8, out int8);

CREATE OR REPLACE PROCEDURE rangley.rangley_i_meet_id(IN p_meet_coordinate_id bigint, IN p_created_by_user_id bigint, OUT new_meet_id bigint)
 LANGUAGE plpgsql
AS $procedure$
-- TODO FIX THE ERROR MESSAGES MAKE THEM MORE HUMAN READABLE
DECLARE
	error_code int := -1;
	is_valid_meet_coordinate int := -1;
  	is_valid_user            int := -1;  -- 1 = ok
 	_state  text;
  	_msg    text;
  	_detail text;
  	_hint   text;
BEGIN
  	-- default sentinel so OUT is NEVER NULL
	new_meet_id := -1;

  	-- basic guards
  IF p_meet_coordinate_id IS NULL OR p_created_by_user_id IS NULL THEN
    RAISE NOTICE 'i_meet_id: null parameter(s)';
    RETURN;
  END IF;
  	SELECT rangley.rangley_fn_validate_meet_coordinate_id(p_meet_coordinate_id)
    	INTO is_valid_meet_coordinate;
  
  IF is_valid_meet_coordinate <> 1 THEN
    RAISE NOTICE 'i_meet_id: invalid meet_coordinate_id %', p_meet_coordinate_id;
    RETURN;
  END IF;
  	SELECT rangley.rangley_fn_validate_user_id(p_created_by_user_id)
    	INTO is_valid_user;
  
  IF is_valid_user <> 1 THEN
    RAISE NOTICE 'i_meet_id: invalid user_id %', p_created_by_user_id;
    RETURN;
  END IF;

  -- insert and capture id
	INSERT INTO rangley.tb_meet_ids
	(
		 meet_coordinate_id
		,created_by_user_id
	)
  	VALUES
	(
		 p_meet_coordinate_id
		,p_created_by_user_id
	)
	RETURNING meet_id INTO new_meet_id;

  IF new_meet_id IS NULL THEN
    RAISE NOTICE 'i_meet_id: insert returned null id';
    RETURN;
  END IF;

	
EXCEPTION
  WHEN unique_violation THEN
    error_code := -2;
    RAISE WARNING 'i_meet_id failed [error_code=%]: duplicate key', error_code;

  WHEN check_violation THEN
    error_code := -3;
    RAISE WARNING 'i_meet_id failed [error_code=%]: check constraint violated', error_code;

  WHEN OTHERS THEN
    error_code := -99;
    GET STACKED DIAGNOSTICS
      _state  = RETURNED_SQLSTATE,
      _msg    = MESSAGE_TEXT,
      _detail = PG_EXCEPTION_DETAIL,
      _hint   = PG_EXCEPTION_HINT;
    RAISE WARNING 'i_meet_id failed [error_code=%]: % - % | detail: % | hint: %',
      error_code, _state, _msg, COALESCE(_detail,'(none)'), COALESCE(_hint,'(none)');

END;
$procedure$
;

-- DROP PROCEDURE rangley.rangley_i_updated_meet(out int4, in int8, in int8, in varchar, in timestamptz, in timestamptz, in varchar, in varchar, in int2, in int4);

CREATE OR REPLACE PROCEDURE rangley.rangley_i_updated_meet(OUT num_inserted integer, IN p_meet_id bigint, IN p_change_stamp bigint, IN p_name character varying, IN p_dttm_start_utc timestamp with time zone, IN p_dttm_end_utc timestamp with time zone, IN p_description character varying DEFAULT ''::character varying(50), IN p_change_reason character varying DEFAULT ''::character varying(50), IN p_meet_category_id smallint DEFAULT (1)::smallint, IN p_max_capacity integer DEFAULT 2)
 LANGUAGE plpgsql
AS $procedure$

DECLARE 
  is_valid_meet_id int := -1;  -- 1 = ok
  _state  text; _msg text; _detail text; _hint text;
BEGIN

	-- initiliaze values
	num_inserted := 0;

	-- CLEAN DATA
	  IF p_meet_id IS NULL
	     OR p_change_stamp IS NULL
	     OR p_dttm_start_utc IS NULL
	     OR p_dttm_end_utc IS NULL
	  THEN
	    RAISE NOTICE E'i_updated_meet: null required param(s)
	(meet_id=%, stamp=%, start=%, end=%)',
	      p_meet_id, p_change_stamp, p_dttm_start_utc, p_dttm_end_utc;
	    RETURN;
	  END IF;


	

	  -- Validate user via your function
  SELECT rangley.rangley_fn_validate_meet_id(p_meet_id)
    INTO is_valid_meet_id;

  -- validate meet exists
  SELECT rangley.rangley_fn_validate_meet_id(p_meet_id)
    INTO is_valid_meet_id;

  IF is_valid_meet_id <> 1 THEN
    RAISE NOTICE 'i_updated_meet: invalid meet_id %', p_meet_id;
    RETURN;
  END IF;
	-- fix this

  -- time window (required → both present)
  IF p_dttm_start_utc >= p_dttm_end_utc THEN
    RAISE NOTICE 'i_updated_meet: start >= end (start=%, end=%)', 
				 p_dttm_start_utc, p_dttm_end_utc;
    RETURN;
  END IF;



	INSERT INTO rangley.tb_meets
    (
    	 meet_id
    	,change_stamp
		,name
		,description     	
  		,change_reason    	
  		,meet_category_id 	
  		,max_capacity
		,dttm_start_utc
		,dttm_end_utc     
	)
  	VALUES
	(
		 p_meet_id
     	,p_change_stamp
     	,p_name
     	,p_description
     	,p_change_reason
     	,p_meet_category_id
     	,p_max_capacity
     	,p_dttm_start_utc
     	,p_dttm_end_utc
	);

	GET DIAGNOSTICS num_inserted = ROW_COUNT;

  	IF num_inserted <> 1 THEN
		RAISE NOTICE 'i_updated_meet: insert affected % rows (expected 1) for meet_id=%',
      				 num_inserted, p_meet_id;
  		RETURN;  		
	END IF;

EXCEPTION
  WHEN unique_violation THEN
    num_inserted := 0;
    RAISE NOTICE 'i_updated_meet: duplicate key (meet_id=%, change_stamp=%)'
                  ,p_meet_id, p_change_stamp;

  WHEN check_violation THEN
    num_inserted := 0;
    RAISE NOTICE 'i_updated_meet: check constraint violated (meet_id=%, change_stamp=%)',
				 p_meet_id, p_change_stamp;

  WHEN OTHERS THEN
    num_inserted := 0;
    GET STACKED DIAGNOSTICS
      _state  = RETURNED_SQLSTATE,
      _msg    = MESSAGE_TEXT,
      _detail = PG_EXCEPTION_DETAIL,
      _hint   = PG_EXCEPTION_HINT;
    RAISE NOTICE E'i_updated_meet: unexpected error sqlstate=% msg=% detail=% hint=%
				(meet_id=%, change_stamp=%)'
				,_state
				,_msg
				,COALESCE(_detail,'(none)')
				,COALESCE(_hint,'(none)')
				,p_meet_id
				,p_change_stamp;
END;
$procedure$
;

-- DROP PROCEDURE rangley.rangley_i_user(in text, in text, in text, in text, in text, out int4, out int8);

CREATE OR REPLACE PROCEDURE rangley.rangley_i_user(IN p_username text, IN p_first_name text, IN p_last_name text, IN p_cellphone text, IN p_email text, OUT num_inserted integer, OUT new_user_id bigint)
 LANGUAGE plpgsql
AS $procedure$
DECLARE
	error_code int := -1;
BEGIN
    INSERT INTO rangley.tb_users 
	(
		 username
		,first_name
		,last_name
		,cellphone
		,email
	)
    VALUES
	(
		 p_username
		,p_first_name
		,p_last_name
		,p_cellphone
		,p_email
	)
    RETURNING user_id INTO new_user_id;

    GET DIAGNOSTICS num_inserted = ROW_COUNT;

	IF num_inserted = 0 THEN
		RETURN;
	END IF;
	

END;
$procedure$
;


-- DROP PROCEDURE rangley.rangley_m_user(int8, text, text, text, text, text);

CREATE OR REPLACE PROCEDURE rangley.rangley_m_user(IN p_user_id bigint, IN p_username text DEFAULT NULL::text, IN p_first_name text DEFAULT NULL::text, IN p_last_name text DEFAULT NULL::text, IN p_cellphone text DEFAULT NULL::text, IN p_email text DEFAULT NULL::text)
 LANGUAGE plpgsql
AS $procedure$

DECLARE
  error_code  int := -1;
  num_updated int := 0;

BEGIN



  	IF p_user_id IS NULL THEN
    	RETURN;
  	END IF;

  	UPDATE rangley.tb_users u
  	SET
  -- coalesce will hold onto the old value if nothing is provided
     	 username          = COALESCE(p_username,   username)
    	,first_name        = COALESCE(p_first_name, first_name)
    	,last_name         = COALESCE(p_last_name,  last_name)
    	,cellphone         = COALESCE(p_cellphone,  cellphone)
    	,email             = COALESCE(p_email,      email)
    	,dttm_modified_utc = NOW() AT TIME ZONE 'UTC'
	WHERE u.user_id = p_user_id;

	GET DIAGNOSTICS num_updated = ROW_COUNT;  -- <- rows affected

	IF num_updated = 0 THEN
    	RETURN;
  	END IF;

EXCEPTION
  WHEN unique_violation THEN error_code := -2; GET DIAGNOSTICS num_updated = ROW_COUNT;
  WHEN check_violation  THEN error_code := -3; num_updated := 0;
  WHEN others           THEN error_code := -99; num_updated := 0;
END;
$procedure$
;





