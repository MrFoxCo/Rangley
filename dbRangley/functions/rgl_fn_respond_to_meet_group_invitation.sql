-- ============================================
-- RESPOND TO MEET GROUP INVITATION
-- ============================================
CREATE OR REPLACE FUNCTION rangley.rgl_fn_respond_to_meet_group_invitation
(
    p_cognito_sub TEXT,
    p_invitation_id INT8,
    p_accept BOOLEAN  -- TRUE = accept, FALSE = decline
)
RETURNS TABLE
(
    success BOOLEAN,
    message TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_user_id INT8;
    v_invitation RECORD;
    v_notification_id INT8;
BEGIN
    -- Get user ID
    SELECT user_id INTO v_user_id
    FROM rangley.vw_users
    WHERE cognito_sub = p_cognito_sub;

    IF v_user_id IS NULL THEN
        RETURN QUERY SELECT FALSE, 'User not found'::TEXT;
        RETURN;
    END IF;

    -- Get invitation details
    SELECT * INTO v_invitation
    FROM rangley.vw_meet_group_invitations
    WHERE invitation_id = p_invitation_id
    AND invited_user_id = v_user_id
    AND status = 4;  -- Must be pending

    IF v_invitation IS NULL THEN
        RETURN QUERY SELECT FALSE, 'Invitation not found or already responded to'::TEXT;
        RETURN;
    END IF;

    IF p_accept THEN
        -- Accept: Update invitation and add to members
        UPDATE rangley.tb_meet_group_invitations
        SET status = 6,  -- Accepted
            dttm_responded_utc = now()
        WHERE invitation_id = p_invitation_id;

        -- Add to group members
        INSERT INTO rangley.tb_meet_group_members (meet_group_id, user_id)
        VALUES (v_invitation.meet_group_id, v_user_id)
        ON CONFLICT (meet_group_id, user_id) DO NOTHING;

        -- Notify group owner
        INSERT INTO rangley.tb_notifications (notification_type_id, created_by_user_id, payload_json)
        VALUES (
            20,  -- Meet Group Invitation Accepted
            v_user_id,
            jsonb_build_object(
                'meet_group_id', v_invitation.meet_group_id,
                'accepted_by_user_id', v_user_id
            )
        )
        RETURNING notification_id INTO v_notification_id;

        INSERT INTO rangley.tb_user_inboxes (user_id, notification_id)
        VALUES (v_invitation.invited_by_user_id, v_notification_id);

        RETURN QUERY SELECT TRUE, 'Invitation accepted'::TEXT;
    ELSE
        -- Decline: Just update invitation status
        UPDATE rangley.tb_meet_group_invitations
        SET status = 5,  -- Declined
            dttm_responded_utc = now()
        WHERE invitation_id = p_invitation_id;

        -- Notify group owner
        INSERT INTO rangley.tb_notifications (notification_type_id, created_by_user_id, payload_json)
        VALUES (
            21,  -- Meet Group Invitation Declined
            v_user_id,
            jsonb_build_object(
                'meet_group_id', v_invitation.meet_group_id,
                'declined_by_user_id', v_user_id
            )
        )
        RETURNING notification_id INTO v_notification_id;

        INSERT INTO rangley.tb_user_inboxes (user_id, notification_id)
        VALUES (v_invitation.invited_by_user_id, v_notification_id);

        RETURN QUERY SELECT TRUE, 'Invitation declined'::TEXT;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        RETURN QUERY SELECT FALSE, ('Error: ' || SQLERRM)::TEXT;
END;
$$;
