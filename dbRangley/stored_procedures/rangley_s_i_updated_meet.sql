-- Updated rangley_s_insert_updated_meet procedure with validation outputs
CREATE OR REPLACE PROCEDURE rangley.rangley_s_insert_updated_meet
(
    -- OUTs
      OUT num_inserted            INT4
    , OUT validation_failed       BOOLEAN
    , OUT validation_reason       TEXT
    , OUT validation_message      TEXT

    -- INs (required)
    , IN  p_cognito_sub           text
    , IN  p_meet_id_uuid          UUID

    -- coordinates (optional - only pass if changed)
    , IN  p_latitude              FLOAT8        DEFAULT NULL
    , IN  p_longitude             FLOAT8        DEFAULT NULL
    , IN  p_region_latitude       FLOAT8        DEFAULT NULL
    , IN  p_region_longitude      FLOAT8        DEFAULT NULL
    , IN  p_region_radius         FLOAT8        DEFAULT NULL

    -- meet fields (optional - only pass if changed)
    , IN  p_meet_status_id        int2          DEFAULT NULL
    , IN  p_name                  varchar(50)   DEFAULT NULL
    , IN  p_dttm_start_utc        timestamptz   DEFAULT NULL
    , IN  p_dttm_end_utc          timestamptz   DEFAULT NULL
    , IN  p_description           varchar(50)   DEFAULT NULL
    , IN  p_change_reason         varchar(50)   DEFAULT NULL
    , IN  p_meet_category_id      int2          DEFAULT NULL
    , IN  p_max_capacity          int4          DEFAULT NULL
)
LANGUAGE plpgsql
AS $procedure$
#variable_conflict use_variable
DECLARE
    _state  text; _msg text; _detail text; _hint text; _ctx text;

    v_sub                 text;
    v_user_id             int8;
    v_meet_id             int8;
    v_new_change_stamp    int8;
    v_new_meet_coord_id   int8;

    -- Current values
    current_coordinate_id   int8;
    current_meet_status_id  int2;
    current_name            varchar(50);
    current_description     varchar(50);
    current_category_id     int2;
    current_max_capacity    int4;
    current_dttm_start_utc  timestamptz;
    current_dttm_end_utc    timestamptz;

    -- Final values
    final_coordinate_id     int8;
    final_meet_status_id    int2;
    final_name              varchar(50);
    final_description       varchar(50);
    final_change_reason     varchar(50);
    final_category_id       int2;
    final_max_capacity      int4;
    final_dttm_start_utc    timestamptz;
    final_dttm_end_utc      timestamptz;

    -- Content validation
    content_validation      json;
    content_valid           boolean;
    content_reason          text;
    content_message         text;

    _provided               int;
    _eps        float8 := 1e-7;
    _eps_radius float8 := 1e-3;
