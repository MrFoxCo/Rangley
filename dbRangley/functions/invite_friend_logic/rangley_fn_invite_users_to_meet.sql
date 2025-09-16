CREATE OR REPLACE FUNCTION rangley.rangley_fn_invite_users_to_meet
(
    p_meet_id BIGINT,
    p_inviter_user_id BIGINT,
    p_invitee_user_ids BIGINT[],
    p_invitation_message TEXT DEFAULT NULL
)
RETURNS TABLE (
    user_id BIGINT,
    username VARCHAR(50),
    invitation_status TEXT,
    notification_id BIGINT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_meet_record RECORD;
    v_inviter_is_authorized BOOLEAN;
    v_notification_id BIGINT;
    v_user_id BIGINT;
    v_username VARCHAR(50);
    v_already_participant BOOLEAN;
    v_payload JSONB;
    v_invited_status_id INT2 := 1; -- 'invited' status
    v_host_status_id INT2 := 5; -- 'host' status
    v_current_participants INT;
BEGIN
    -- Get meet details from the up-to-date view
    SELECT 
        m.*,
        (SELECT COUNT(*) FROM rangley.vw_meet_participants mp 
         WHERE mp.meet_id = m.meet_id 
         AND mp.participant_status_id IN (2, 5)) -- accepted or host
    INTO v_meet_record, v_current_participants
    FROM rangley.vw_up_to_date_meets m
    WHERE m.meet_id = p_meet_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Meet with ID % does not exist or is no longer active', p_meet_id;
    END IF;

    -- Check authorization: inviter must be host or meet creator
    SELECT EXISTS(
        SELECT 1 
        FROM rangley.vw_meet_participants mp
        WHERE mp.meet_id = p_meet_id 
        AND mp.user_id = p_inviter_user_id
        AND mp.participant_status_id = v_host_status_id
        
        UNION
        
        SELECT 1
        FROM rangley.vw_meet_ids mi
        WHERE mi.meet_id = p_meet_id 
        AND mi.created_by_user_id = p_inviter_user_id
    ) INTO v_inviter_is_authorized;

    IF NOT v_inviter_is_authorized THEN
        RAISE EXCEPTION 'User % does not have permission to invite others to meet %', 
            p_inviter_user_id, p_meet_id;
    END IF;

    -- Check capacity before inviting
    IF v_current_participants + array_length(p_invitee_user_ids, 1) > v_meet_record.max_capacity THEN
        RAISE NOTICE 'Warning: Inviting % users would exceed meet capacity of %', 
            array_length(p_invitee_user_ids, 1), v_meet_record.max_capacity;
    END IF;

    -- Process each invitee
    FOREACH v_user_id IN ARRAY p_invitee_user_ids
    LOOP
        -- Get username for response
        SELECT u.username 
        INTO v_username
        FROM rangley.vw_users u
        WHERE u.user_id = v_user_id;

        -- Skip if user doesn't exist
        IF v_username IS NULL THEN
            RETURN QUERY SELECT 
                v_user_id,
                NULL::VARCHAR(50),
                'user_not_found'::TEXT,
                NULL::BIGINT;
            CONTINUE;
        END IF;

        -- Check if user is already a participant
        SELECT EXISTS(
            SELECT 1 
            FROM rangley.vw_meet_participants mp
            WHERE mp.meet_id = p_meet_id 
            AND mp.user_id = v_user_id
            AND mp.participant_status_id NOT IN (3, 6, 7) -- not declined, left, or removed
        ) INTO v_already_participant;

        IF v_already_participant THEN
            RETURN QUERY SELECT 
                v_user_id,
                v_username,
                'already_participant'::TEXT,
                NULL::BIGINT;
            CONTINUE;
        END IF;

        -- Add user as invited participant (or re-invite if they previously declined/left)
        INSERT INTO rangley.tb_meet_participants (
            meet_id, 
            user_id, 
            participant_status_id,
            dttm_joined_utc
        )
        VALUES (
            p_meet_id, 
            v_user_id, 
            v_invited_status_id,
            now()
        )
        ON CONFLICT (meet_id, user_id) 
        DO UPDATE SET 
            participant_status_id = v_invited_status_id,
            dttm_modified_utc = now()
        WHERE rangley.tb_meet_participants.participant_status_id IN (3, 6, 7); -- only re-invite if declined/left/removed

        -- Build notification payload
        v_payload := jsonb_build_object(
            'meet_id', p_meet_id,
            'meet_id_uuid', v_meet_record.meet_id_uuid,
            'meet_name', v_meet_record.name,
            'meet_start', v_meet_record.dttm_start_utc,
            'meet_end', v_meet_record.dttm_end_utc,
            'meet_location', jsonb_build_object(
                'latitude', v_meet_record.latitude,
                'longitude', v_meet_record.longitude
            ),
            'category_name', v_meet_record.category_name,
            'invited_by_user_id', p_inviter_user_id,
            'invitation_message', p_invitation_message,
            'action_required', 'respond_to_invitation'
        );

        -- Create notification
        INSERT INTO rangley.tb_notifications (
            notification_type_id,
            meet_id,
            created_by_user_id,
            payload_json
        )
        VALUES (
            1, -- meet_invitation type
            p_meet_id,
            p_inviter_user_id,
            v_payload
        )
        RETURNING notification_id INTO v_notification_id;

        -- Add to user's inbox
        INSERT INTO rangley.tb_user_inboxes (
            user_id,
            notification_id
        )
        VALUES (
            v_user_id,
            v_notification_id
        );

        -- Return success for this user
        RETURN QUERY SELECT 
            v_user_id,
            v_username,
            'invited'::TEXT,
            v_notification_id;
    END LOOP;

    RETURN;
END;
$$;
