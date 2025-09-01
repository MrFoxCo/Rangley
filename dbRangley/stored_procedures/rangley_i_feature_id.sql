CREATE OR REPLACE PROCEDURE rangley.rangley_i_feature_id
(
     OUT num_inserted  int4
    ,IN  p_feature_id  int4
    ,IN  p_name        text
)
LANGUAGE plpgsql
AS $procedure$
/*
##########################################################################################

##########################################################################################
-- Purpose of Stored Procedure
 Insert feature id
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
DECLARE
    _state  text;
    _msg    text;
    _detail text;
    _hint   text;
    _ctx    text;
BEGIN
    -- OUT default
    num_inserted := 0;

    -- Guards
    IF p_feature_id IS NULL THEN
        RAISE LOG '[ERRO] Insert aborted: Feature ID Param is NULL';
        RAISE EXCEPTION USING
            ERRCODE = '22023',
            MESSAGE = '[ERRO] Invalid feature_id',
            DETAIL  = 'p_feature_id=NULL; table=td_features; action=INSERT',
            HINT    = 'Provide a valid integer feature_id.';
    END IF;

    IF p_name IS NULL OR btrim(p_name) = '' THEN
        RAISE LOG '[ERRO] Insert aborted: Name Param is NULL/empty';
        RAISE EXCEPTION USING
            ERRCODE = '22023',
            MESSAGE = '[ERRO] Invalid p_name',
            DETAIL  = format('p_feature_id=%s; p_name=%s; table=td_features; action=INSERT',
                             p_feature_id, coalesce(p_name,'(null)')),
            HINT    = 'Provide a non-empty text name.';
    END IF;

    -- Insert (idempotent on feature_id)
    INSERT INTO rangley.td_features
	(
		feature_id, name
	)
    VALUES
	(
		p_feature_id, btrim(p_name)
	)
    ON CONFLICT (feature_id) DO NOTHING;

    GET DIAGNOSTICS num_inserted = ROW_COUNT;

    IF num_inserted = 0 THEN
        RAISE LOG '[WARN] Insert skipped: Feature ID:[%] already exists; no rows affected', p_feature_id;
    END IF;

EXCEPTION
    WHEN unique_violation THEN
        -- (e.g., unique constraint on name if you add one)
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
            MESSAGE = '[ERRO] Duplicate detected inserting td_features',
            DETAIL  = format('p_feature_id=%s; p_name=%s; pg_detail=%s',
                             p_feature_id, btrim(p_name), COALESCE(_detail,'(none)')),
            HINT    = COALESCE(_hint, 'Check unique constraints (feature_id, name).');

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
            MESSAGE = '[ERRO] Row failed a CHECK constraint inserting td_features',
            DETAIL  = format('p_feature_id=%s; p_name=%s; pg_detail=%s',
                             p_feature_id, btrim(p_name), COALESCE(_detail,'(none)')),
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
            MESSAGE = '[ERRO] Unexpected failure in rangley_i_feature_id',
            DETAIL  = format('p_feature_id=%s; p_name=%s; pg_detail=%s',
                             p_feature_id, btrim(p_name), COALESCE(_detail,'(none)')),
            HINT    = COALESCE(_hint, 'Check server logs for full context.');
END;
$procedure$;
