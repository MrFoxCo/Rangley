-- ============================================
-- GET FRIENDS LIST
-- ============================================
CREATE OR REPLACE FUNCTION rangley.rgl_fn_v_friends_list
(
    p_cognito_sub TEXT
)
RETURNS TABLE (
    user_uuid UUID,
    username VARCHAR(50),
    display_name VARCHAR(50),
    friend_since TIMESTAMPTZ
)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_user_id INT8;
BEGIN
    -- Get current user's ID
    SELECT user_id INTO v_user_id 
    FROM rangley.vw_users 
    WHERE cognito_sub = p_cognito_sub;
    
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'User not found for cognito_sub: %', p_cognito_sub;
    END IF;
    
    -- Return all friends with their info
    -- Using vw_user_friendships which already handles the bidirectional relationship
    RETURN QUERY
    SELECT 
        uf.friend_uuid AS user_uuid,
        uf.friend_username AS username,
        uf.friend_display_name AS display_name,
        uf.friends_since AS friend_since
    FROM rangley.vw_user_friendships uf
    WHERE uf.user_id = v_user_id
    ORDER BY uf.friends_since DESC;
END;
$$;