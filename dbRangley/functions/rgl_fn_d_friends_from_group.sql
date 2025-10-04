-- ============================================
-- REMOVE FRIENDS FROM GROUP (BULK)
-- ============================================
CREATE OR REPLACE FUNCTION rangley.rgl_fn_d_friends_from_group
(
    p_cognito_sub TEXT,
    p_friend_group_id INT8,
    p_friend_uuids UUID[]
)
RETURNS TABLE
(
    success BOOLEAN,
    message TEXT,
    removed_count INT4
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_user_id INT8;
    v_group_owner_id INT8;
    v_removed_count INT4;
BEGIN
    -- Get user ID
    SELECT user_id INTO v_user_id
    FROM rangley.vw_users
    WHERE cognito_sub = p_cognito_sub;
    
    IF v_user_id IS NULL THEN
        RETURN QUERY SELECT FALSE, 'User not found'::TEXT, 0::INT4;
        RETURN;
    END IF;
    
    -- Verify group exists and user owns it
    SELECT created_by_user_id INTO v_group_owner_id
    FROM rangley.vw_friend_groups
    WHERE friend_group_id = p_friend_group_id;
    
    IF v_group_owner_id IS NULL THEN
        RETURN QUERY SELECT FALSE, 'Friend group not found'::TEXT, 0::INT4;
        RETURN;
    END IF;
    
    IF v_group_owner_id != v_user_id THEN
        RETURN QUERY SELECT FALSE, 'You do not own this friend group'::TEXT, 0::INT4;
        RETURN;
    END IF;
    
    -- Remove friends from group
    DELETE FROM rangley.tb_friend_group_members
    WHERE friend_group_id = p_friend_group_id
    AND user_id IN (
        SELECT user_id 
        FROM rangley.vw_users 
        WHERE uuid = ANY(p_friend_uuids)
    );
    
    GET DIAGNOSTICS v_removed_count = ROW_COUNT;
    
    RETURN QUERY SELECT TRUE, 
                        format('Removed %s friend(s) from group', v_removed_count)::TEXT,
                        v_removed_count;
    
EXCEPTION
    WHEN OTHERS THEN
        RETURN QUERY SELECT FALSE, ('Error: ' || SQLERRM)::TEXT, 0::INT4;
END;
$$;
