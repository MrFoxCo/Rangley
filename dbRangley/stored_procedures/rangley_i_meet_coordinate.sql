-- DROP PROCEDURE rangley.rangley_i_meet_coordinate(in float8, in float8, in float8, in float8, in float8, out int8);

CREATE OR REPLACE PROCEDURE rangley.rangley_i_meet_coordinate
(
	 OUT new_meet_coordinate_id bigint
	
	,IN p_latitude 				float8
	,IN p_longitude 			double precision
	,IN p_region_latitude 		double precision
	,IN p_region_longitude 		double precision
	,IN p_region_radius 		double precision

)
 LANGUAGE plpgsql
AS $procedure$
/*
##########################################################################################

##########################################################################################
-- Purpose of Stored Procedure
 Insert meet coordinates
-- DECLARED OBJECTS 


RETURNED_SQLSTATE → _state
The standardized 5-character SQLSTATE error code.
Example:
23505 = unique_violation
22023 = invalid_parameter_value
MESSAGE_TEXT → _msg
The human-readable error message from Postgres itself.
Example:
"duplicate key value violates unique constraint \"ux_tb_meets_meet_id\""
PG_EXCEPTION_DETAIL → _detail
Additional context the database engine provides about the error.
Example:
"Key (meet_id)=(42) already exists."
PG_EXCEPTION_HINT → _hint
Optional suggestion text from Postgres.
Example:
"Perhaps you meant to use ON CONFLICT DO NOTHING."
PG_EXCEPTION_CONTEXT → _ctx
The execution context where the error occurred — e.g., which function/procedure line.
Example:
"SQL statement \"INSERT INTO ...\""
##########################################################################################

##########################################################################################
*/
/*

do $$
declare
result bigint;
begin
	CALL rangley.rangley_i_meet_coordinate(result, 1.0,2.0,3.0,4.0,5.0);
end $$;

select * from rangley.vw_meet_coordinates;

*/
-- TODO FIX THE ERROR MESSAGES MAKE THEM MORE HUMAN READABLE
DECLARE
    _state  text; _msg text; _detail text; _hint text; _ctx text;
BEGIN
-- OUT sentinel so it’s never NULL
    new_meet_coordinate_id := -1;

    -- ===== Required params (NULL guards)
    IF 		p_latitude 			IS NULL
       OR 	p_longitude 		IS NULL
       OR 	p_region_latitude 	IS NULL
       OR 	p_region_longitude 	IS NULL
       OR 	p_region_radius 	IS NULL THEN
        RAISE LOG '[ERRO] Insert aborted: one or more required params are NULL';
        RAISE EXCEPTION USING
            ERRCODE = '22023',  -- invalid_parameter_value
            MESSAGE = '[ERRO] Missing required parameters',
            DETAIL  = format('lat=%s lon=%s r_lat=%s r_lon=%s r_rad=%s',
                              p_latitude, p_longitude, p_region_latitude,
							  p_region_longitude, p_region_radius),
            HINT = E'Provide all five parameters (latitude/longitude/region_latitude/'
        			'region_longitude/region_radius).';

    END IF;

    -- ===== Range checks (actionable and human-readable)
    IF p_latitude < -90 OR p_latitude > 90 THEN
        RAISE LOG '[ERRO] Invalid latitude:[%] (expected -90..90)', p_latitude;
        RAISE EXCEPTION USING
            ERRCODE = '22023',
            MESSAGE = '[ERRO] Latitude out of range',
            DETAIL  = format('latitude=%s; expected -90..90', p_latitude),
            HINT    = 'Clamp or validate the source before calling.';
    END IF;

    IF p_longitude < -180 OR p_longitude > 180 THEN
        RAISE LOG '[ERRO] Invalid longitude:[%] (expected -180..180)', p_longitude;
        RAISE EXCEPTION USING
            ERRCODE = '22023',
            MESSAGE = '[ERRO] Longitude out of range',
            DETAIL  = format('longitude=%s; expected -180..180', p_longitude),
            HINT    = 'Clamp or validate the source before calling.';
    END IF;

    IF p_region_latitude < -90 OR p_region_latitude > 90 THEN
        RAISE LOG '[ERRO] Invalid region_latitude:[%] (expected -90..90)', p_region_latitude;
        RAISE EXCEPTION USING
            ERRCODE = '22023',
            MESSAGE = '[ERRO] Region latitude out of range',
            DETAIL  = format('region_latitude=%s; expected -90..90', p_region_latitude),
            HINT    = 'Clamp or validate the source before calling.';
    END IF;

    IF p_region_longitude < -180 OR p_region_longitude > 180 THEN
        RAISE LOG '[ERRO] Invalid region_longitude:[%] (expected -180..180)', p_region_longitude;
        RAISE EXCEPTION USING
            ERRCODE = '22023',
            MESSAGE = '[ERRO] Region longitude out of range',
            DETAIL  = format('region_longitude=%s; expected -180..180', p_region_longitude),
            HINT    = 'Clamp or validate the source before calling.';
    END IF;

    IF p_region_radius <= 0 THEN
        RAISE LOG '[ERRO] Invalid region_radius:[%] (must be > 0)', p_region_radius;
        RAISE EXCEPTION USING
            ERRCODE = '22023',
            MESSAGE = '[ERRO] Region radius must be positive',
            DETAIL  = format('region_radius=%s', p_region_radius),
            HINT    = 'Choose a positive radius in meters/kilometers (your unit convention).';
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
        RAISE LOG '[ERRO] INSERT into tb_meet_coordinates returned NULL meet_coordinate_id';
        RAISE EXCEPTION USING
            ERRCODE = '23514', -- invariant breach (closest)
            MESSAGE = '[ERRO] Failed to obtain new meet_coordinate_id after insert',
            DETAIL  = format('lat=%s lon=%s r_lat=%s r_lon=%s r_rad=%s',
                             p_latitude, p_longitude, p_region_latitude
							,p_region_longitude, p_region_radius),
            HINT    = 'Verify triggers/defaults and the RETURNING clause.';
    END IF;

    RAISE LOG '[INFO] Created meet_coordinate_id:[%] (lat=%, lon=%, r_lat=%, r_lon=%, r_rad=%)',
         new_meet_coordinate_id, p_latitude, p_longitude
		,p_region_latitude, p_region_longitude, p_region_radius;

