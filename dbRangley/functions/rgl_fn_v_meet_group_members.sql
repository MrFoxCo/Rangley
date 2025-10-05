-- ============================================
-- GET MEET GROUP MEMBERS (UPDATED)
-- ============================================
-- GET MEET GROUP MEMBERS (UPDATED WITH OWNER FLAG)
CREATE OR REPLACE FUNCTION rangley.rgl_fn_v_meet_group_members
(
    p_cognito_sub TEXT,
    p_meet_group_id INT8
)
RETURNS TABLE
(
    user_uuid UUID,
    username VARCHAR(50),
    display_name VARCHAR(50),
    dttm_added_utc TIMESTAMPTZ,
    is_owner BOOLEAN
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_user_id INT8;
BEGIN
    SELECT user_id INTO v_user_id
    FROM rangley.vw_users
    WHERE cognito_sub = p_cognito_sub;

    IF v_user_id IS NULL THEN
        RETURN;
    END IF;

    -- Verify user is a member of the group
    IF NOT EXISTS (
        SELECT 1 
        FROM rangley.tb_meet_group_members
        WHERE meet_group_id = p_meet_group_id
        AND user_id = v_user_id
    ) THEN
        RETURN;
    END IF;

    -- Return group members with owner flag
    RETURN QUERY
    SELECT
        u.uuid,
        u.username,
        u.display_name,
        mgm.dttm_added_utc,
        (mg.created_by_user_id = mgm.user_id) AS is_owner
    FROM rangley.vw_meet_group_members mgm
    JOIN rangley.vw_users u ON u.user_id = mgm.user_id
    JOIN rangley.vw_meet_groups mg ON mg.meet_group_id = mgm.meet_group_id
    WHERE mgm.meet_group_id = p_meet_group_id
    ORDER BY (mg.created_by_user_id = mgm.user_id) DESC, u.display_name;  -- Owner first
END;
$$;