-- ================================================================
-- GET USERS BY SPECIFIC IDENTIFIERS (for direct invites)
-- ================================================================
CREATE OR REPLACE FUNCTION rangley.rangley_fn_find_users_by_contact(
    p_searching_user_id BIGINT,
    p_usernames TEXT[] DEFAULT NULL,
    p_emails TEXT[] DEFAULT NULL,
    p_phones TEXT[] DEFAULT NULL
)
RETURNS TABLE (
    user_uuid UUID,
    username VARCHAR(50),
    display_name VARCHAR(50),
    matched_by TEXT,  -- 'username', 'email', or 'phone'
    can_be_invited BOOLEAN
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    WITH found_users AS (
        -- Search by username
        SELECT 
            u.user_id,
            u.uuid AS user_uuid,
            u.username,
            u.display_name,
            'username'::TEXT AS matched_by,
            COALESCE(ps.discoverable_by_username, TRUE) AS can_invite
        FROM rangley.vw_users u
        LEFT JOIN rangley.tb_user_privacy_settings ps ON ps.user_id = u.user_id
        WHERE 
            p_usernames IS NOT NULL 
            AND LOWER(u.username) = ANY(
                SELECT LOWER(UNNEST(p_usernames))
            )
            AND u.user_id != p_searching_user_id
        
        UNION
        
        -- Search by email (only if user allows)
        SELECT 
            u.user_id,
            u.uuid AS user_uuid,
            u.username,
            u.display_name,
            'email'::TEXT AS matched_by,
            COALESCE(ps.discoverable_by_email, FALSE) AS can_invite
        FROM rangley.vw_users u
        LEFT JOIN rangley.tb_user_privacy_settings ps ON ps.user_id = u.user_id
        WHERE 
            p_emails IS NOT NULL
            AND LOWER(u.email) = ANY(
                SELECT LOWER(UNNEST(p_emails))
            )
            AND u.user_id != p_searching_user_id
            AND COALESCE(ps.discoverable_by_email, FALSE) = TRUE
        
        UNION
        
        -- Search by phone (only if user allows)
        SELECT 
            u.user_id,
            u.uuid AS user_uuid,
            u.username,
            u.display_name,
            'phone'::TEXT AS matched_by,
            COALESCE(ps.discoverable_by_phone, FALSE) AS can_invite
        FROM rangley.vw_users u
        LEFT JOIN rangley.tb_user_privacy_settings ps ON ps.user_id = u.user_id
        WHERE 
            p_phones IS NOT NULL
            AND u.cellphone = ANY(p_phones)
            AND u.user_id != p_searching_user_id
            AND COALESCE(ps.discoverable_by_phone, FALSE) = TRUE
    )
    SELECT 
        fu.user_uuid,
        fu.username,
        fu.display_name,
        fu.matched_by,
        fu.can_invite
    FROM found_users fu;
END;
$$;
