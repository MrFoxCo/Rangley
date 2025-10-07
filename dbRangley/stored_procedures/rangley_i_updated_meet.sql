-- DROP PROCEDURE rangley.rangley_i_updated_meet(out int4, in int8, in int8, in varchar, in timestamptz, in timestamptz, in varchar, in varchar, in int2, in int4);

CREATE OR REPLACE PROCEDURE rangley.rangley_i_updated_meet
(
	 OUT num_inserted 			int4
	 
	,IN p_meet_id 				int8
	,IN p_change_stamp 			int8
	,in p_meet_coordinate_id    int8
	,IN p_name 					character varying
	,IN p_dttm_start_utc 		timestamp with time zone
	,IN p_dttm_end_utc 			timestamp with time zone
	
	,in p_meet_status_id        int2 	  default 0::int2
	,IN p_description 			character varying DEFAULT ''::character varying(200)
	,IN p_change_reason 		character varying DEFAULT ''::character varying(50)
	,IN p_meet_category_id 		smallint  DEFAULT 1::smallint
	,IN p_max_capacity 			integer   DEFAULT -1::smallint
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
result integer;
begin

CALL rangley.rangley_i_updated_meet(result,1,1,1,'updated-meet','2025-10-29T21:00:00Z', '2025-11-29T21:00:00Z');

end $$;
select * from rangley.vw_meets;


*/
DECLARE 
    is_valid_meet_status_id int := -1;

    _state  text; _msg text; _detail text; _hint text; _ctx text;

BEGIN

	num_inserted := 0;

    -- ===== Required params
    IF p_meet_id IS NULL OR p_change_stamp IS NULL
       OR p_dttm_start_utc IS NULL OR p_dttm_end_utc IS NULL
       OR p_name IS NULL OR btrim(p_name) = '' THEN
        RAISE LOG '[ERRO] Insert aborted: missing required parameters';
        RAISE EXCEPTION USING
            ERRCODE = '22023',
            MESSAGE = '[ERRO] Missing required parameters for rangley_i_updated_meet',
            DETAIL  = format('meet_id=%s change_stamp=%s name=%s start=%s end=%s',
                              p_meet_id, p_change_stamp, p_name, p_dttm_start_utc, p_dttm_end_utc),
            HINT    = 'Provide non-null meet_id/change_stamp/name/start/end.';
    END IF;

    -- ===== Referential checks
    IF NOT EXISTS (SELECT 1 FROM rangley.tb_meets WHERE meet_id = p_meet_id) THEN
        RAISE LOG '[ERRO] Insert aborted: meet_id:[%] not found', p_meet_id;
        RAISE EXCEPTION USING
            ERRCODE = '22023',
            MESSAGE = '[ERRO] Unknown meet_id',
            DETAIL  = format('meet_id=%s', p_meet_id),
            HINT    = 'Create the meet_id first or verify the id.';
    END IF;

    IF p_meet_coordinate_id IS NOT NULL AND
       NOT EXISTS (SELECT 1 FROM rangley.tb_meet_coordinates WHERE meet_coordinate_id = p_meet_coordinate_id) THEN
        RAISE LOG '[ERRO] Insert aborted: meet_coordinate_id % not found', p_meet_coordinate_id;
        RAISE EXCEPTION USING
            ERRCODE = '22023',
            MESSAGE = '[ERRO] Unknown meet_coordinate_id',
            DETAIL  = format('meet_coordinate_id=%s', p_meet_coordinate_id),
            HINT    = 'Insert the coordinate first or pass a valid id.';
    END IF;

    -- ===== Time window
    IF p_dttm_start_utc >= p_dttm_end_utc THEN
        RAISE LOG '[ERRO] Invalid time window: start >= end (start:[%] end:[%])',
            p_dttm_start_utc, p_dttm_end_utc;
        RAISE EXCEPTION USING
            ERRCODE = '22023',
            MESSAGE = '[ERRO] dttm_start_utc must be before dttm_end_utc',
            DETAIL  = format('start=%s end=%s', p_dttm_start_utc, p_dttm_end_utc),
            HINT    = 'Swap or adjust the timestamps.';
    END IF;

	-- Add this validation block after the time window check
	IF p_max_capacity > 0 AND p_max_capacity < 2 THEN
	    RAISE EXCEPTION USING
	      ERRCODE='22023',
	      MESSAGE='[ERRO] max_capacity must be >= 2 (or -1 for unlimited)',
	      DETAIL=format('max_capacity=%s', p_max_capacity);
	END IF;

    -- ===== Optional status validation (only 2/3/7 allowed when provided)
    IF p_meet_status_id IS NOT NULL AND p_meet_status_id <> 0 THEN
        is_valid_meet_status_id := rangley.rangley_fn_valid_change_stamp_meet_status_id(p_meet_status_id);
        IF is_valid_meet_status_id <> 1 THEN
            RAISE LOG '[ERRO] Invalid meet_status_id:[%] (only 2,3,7 allowed)', p_meet_status_id;
            RAISE EXCEPTION USING
                ERRCODE = '22023',
                MESSAGE = '[ERRO] Only Cancelled(2), Postponed(3), or Deleted(7) may be inserted',
                DETAIL  = format('meet_status_id=%s', p_meet_status_id),
                HINT    = 'Active/Completed/Draft/Full are inferred.';
        END IF;
    END IF;

	INSERT INTO rangley.tb_meets
    (
    	 meet_id
    	,change_stamp
		,meet_coordinate_id
		,meet_status_id
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
		,p_meet_coordinate_id
		,p_meet_status_id -- only get's inserted on meet updates
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
        RAISE LOG '[ERRO] Insert affected % rows (expected 1) for meet_id %', num_inserted, p_meet_id;
        RAISE EXCEPTION USING
            ERRCODE = '23514',
            MESSAGE = '[ERRO] Unexpected insert count for updated meet',
            DETAIL  = format('meet_id=%s change_stamp=%s rows=%s',
				p_meet_id, p_change_stamp, num_inserted),
            HINT    = 'Check triggers and constraints.';
    END IF;

    RAISE LOG '[INFO] Inserted updated meet version (meet_id=% change_stamp=%)', 
		p_meet_id, p_change_stamp;

EXCEPTION
    WHEN unique_violation THEN
        GET STACKED DIAGNOSTICS
            _state=RETURNED_SQLSTATE, _msg=MESSAGE_TEXT,
            _detail=PG_EXCEPTION_DETAIL, _hint=PG_EXCEPTION_HINT, _ctx=PG_EXCEPTION_CONTEXT;

        RAISE LOG '[ERRO] unique_violation (%): % | detail: % | hint: % | ctx: %',
            _state, _msg, COALESCE(_detail,'(none)'), COALESCE(_hint,'(none)'), COALESCE(_ctx,'(none)');

        RAISE EXCEPTION USING
            ERRCODE = _state,
            MESSAGE = '[ERRO] Duplicate detected inserting updated meet',
            DETAIL  = format('meet_id=%s change_stamp=%s | pg_detail=%s',
                             p_meet_id, p_change_stamp, COALESCE(_detail,'(none)')),
            HINT    = COALESCE(_hint, 'Verify unique keys on tb_meets (meet_id+change_stamp).');

    WHEN check_violation THEN
        GET STACKED DIAGNOSTICS
            _state=RETURNED_SQLSTATE, _msg=MESSAGE_TEXT,
            _detail=PG_EXCEPTION_DETAIL, _hint=PG_EXCEPTION_HINT, _ctx=PG_EXCEPTION_CONTEXT;

        RAISE LOG '[ERRO] check_violation (%): % | detail: % | hint: % | ctx: %',
            _state, _msg, COALESCE(_detail,'(none)'), COALESCE(_hint,'(none)'), COALESCE(_ctx,'(none)');

        RAISE EXCEPTION USING
            ERRCODE = _state,
            MESSAGE = '[ERRO] Row failed a CHECK constraint inserting updated meet',
            DETAIL  = format('meet_id=%s change_stamp=%s | pg_detail=%s',
                             p_meet_id, p_change_stamp, COALESCE(_detail,'(none)')),
            HINT    = COALESCE(_hint, 'Review table constraints and input values.');

    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS
            _state=RETURNED_SQLSTATE, _msg=MESSAGE_TEXT,
            _detail=PG_EXCEPTION_DETAIL, _hint=PG_EXCEPTION_HINT, _ctx=PG_EXCEPTION_CONTEXT;

        RAISE LOG '[ERRO] unhandled_exception (%): % | detail: % | hint: % | ctx: %',
            _state, _msg, COALESCE(_detail,'(none)'), COALESCE(_hint,'(none)'), COALESCE(_ctx,'(none)');

        RAISE EXCEPTION USING
            ERRCODE = _state,
            MESSAGE = '[ERRO] Unexpected failure in rangley_i_updated_meet',
            DETAIL  = format('meet_id=%s change_stamp=%s | pg_detail=%s',
                             p_meet_id, p_change_stamp, COALESCE(_detail,'(none)')),
            HINT    = COALESCE(_hint, 'Check server logs for full context and stack trace.');
END;
$procedure$;