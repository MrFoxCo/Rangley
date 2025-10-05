-- ============================================
-- LIST USER'S FRIEND GROUPS (WITH MEMBER COUNT)
-- ============================================
CREATE OR REPLACE FUNCTION rangley.rgl_fn_v_friend_groups
(
    p_cognito_sub TEXT
)
RETURNS TABLE
(
    friend_group_id INT8,
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
        fg.friend_group_id,
        fg.name,
        COALESCE(COUNT(fgm.user_id), 0) AS member_count,
        fg.dttm_created_utc,
        fg.dttm_modified_utc
    FROM rangley.vw_friend_groups fg
    LEFT JOIN rangley.vw_friend_group_members fgm 
        ON fgm.friend_group_id = fg.friend_group_id
	WHERE fg.created_by_user_id = v_user_id  -- Groups they created
	   OR EXISTS (  -- OR groups they're a member of
	        SELECT 1 
	        FROM rangley.vw_friend_group_members m
	        WHERE m.friend_group_id = fg.friend_group_id
	          AND m.user_id = v_user_id
	    )
    GROUP BY fg.friend_group_id, fg.name, fg.dttm_created_utc, fg.dttm_modified_utc
    ORDER BY fg.name;
END;
$$;
