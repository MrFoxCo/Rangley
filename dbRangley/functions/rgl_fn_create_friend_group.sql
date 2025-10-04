-- ============================================
-- CREATE FRIEND GROUP
-- ============================================
CREATE OR REPLACE FUNCTION rangley.rgl_fn_create_friend_group
(
    p_cognito_sub TEXT,
    p_group_name TEXT
)
RETURNS TABLE
(
    success BOOLEAN,
    message TEXT,
    friend_group_id INT8
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_user_id INT8;
    v_friend_group_id INT8;
BEGIN
    -- Get user ID
    SELECT user_id INTO v_user_id
    FROM rangley.vw_users
    WHERE cognito_sub = p_cognito_sub;
    
    IF v_user_id IS NULL THEN
        RETURN QUERY SELECT FALSE, 'User not found'::TEXT, NULL::INT8;
        RETURN;
    END IF;
    
    -- Validate group name
    IF p_group_name IS NULL OR trim(p_group_name) = '' THEN
        RETURN QUERY SELECT FALSE, 'Group name cannot be empty'::TEXT, NULL::INT8;
        RETURN;
    END IF;
    
    IF length(trim(p_group_name)) > 50 THEN
        RETURN QUERY SELECT FALSE, 'Group name too long (max 50 characters)'::TEXT, NULL::INT8;
        RETURN;
    END IF;
    
    -- Check for duplicate group name
    IF EXISTS (
        SELECT 1 FROM rangley.vw_friend_groups
        WHERE created_by_user_id = v_user_id
        AND lower(name) = lower(trim(p_group_name))
    ) THEN
        RETURN QUERY SELECT FALSE, 'You already have a group with this name'::TEXT, NULL::INT8;
        RETURN;
    END IF;
    
    -- Create the group
    INSERT INTO rangley.tb_friend_groups (created_by_user_id, name)
    VALUES (v_user_id, trim(p_group_name))
    RETURNING rangley.tb_friend_groups.friend_group_id INTO v_friend_group_id;
    
    RETURN QUERY SELECT TRUE, 'Friend group created successfully'::TEXT, v_friend_group_id;
    
EXCEPTION
    WHEN OTHERS THEN
        RETURN QUERY SELECT FALSE, ('Error: ' || SQLERRM)::TEXT, NULL::INT8;
END;
$$;
