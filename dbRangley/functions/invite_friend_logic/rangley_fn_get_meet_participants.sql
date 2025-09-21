-- ================================================================
-- GET MEET PARTICIPANTS WITH STATUS
-- ================================================================
CREATE OR REPLACE FUNCTION rangley.rangley_fn_v_meet_participants
(
    p_meet_id BIGINT
)
RETURNS TABLE (
     user_id 		BIGINT
    ,user_uuid 		UUID
    ,username 		VARCHAR(50)
    ,display_name 	VARCHAR(50)
    ,status_name 	VARCHAR(50)
    ,joined_date 	TIMESTAMPTZ
)
LANGUAGE plpgsql
AS $$

/*

1	Attending
2	Not Attending
3	Maybe
4	Invited
5	Declined
6	Accepted
7	Owner
8	Left
9	Removed


1	Meet Created
2	Meet Updated
3	Meet Cancelled
4	New Attendee
5	Attendee Left
6	Meet Reminder
7	System Alert
8	Meet Invitation Received
9	Meet Invitation Accepted
10	Meet Invitation Declined
11	Meet Invitation Expired
12	Meet Full
13	Meet Role Changed
14	Meet Location Changed

select * from rangley.rangley_fn_v_meet_participants(16);


*/

DECLARE

v_declined_id 	int2 := 5;
v_left_id 		int2 := 8;
v_removed_id   int2 := 9;


BEGIN
    RETURN QUERY
    SELECT 
         u.user_id
        ,u.uuid 				AS user_uuid
        ,u.username
		,u.display_name
        ,ps.name 				AS status_name
        ,mp.dttm_invited_utc 	AS invited_date
    FROM rangley.vw_meet_participants mp
    JOIN rangley.vw_users u ON 
		u.user_id = mp.user_id
    JOIN rangley.vw_participant_status ps 
		ON ps.participant_status_id = mp.participant_status_id
    WHERE mp.meet_id = p_meet_id
	 -- exclude declined, left, removed
    AND mp.participant_status_id NOT IN (v_declined_id, v_left_id, v_removed_id)
    ORDER BY 
        CASE mp.participant_status_id 
            WHEN 7 THEN 1 -- Owner First
            WHEN 6 THEN 2 -- accepted
            WHEN 4 THEN 3 -- maybe
            WHEN 4 THEN 4 -- invited
            ELSE 5
        END,
        mp.dttm_invited_utc;
END;
$$;




