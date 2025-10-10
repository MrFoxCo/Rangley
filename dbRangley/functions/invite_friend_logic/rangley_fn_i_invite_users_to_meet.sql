CREATE OR REPLACE FUNCTION rangley.rangley_fn_i_invite_users_to_meet
(
     p_meet_id              INT8
    ,p_inviter_user_id      INT8
    ,p_invitee_user_ids     INT8[]
    ,p_invitation_message   TEXT DEFAULT NULL
)
RETURNS TABLE (
    returned_user_id BIGINT,  -- Renamed to avoid conflict
    username VARCHAR(50),
    invitation_status TEXT,
    returned_notification_id BIGINT  -- Renamed to avoid conflict
)
LANGUAGE plpgsql
AS $$
DECLARE
    -- status ids (dictionary-backed; inline constants for speed)
    v_attending_status_id     INT2 := 1;
    v_not_attending_status_id INT2 := 2;
    v_maybe_status_id         INT2 := 3;
    v_invited_status_id       INT2 := 4;
    v_declined_status_id      INT2 := 5;
    v_accepted_status_id      INT2 := 6;
    v_owner_status_id         INT2 := 7;
    v_left_status_id          INT2 := 8;
    v_removed_status_id       INT2 := 9;

    -- meet facts from view (already latest & not ended/cancelled/postponed)
    v_meet_uuid 			UUID;
    v_meet_name 			VARCHAR(50);
    v_meet_start 			TIMESTAMPTZ;
    v_meet_end   			TIMESTAMPTZ;
    v_category_name 		TEXT;
    v_meet_category_id 		INT2;
    v_lat FLOAT8; v_lon 	FLOAT8;
    v_max_capacity 			INT4;

    v_current_participants 	INT;
    v_notification_type_id 	INT2;
    v_notification_id 		BIGINT;
	
    v_inviter_display_name  TEXT;
    v_inviter_username		TEXT;
    v_user_id 				BIGINT;
    v_username 				VARCHAR(50);
    v_existing_status 		INT2;
    v_allow_invites 		BOOLEAN;
