-- DROP PROCEDURE rangley.rangley_i_meet_id(in int8, in int8, out int8);

CREATE OR REPLACE PROCEDURE rangley.rangley_i_meet_id
(
	 OUT new_meet_id bigint
	,IN p_created_by_user_id bigint
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
result bigint;
begin
	CALL rangley.rangley_i_meet_id(result, 2);
end $$;

*/

-- TODO FIX THE ERROR MESSAGES MAKE THEM MORE HUMAN READABLE
DECLARE
    is_valid_user int := -1;  -- 1 = ok
    _state  text; _msg text; _detail text; _hint text; _ctx text;
BEGIN
    -- OUT sentinel so it's never NULL
    new_meet_id := -1;

    -- ===== Guard: required param
    IF p_created_by_user_id IS NULL THEN
        RAISE LOG '[ERRO] Insert aborted: p_created_by_user_id is NULL';
        RAISE EXCEPTION USING
            ERRCODE = '22023', -- invalid_parameter_value
            MESSAGE = '[ERRO] Invalid input for rangley_i_meet_id',
            DETAIL  = 'p_created_by_user_id=NULL; table=tb_meet_ids; action=INSERT',
            HINT    = 'Provide a valid tb_users.user_id (BIGINT).';
    END IF;

    -- ===== Validate user
    is_valid_user := rangley.rangley_fn_validate_user_id(p_created_by_user_id);
    IF is_valid_user <> 1 THEN
        RAISE LOG '[ERRO] Insert aborted: user_id:[%] is invalid or does not exist', p_created_by_user_id;
        RAISE EXCEPTION USING
            ERRCODE = '22023',
            MESSAGE = '[ERRO] User ID failed validation',
            DETAIL  = format('p_created_by_user_id=%s; validator=rangley_fn_validate_user_id -> 0',
				p_created_by_user_id),
            HINT    = 'Ensure the user exists in tb_users and is allowed to create meets.';
    END IF;

 	 -- insert and capture id
	INSERT INTO rangley.tb_meet_ids
	(
		created_by_user_id
	)
  	VALUES
	(
		p_created_by_user_id
	)
	RETURNING meet_id INTO new_meet_id;

    IF new_meet_id IS NULL THEN
        RAISE LOG '[ERRO] INSERT into tb_meet_ids returned NULL meet_id for user_id:[%]',
			p_created_by_user_id;
        RAISE EXCEPTION USING
            ERRCODE = '23514', -- treat as invariant breach
            MESSAGE = '[ERRO] Failed to obtain new meet_id after insert',
            DETAIL  = format('p_created_by_user_id=%s; table=tb_meet_ids; action=INSERT; meet_id=NULL',
				p_created_by_user_id),
            HINT    = 'Verify triggers/defaults and the RETURNING clause.';
    END IF;

    RAISE LOG '[INFO] Created meet_id % for user_id %', new_meet_id, p_created_by_user_id;

EXCEPTION
    WHEN unique_violation THEN
        GET STACKED DIAGNOSTICS
            _state=RETURNED_SQLSTATE, _msg=MESSAGE_TEXT,
            _detail=PG_EXCEPTION_DETAIL, _hint=PG_EXCEPTION_HINT, _ctx=PG_EXCEPTION_CONTEXT;

        RAISE LOG '[ERRO] unique_violation (%): % | detail: % | hint: % | ctx: %',
            _state, _msg, COALESCE(_detail,'(none)'), COALESCE(_hint,'(none)'), COALESCE(_ctx,'(none)');

        RAISE EXCEPTION USING
            ERRCODE = _state,
            MESSAGE = '[ERRO] Duplicate detected while creating meet_id',
            DETAIL  = format('p_created_by_user_id=%s; table=tb_meet_ids; action=INSERT; pg_detail=%s',
                             p_created_by_user_id, COALESCE(_detail,'(none)')),
            HINT    = COALESCE(_hint, 'Check unique constraints or prior rows for this user.');

    WHEN check_violation THEN
        GET STACKED DIAGNOSTICS
            _state=RETURNED_SQLSTATE, _msg=MESSAGE_TEXT,
            _detail=PG_EXCEPTION_DETAIL, _hint=PG_EXCEPTION_HINT, _ctx=PG_EXCEPTION_CONTEXT;

        RAISE LOG '[ERRO] check_violation (%): % | detail: % | hint: % | ctx: %',
            _state, _msg, COALESCE(_detail,'(none)'), COALESCE(_hint,'(none)'), COALESCE(_ctx,'(none)');

        RAISE EXCEPTION USING
            ERRCODE = _state,
            MESSAGE = '[ERRO] Row failed a CHECK constraint while creating meet_id',
            DETAIL  = format('p_created_by_user_id=%s; table=tb_meet_ids; action=INSERT; pg_detail=%s',
                             p_created_by_user_id, COALESCE(_detail,'(none)')),
            HINT    = COALESCE(_hint, 'Review table constraints and input values.');

    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS
            _state=RETURNED_SQLSTATE, _msg=MESSAGE_TEXT,
            _detail=PG_EXCEPTION_DETAIL, _hint=PG_EXCEPTION_HINT, _ctx=PG_EXCEPTION_CONTEXT;

        RAISE LOG '[ERRO] unhandled_exception (%): % | detail: % | hint: % | ctx: %',
            _state, _msg, COALESCE(_detail,'(none)'), COALESCE(_hint,'(none)'), COALESCE(_ctx,'(none)');

        RAISE EXCEPTION USING
            ERRCODE = _state,
            MESSAGE = '[ERRO] Unexpected failure in rangley_i_meet_id',
            DETAIL  = format('p_created_by_user_id=%s; table=tb_meet_ids; action=INSERT; pg_detail=%s',
                             p_created_by_user_id, COALESCE(_detail,'(none)')),
            HINT    = COALESCE(_hint, 'Check server logs for full context and stack trace.');
END;
$procedure$;
