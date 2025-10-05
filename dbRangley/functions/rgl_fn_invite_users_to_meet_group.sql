-- ============================================
-- INVITE USERS TO MEET GROUP
-- ============================================
CREATE OR REPLACE FUNCTION rangley.rgl_fn_invite_users_to_meet_group
(
    p_cognito_sub TEXT,
    p_meet_group_id INT8,
    p_user_uuids UUID[]
)
RETURNS TABLE
(
    success BOOLEAN,
    message TEXT,
    invited_count INT4,
    skipped_count INT4
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_user_id INT8;
    v_group_owner_id INT8;
    v_group_name VARCHAR(50);
    v_target_user_id INT8;
    v_user_uuid UUID;
    v_invited_count INT4 := 0;
    v_skipped_count INT4 := 0;
    v_notification_id INT8;
    v_invitation_id INT8;  -- ADDED
BEGIN
    -- Get user ID
    SELECT user_id INTO v_user_id
    FROM rangley.vw_users
    WHERE cognito_sub = p_cognito_sub;

    IF v_user_id IS NULL THEN
        RETURN QUERY SELECT FALSE, 'User not found'::TEXT, 0::INT4, 0::INT4;
        RETURN;
    END IF;

    -- Verify group exists and user owns it
    SELECT created_by_user_id, name INTO v_group_owner_id, v_group_name
    FROM rangley.vw_meet_groups
    WHERE meet_group_id = p_meet_group_id;

    IF v_group_owner_id IS NULL THEN
        RETURN QUERY SELECT FALSE, 'Meet group not found'::TEXT, 0::INT4, 0::INT4;
        RETURN;
    END IF;

    IF v_group_owner_id != v_user_id THEN
        RETURN QUERY SELECT FALSE, 'You do not own this meet group'::TEXT, 0::INT4, 0::INT4;
        RETURN;
    END IF;

    -- Process each user UUID
    FOREACH v_user_uuid IN ARRAY p_user_uuids
    LOOP
        -- Get target user's user_id
        SELECT user_id INTO v_target_user_id
        FROM rangley.vw_users
        WHERE uuid = v_user_uuid;

        -- Skip if user not found
        IF v_target_user_id IS NULL THEN
            v_skipped_count := v_skipped_count + 1;
            CONTINUE;
        END IF;

        -- Skip if already a member
        IF EXISTS (
            SELECT 1 FROM rangley.tb_meet_group_members
            WHERE meet_group_id = p_meet_group_id
            AND user_id = v_target_user_id
        ) THEN
            v_skipped_count := v_skipped_count + 1;
            CONTINUE;
        END IF;

        -- Skip if already invited (pending)
        IF EXISTS (
            SELECT 1 FROM rangley.tb_meet_group_invitations
            WHERE meet_group_id = p_meet_group_id
            AND invited_user_id = v_target_user_id
            AND status = 4  -- Invited
        ) THEN
            v_skipped_count := v_skipped_count + 1;
            CONTINUE;
        END IF;

        -- Create invitation record and capture the ID
        INSERT INTO rangley.tb_meet_group_invitations 
            (meet_group_id, invited_user_id, invited_by_user_id, status)
        VALUES 
            (p_meet_group_id, v_target_user_id, v_user_id, 4)
        ON CONFLICT (meet_group_id, invited_user_id) 
        DO UPDATE SET 
            status = 4,
            invited_by_user_id = v_user_id,
            dttm_invited_utc = now(),
            dttm_responded_utc = NULL
        RETURNING invitation_id INTO v_invitation_id;  -- CAPTURE THE ID

        -- Create notification with invitation_id in payload
        INSERT INTO rangley.tb_notifications (notification_type_id, created_by_user_id, payload_json)
        VALUES (
            19,  -- Meet Group Invitation Received
            v_user_id,
            jsonb_build_object(
                'invitation_id', v_invitation_id,  -- ADDED
                'meet_group_id', p_meet_group_id,
                'meet_group_name', v_group_name,
                'invited_by_user_id', v_user_id,
                'invited_user_id', v_target_user_id
            )
        )
        RETURNING notification_id INTO v_notification_id;

        -- Add to user's inbox
        INSERT INTO rangley.tb_user_inboxes (user_id, notification_id)
        VALUES (v_target_user_id, v_notification_id);

        v_invited_count := v_invited_count + 1;
    END LOOP;

    RETURN QUERY SELECT TRUE,
                        format('Invited %s user(s), skipped %s', v_invited_count, v_skipped_count)::TEXT,
                        v_invited_count,
                        v_skipped_count;

EXCEPTION
    WHEN OTHERS THEN
        RETURN QUERY SELECT FALSE, ('Error: ' || SQLERRM)::TEXT, 0::INT4, 0::INT4;
END;
$$;