BEGIN
    -- Latest active/up-to-date meet row
    SELECT
    	 um.meet_id_uuid	,um.name
    	,um.dttm_start_utc	,um.dttm_end_utc
        ,um.category_name	,um.meet_category_id
        ,um.latitude		,um.longitude
        ,um.max_capacity
    INTO
    	 v_meet_uuid		,v_meet_name
    	,v_meet_start		,v_meet_end
        ,v_category_name	,v_meet_category_id
        ,v_lat				,v_lon				
        ,v_max_capacity
    FROM rangley.vw_up_to_date_meets um
    WHERE um.meet_id = p_meet_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Meet % not found, inactive, or already ended.', p_meet_id;
    END IF;

    -- Authorization: owner OR creator
    IF NOT EXISTS (
        SELECT 1 FROM rangley.vw_meet_participants mp
        WHERE 	mp.meet_id = p_meet_id
        AND 	mp.user_id = p_inviter_user_id 
        AND 	mp.participant_status_id = v_owner_status_id
    ) AND NOT EXISTS (
        SELECT 1 FROM rangley.vw_meet_ids mi
        WHERE 	mi.meet_id = p_meet_id
        AND 	mi.created_by_user_id = p_inviter_user_id
    ) THEN
        RAISE EXCEPTION 'User % lacks permission to invite for meet %', p_inviter_user_id, p_meet_id;
    END IF;

    -- Current accepted+owner count (capacity signal; doesn't block)
    SELECT COUNT(*) INTO v_current_participants
    FROM rangley.vw_meet_participants mp
    WHERE mp.meet_id = p_meet_id
      AND mp.participant_status_id IN (v_accepted_status_id, v_owner_status_id);


 	v_notification_type_id := 8;
 	
    SELECT u.username, u.display_name INTO v_inviter_username ,v_inviter_display_name
    FROM rangley.vw_users u
    WHERE u.user_id = p_inviter_user_id;
 	

    FOREACH v_user_id IN ARRAY p_invitee_user_ids LOOP
        IF v_user_id IS NULL THEN
            RETURN QUERY SELECT NULL::BIGINT, NULL::VARCHAR(50), 'user_not_found'::TEXT, NULL::BIGINT;
            CONTINUE;
        END IF;

        SELECT u.username INTO v_username
        FROM rangley.vw_users u
        WHERE u.user_id = v_user_id;

        IF v_username IS NULL THEN
            RETURN QUERY SELECT v_user_id, NULL::VARCHAR(50), 'user_not_found'::TEXT, NULL::BIGINT;
            CONTINUE;
        END IF;

        -- self-invite guard
        IF v_user_id = p_inviter_user_id THEN
            RETURN QUERY SELECT v_user_id, v_username, 'cannot_invite_self'::TEXT, NULL::BIGINT;
            CONTINUE;
        END IF;

        -- privacy
        SELECT COALESCE(s.allow_invites_from_anyone, TRUE)
        INTO v_allow_invites
        FROM rangley.vw_user_privacy_settings s
        WHERE s.user_id = v_user_id;

        IF NOT v_allow_invites THEN
            RETURN QUERY SELECT v_user_id, v_username, 'invites_blocked'::TEXT, NULL::BIGINT;
            CONTINUE;
        END IF;

        -- existing participant state
        SELECT mp.participant_status_id
        INTO v_existing_status
        FROM rangley.vw_meet_participants mp
        WHERE mp.meet_id = p_meet_id AND mp.user_id = v_user_id;

        IF v_existing_status = v_invited_status_id THEN
            RETURN QUERY SELECT v_user_id, v_username, 'already_invited'::TEXT, NULL::BIGINT;
            CONTINUE;

        ELSIF v_existing_status IS NOT NULL
              AND v_existing_status NOT IN (v_declined_status_id, v_left_status_id, v_removed_status_id) THEN
            RETURN QUERY SELECT v_user_id, v_username, 'already_participant'::TEXT, NULL::BIGINT;
            CONTINUE;
        END IF;

        -- heads-up capacity (not a blocker)
        IF v_current_participants + 1 > v_max_capacity THEN
            RAISE NOTICE 'Inviting user % would exceed capacity %', v_user_id, v_max_capacity;
        END IF;

		-- insert / re-invite with proper timestamps
        INSERT INTO rangley.tb_meet_participants(meet_id, user_id, participant_status_id, dttm_invited_utc)
        VALUES (p_meet_id, v_user_id, v_invited_status_id, now())
        ON CONFLICT (meet_id, user_id)
        DO UPDATE SET
            participant_status_id = EXCLUDED.participant_status_id,
            dttm_invited_utc = now(),
            dttm_accepted_utc = NULL,
            dttm_left_utc = NULL,
            dttm_modified_utc = now();

		-- Create notification for NEW invitations OR re-invitations after decline/leave
		IF v_existing_status IS NULL OR v_existing_status IN (v_declined_status_id, v_left_status_id, v_removed_status_id) THEN
		    -- Create notification for both new and re-invitations
		    INSERT INTO rangley.tb_notifications (notification_type_id, meet_id, created_by_user_id, payload_json)
		    VALUES (
		        v_notification_type_id,
		        p_meet_id,
		        p_inviter_user_id,
		        jsonb_build_object(
		            'meet_id_uuid', v_meet_uuid,
		            'meet_name', v_meet_name,
		            'meet_start', v_meet_start,
		            'meet_end', v_meet_end,
		            'meet_location', jsonb_build_object('latitude', v_lat, 'longitude', v_lon),
		            'category_name', v_category_name,
		            'invited_by_display_name', v_inviter_display_name,
		            'invited_by_username', v_inviter_username,
		            'invitation_message', p_invitation_message,
		            'action_required', 'respond_to_invitation'
		        )
		    )
		    RETURNING notification_id INTO v_notification_id;
		
		    INSERT INTO rangley.tb_user_inboxes (user_id, notification_id)
		    VALUES (v_user_id, v_notification_id);
		    
		    -- Determine correct status message
		    IF v_existing_status IS NULL THEN
		        RETURN QUERY SELECT v_user_id, v_username, 'invited'::TEXT, v_notification_id;
		    ELSE
		        RETURN QUERY SELECT v_user_id, v_username, 're_invited'::TEXT, v_notification_id;
		    END IF;
		ELSE
		    -- Should never reach here due to earlier guards, but just in case
		    v_notification_id := NULL;
		    RETURN QUERY SELECT v_user_id, v_username, 'unexpected_status'::TEXT, NULL::BIGINT;
		END IF;

    END LOOP;

    RETURN;
END;
$$;



/*
    {
    "meet_id": 123,
    "meet_end": "2025-09-27T15:48:04+00:00", 
    "meet_name": "wabbit hunting",
    "meet_start": "2025-09-22T14:48:04+00:00",
    "meet_id_uuid": "f0b9d1d2-f47f-4277-b7de-cc0f311583cb", 
    "category_name": "Activity", 
    "meet_location": {"latitude": 41.984702430934014, "longitude": -87.68324789956196}, 
    "action_required": "respond_to_invitation", "meet_category_id": 1, "invitation_message": "",
    "invited_by_user_id": 6
    }

*/
