-- ============================================
-- LIST USER'S MEET GROUPS (WITH MEMBER COUNT)
-- ============================================
CREATE OR REPLACE FUNCTION rangley.rgl_fn_v_meet_groups
(
    p_cognito_sub TEXT
)
RETURNS TABLE
(
    meet_group_id INT8,
    name VARCHAR(50),
    member_count INT8,
    dttm_created_utc TIMESTAMPTZ,
    dttm_modified_utc TIMESTAMPTZ
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_user_id INT8;
BEGIN
    -- Get user ID
    SELECT user_id INTO v_user_id
    FROM rangley.vw_users
    WHERE cognito_sub = p_cognito_sub;

    IF v_user_id IS NULL THEN
        RETURN;
    END IF;

    -- Return groups with member counts
    RETURN QUERY
    SELECT
        mg.meet_group_id,
        mg.name,
        COALESCE(COUNT(mgm.user_id), 0) AS member_count,
        mg.dttm_created_utc,
        mg.dttm_modified_utc
    FROM rangley.vw_meet_groups mg
    LEFT JOIN rangley.vw_meet_group_members mgm
        ON mgm.meet_group_id = mg.meet_group_id
    WHERE mg.created_by_user_id = v_user_id -- Groups they created
       OR EXISTS ( -- OR groups they're a member of
            SELECT 1
            FROM rangley.vw_meet_group_members m
            WHERE m.meet_group_id = mg.meet_group_id
              AND m.user_id = v_user_id
        )
    GROUP BY mg.meet_group_id, mg.name, mg.dttm_created_utc, mg.dttm_modified_utc
    ORDER BY mg.name;
END;
$$;