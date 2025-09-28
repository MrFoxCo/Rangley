CREATE OR REPLACE PROCEDURE rangley.rangley_s_insert_meet_w_user_invites
(
    -- OUTs
     OUT num_inserted            INT4
    ,OUT new_meet_id_uuid        UUID
    ,OUT validation_failed       BOOLEAN
    ,OUT validation_reason       TEXT
    ,OUT validation_message      TEXT

    -- INs
    ,IN  p_cognito_sub           TEXT
    ,IN  p_initial_invitee_uuids UUID[]      -- REQUIRED (no default)

    -- coordinates
    ,IN  p_latitude              FLOAT8
    ,IN  p_longitude             FLOAT8
    ,IN  p_region_latitude       FLOAT8
    ,IN  p_region_longitude      FLOAT8
    ,IN  p_region_radius         FLOAT8

    -- meet fields
    ,IN  p_name                  VARCHAR(50)
    ,IN  p_dttm_start_utc        TIMESTAMPTZ
    ,IN  p_dttm_end_utc          TIMESTAMPTZ
    ,IN  p_description           VARCHAR(50) DEFAULT ''::VARCHAR
    ,IN  p_meet_category_id      INT2        DEFAULT 1::INT2
    ,IN  p_max_capacity          INT4        DEFAULT 2::INT4
    ,IN  p_invitation_message    TEXT        DEFAULT ''::TEXT
)
LANGUAGE plpgsql
AS $procedure$
DECLARE
    _state  text; _msg text; _detail text; _hint text; _ctx text;
    v_sub                   	text;
    v_creator_user_id       	BIGINT;
    v_creator_user_uuid     	UUID;
    v_meet_id_uuid	        	UUID;
    v_rows                  	INT4;
    v_invitee_uuids         	UUID[];
    -- Validation variables to receive from inner procedure
    v_validation_failed         BOOLEAN;
    v_validation_reason         TEXT;
    v_validation_message        TEXT;
BEGIN
    -- OUT sentinels
    num_inserted := 0;
    new_meet_id_uuid := NULL;
    validation_failed := FALSE;
    validation_reason := NULL;
    validation_message := NULL;

    -- Guards
    v_sub := nullif(btrim(p_cognito_sub), '');
    IF v_sub IS NULL THEN
        RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='[ERRO] p_cognito_sub is required (non-empty)';
    END IF;

    -- Keep ONLY this invite guard (with SQLSTATE)
    IF p_initial_invitee_uuids IS NULL OR array_length(p_initial_invitee_uuids,1) = 0 THEN
      RAISE EXCEPTION USING ERRCODE='22023',
        MESSAGE='[ERRO] p_initial_invitee_uuids must be a non-empty array';
    END IF;

    -- Guard creator resolution
    SELECT u.user_id, u.uuid
      INTO v_creator_user_id, v_creator_user_uuid
    FROM rangley.vw_users u
    WHERE u.cognito_sub = v_sub;
    
    IF v_creator_user_id IS NULL THEN
      RAISE EXCEPTION USING ERRCODE='22023',
        MESSAGE='[ERRO] Could not resolve user from cognito_sub',
        DETAIL=format('cognito_sub=%s', v_sub);
    END IF;

    -- Create meet via existing proc (now with validation outputs)
    CALL rangley.rangley_s_insert_meet
    (
         v_rows                 ,v_meet_id_uuid        ,v_validation_failed
        ,v_validation_reason    ,v_validation_message  ,v_sub                    
        ,p_latitude             ,p_longitude
        ,p_region_latitude      ,p_region_longitude    ,p_region_radius
        ,p_name                 ,p_dttm_start_utc      ,p_dttm_end_utc
        ,p_description          ,p_meet_category_id    ,p_max_capacity
    );

    -- Pass through validation results to our OUT parameters
	num_inserted      := v_rows;
	new_meet_id_uuid  := v_meet_id_uuid;
	validation_failed := v_validation_failed;
	validation_reason := v_validation_reason;
	validation_message := v_validation_message;
	
	-- If validation failed, return early (don't process invites)
	IF v_validation_failed THEN
	    RETURN;
	END IF;
	
	-- Only check for success if validation passed
	IF v_rows <> 1 OR v_meet_id_uuid IS NULL THEN
	    RAISE EXCEPTION USING ERRCODE='P0004',
	        MESSAGE='[ERRO] Failed to get meet_id_uuid from s_insert_meet',
	        DETAIL=format('rows=%s, uuid=%s', v_rows, v_meet_id_uuid);
END IF;

    -- restore normalization before the invite
    WITH norm AS (
      SELECT DISTINCT u AS uuid
      FROM unnest(p_initial_invitee_uuids) AS u
      WHERE u IS NOT NULL AND u <> v_creator_user_uuid
    )
    SELECT COALESCE(array_agg(uuid), ARRAY[]::uuid[])
      INTO v_invitee_uuids
    FROM norm;
    
    -- invite if any remain
    IF array_length(v_invitee_uuids, 1) > 0 THEN
      PERFORM rangley.rangley_fn_i_invite_users_to_meet_by_meet_id_uuid(
        new_meet_id_uuid,
        v_creator_user_uuid,
        v_invitee_uuids,
        p_invitation_message
      );
    END IF;

    RETURN;
EXCEPTION
    WHEN unique_violation THEN
        GET STACKED DIAGNOSTICS
          _state=RETURNED_SQLSTATE, _msg=MESSAGE_TEXT, _detail=PG_EXCEPTION_DETAIL,
          _hint=PG_EXCEPTION_HINT, _ctx=PG_EXCEPTION_CONTEXT;
        RAISE LOG '[ERRO] unique_violation (%): % | detail: % | hint: % | ctx: %',
          _state, _msg, COALESCE(_detail,'(none)'), COALESCE(_hint,'(none)'), COALESCE(_ctx,'(none)');
        RAISE EXCEPTION USING ERRCODE=_state,
          MESSAGE='[ERRO] Duplicate detected inserting meet (or related rows)',
          DETAIL=COALESCE(_detail,'(none)');
    WHEN check_violation OR foreign_key_violation THEN
        GET STACKED DIAGNOSTICS
          _state=RETURNED_SQLSTATE, _msg=MESSAGE_TEXT, _detail=PG_EXCEPTION_DETAIL,
          _hint=PG_EXCEPTION_HINT, _ctx=PG_EXCEPTION_CONTEXT;
        RAISE LOG '[ERRO] constraint_violation (%): % | detail: % | hint: % | ctx: %',
          _state, _msg, COALESCE(_detail,'(none)'), COALESCE(_hint,'(none)'), COALESCE(_ctx,'(none)');
        RAISE EXCEPTION USING ERRCODE=_state,
          MESSAGE='[ERRO] Constraint violation while inserting meet',
          DETAIL=COALESCE(_detail,'(none)');
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS
          _state=RETURNED_SQLSTATE, _msg=MESSAGE_TEXT, _detail=PG_EXCEPTION_DETAIL,
          _hint=PG_EXCEPTION_HINT, _ctx=PG_EXCEPTION_CONTEXT;
        RAISE LOG '[ERRO] unhandled_exception (%): % | detail: % | hint: % | ctx: %',
          _state, _msg, COALESCE(_detail,'(none)'), COALESCE(_hint,'(none)'), COALESCE(_ctx,'(none)');
        RAISE EXCEPTION USING ERRCODE=_state,
          MESSAGE='[ERRO] Unexpected failure in rangley_s_insert_meet_w_user_invites',
          DETAIL=COALESCE(_detail,'(none)');
END;
$procedure$;