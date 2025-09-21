-- ================================================================
-- RESPOND TO MEET INVITATION (flip participant_status + notify creator)
-- ================================================================
CREATE OR REPLACE FUNCTION rangley.rangley_fn_m_respond_to_meet_invitation
(
     p_cognito_sub          TEXT
    ,p_meet_id              INT8
    ,p_response_status_id   INT2  -- 6=Accepted, 5=Declined, 3=Maybe
)
RETURNS TABLE
(
     success         BOOLEAN
    ,message         TEXT
    ,participant_id  BIGINT
    ,old_status_id   INT2
    ,new_status_id   INT2
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_user_id                BIGINT;
    v_participant_id         BIGINT;
    v_old_status_id          INT2;
    v_meet_creator_id        BIGINT;
    v_notification_id        BIGINT;

    -- statuses
    v_status_invited         INT2 := 4;
    v_status_accepted        INT2 := 6;
    v_status_declined        INT2 := 5;
    v_status_maybe           INT2 := 3;
    v_status_owner           INT2 := 7;
    v_status_left            INT2 := 8;
    v_status_removed         INT2 := 9;

    -- notification types
    v_ntype_accepted         INT2 := 9;
    v_ntype_declined         INT2 := 10;

    v_notification_type_id   INT2;
BEGIN
    -- who is responding
    SELECT u.user_id
      INTO v_user_id
      FROM rangley.vw_users u
     WHERE u.cognito_sub = p_cognito_sub;

    IF v_user_id IS NULL THEN
        RETURN QUERY SELECT FALSE, 'User not found'::TEXT, NULL::BIGINT, NULL::INT2, NULL::INT2;
        RETURN;
    END IF;

    -- validate requested new status
    IF p_response_status_id NOT IN (v_status_accepted, v_status_declined, v_status_maybe) THEN
        RETURN QUERY SELECT FALSE, 'Invalid response status'::TEXT, NULL::BIGINT, NULL::INT2, NULL::INT2;
        RETURN;
    END IF;

    -- participant row
    SELECT mp.participant_id, mp.participant_status_id
      INTO v_participant_id, v_old_status_id
      FROM rangley.tb_meet_participants mp
     WHERE mp.meet_id = p_meet_id
       AND mp.user_id = v_user_id;

    IF v_participant_id IS NULL THEN
        RETURN QUERY SELECT FALSE, 'No participant record for this meet'::TEXT, NULL::BIGINT, NULL::INT2, NULL::INT2;
        RETURN;
    END IF;

    -- block impossible states (owner/left/removed)
    IF v_old_status_id IN (v_status_owner, v_status_left, v_status_removed) THEN
        RETURN QUERY SELECT FALSE, 'Cannot respond in current state'::TEXT, v_participant_id, v_old_status_id, NULL::INT2;
        RETURN;
    END IF;

    -- (optional) if you want to require they were at least invited first:
    -- IF v_old_status_id NOT IN (v_status_invited, v_status_accepted, v_status_declined, v_status_maybe) THEN
    --     RETURN QUERY SELECT FALSE, 'Not in a respondable state'::TEXT, v_participant_id, v_old_status_id, NULL::INT2;
    --     RETURN;
    -- END IF;

    -- meet creator for notification (FIX: pull from vw_meet_ids / tb_meet_ids)
    SELECT mi.created_by_user_id
      INTO v_meet_creator_id
      FROM rangley.vw_meet_ids mi
     WHERE mi.meet_id = p_meet_id;

    IF v_meet_creator_id IS NULL THEN
        RETURN QUERY SELECT FALSE, 'Meet not found'::TEXT, v_participant_id, v_old_status_id, NULL::INT2;
        RETURN;
    END IF;

    -- update participant status
    UPDATE rangley.tb_meet_participants
       SET participant_status_id = p_response_status_id,
           dttm_accepted_utc = CASE WHEN p_response_status_id = v_status_accepted THEN NOW() ELSE NULL END,
           dttm_modified_utc = NOW()
     WHERE participant_id = v_participant_id;

    -- choose notification type (Maybe -> no notification)
    v_notification_type_id :=
        CASE
            WHEN p_response_status_id = v_status_accepted THEN v_ntype_accepted
            WHEN p_response_status_id = v_status_declined THEN v_ntype_declined
            ELSE NULL
        END;

    IF v_notification_type_id IS NOT NULL AND v_meet_creator_id IS NOT NULL AND v_meet_creator_id <> v_user_id THEN
        INSERT INTO rangley.tb_notifications
            (notification_type_id, meet_id, created_by_user_id, payload_json)
        VALUES
            (v_notification_type_id, p_meet_id, v_user_id,
             jsonb_build_object(
                 'respondent_user_id', v_user_id,
                 'response_status_id', p_response_status_id,
                 'response_timestamp', NOW()
             ))
        RETURNING notification_id INTO v_notification_id;

        INSERT INTO rangley.tb_user_inboxes (user_id, notification_id)
        VALUES (v_meet_creator_id, v_notification_id);
    END IF;

    RETURN QUERY
        SELECT TRUE,
               'Response recorded successfully'::TEXT,
               v_participant_id,
               v_old_status_id,
               p_response_status_id;
EXCEPTION
    WHEN OTHERS THEN
        RETURN QUERY SELECT FALSE, ('Error: ' || SQLERRM)::TEXT, NULL::BIGINT, NULL::INT2, NULL::INT2;
END;
$$;
