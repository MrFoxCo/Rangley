CREATE OR REPLACE FUNCTION rangley.rgl_fn_v_friendship_status
(
    p_cognito_sub TEXT,
    p_target_user_uuid UUID
)
RETURNS TABLE (
    status VARCHAR(20),
    friend_request_id INT8
)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_user_id INT8;
    v_target_user_id INT8;
BEGIN
    -- Get current user's ID
    SELECT user_id INTO v_user_id 
    FROM rangley.vw_users 
    WHERE cognito_sub = p_cognito_sub;
    
    -- Get target user's ID
    SELECT user_id INTO v_target_user_id 
    FROM rangley.vw_users 
    WHERE uuid = p_target_user_uuid;
    
    -- Check if already friends (using vw_friendships, not vw_friends)
    IF EXISTS (
        SELECT 1 FROM rangley.vw_friendships 
        WHERE (user_id_a = LEAST(v_user_id, v_target_user_id) 
           AND user_id_b = GREATEST(v_user_id, v_target_user_id))
    ) THEN
        RETURN QUERY SELECT 'friends'::VARCHAR(20), NULL::INT8;
        RETURN;
    END IF;
    
    -- Check for pending request (sent by current user)
    IF EXISTS (
        SELECT 1 FROM rangley.vw_friend_requests
        WHERE requester_user_id = v_user_id 
          AND recipient_user_id = v_target_user_id
          AND friend_request_status_id = 1  -- pending status
    ) THEN
        RETURN QUERY 
        SELECT 'pending_sent'::VARCHAR(20), friend_request_id
        FROM rangley.vw_friend_requests
        WHERE requester_user_id = v_user_id 
          AND recipient_user_id = v_target_user_id
          AND friend_request_status_id = 1;
        RETURN;
    END IF;
    
    -- Check for pending request (received by current user)
    IF EXISTS (
        SELECT 1 FROM rangley.vw_friend_requests
        WHERE requester_user_id = v_target_user_id 
          AND recipient_user_id = v_user_id
          AND friend_request_status_id = 1  -- pending status
    ) THEN
        RETURN QUERY 
        SELECT 'pending_received'::VARCHAR(20), friend_request_id
        FROM rangley.vw_friend_requests
        WHERE requester_user_id = v_target_user_id 
          AND recipient_user_id = v_user_id
          AND friend_request_status_id = 1;
        RETURN;
    END IF;
    
    -- No relationship
    RETURN QUERY SELECT 'none'::VARCHAR(20), NULL::INT8;
END;
$$;