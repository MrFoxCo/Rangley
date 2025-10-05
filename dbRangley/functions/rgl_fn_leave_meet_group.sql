-- ============================================
-- LEAVE MEET GROUP
-- ============================================
CREATE OR REPLACE FUNCTION rangley.rgl_fn_leave_meet_group
(
    p_cognito_sub TEXT,
    p_meet_group_id INT8
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
    v_group_owner_id INT8;
BEGIN
    -- Get user ID
    SELECT user_id INTO v_user_id
    FROM rangley.vw_users
    WHERE cognito_sub = p_cognito_sub;

    IF v_user_id IS NULL THEN
        RETURN QUERY SELECT FALSE, 'User not found'::TEXT;
        RETURN;
    END IF;

    -- Get group owner
    SELECT created_by_user_id INTO v_group_owner_id
    FROM rangley.vw_meet_groups
    WHERE meet_group_id = p_meet_group_id;

    IF v_group_owner_id IS NULL THEN
        RETURN QUERY SELECT FALSE, 'Group not found'::TEXT;
        RETURN;
    END IF;

    -- Prevent owner from leaving
    IF v_group_owner_id = v_user_id THEN
        RETURN QUERY SELECT FALSE, 'Group owner cannot leave. Delete the group instead.'::TEXT;
        RETURN;
    END IF;

    -- Remove user from group
    DELETE FROM rangley.tb_meet_group_members
    WHERE meet_group_id = p_meet_group_id
    AND user_id = v_user_id;

    IF NOT FOUND THEN
        RETURN QUERY SELECT FALSE, 'You are not a member of this group'::TEXT;
        RETURN;
    END IF;

    RETURN QUERY SELECT TRUE, 'Successfully left the group'::TEXT;

EXCEPTION
    WHEN OTHERS THEN
        RETURN QUERY SELECT FALSE, ('Error: ' || SQLERRM)::TEXT;
END;
$$;