BEGIN
    -- OUT sentinels
    num_inserted := 0;
    validation_failed := FALSE;
    validation_reason := NULL;
    validation_message := NULL;

    -- Basic guards
    v_sub := nullif(btrim(p_cognito_sub), '');
    IF v_sub IS NULL THEN
        RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='[ERRO] p_cognito_sub is required (non-empty)';
    END IF;

    -- Resolve user id
    SELECT rangley.rangley_fn_v_user_id_by_cognito_sub(v_sub)
      INTO v_user_id;
    IF v_user_id IS NULL OR v_user_id <= 0 THEN
        RAISE EXCEPTION USING ERRCODE='22023',
          MESSAGE='[ERRO] Could not resolve user_id from cognito_sub',
          DETAIL=format('cognito_sub=%s', v_sub);
    END IF;

    -- Existence and ownership checks
    IF NOT EXISTS (
        SELECT 1
        FROM rangley.tb_meet_ids mid
        JOIN rangley.vw_up_to_date_meets v ON v.meet_id = mid.meet_id
        WHERE v.meet_id_uuid = p_meet_id_uuid
    ) THEN
        RAISE EXCEPTION USING ERRCODE='P0002', MESSAGE='[ERRO] Meet not found';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM rangley.tb_meet_ids mid
        JOIN rangley.vw_up_to_date_meets v ON v.meet_id = mid.meet_id
        WHERE v.meet_id_uuid = p_meet_id_uuid
          AND mid.created_by_user_id = v_user_id
    ) THEN
        RAISE EXCEPTION USING ERRCODE='42501', MESSAGE='[ERRO] Not authorized to update this meet';
    END IF;

    -- Load current values
    SELECT 
        utdm.meet_id,
        utdm.meet_coordinate_id,
        utdm.meet_status_id,
        utdm.name,
        utdm.description,
        utdm.meet_category_id,
        utdm.max_capacity,
        utdm.dttm_start_utc,
        utdm.dttm_end_utc
    INTO 
        v_meet_id,
        current_coordinate_id,
        current_meet_status_id,
        current_name,
        current_description,
        current_category_id,
        current_max_capacity,
        current_dttm_start_utc,
        current_dttm_end_utc
    FROM rangley.vw_up_to_date_meets utdm
    WHERE utdm.meet_id_uuid = p_meet_id_uuid;

    IF v_meet_id IS NULL THEN
        RAISE EXCEPTION USING ERRCODE='P0002',
          MESSAGE='[ERRO] Meet not found',
          DETAIL=format('meet_id_uuid=%s', p_meet_id_uuid);
    END IF;

    -- Prepare finals
    final_meet_status_id := COALESCE(p_meet_status_id, current_meet_status_id);
    final_name           := COALESCE(p_name, current_name);
    final_description    := COALESCE(p_description, current_description);
    final_change_reason  := COALESCE(p_change_reason, '');
    final_category_id    := COALESCE(p_meet_category_id, current_category_id);
    final_max_capacity   := COALESCE(p_max_capacity, current_max_capacity);
    final_dttm_start_utc := COALESCE(p_dttm_start_utc, current_dttm_start_utc);
    final_dttm_end_utc   := COALESCE(p_dttm_end_utc,   current_dttm_end_utc);

    -- Validate finals
    IF final_name IS NULL OR btrim(final_name) = '' THEN
        RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='[ERRO] name is required';
    END IF;

    -- ===== Content validation for inappropriate language
    content_validation := rangley.rgl_fn_validate_meet_content(final_name, v_user_id, final_description);
    content_valid := (content_validation->>'valid')::boolean;
    content_reason := content_validation->>'reason';
    content_message := content_validation->>'message';
    
	IF NOT content_valid THEN
	    -- Set validation failure outputs
	    validation_failed := TRUE;
	    validation_reason := content_reason;
	    validation_message := content_message;
	    
	    RAISE LOG '[INFO] Update aborted: inappropriate content detected (reason: %)', content_reason;
	    -- Return normally instead of throwing exception
	    RETURN;
	END IF;

    -- Time validation
    IF final_dttm_start_utc IS NULL OR final_dttm_end_utc IS NULL OR final_dttm_start_utc >= final_dttm_end_utc THEN
        RAISE EXCEPTION USING ERRCODE='22023',
          MESSAGE='[ERRO] Invalid time window (start must be before end)',
          DETAIL=format('start=%s end=%s', final_dttm_start_utc, final_dttm_end_utc);
    END IF;

    IF final_max_capacity IS NULL OR final_max_capacity < 2 THEN
        RAISE EXCEPTION USING ERRCODE='22023',
          MESSAGE='[ERRO] max_capacity must be >= 2',
          DETAIL=format('max_capacity=%s', final_max_capacity);
    END IF;

    -- Coordinate handling
    _provided := (CASE WHEN p_latitude         IS NULL THEN 0 ELSE 1 END)
               + (CASE WHEN p_longitude        IS NULL THEN 0 ELSE 1 END)
               + (CASE WHEN p_region_latitude  IS NULL THEN 0 ELSE 1 END)
               + (CASE WHEN p_region_longitude IS NULL THEN 0 ELSE 1 END)
               + (CASE WHEN p_region_radius    IS NULL THEN 0 ELSE 1 END);

    IF _provided = 0 THEN
        final_coordinate_id := current_coordinate_id;

    ELSIF _provided = 5 THEN
        IF p_latitude < -90 OR p_latitude > 90
           OR p_longitude < -180 OR p_longitude > 180
           OR p_region_latitude < -90 OR p_region_latitude > 90
           OR p_region_longitude < -180 OR p_region_longitude > 180
           OR p_region_radius <= 0
        THEN
            RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='[ERRO] Invalid coordinate bounds';
        END IF;

        PERFORM 1
        FROM rangley.tb_meet_coordinates c
        WHERE c.meet_coordinate_id = current_coordinate_id
          AND abs(c.latitude         - p_latitude        ) < _eps
          AND abs(c.longitude        - p_longitude       ) < _eps
          AND abs(c.region_latitude  - p_region_latitude ) < _eps
          AND abs(c.region_longitude - p_region_longitude) < _eps
          AND abs(c.region_radius    - p_region_radius   ) < _eps_radius;

        IF FOUND THEN
            final_coordinate_id := current_coordinate_id;
        ELSE
            CALL rangley.rangley_i_meet_coordinate(
                v_new_meet_coord_id,
                p_latitude, p_longitude, p_region_latitude,
                p_region_longitude, p_region_radius
            );
            final_coordinate_id := v_new_meet_coord_id;
        END IF;

    ELSE
        RAISE EXCEPTION USING ERRCODE='22023',
          MESSAGE='[ERRO] Provide all 5 coordinate fields or none',
          HINT='Required set: latitude, longitude, region_latitude, region_longitude, region_radius.';
    END IF;

    -- No-op guard
    IF final_coordinate_id       = current_coordinate_id
       AND final_meet_status_id  = current_meet_status_id
       AND final_name            = current_name
       AND final_description     IS NOT DISTINCT FROM current_description
       AND final_category_id     = current_category_id
       AND final_max_capacity    = current_max_capacity
       AND final_dttm_start_utc  = current_dttm_start_utc
       AND final_dttm_end_utc    = current_dttm_end_utc
    THEN
        RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='[ERRO] No changes provided';
    END IF;

    -- New change_stamp
    CALL rangley.rangley_i_change_stamp(v_new_change_stamp, v_meet_id);
    IF v_new_change_stamp IS NULL OR v_new_change_stamp <= 0 THEN
        RAISE EXCEPTION USING ERRCODE='23514',
          MESSAGE='[ERRO] Failed to create new change_stamp',
          DETAIL=format('meet_id=%s', v_meet_id);
    END IF;

    -- Insert new version
    INSERT INTO rangley.tb_meets
    (
        meet_id,
        change_stamp,
        meet_coordinate_id,
        meet_status_id,
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
        v_meet_id,
        v_new_change_stamp,
        final_coordinate_id,
        final_meet_status_id,
        final_name,
        final_description,
        final_change_reason,
        final_category_id,
        final_max_capacity,
        final_dttm_start_utc,
        final_dttm_end_utc
    );

    GET DIAGNOSTICS num_inserted = ROW_COUNT;

    IF num_inserted <> 1 THEN
        RAISE EXCEPTION USING ERRCODE='23514',
          MESSAGE='[ERRO] Unexpected insert count for tb_meets',
          DETAIL=format('rows=%s meet_id=%s change_stamp=%s', num_inserted, v_meet_id, v_new_change_stamp);
    END IF;

    RAISE LOG '[INFO] Updated meet_id=% with change_stamp=% and meet_coordinate_id=% by user_id=% with validated content',
        v_meet_id, v_new_change_stamp, final_coordinate_id, v_user_id;

EXCEPTION
    WHEN unique_violation THEN
        GET STACKED DIAGNOSTICS
          _state=RETURNED_SQLSTATE, _msg=MESSAGE_TEXT, _detail=PG_EXCEPTION_DETAIL,
          _hint=PG_EXCEPTION_HINT, _ctx=PG_EXCEPTION_CONTEXT;
        RAISE LOG '[ERRO] unique_violation (%): % | detail: % | hint: % | ctx: %',
          _state, _msg, COALESCE(_detail,'(none)'), COALESCE(_hint,'(none)'), COALESCE(_ctx,'(none)');
        RAISE EXCEPTION USING
          ERRCODE=_state,
          MESSAGE='[ERRO] Duplicate detected updating meet',
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
          MESSAGE='[ERRO] Constraint violation while updating meet',
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
          MESSAGE='[ERRO] Unexpected failure in rangley_s_insert_updated_meet',
          DETAIL=COALESCE(_detail,'(none)'),
          HINT=COALESCE(_hint, 'Check server logs for full context and stack trace.');
END;
$procedure$;