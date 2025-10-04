-- ============================================
-- RESPOND TO FRIEND REQUEST (USING VIEWS)
-- ============================================
CREATE OR REPLACE FUNCTION rangley.rgl_fn_respond_to_friend_request
(
    p_recipient_cognito_sub TEXT,
    p_friend_request_id     INT8,
    p_accept                BOOLEAN
)
RETURNS table
(
    success boolean,
    message text
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_recipient_user_id 	int8;
    v_requester_user_id 	int8;
    v_request_status_id 	int2;
    v_notification_id   	int8;
    v_notification_type_id 	int2;
BEGIN
    -- Get recipient user_id from view
    SELECT user_id INTO v_recipient_user_id
    FROM rangley.vw_users
    WHERE cognito_sub = p_recipient_cognito_sub;
    
    IF v_recipient_user_id IS NULL THEN
        RETURN QUERY SELECT false, '[ERRO] User not found';
        RETURN;
    END IF;
    
    -- Get request details from view
    SELECT requester_user_id, friend_request_status_id
    INTO v_requester_user_id, v_request_status_id
    FROM rangley.vw_friend_requests
    WHERE friend_request_id = p_friend_request_id
      AND recipient_user_id = v_recipient_user_id;
    
    IF v_requester_user_id IS NULL THEN
        RETURN QUERY SELECT false, '[ERRO] Friend request not found or not authorized';
        RETURN;
    END IF;
    
    IF v_request_status_id != 1 THEN
        RETURN QUERY SELECT false, '[ERRO] Friend request already responded to';
        RETURN;
    END IF;
    
    IF p_accept THEN
        -- Update base table
        UPDATE rangley.tb_friend_requests
        SET friend_request_status_id = 2,
            dttm_responded_utc = now(),
            dttm_modified_utc = now()
        WHERE friend_request_id = p_friend_request_id;
        
        -- Insert friendship into base table
        INSERT INTO rangley.tb_friendships (user_id_a, user_id_b)
        VALUES (
            LEAST(v_requester_user_id, v_recipient_user_id),
            GREATEST(v_requester_user_id, v_recipient_user_id)
        );
        
        v_notification_type_id := 16;
    ELSE
        -- Update base table
        UPDATE rangley.tb_friend_requests
        SET friend_request_status_id = 3,
            dttm_responded_utc = now(),
            dttm_modified_utc = now()
        WHERE friend_request_id = p_friend_request_id;
        
        v_notification_type_id := 17;
    END IF;


	-- Delete the friend request notification from recipient's inbox
	DELETE FROM rangley.tb_user_inboxes ui
	WHERE ui.user_id = v_recipient_user_id
	  AND ui.notification_id IN (
	      SELECT n.notification_id 
	      FROM rangley.tb_notifications n
	      WHERE n.notification_type_id = 15  -- Friend Request Received
	        AND n.payload_json->>'friend_request_id' = p_friend_request_id::text
	  );

    
    -- Insert notification into base table
    INSERT INTO rangley.tb_notifications (
        notification_type_id,
        meet_id,
        created_by_user_id,
        payload_json
    ) VALUES (
        v_notification_type_id,
        NULL,
        v_recipient_user_id,
        jsonb_build_object(
            'friend_request_id', p_friend_request_id,
            'recipient_user_id', v_recipient_user_id
        )
    )
    RETURNING rangley.tb_notifications.notification_id INTO v_notification_id;
    
    -- Insert into inbox base table
    INSERT INTO rangley.tb_user_inboxes (
        user_id,
        notification_id
    ) VALUES (
        v_requester_user_id,
        v_notification_id
    );
    
    IF p_accept THEN
        RETURN QUERY SELECT true, 'Friend request accepted';
    ELSE
        RETURN QUERY SELECT true, 'Friend request declined';
    END IF;
END;
$$;