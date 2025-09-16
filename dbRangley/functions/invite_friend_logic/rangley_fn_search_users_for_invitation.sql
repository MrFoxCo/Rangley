-- ================================================================
-- SEARCH USERS FOR INVITATION (Privacy-Aware)
-- ================================================================
CREATE OR REPLACE FUNCTION rangley.rangley_fn_search_users_for_invitation(
    p_searching_user_id BIGINT,
    p_search_term TEXT DEFAULT NULL,
    p_meet_id BIGINT DEFAULT NULL,  -- Optional: exclude already invited users
    p_limit INT DEFAULT 20,
    p_offset INT DEFAULT 0
)
RETURNS TABLE (
    user_uuid UUID,
    username VARCHAR(50),
    display_name VARCHAR(50),
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    is_already_participant BOOLEAN,
    participant_status VARCHAR(50)
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Sanitize search term
    p_search_term := LOWER(TRIM(COALESCE(p_search_term, '')));
    
    RETURN QUERY
    WITH user_search AS (
        SELECT 
            u.user_id,
            u.uuid AS user_uuid,
            u.username,
            u.display_name,
            CASE 
                WHEN COALESCE(ps.show_full_name, FALSE) THEN u.first_name 
                ELSE NULL 
            END AS first_name,
            CASE 
                WHEN COALESCE(ps.show_full_name, FALSE) THEN u.last_name 
                ELSE NULL 
            END AS last_name,
            COALESCE(ps.discoverable_by_username, TRUE) AS discoverable
        FROM rangley.vw_users u
        LEFT JOIN rangley.tb_user_privacy_settings ps ON ps.user_id = u.user_id
        WHERE 
            u.user_id != p_searching_user_id  -- Don't show self
            AND (
                p_search_term = '' 
                OR LOWER(u.username) LIKE '%' || p_search_term || '%'
                OR LOWER(u.display_name) LIKE '%' || p_search_term || '%'
                -- Only search by real names if they've allowed it
                OR (COALESCE(ps.show_full_name, FALSE) 
                    AND (LOWER(u.first_name) LIKE '%' || p_search_term || '%'
                         OR LOWER(u.last_name) LIKE '%' || p_search_term || '%'))
            )
    ),
    participant_info AS (
        SELECT 
            mp.user_id,
            mp.participant_status_id,
            ps.name AS status_name
        FROM rangley.vw_meet_participants mp
        JOIN rangley.vw_participant_status ps ON ps.participant_status_id = mp.participant_status_id
        WHERE mp.meet_id = p_meet_id
    )
    SELECT 
        us.user_uuid,
        us.username,
        us.display_name,
        us.first_name,
        us.last_name,
        (pi.user_id IS NOT NULL) AS is_already_participant,
        pi.status_name AS participant_status
    FROM user_search us
    LEFT JOIN participant_info pi ON pi.user_id = us.user_id
    WHERE us.discoverable = TRUE
    ORDER BY 
        -- Prioritize exact username matches
        CASE WHEN LOWER(us.username) = p_search_term THEN 0 ELSE 1 END,
        -- Then partial matches
        us.username
    LIMIT p_limit
    OFFSET p_offset;
END;
$$;