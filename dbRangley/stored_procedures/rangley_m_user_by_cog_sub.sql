CREATE OR REPLACE PROCEDURE rangley.rangley_m_user_by_cog_sub
(
     OUT num_affected   int4

    ,IN  p_cognito_sub  text           DEFAULT NULL
    ,IN  p_username     varchar(50)    DEFAULT NULL
    ,IN  p_display_name varchar(50)    DEFAULT NULL
    ,IN  p_first_name   varchar(50)    DEFAULT NULL
    ,IN  p_last_name    varchar(50)    DEFAULT NULL
    ,IN  p_cellphone    varchar(16)    DEFAULT NULL
    ,IN  p_email        varchar(256)   DEFAULT NULL
    ,IN  p_dob          date           DEFAULT NULL
)
LANGUAGE plpgsql
AS $procedure$
/*

##########################################################################################

##########################################################################################
-- Purpose of Stored Procedure
MODIFY USER
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
"Key (meet_id)=(42) already exists."z
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
	is_valid_user int := -1;
    v_digits text;
    v_e164   text;
    _state text; _msg text; _detail text; _hint text; _ctx text;
BEGIN
    num_affected := 0;

    -- Guard: user_id required and must exist
    IF p_cognito_sub IS NULL THEN
        RAISE LOG '[ERRO] Update aborted: user_id is NULL';
        RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='[ERRO] Invalid user_id',
            DETAIL='p_user_id=NULL; table=tb_users; action=UPDATE',
            HINT='Provide a valid tb_users.user_id.';
    END IF;

	is_valid_user := rangley.rangley_fn_validate_cog_sub(p_cognito_sub);
    IF is_valid_user <> 1 THEN
        RAISE LOG '[ERRO] Update aborted: User does not exist or failed validation';

        RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='[ERRO] User ID failed validation',
            DETAIL=format('validator=rangley_fn_validate_user_id -> 0'),
            HINT='Ensure the user exists in tb_users.';
    END IF;

    -- Normalize inputs if provided
    IF p_username     IS NOT NULL THEN p_username     := lower(NULLIF(btrim(p_username),'')); END IF;
    IF p_display_name IS NOT NULL THEN p_display_name := NULLIF(btrim(p_display_name),''); END IF;
    IF p_first_name   IS NOT NULL THEN p_first_name   := NULLIF(btrim(p_first_name),  ''); END IF;
    IF p_last_name    IS NOT NULL THEN p_last_name    := NULLIF(btrim(p_last_name),   ''); END IF;

    IF p_email IS NOT NULL THEN
        p_email := lower(btrim(p_email));
        IF p_email !~* '^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$' THEN
            RAISE LOG '[ERRO] Bad email format: email=%', p_email;
            RAISE EXCEPTION USING ERRCODE='22023',
                MESSAGE='[ERRO] Email format looks invalid',
                DETAIL=format('email=%s', p_email),
                HINT='Expected like name@example.com';
        END IF;
    END IF;

    -- Phone → E.164 if provided
    IF p_cellphone IS NOT NULL THEN
        v_digits := regexp_replace(btrim(p_cellphone), '\D', '', 'g');
        IF length(v_digits) = 10 THEN
            v_e164 := '+1' || v_digits;
        ELSIF length(v_digits) = 11 AND substr(v_digits,1,1) = '1' THEN
            v_e164 := '+' || v_digits;
        ELSIF length(v_digits) BETWEEN 8 AND 15 AND substr(v_digits,1,1) <> '0' THEN
            v_e164 := '+' || v_digits;
        ELSE
            RAISE LOG '[ERRO] Bad phone format: raw=% digits=%', p_cellphone, v_digits;
            RAISE EXCEPTION USING ERRCODE='22023',
                MESSAGE='[ERRO] Cellphone invalid (expect E.164: + and 8–15 digits)',
                DETAIL=format('raw=%s; digits=%s', p_cellphone, v_digits),
                HINT='Example: +13125550123';
        END IF;
        p_cellphone := v_e164;
    END IF;

    -- DOB checks (only if provided)
    IF p_dob IS NOT NULL THEN
        IF p_dob > CURRENT_DATE THEN
            RAISE LOG '[ERRO] DOB in future: dob=%', p_dob;
            RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='[ERRO] DOB cannot be in the future';
        END IF;
        IF p_dob > CURRENT_DATE - INTERVAL '13 years' THEN
            RAISE LOG '[ERRO] Underage: dob=%', p_dob;
            RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='[ERRO] Must be at least 13 years old';
        END IF;
    END IF;

    -- No-op guard: if nothing provided, skip
    IF p_cognito_sub  IS NULL
       AND p_username  IS NULL
       AND p_display_name IS NULL
       AND p_first_name IS NULL
       AND p_last_name  IS NULL
       AND p_cellphone  IS NULL
       AND p_email      IS NULL
       AND p_dob        IS NULL THEN
        RAISE LOG '[WARN] No changes provided for user_id %; nothing to update', p_user_id;
        RETURN;
    END IF;

    -- Update only what’s provided
    UPDATE rangley.tb_users u
       SET username           = COALESCE(p_username,     username)
          ,display_name       = COALESCE(p_display_name, display_name)
          ,first_name         = COALESCE(p_first_name,   first_name)
          ,last_name          = COALESCE(p_last_name,    last_name)
          ,cellphone          = COALESCE(p_cellphone,    cellphone)
          ,email              = COALESCE(p_email,        email)
          ,dob                = COALESCE(p_dob,          dob)
          ,dttm_modified_utc  = now()
     WHERE u.user_id = p_user_id;

    GET DIAGNOSTICS num_affected = ROW_COUNT;

    IF num_affected = 0 THEN
        RAISE LOG '[INFO] No-op update: user_id % values unchanged', p_user_id;
    ELSE
        RAISE LOG '[INFO] Updated user_id % (rows affected=%)', p_user_id, num_affected;
    END IF;

EXCEPTION
    WHEN unique_violation THEN
        GET STACKED DIAGNOSTICS
            _state=RETURNED_SQLSTATE, _msg=MESSAGE_TEXT,
            _detail=PG_EXCEPTION_DETAIL, _hint=PG_EXCEPTION_HINT, _ctx=PG_EXCEPTION_CONTEXT;

        RAISE LOG '[ERRO] unique_violation (%): % | detail: % | hint: % | ctx: %',
            _state, _msg, COALESCE(_detail,'(none)'), COALESCE(_hint,'(none)'), COALESCE(_ctx,'(none)');

        RAISE EXCEPTION USING
            ERRCODE = _state,
            MESSAGE = '[ERRO] Duplicate detected updating tb_users',
            DETAIL  = format('user_id=%s; pg_detail=%s', p_user_id, COALESCE(_detail,'(none)')),
            HINT    = COALESCE(_hint, 'Check unique constraints (cognito_sub/username/email/cellphone).');

    WHEN check_violation THEN
        GET STACKED DIAGNOSTICS
            _state=RETURNED_SQLSTATE, _msg=MESSAGE_TEXT,
            _detail=PG_EXCEPTION_DETAIL, _hint=PG_EXCEPTION_HINT, _ctx=PG_EXCEPTION_CONTEXT;

        RAISE LOG '[ERRO] check_violation (%): % | detail: % | hint: % | ctx: %',
            _state, _msg, COALESCE(_detail,'(none)'), COALESCE(_hint,'(none)'), COALESCE(_ctx,'(none)');

        RAISE EXCEPTION USING
            ERRCODE = _state,
            MESSAGE = '[ERRO] Row failed a CHECK constraint updating tb_users',
            DETAIL  = format('user_id=%s; pg_detail=%s', p_user_id, COALESCE(_detail,'(none)')),
            HINT    = COALESCE(_hint, 'Review table constraints and input values.');

    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS
            _state=RETURNED_SQLSTATE, _msg=MESSAGE_TEXT,
            _detail=PG_EXCEPTION_DETAIL, _hint=PG_EXCEPTION_HINT, _ctx=PG_EXCEPTION_CONTEXT;

        RAISE LOG '[ERRO] unhandled_exception (%): % | detail: % | hint: % | ctx: %',
            _state, _msg, COALESCE(_detail,'(none)'), COALESCE(_hint,'(none)'), COALESCE(_ctx,'(none)');

        RAISE EXCEPTION USING
            ERRCODE = _state,
            MESSAGE = '[ERRO] Unexpected failure in rangley_m_user',
            DETAIL  = format('user_id=%s; pg_detail=%s', p_user_id, COALESCE(_detail,'(none)')),
            HINT    = COALESCE(_hint, 'Check server logs for full context.');
END;
$procedure$;
