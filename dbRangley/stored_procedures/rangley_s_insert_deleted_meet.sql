CREATE OR REPLACE PROCEDURE rangley.rangley_s_insert_deleted_meet
(
    -- OUTs
      OUT num_inserted            INT4

    -- INs (required)
    , IN  p_cognito_sub           text
    , IN  p_meet_id_uuid          UUID
)
LANGUAGE plpgsql
AS $procedure$
/*
	SELECT * FROM rangley.vw_meet_status;
*/
#variable_conflict use_variable
DECLARE
    _state  text; _msg text; _detail text; _hint text; _ctx text;

    v_sub                 text;
    v_user_id             int8;
    v_meet_id             int8;
    v_new_change_stamp    int8;
	v_meet_status_id      int2;
	v_change_reason       varchar(50);
	v_notification_id 		int8;

    -- Current values
    current_coordinate_id   int8;
    current_name            varchar(50);
    current_description     varchar(50);
    current_category_id     int2;
    current_max_capacity    int4;
    current_dttm_start_utc  timestamptz;
    current_dttm_end_utc    timestamptz;

    _provided               int;
    _eps        float8 := 1e-7;
    _eps_radius float8 := 1e-3;
BEGIN
    num_inserted := 0;
	v_meet_status_id := 7;
	v_change_reason  := 'Deleted';

    -- Basic guards
    v_sub := nullif(btrim(p_cognito_sub), '');
    IF v_sub IS NULL THEN
        RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='[ERRO] p_cognito_sub is required (non-empty)';
    END IF;

    -- Resolve user id (was previously missing before ownership check)
    SELECT rangley.rangley_fn_v_user_id_by_cognito_sub(v_sub)
      INTO v_user_id;
    IF v_user_id IS NULL OR v_user_id <= 0 THEN
        RAISE EXCEPTION USING ERRCODE='22023',
          MESSAGE='[ERRO] Could not resolve user_id from cognito_sub',
          DETAIL=format('cognito_sub=%s', v_sub);
    END IF;

    -- Existence, then ownership
    IF NOT EXISTS(
        SELECT 1
        FROM rangley.tb_meet_ids mid
        JOIN rangley.vw_up_to_date_meets v ON v.meet_id = mid.meet_id
        WHERE v.meet_id_uuid = p_meet_id_uuid
    ) THEN
        RAISE EXCEPTION USING ERRCODE='P0002', MESSAGE='[ERRO] Meet not found';
    END IF;

    IF NOT EXISTS(
        SELECT 1
        FROM rangley.tb_meet_ids mid
        JOIN rangley.vw_up_to_date_meets v ON v.meet_id = mid.meet_id
        WHERE v.meet_id_uuid = p_meet_id_uuid
          AND mid.created_by_user_id = v_user_id
    )THEN
    	RAISE EXCEPTION USING ERRCODE='42501', MESSAGE='[ERRO] Not authorized to update this meet';
    END IF;

    -- Load current values
    SELECT 
        utdm.meet_id,
        utdm.meet_coordinate_id,
        utdm.name,
        utdm.description,
        utdm.meet_category_id,
        utdm.max_capacity,
        utdm.dttm_start_utc,
        utdm.dttm_end_utc
    INTO 
        v_meet_id,
        current_coordinate_id,
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
		current_coordinate_id,
		v_meet_status_id,
		current_name,
		current_description,
		v_change_reason,
		current_category_id,
		current_max_capacity,
		current_dttm_start_utc,
		current_dttm_end_utc
    );

    GET DIAGNOSTICS num_inserted = ROW_COUNT;


    IF num_inserted <> 1 THEN
        RAISE EXCEPTION USING ERRCODE='23514',
          MESSAGE='[ERRO] Unexpected insert count for tb_meets',
          DETAIL=format('rows=%s meet_id=%s change_stamp=%s', num_inserted, v_meet_id, v_new_change_stamp);
    END IF;


	INSERT INTO rangley.tb_notifications (
	    notification_type_id,
	    meet_id,
	    created_by_user_id,
	    payload_json
	)
	SELECT 
	    18,  -- Meet Deleted
	    v_meet_id,
	    v_user_id,
	    jsonb_build_object(
	        'meet_name', current_name,
	        'deleted_by_user_id', v_user_id,
	        'deletion_timestamp', NOW()
	    )
	FROM (SELECT 1) dummy  -- Just to make SELECT work
	RETURNING notification_id INTO v_notification_id;
	
	-- Add to all participants' inboxes (except the deleter)
	INSERT INTO rangley.tb_user_inboxes (user_id, notification_id)
	SELECT DISTINCT mp.user_id, v_notification_id
	FROM rangley.tb_meet_participants mp
	WHERE mp.meet_id = v_meet_id
	  AND mp.user_id != v_user_id  -- Don't notify yourself
	  AND mp.participant_status_id IN (4, 6, 7);  -- Invited, Accepted, Owner

	
	-- Delete the original invitation notifications for this meet from all inboxes
	DELETE FROM rangley.tb_user_inboxes ui
	WHERE ui.notification_id IN (
	    SELECT n.notification_id 
	    FROM rangley.tb_notifications n
	    WHERE n.meet_id = v_meet_id
	      AND n.notification_type_id = 8  -- Meet Invitation Received
	);

	
    RAISE LOG '[INFO] Updated meet_id=% with change_stamp=% and meet_coordinate_id=% by user_id=%',
        v_meet_id, v_new_change_stamp, current_coordinate_id, v_user_id;

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
