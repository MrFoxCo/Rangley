CREATE OR REPLACE PROCEDURE rangley.rangley_s_insert_updated_meet
(
    -- OUTs
      OUT num_inserted            INT4

    -- INs (required)
    , IN  p_cognito_sub           text
    , IN  p_meet_id_uuid		  UUID

    -- coordinates (optional - only pass if changed)
    , IN  p_latitude              FLOAT8        DEFAULT NULL
    , IN  p_longitude             FLOAT8        DEFAULT NULL
    , IN  p_region_latitude       FLOAT8        DEFAULT NULL
    , IN  p_region_longitude      FLOAT8        DEFAULT NULL
    , IN  p_region_radius         FLOAT8        DEFAULT NULL

    -- meet fields (optional - only pass if changed)
    , in  p_meet_status_id        int2          DEFAULT NULL
    , IN  p_name                  varchar(50)   DEFAULT NULL
    , IN  p_dttm_start_utc        timestamptz   DEFAULT NULL
    , IN  p_dttm_end_utc          timestamptz   DEFAULT NULL
    , IN  p_description           varchar(50)   DEFAULT null
    , IN  p_change_reason         varchar(50)   default NULL
    , IN  p_meet_category_id      int2          DEFAULT NULL
    , IN  p_max_capacity          int4          DEFAULT NULL
)
LANGUAGE plpgsql
/*
	THIS IS UPDATING AN EXISTING MEET WITH A NEW CHANGE_STAMP
	Only pass parameters for fields that are actually changing.
	NULL parameters mean "keep the existing value"
*/
AS $procedure$
DECLARE
    _state  text; _msg text; _detail text; _hint text; _ctx text;
    v_sub                text;
    created_by_user_id   INT8;
	meet_id				 INT8;
	new_change_stamp	 INT8;
	new_meet_coordinate_id INT8;
	
	-- Current values from latest version
	current_coordinate_id    INT8;
	current_meet_status_id    INT2;
	current_name            varchar(50);
	current_description     varchar(50);
	current_category_id     int2;
	current_max_capacity    int4;
	current_dttm_start_utc  timestamptz;
	current_dttm_end_utc    timestamptz;
	
	-- Final values to insert
	final_coordinate_id     INT8;
	final_meet_status_id    INT2;
	final_name             varchar(50);
	final_description      varchar(50);
	final_change_reason    varchar(50);
	final_category_id      int2;
	final_max_capacity     int4;
	final_dttm_start_utc   timestamptz;
	final_dttm_end_utc     timestamptz;
	
	coordinates_changed     BOOLEAN := FALSE;
BEGIN
    -- OUT sentinels
    num_inserted := 0;

    -- ===== Basic guards
    v_sub := nullif(btrim(p_cognito_sub), '');
    IF v_sub IS NULL THEN
        RAISE EXCEPTION USING
          ERRCODE='22023', MESSAGE='[ERRO] p_cognito_sub is required (non-empty)';
    END IF;


	-- MAKE SURE THAT THE USER EXISTS
    SELECT rangley.rangley_fn_v_user_id_by_cognito_sub(v_sub)
      INTO created_by_user_id;

    IF created_by_user_id IS NULL OR created_by_user_id <= 0 THEN
        RAISE EXCEPTION USING
          ERRCODE='22023',
          MESSAGE='[ERRO] Could not resolve user_id from cognito_sub',
          DETAIL=format('cognito_sub=%s', v_sub),
          HINT='Ensure the user exists in tb_users and the sub is correct.';
    END IF;

    -- ===== Get current values from latest version

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
	    meet_id,                    -- you need this variable too
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
	
   	IF meet_id IS NULL THEN
		RAISE EXCEPTION USING
         	ERRCODE='P0002',
         	MESSAGE='[ERRO] Meet not found',
         	DETAIL=format('meet_id_uuid=%s', p_meet_id_uuid);
   	END IF;

    -- ===== Prepare final values (new values override current values, treat empty strings as valid)
	final_meet_status_id 	:= COALESCE(p_meet_status_id, current_meet_status_id);
    final_name 				:= COALESCE(p_name, current_name);
    final_description 		:= COALESCE(p_description, current_description);
    final_change_reason 	:= COALESCE(p_change_reason, '');
    final_category_id 		:= COALESCE(p_meet_category_id, current_category_id);
    final_max_capacity 		:= COALESCE(p_max_capacity, current_max_capacity);
    final_dttm_start_utc 	:= COALESCE(p_dttm_start_utc, current_dttm_start_utc);
    final_dttm_end_utc 		:= COALESCE(p_dttm_end_utc, current_dttm_end_utc);

    -- ===== Validate final values (same validations as insert)
    IF final_name IS NULL OR btrim(final_name) = '' THEN
        RAISE EXCEPTION USING
          ERRCODE='22023', MESSAGE='[ERRO] name is required';
    END IF;

    IF final_dttm_start_utc IS NULL OR final_dttm_end_utc IS NULL OR final_dttm_start_utc >= final_dttm_end_utc THEN
        RAISE EXCEPTION USING
          ERRCODE='22023',
          MESSAGE='[ERRO] Invalid time window (start must be before end)',
          DETAIL=format('start=%s end=%s', final_dttm_start_utc, final_dttm_end_utc);
    END IF;

    IF final_max_capacity IS NULL OR final_max_capacity < 2 THEN
        RAISE EXCEPTION USING
          ERRCODE='22023',
          MESSAGE='[ERRO] max_capacity must be >= 2',
          DETAIL=format('max_capacity=%s', final_max_capacity);
    END IF;

    -- ===== Determine if coordinates changed
    coordinates_changed := (
        p_latitude 			IS NOT NULL OR 
        p_longitude 		IS NOT NULL OR 
        p_region_latitude 	IS NOT NULL OR 
        p_region_longitude 	IS NOT NULL OR 
        p_region_radius 	IS NOT NULL
    );

    -- ===== Handle coordinates (same pattern as insert)
    IF coordinates_changed THEN
        -- Create new coordinate record
        CALL rangley.rangley_i_meet_coordinate(
            new_meet_coordinate_id,
            p_latitude, 
            p_longitude, 
            p_region_latitude, 
            p_region_longitude, 
            p_region_radius
        );
        final_coordinate_id := new_meet_coordinate_id;
        
        RAISE LOG '[INFO] Created new meet_coordinate_id=%', final_coordinate_id;
    ELSE
        -- Reuse existing coordinate record
        final_coordinate_id := current_coordinate_id;
        RAISE LOG '[INFO] Reusing existing meet_coordinate_id=%', final_coordinate_id;
    END IF;

    -- ===== Create new change_stamp for this update
	-- new_change_stamp is an OUT 
    CALL rangley.rangley_i_change_stamp(new_change_stamp, meet_id);

    IF new_change_stamp IS NULL OR new_change_stamp <= 0 THEN
        RAISE EXCEPTION USING
          ERRCODE='23514',
          MESSAGE='[ERRO] Failed to create new change_stamp',
          DETAIL=format('meet_id=%s', meet_id);
    END IF;

    -- ===== Insert new version (same structure as insert)
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
        meet_id,
        new_change_stamp,
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
        RAISE EXCEPTION USING
          ERRCODE='23514',
          MESSAGE='[ERRO] Unexpected insert count for tb_meets',
          DETAIL=format('rows=%s meet_id=%s change_stamp=%s', num_inserted, meet_id, new_change_stamp);
    END IF;

    RAISE LOG '[INFO] Updated meet_id=% with change_stamp=% and meet_coordinate_id=% by user_id=%',
        meet_id, new_change_stamp, final_coordinate_id, created_by_user_id;

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