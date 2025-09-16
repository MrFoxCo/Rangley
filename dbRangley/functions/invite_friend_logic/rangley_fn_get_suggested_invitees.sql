-- ================================================================
-- GET SUGGESTED USERS (friends, recent meet participants, etc.)
-- ================================================================
CREATE OR REPLACE FUNCTION rangley.rangley_fn_get_suggested_invitees(
    p_user_id BIGINT,
    p_meet_id BIGINT DEFAULT NULL,
    p_limit INT DEFAULT 10
)
RETURNS TABLE (
    user_uuid UUID,
    username VARCHAR(50),
    display_name VARCHAR(50),
    suggestion_reason TEXT,
    mutual_meets_count INT
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    WITH recent_coparticipants AS (
        -- People you've been in meets with recently
        SELECT 
            mp2.user_id,
            COUNT(DISTINCT mp2.meet_id) AS shared_meets
        FROM rangley.vw_meet_participants mp1
        JOIN rangley.vw_meet_participants mp2 ON mp2.meet_id = mp1.meet_id
        WHERE 
            mp1.user_id = p_user_id
            AND mp2.user_id != p_user_id
            AND mp1.participant_status_id IN (2, 5) -- accepted or host
            AND mp2.participant_status_id IN (2, 5)
        GROUP BY mp2.user_id
    ),
    excluded_users AS (
        -- Users already in this specific meet
        SELECT user_id 
        FROM rangley.vw_meet_participants
        WHERE meet_id = p_meet_id
    )
    SELECT 
        u.uuid AS user_uuid,
        u.username,
        u.display_name,
        'Attended ' || rc.shared_meets || ' meets together' AS suggestion_reason,
        rc.shared_meets::INT AS mutual_meets_count
    FROM recent_coparticipants rc
    JOIN rangley.vw_users u ON u.user_id = rc.user_id
    LEFT JOIN rangley.tb_user_privacy_settings ps ON ps.user_id = u.user_id
    WHERE 
        rc.user_id NOT IN (SELECT user_id FROM excluded_users WHERE user_id IS NOT NULL)
        AND COALESCE(ps.discoverable_by_username, TRUE) = TRUE
    ORDER BY rc.shared_meets DESC
    LIMIT p_limit;
END;
$$;