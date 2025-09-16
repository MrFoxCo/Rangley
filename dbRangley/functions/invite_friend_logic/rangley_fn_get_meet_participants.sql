-- ================================================================
-- GET MEET PARTICIPANTS WITH STATUS
-- ================================================================
CREATE OR REPLACE FUNCTION rangley.rangley_fn_get_meet_participants(
    p_meet_id BIGINT
)
RETURNS TABLE (
    user_id BIGINT,
    user_uuid UUID,
    username VARCHAR(50),
    display_name VARCHAR(50),
    status_name VARCHAR(50),
    joined_date TIMESTAMPTZ
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.user_id,
        u.uuid AS user_uuid,
        u.username,
        u.display_name,
        ps.name AS status_name,
        mp.dttm_joined_utc AS joined_date
    FROM rangley.vw_meet_participants mp
    JOIN rangley.vw_users u ON u.user_id = mp.user_id
    JOIN rangley.vw_participant_status ps ON ps.participant_status_id = mp.participant_status_id
    WHERE mp.meet_id = p_meet_id
    AND mp.participant_status_id NOT IN (3, 6, 7) -- exclude declined, left, removed
    ORDER BY 
        CASE mp.participant_status_id 
            WHEN 5 THEN 1 -- host first
            WHEN 2 THEN 2 -- accepted
            WHEN 4 THEN 3 -- maybe
            WHEN 1 THEN 4 -- invited
            ELSE 5
        END,
        mp.dttm_joined_utc;
END;
$$;