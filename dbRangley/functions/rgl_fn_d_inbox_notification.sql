-- ============================================
-- DELETE SINGLE NOTIFICATION FROM INBOX
-- ============================================
CREATE OR REPLACE FUNCTION rangley.rgl_fn_d_inbox_notification
(
    p_cognito_sub TEXT,
    p_notification_id INT8
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
    v_deleted_count INT4;
BEGIN
    SELECT user_id INTO v_user_id
    FROM rangley.vw_users
    WHERE cognito_sub = p_cognito_sub;
    
    IF v_user_id IS NULL THEN
        RETURN QUERY SELECT FALSE, 'User not found'::TEXT;
        RETURN;
    END IF;
    
    -- Delete the specific notification from this user's inbox
    DELETE FROM rangley.tb_user_inboxes
    WHERE user_id = v_user_id
      AND notification_id = p_notification_id;
    
    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
    
    IF v_deleted_count = 0 THEN
        RETURN QUERY SELECT FALSE, 'Notification not found in inbox'::TEXT;
    ELSE
        RETURN QUERY SELECT TRUE, 'Notification deleted'::TEXT;
    END IF;
    
EXCEPTION
    WHEN OTHERS THEN
        RETURN QUERY SELECT FALSE, ('Error: ' || SQLERRM)::TEXT;
END;
$$;