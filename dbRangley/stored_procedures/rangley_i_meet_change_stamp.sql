-- DROP PROCEDURE rangley.rangley_i_meet_change_stamp(in int8, in int4, out int8);

CREATE OR REPLACE PROCEDURE rangley.rangley_i_change_stamp
(
	-- OUTPUT PARAMS
	 OUT 	new_change_stamp	int8

	 -- INPUT PARAMS
	,IN 	p_meet_id 			int8
	
)
LANGUAGE plpgsql
AS $procedure$
/*
##########################################################################################
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


##########################################################################################

##########################################################################################
-- Purpose of Stored Procedure
	INSERT CHANGE STAMP -- used for versioning meets
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
	
	CALL rangley.rangley_i_change_stamp(result, 1);
end $$;

select * from rangley.vw_change_stamps;
*/
DECLARE
	is_valid_meet_id int;
	error_code int := -1;
    _state  text; _msg    text;_detail text;_hint   text;_ctx    text;
BEGIN

	-- OUT default so it’s never NULL
    new_change_stamp := -1;

    -- Guard: meet_id required
    IF p_meet_id IS NULL THEN
        RAISE LOG '[ERRO] Insert aborted: p_meet_id is NULL';
        RAISE EXCEPTION USING
            ERRCODE = '22023',  -- invalid_parameter_value
            MESSAGE = '[ERRO] Invalid meet_id',
            DETAIL  = 'p_meet_id=NULL; table=tb_change_stamps; action=INSERT',
            HINT    = 'Provide a valid meet_id (BIGINT).';
    END IF;

	is_valid_meet_id := rangley.rangley_fn_validate_meet_id(p_meet_id);
    -- Validate meet exists
    IF is_valid_meet_id <> 1 THEN
        RAISE LOG '[ERRO] Insert aborted: Meet ID:[%] does not exist or failed validation',
			p_meet_id;
        RAISE EXCEPTION USING
            ERRCODE = '22023',
            MESSAGE = '[ERRO] Meet ID failed validation',
            DETAIL  = format('p_meet_id=%s; validator=rangley_fn_validate_meet_id -> 0', p_meet_id),
            HINT    = 'Ensure the meet exists in tb_meets before creating a change stamp.';
    END IF;
	

  	-- insert & return generated change_stamp
	INSERT INTO rangley.tb_change_stamps(meet_id) VALUES(p_meet_id)
  	RETURNING change_stamp INTO new_change_stamp;
	
	IF new_change_stamp IS NULL THEN
        -- Should not happen; treat as fatal invariant breach
        RAISE LOG '[ERRO] INSERT into tb_change_stamps returned NULL change_stamp for Meet ID:[%]',
			p_meet_id;
        RAISE EXCEPTION USING
            ERRCODE = '23514', -- closest: check_violation / invariant violation
            MESSAGE = '[ERRO] Failed to obtain new change_stamp after insert',
            DETAIL  = format('p_meet_id=%s; table=tb_change_stamps; action=INSERT; change_stamp=NULL',
				p_meet_id),
            HINT    = 'Verify triggers/defaults and the RETURNING clause.';
    END IF;
	
EXCEPTION
    WHEN unique_violation THEN
        GET STACKED DIAGNOSTICS
            _state  = RETURNED_SQLSTATE,
            _msg    = MESSAGE_TEXT,
            _detail = PG_EXCEPTION_DETAIL,
            _hint   = PG_EXCEPTION_HINT,
            _ctx    = PG_EXCEPTION_CONTEXT;

        RAISE LOG '[ERRO] unique_violation (%): % | detail: % | hint: % | ctx: %',
            _state, _msg, COALESCE(_detail,'(none)'), COALESCE(_hint,'(none)'), COALESCE(_ctx,'(none)');

        RAISE EXCEPTION USING
            ERRCODE = _state,
            MESSAGE = '[ERRO] Duplicate detected inserting tb_change_stamps',
            DETAIL  = format('p_meet_id=%s; pg_detail=%s', p_meet_id, COALESCE(_detail,'(none)')),
            HINT    = COALESCE(_hint, 'Check unique constraints on tb_change_stamps.');

    WHEN check_violation THEN
        GET STACKED DIAGNOSTICS
            _state  = RETURNED_SQLSTATE,
            _msg    = MESSAGE_TEXT,
            _detail = PG_EXCEPTION_DETAIL,
            _hint   = PG_EXCEPTION_HINT,
            _ctx    = PG_EXCEPTION_CONTEXT;

        RAISE LOG '[ERRO] check_violation (%): % | detail: % | hint: % | ctx: %',
            _state, _msg, COALESCE(_detail,'(none)'), COALESCE(_hint,'(none)'), COALESCE(_ctx,'(none)');

        RAISE EXCEPTION USING
            ERRCODE = _state,
            MESSAGE = '[ERRO] Row failed a CHECK constraint inserting tb_change_stamps',
            DETAIL  = format('p_meet_id=%s; pg_detail=%s', p_meet_id, COALESCE(_detail,'(none)')),
            HINT    = COALESCE(_hint, 'Review table constraints and input values.');

    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS
            _state  = RETURNED_SQLSTATE,
            _msg    = MESSAGE_TEXT,
            _detail = PG_EXCEPTION_DETAIL,
            _hint   = PG_EXCEPTION_HINT,
            _ctx    = PG_EXCEPTION_CONTEXT;

        RAISE LOG '[ERRO] unhandled_exception (%): % | detail: % | hint: % | ctx: %',
            _state, _msg, COALESCE(_detail,'(none)'), COALESCE(_hint,'(none)'), COALESCE(_ctx,'(none)');

        RAISE EXCEPTION USING
            ERRCODE = _state,
            MESSAGE = '[ERRO] Unexpected failure in rangley_i_change_stamp',
            DETAIL  = format('p_meet_id=%s; pg_detail=%s', p_meet_id, COALESCE(_detail,'(none)')),
            HINT    = COALESCE(_hint, 'Check server logs for full context and stack trace.');

END;
$procedure$;
