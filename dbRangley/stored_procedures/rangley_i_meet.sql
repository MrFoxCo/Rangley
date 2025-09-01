-- DROP PROCEDURE rangley.rangley_i_meet(out int4, in int8, in varchar, in timestamptz, in timestamptz, in varchar, in varchar, in int2, in int4);

CREATE OR REPLACE PROCEDURE rangley.rangley_i_meet
(
	 OUT num_inserted 			int4
	
	,in p_meet_id				int8
	,IN p_meet_coordinate_id 	int8
	,IN p_name 					varchar(50)
	,IN p_dttm_start_utc 		timestamp with time zone
	,IN p_dttm_end_utc 			timestamp with time zone

	,IN p_description 			character 	varying DEFAULT ''::character varying(50)
	,IN p_change_reason 		character 	varying DEFAULT ''::character varying(50)
	,IN p_meet_category_id 		int2 		DEFAULT (1)::int2
	,IN p_max_capacity 			int4 		DEFAULT 2::int4

)
LANGUAGE plpgsql
AS $procedure$
/*
##########################################################################################

##########################################################################################
-- Purpose of Stored Procedure
 Insert meet object
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
result integer;
begin
	CALL rangley.rangley_i_meet
	(
		 result
		,2
		,3
		,'Cubs Rooftop Meetup'
		,'2025-09-29T18:00:00Z' , '2025-09-29T21:00:00Z"'
	);
end $$;

select * from rangley.vw_meets;

*/

-- TODO FIX THE ERROR MESSAGES MAKE THEM MORE HUMAN READABLE
DECLARE
    _state  text; _msg text; _detail text; _hint text; _ctx text;
    is_valid_meet_id         int := -1; -- 1 = ok
    is_valid_meet_coordinate int := -1; -- 1 = ok
