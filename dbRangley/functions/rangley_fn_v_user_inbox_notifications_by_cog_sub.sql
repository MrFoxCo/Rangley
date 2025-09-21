-- ================================================================
-- GET MEET NOTIFICATIONS FOR USER INBOX
-- ================================================================
CREATE OR REPLACE FUNCTION rangley.rangley_fn_v_user_inbox_notifications_by_cog_sub
(
	 p_cognito_sub text
)
RETURNS TABLE 
(
	 notification_id BIGINT
	,notification_type_id INT2
	,notification_name VARCHAR(50)
	,meet_id BIGINT
	,created_by_user_id BIGINT
	,creator_display_name VARCHAR(50)
	,payload_json JSONB
	,dttm_notification_created_utc TIMESTAMPTZ
	,dttm_received_utc TIMESTAMPTZ
	,dttm_opened_utc TIMESTAMPTZ
	,is_read BOOLEAN
)
LANGUAGE plpgsql
AS $$
/*


TRUNCATE TABLE rangley.tb_notifications RESTART IDENTITY CASCADE;
TRUNCATE TABLE rangley.tb_user_inboxes RESTART IDENTITY CASCADE;
TRUNCATE TABLE rangley.tb_meet_participants RESTART IDENTITY CASCADE;

PARTICIPANT STATUSES:   NOTIFICATION TYPES:
1 Attending             1 Meet Created
2 Not Attending         2 Meet Updated
3 Maybe                 3 Meet Cancelled
4 Invited               4 New Attendee
5 Declined              5 Attendee Left
6 Accepted              6 Meet Reminder
7 Owner                 7 System Alert
8 Left                  8 Meet Invitation Received
9 Removed               9 Meet Invitation Accepted
                        10 Meet Invitation Declined
                        11 Meet Invitation Expired
                        12 Meet Full
                        13 Meet Role Changed
                        14 Meet Location Changed

select * 
from rangley.rangley_fn_v_user_inbox_notifications_by_cog_sub
('a11b5510-2051-703c-eb7b-34ff537736ce');

select * 
from rangley.rangley_fn_v_user_inbox_notifications_by_cog_sub
('01cb4500-90e1-709c-decd-a64858d1de8d');


*/
BEGIN

RETURN QUERY
SELECT
    n.notification_id,
    n.notification_type_id,
    nt.name AS notification_name,
    n.meet_id,
    n.created_by_user_id,
    creator.display_name AS creator_display_name,
    n.payload_json,
    n.dttm_created_utc AS dttm_notification_created_utc,
    ui.dttm_received_utc,
    ui.dttm_opened_utc,
    (ui.dttm_opened_utc IS NOT NULL) AS is_read
FROM rangley.vw_user_inboxes ui
JOIN rangley.vw_notifications n ON
	n.notification_id = ui.notification_id
JOIN rangley.vw_notification_type nt ON 
	nt.notification_type_id = n.notification_type_id
JOIN rangley.vw_users recipient ON 
	recipient.user_id = ui.user_id  -- JOIN to get recipient
LEFT JOIN rangley.vw_users creator ON 
	creator.user_id = n.created_by_user_id  -- LEFT JOIN to get creator
WHERE recipient.cognito_sub = p_cognito_sub  -- Filter by RECIPIENT's cognito_sub
ORDER BY ui.dttm_received_utc DESC;

END;
$$;









