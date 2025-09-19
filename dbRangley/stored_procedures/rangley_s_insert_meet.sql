CREATE OR REPLACE PROCEDURE rangley.rangley_s_insert_meet
(
    -- OUTs
     OUT num_inserted            INT4
	,OUT meet_id_uuid        UUID
    -- INs
    ,IN  p_cognito_sub           text

    -- coordinates
    ,IN  p_latitude              FLOAT8
    ,IN  p_longitude             FLOAT8
    ,IN  p_region_latitude       FLOAT8
    ,IN  p_region_longitude      FLOAT8
    ,IN  p_region_radius         FLOAT8

    -- meet fields
    ,IN  p_name                  varchar(50)
    ,IN  p_dttm_start_utc        timestamptz
    ,IN  p_dttm_end_utc          timestamptz
    ,IN  p_description           varchar(50) DEFAULT ''::varchar
    ,IN  p_meet_category_id      int2        DEFAULT 1::int2
    ,IN  p_max_capacity          int4        DEFAULT 2::int4
)
LANGUAGE plpgsql
/*
	THIS IS INSERTING A NEW MEET THAT IS WHY CHANGESTAMP IS DEFAULTED TO 0
*/
AS $procedure$
DECLARE
    _state  text; _msg text; _detail text; _hint text; _ctx text;
    v_sub                text;
    created_by_user_id   	INT8;
	new_meet_id          	INT8;
	new_meet_coordinate_id 	INT8;          
	v_new_meet_id_uuid        UUID;
BEGIN
    -- OUT sentinel
    num_inserted           := 0;

    -- ===== Basic guards
    v_sub := nullif(btrim(p_cognito_sub), '');
    IF v_sub IS NULL THEN
        RAISE EXCEPTION USING
          ERRCODE='22023', MESSAGE='[ERRO] p_cognito_sub is required (non-empty)';
    END IF;

    IF p_name IS NULL OR btrim(p_name) = '' THEN
        RAISE EXCEPTION USING
          ERRCODE='22023', MESSAGE='[ERRO] name is required';
    END IF;

    IF p_dttm_start_utc IS NULL OR p_dttm_end_utc IS NULL OR p_dttm_start_utc >= p_dttm_end_utc THEN
        RAISE EXCEPTION USING
          ERRCODE='22023',
          MESSAGE='[ERRO] Invalid time window (start must be before end)',
          DETAIL=format('start=%s end=%s', p_dttm_start_utc, p_dttm_end_utc);
    END IF;

    IF p_max_capacity IS NULL OR p_max_capacity < 2 THEN
        RAISE EXCEPTION USING
          ERRCODE='22023',
          MESSAGE='[ERRO] max_capacity must be >= 2',
          DETAIL=format('max_capacity=%s', p_max_capacity);
    END IF;

    -- ===== Resolve user_id from Cognito sub (trimmed)
    SELECT rangley.rangley_fn_v_user_id_by_cognito_sub(v_sub)
      INTO created_by_user_id;

    IF created_by_user_id IS NULL OR created_by_user_id <= 0 THEN
        RAISE EXCEPTION USING
          ERRCODE='22023',
          MESSAGE='[ERRO] Could not resolve user_id from cognito_sub',
          DETAIL=format('cognito_sub=%s', v_sub),
          HINT='Ensure the user exists in tb_users and the sub is correct.';
    END IF;

    -- 1) create meet_id
    CALL rangley.rangley_i_meet_id(new_meet_id, created_by_user_id);

	SELECT uuid INTO meet_id_uuid
	FROM rangley.tb_meet_ids
	WHERE meet_id = new_meet_id;


    -- 2) create meet_coordinate_id (has its own range/NULL checks)
    CALL rangley.rangley_i_meet_coordinate(
        new_meet_coordinate_id,
        p_latitude, p_longitude, p_region_latitude, p_region_longitude, p_region_radius
    );

    -- 3) insert first version (change_stamp = 0)
    INSERT INTO rangley.tb_meets
    (
        meet_id,
        change_stamp,
        meet_coordinate_id,
        name,
        description,
        change_reason,
        meet_category_id,
        max_capacity,
        dttm_start_utc,
        dttm_end_utc
    )
    VALUES
    (
        new_meet_id,
        0,
        new_meet_coordinate_id,
        p_name,
        p_description,
        '',
        p_meet_category_id,
        p_max_capacity,
        p_dttm_start_utc,
        p_dttm_end_utc
    );

    GET DIAGNOSTICS num_inserted = ROW_COUNT;

    IF num_inserted <> 1 THEN
        RAISE EXCEPTION USING
          ERRCODE='23514',
          MESSAGE='[ERRO] Unexpected insert count for tb_meets',
          DETAIL=format('rows=%s meet_id=%s', num_inserted, new_meet_id);
    END IF;

    -- Seed owner participant (status = 7 Owner)
    INSERT INTO rangley.tb_meet_participants(
        meet_id, user_id, participant_status_id, dttm_invited_utc, dttm_accepted_utc
    )
    VALUES (new_meet_id, created_by_user_id, 7, now(), now())
    ON CONFLICT (meet_id, user_id) DO NOTHING;


    RAISE LOG '[INFO] Created meet_id=% with meet_coordinate_id=% (change_stamp=0) by user_id=%',
        new_meet_id, new_meet_coordinate_id, created_by_user_id;