EXCEPTION
    WHEN unique_violation THEN
        GET STACKED DIAGNOSTICS
            _state=RETURNED_SQLSTATE, _msg=MESSAGE_TEXT,
            _detail=PG_EXCEPTION_DETAIL, _hint=PG_EXCEPTION_HINT, _ctx=PG_EXCEPTION_CONTEXT;

        RAISE LOG '[ERRO] unique_violation (%): % | detail: % | hint: % | ctx: %',
            _state, _msg, COALESCE(_detail,'(none)'), COALESCE(_hint,'(none)'), COALESCE(_ctx,'(none)');

        RAISE EXCEPTION USING
            ERRCODE = _state,
            MESSAGE = '[ERRO] Duplicate detected inserting tb_meet_coordinates',
            DETAIL  = format('lat=%s lon=%s r_lat=%s r_lon=%s r_rad=%s | pg_detail=%s',
                             p_latitude, p_longitude, p_region_latitude
							,p_region_longitude, p_region_radius,
                             COALESCE(_detail,'(none)')),
            HINT    = COALESCE(_hint, 'Check unique constraints or de-duplication rules.');

    WHEN check_violation THEN
        GET STACKED DIAGNOSTICS
            _state=RETURNED_SQLSTATE, _msg=MESSAGE_TEXT,
            _detail=PG_EXCEPTION_DETAIL, _hint=PG_EXCEPTION_HINT, _ctx=PG_EXCEPTION_CONTEXT;

        RAISE LOG '[ERRO] check_violation (%): % | detail: % | hint: % | ctx: %',
            _state, _msg, COALESCE(_detail,'(none)'), COALESCE(_hint,'(none)'), COALESCE(_ctx,'(none)');

        RAISE EXCEPTION USING
            ERRCODE = _state,
            MESSAGE = '[ERRO] Row failed a CHECK constraint inserting tb_meet_coordinates',
            DETAIL  = format('lat=%s lon=%s r_lat=%s r_lon=%s r_rad=%s | pg_detail=%s',
                             p_latitude, p_longitude, p_region_latitude
							,p_region_longitude, p_region_radius,
                             COALESCE(_detail,'(none)')),
            HINT    = COALESCE(_hint, 'Review table constraints and input values.');

    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS
            _state=RETURNED_SQLSTATE, _msg=MESSAGE_TEXT,
            _detail=PG_EXCEPTION_DETAIL, _hint=PG_EXCEPTION_HINT, _ctx=PG_EXCEPTION_CONTEXT;

        RAISE LOG '[ERRO] unhandled_exception (%): % | detail: % | hint: % | ctx: %',
            _state, _msg, COALESCE(_detail,'(none)'), COALESCE(_hint,'(none)'), COALESCE(_ctx,'(none)');

        RAISE EXCEPTION USING
            ERRCODE = _state,
            MESSAGE = '[ERRO] Unexpected failure in rangley_i_meet_coordinate',
            DETAIL  = format('lat=%s lon=%s r_lat=%s r_lon=%s r_rad=%s | pg_detail=%s',
                             p_latitude, p_longitude, p_region_latitude
	    					,p_region_longitude, p_region_radius,
                             COALESCE(_detail,'(none)')),
            HINT    = COALESCE(_hint, 'Check server logs for full context and stack trace.');
END;
$procedure$;