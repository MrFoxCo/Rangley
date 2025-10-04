-- ============================================
-- SEND FRIEND REQUEST
-- ============================================

CREATE OR REPLACE FUNCTION rangley.rgl_fn_send_friend_request
(
    p_requester_cognito_sub text,
    p_recipient_user_uuid   uuid
)
RETURNS table
(
    friend_request_id bigint,
    success           boolean,
    message           text
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_requester_user_id bigint;
    v_recipient_user_id bigint;
    v_friend_request_id bigint;
    v_notification_id   bigint;
BEGIN
    -- Get requester user_id from view
    SELECT user_id INTO v_requester_user_id
    FROM rangley.vw_users
    WHERE cognito_sub = p_requester_cognito_sub;
    
    IF v_requester_user_id IS NULL THEN
        RETURN QUERY SELECT NULL::bigint, false, '[ERRO] Requester not found';
        RETURN;
    END IF;
    
    -- Get recipient user_id from view
    SELECT user_id INTO v_recipient_user_id
    FROM rangley.vw_users
    WHERE uuid = p_recipient_user_uuid;
    
    IF v_recipient_user_id IS NULL THEN
        RETURN QUERY SELECT NULL::bigint, false, '[ERRO] Recipient not found';
        RETURN;
    END IF;
    
    -- Check if users are already friends
    IF rangley.rgl_fn_are_users_friends(v_requester_user_id, v_recipient_user_id) THEN
        RETURN QUERY SELECT NULL::bigint, false, '[ERRO] Already friends';
        RETURN;
    END IF;
    
    -- Check if request already exists (either direction) using view
    IF EXISTS (
        SELECT 1 FROM rangley.vw_friend_requests
        WHERE (requester_user_id = v_requester_user_id AND recipient_user_id = v_recipient_user_id)
           OR (requester_user_id = v_recipient_user_id AND recipient_user_id = v_requester_user_id)
    ) THEN
        RETURN QUERY SELECT NULL::bigint, false, '[ERRO] Friend request already exists';
        RETURN;
    END IF;
    
    -- Insert into base table (views can't be inserted into)
    INSERT INTO rangley.tb_friend_requests (
        requester_user_id,
        recipient_user_id,
        friend_request_status_id
    ) VALUES (
        v_requester_user_id,
        v_recipient_user_id,
        1  -- Pending
    )
    RETURNING rangley.tb_friend_requests.friend_request_id INTO v_friend_request_id;
    
    -- Insert notification into base table
    INSERT INTO rangley.tb_notifications (
        notification_type_id,
        meet_id,
        created_by_user_id,
        payload_json
    ) VALUES (
        15,  -- Friend Request Received
        NULL,
        v_requester_user_id,
        jsonb_build_object(
            'friend_request_id', v_friend_request_id,
            'requester_user_id', v_requester_user_id
        )
    )
    RETURNING rangley.tb_notifications.notification_id INTO v_notification_id;
    
    -- Insert into inbox base table
    INSERT INTO rangley.tb_user_inboxes (
        user_id,
        notification_id
    ) VALUES (
        v_recipient_user_id,
        v_notification_id
    );
    
    RETURN QUERY SELECT v_friend_request_id, true, '[INFO] Friend request sent';
END;
$$;