EXCEPTION
    WHEN unique_violation THEN
        GET STACKED DIAGNOSTICS
          _state=RETURNED_SQLSTATE, _msg=MESSAGE_TEXT, _detail=PG_EXCEPTION_DETAIL,
          _hint=PG_EXCEPTION_HINT, _ctx=PG_EXCEPTION_CONTEXT;
        RAISE LOG '[ERRO] unique_violation (%): % | detail: % | hint: % | ctx: %',
          _state, _msg, COALESCE(_detail,'(none)'), COALESCE(_hint,'(none)'), COALESCE(_ctx,'(none)');
        RAISE EXCEPTION USING
          ERRCODE=_state,
          MESSAGE='[ERRO] Duplicate detected inserting meet',
          DETAIL=COALESCE(_detail,'(none)'),
          HINT=COALESCE(_hint, 'Verify unique/PK constraints (meet_id, change_stamp).');

    WHEN check_violation OR foreign_key_violation THEN
        GET STACKED DIAGNOSTICS
          _state=RETURNED_SQLSTATE, _msg=MESSAGE_TEXT, _detail=PG_EXCEPTION_DETAIL,
          _hint=PG_EXCEPTION_HINT, _ctx=PG_EXCEPTION_CONTEXT;
        RAISE LOG '[ERRO] constraint_violation (%): % | detail: % | hint: % | ctx: %',
          _state, _msg, COALESCE(_detail,'(none)'), COALESCE(_hint,'(none)'), COALESCE(_ctx,'(none)');
        RAISE EXCEPTION USING
          ERRCODE=_state,
          MESSAGE='[ERRO] Constraint violation while inserting meet',
          DETAIL=COALESCE(_detail,'(none)'),
          HINT=COALESCE(_hint, 'Review table constraints and input values.');

    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS
          _state=RETURNED_SQLSTATE, _msg=MESSAGE_TEXT, _detail=PG_EXCEPTION_DETAIL,
          _hint=PG_EXCEPTION_HINT, _ctx=PG_EXCEPTION_CONTEXT;
        RAISE LOG '[ERRO] unhandled_exception (%): % | detail: % | hint: % | ctx: %',
          _state, _msg, COALESCE(_detail,'(none)'), COALESCE(_hint,'(none)'), COALESCE(_ctx,'(none)');
        RAISE EXCEPTION USING
          ERRCODE=_state,
          MESSAGE='[ERRO] Unexpected failure in rangley_s_insert_meet',
          DETAIL=COALESCE(_detail,'(none)'),
          HINT=COALESCE(_hint, 'Check server logs for full context and stack trace.');
END;
$procedure$;