-- ============================================
-- REMOVE FRIEND (UNFRIEND)
-- ============================================
CREATE OR REPLACE FUNCTION rangley.rgl_fn_d_friend
(
    p_cognito_sub TEXT,
    p_target_user_uuid UUID
)
RETURNS TABLE (
    success BOOLEAN,
    message TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_user_id INT8;
    v_target_user_id INT8;
    v_rows_deleted INT;
    v_user_id_a INT8;
    v_user_id_b INT8;
BEGIN
    -- Get current user's ID
    SELECT user_id INTO v_user_id
    FROM rangley.vw_users
    WHERE cognito_sub = p_cognito_sub;

    IF v_user_id IS NULL THEN
        RETURN QUERY SELECT FALSE, 'User not found';
        RETURN;
    END IF;

    -- Get target user's ID
    SELECT user_id INTO v_target_user_id
    FROM rangley.vw_users
    WHERE uuid = p_target_user_uuid;

    IF v_target_user_id IS NULL THEN
        RETURN QUERY SELECT FALSE, 'Target user not found';
        RETURN;
    END IF;

    -- Check if they are actually friends
    IF NOT EXISTS (
        SELECT 1 FROM rangley.vw_friendships
        WHERE (user_id_a = LEAST(v_user_id, v_target_user_id)
           AND user_id_b = GREATEST(v_user_id, v_target_user_id))
    ) THEN
        RETURN QUERY SELECT FALSE, 'You are not friends with this user';
        RETURN;
    END IF;

    -- Normalize IDs (smaller first, due to CHECK constraint)
    v_user_id_a := LEAST(v_user_id, v_target_user_id);
    v_user_id_b := GREATEST(v_user_id, v_target_user_id);

    -- Delete the friendship
    DELETE FROM rangley.tb_friendships
    WHERE user_id_a = v_user_id_a
      AND user_id_b = v_user_id_b;

    GET DIAGNOSTICS v_rows_deleted = ROW_COUNT;

    -- Also delete any friend requests between these users (either direction)
    DELETE FROM rangley.tb_friend_requests
    WHERE (requester_user_id = v_user_id AND recipient_user_id = v_target_user_id)
       OR (requester_user_id = v_target_user_id AND recipient_user_id = v_user_id);

    IF v_rows_deleted > 0 THEN
        RETURN QUERY SELECT TRUE, 'Friend removed successfully';
    ELSE
        RETURN QUERY SELECT FALSE, 'Failed to remove friend';
    END IF;
END;
$$;



