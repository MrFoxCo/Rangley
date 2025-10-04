-- ============================================
-- GET FRIEND GROUP MEMBERS
-- ============================================
CREATE OR REPLACE FUNCTION rangley.rgl_fn_v_friend_group_members
(
    p_cognito_sub TEXT,
    p_friend_group_id INT8
)
RETURNS TABLE
(
    user_uuid UUID,
    username TEXT,
    display_name TEXT,
    dttm_added_utc TIMESTAMPTZ
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_user_id INT8;
    v_group_owner_id INT8;
BEGIN
    -- Get user ID
    SELECT user_id INTO v_user_id
    FROM rangley.vw_users
    WHERE cognito_sub = p_cognito_sub;
    
    IF v_user_id IS NULL THEN
        RETURN;
    END IF;
    
    -- Verify group exists and user owns it
    SELECT created_by_user_id INTO v_group_owner_id
    FROM rangley.vw_friend_groups
    WHERE friend_group_id = p_friend_group_id;
    
    IF v_group_owner_id IS NULL OR v_group_owner_id != v_user_id THEN
        RETURN;
    END IF;
    
    -- Return group members
    RETURN QUERY
    SELECT 
        u.uuid,
        u.username,
        u.display_name,
        fgm.dttm_added_utc
    FROM rangley.vw_friend_group_members fgm
    JOIN rangley.vw_users u ON u.user_id = fgm.user_id
    WHERE fgm.friend_group_id = p_friend_group_id
    ORDER BY u.display_name;
END;
$$;