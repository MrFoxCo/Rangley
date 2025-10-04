-- ============================================
-- ADD FRIENDS TO GROUP (BULK)
-- ============================================
CREATE OR REPLACE FUNCTION rangley.rgl_fn_add_friends_to_group
(
    p_cognito_sub TEXT,
    p_friend_group_id INT8,
    p_friend_uuids UUID[]
)
RETURNS TABLE
(
    success BOOLEAN,
    message TEXT,
    added_count INT4,
    skipped_count INT4
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_user_id INT8;
    v_group_owner_id INT8;
    v_friend_user_id INT8;
    v_friend_uuid UUID;
    v_added_count INT4 := 0;
    v_skipped_count INT4 := 0;
BEGIN
    -- Get user ID
    SELECT user_id INTO v_user_id
    FROM rangley.vw_users
    WHERE cognito_sub = p_cognito_sub;
    
    IF v_user_id IS NULL THEN
        RETURN QUERY SELECT FALSE, 'User not found'::TEXT, 0::INT4, 0::INT4;
        RETURN;
    END IF;
    
    -- Verify group exists and user owns it
    SELECT created_by_user_id INTO v_group_owner_id
    FROM rangley.vw_friend_groups
    WHERE friend_group_id = p_friend_group_id;
    
    IF v_group_owner_id IS NULL THEN
        RETURN QUERY SELECT FALSE, 'Friend group not found'::TEXT, 0::INT4, 0::INT4;
        RETURN;
    END IF;
    
    IF v_group_owner_id != v_user_id THEN
        RETURN QUERY SELECT FALSE, 'You do not own this friend group'::TEXT, 0::INT4, 0::INT4;
        RETURN;
    END IF;
    
    -- Process each friend UUID
    FOREACH v_friend_uuid IN ARRAY p_friend_uuids
    LOOP
        -- Get friend's user_id
        SELECT user_id INTO v_friend_user_id
        FROM rangley.vw_users
        WHERE uuid = v_friend_uuid;
        
        -- Skip if user not found
        IF v_friend_user_id IS NULL THEN
            v_skipped_count := v_skipped_count + 1;
            CONTINUE;
        END IF;
        
        -- Verify they are actually friends
        IF NOT rangley.rgl_fn_are_users_friends(v_user_id, v_friend_user_id) THEN
            v_skipped_count := v_skipped_count + 1;
            CONTINUE;
        END IF;
        
        -- Add to group (skip if already exists)
        INSERT INTO rangley.tb_friend_group_members (friend_group_id, user_id)
        VALUES (p_friend_group_id, v_friend_user_id)
        ON CONFLICT (friend_group_id, user_id) DO NOTHING;
        
        -- Check if insert happened
        IF FOUND THEN
            v_added_count := v_added_count + 1;
        ELSE
            v_skipped_count := v_skipped_count + 1;
        END IF;
    END LOOP;
    
    RETURN QUERY SELECT TRUE, 
                        format('Added %s friend(s), skipped %s', v_added_count, v_skipped_count)::TEXT,
                        v_added_count,
                        v_skipped_count;
    
EXCEPTION
    WHEN OTHERS THEN
        RETURN QUERY SELECT FALSE, ('Error: ' || SQLERRM)::TEXT, 0::INT4, 0::INT4;
END;
$$;