BEGIN
    num_inserted := 0;

    -- ===== Required params
    IF p_meet_id IS NULL
       OR p_name IS NULL OR btrim(p_name) = ''
       OR p_dttm_start_utc IS NULL
       OR p_dttm_end_utc   IS NULL THEN
        RAISE LOG '[ERRO] Insert aborted: missing required parameters';
        RAISE EXCEPTION USING
            ERRCODE = '22023',
            MESSAGE = '[ERRO] Missing required parameters for rangley_i_meet',
            DETAIL  = format('meet_id=%s name=%s start=%s end=%s',
				p_meet_id, p_name, p_dttm_start_utc, p_dttm_end_utc),
            HINT    = 'Provide non-null meet_id/name/dttm_start_utc/dttm_end_utc.';
    END IF;

    -- ===== Validate meet_id (must already exist/is valid per your model)
    is_valid_meet_id := rangley.rangley_fn_validate_meet_id(p_meet_id);
    IF is_valid_meet_id <> 1 THEN
        RAISE LOG '[ERRO] Insert aborted: invalid meet_id %', p_meet_id;
        RAISE EXCEPTION USING
            ERRCODE = '22023',
            MESSAGE = '[ERRO] meet_id failed validation',
            DETAIL  = format('meet_id=%s; validator=rangley_fn_validate_meet_id -> %s',
				p_meet_id, is_valid_meet_id),
            HINT    = 'Create the meet_id first (rangley_i_meet_id) or verify the id.';
    END IF;

    -- ===== Validate meet_coordinate_id
    is_valid_meet_coordinate := rangley.rangley_fn_validate_meet_coordinate_id(p_meet_coordinate_id);
    IF is_valid_meet_coordinate <> 1 THEN
        RAISE LOG '[ERRO] Insert aborted: invalid meet_coordinate_id %', p_meet_coordinate_id;
        RAISE EXCEPTION USING
            ERRCODE = '22023',
            MESSAGE = '[ERRO] meet_coordinate_id failed validation',
            DETAIL  = format('meet_coordinate_id=%s; validator=rangley_fn_validate_meet_coordinate_id -> %s',
                             p_meet_coordinate_id, is_valid_meet_coordinate),
            HINT    = 'Insert the coordinate first or pass a valid id.';
    END IF;

    -- ===== Time window
    IF p_dttm_start_utc >= p_dttm_end_utc THEN
        RAISE LOG '[ERRO] Invalid time window: start >= end (start=% end=%)',
			p_dttm_start_utc, p_dttm_end_utc;
        RAISE EXCEPTION USING
            ERRCODE = '22023',
            MESSAGE = '[ERRO] dttm_start_utc must be before dttm_end_utc',
            DETAIL  = format('start=%s end=%s', p_dttm_start_utc, p_dttm_end_utc),
            HINT    = 'Swap or adjust the timestamps.';
    END IF;


  	INSERT INTO rangley.tb_meets
	(
		 meet_id
		,meet_coordinate_id
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
		,p_meet_coordinate_id
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
        RAISE LOG '[ERRO] Insert affected % rows (expected 1) for meet_id %', 
			num_inserted, p_meet_id;
        RAISE EXCEPTION USING
            ERRCODE = '23514',
            MESSAGE = '[ERRO] Unexpected insert count for rangley_i_meet',
            DETAIL  = format('meet_id=%s rows=%s', p_meet_id, num_inserted),
            HINT    = 'Check triggers and constraints.';
    END IF;

    RAISE LOG '[INFO] Inserted meet (meet_id=% meet_coordinate_id=%)',
		p_meet_id, p_meet_coordinate_id;

EXCEPTION
    WHEN unique_violation THEN
        GET STACKED DIAGNOSTICS
            _state=RETURNED_SQLSTATE, _msg=MESSAGE_TEXT,
            _detail=PG_EXCEPTION_DETAIL, _hint=PG_EXCEPTION_HINT, _ctx=PG_EXCEPTION_CONTEXT;

        RAISE LOG '[ERRO] unique_violation (%): % | detail: % | hint: % | ctx: %',
            _state, _msg, COALESCE(_detail,'(none)'), COALESCE(_hint,'(none)'), COALESCE(_ctx,'(none)');

        RAISE EXCEPTION USING
            ERRCODE = _state,
            MESSAGE = '[ERRO] Duplicate detected inserting tb_meets',
            DETAIL  = COALESCE(_detail,'(none)'),
            HINT    = COALESCE(_hint, 'Verify unique keys (e.g., PRIMARY KEY or other uniques).');

    WHEN check_violation THEN
        GET STACKED DIAGNOSTICS
            _state=RETURNED_SQLSTATE, _msg=MESSAGE_TEXT,
            _detail=PG_EXCEPTION_DETAIL, _hint=PG_EXCEPTION_HINT, _ctx=PG_EXCEPTION_CONTEXT;

        RAISE LOG '[ERRO] check_violation (%): % | detail: % | hint: % | ctx: %',
            _state, _msg, COALESCE(_detail,'(none)'), COALESCE(_hint,'(none)'), COALESCE(_ctx,'(none)');

        RAISE EXCEPTION USING
            ERRCODE = _state,
            MESSAGE = '[ERRO] Row failed a CHECK constraint inserting tb_meets',
            DETAIL  = COALESCE(_detail,'(none)'),
            HINT    = COALESCE(_hint, 'Review table constraints and input values.');

    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS
            _state=RETURNED_SQLSTATE, _msg=MESSAGE_TEXT,
            _detail=PG_EXCEPTION_DETAIL, _hint=PG_EXCEPTION_HINT, _ctx=PG_EXCEPTION_CONTEXT;

        RAISE LOG '[ERRO] unhandled_exception (%): % | detail: % | hint: % | ctx: %',
            _state, _msg, COALESCE(_detail,'(none)'), COALESCE(_hint,'(none)'), COALESCE(_ctx,'(none)');

        RAISE EXCEPTION USING
            ERRCODE = _state,
            MESSAGE = '[ERRO] Unexpected failure in rangley_i_meet',
            DETAIL  = COALESCE(_detail,'(none)'),
            HINT    = COALESCE(_hint, 'Check server logs for full context and stack trace.');
END;
$procedure$;