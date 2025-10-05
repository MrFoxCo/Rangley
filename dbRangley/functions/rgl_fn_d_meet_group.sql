-- ============================================
-- DELETE MEET GROUP
-- ============================================
CREATE OR REPLACE FUNCTION rangley.rgl_fn_d_meet_group
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

    -- Verify group exists and user owns it
    SELECT created_by_user_id INTO v_group_owner_id
    FROM rangley.vw_meet_groups
    WHERE meet_group_id = p_meet_group_id;

    IF v_group_owner_id IS NULL THEN
        RETURN QUERY SELECT FALSE, 'Meet group not found'::TEXT;
        RETURN;
    END IF;

    IF v_group_owner_id != v_user_id THEN
        RETURN QUERY SELECT FALSE, 'You do not own this meet group'::TEXT;
        RETURN;
    END IF;

    -- Delete members first (due to FK)
    DELETE FROM rangley.tb_meet_group_members
    WHERE meet_group_id = p_meet_group_id;

    -- Delete the group
    DELETE FROM rangley.tb_meet_groups
    WHERE meet_group_id = p_meet_group_id;

    RETURN QUERY SELECT TRUE, 'Meet group deleted successfully'::TEXT;

EXCEPTION
    WHEN OTHERS THEN
        RETURN QUERY SELECT FALSE, ('Error: ' || SQLERRM)::TEXT;
END;
$$;
