


select cognito_sub from rangley.vw_users where user_id = 2;

select display_name, cognito_sub from rangley.vw_users;

select * from rangley.vw_notification_type;

select * from rangley.vw_meet_category;

delete from rangley.vw_meet_category;

select * from rangley.vw_up_to_date_meets;

select * from rangley.td_participant_status;
select * from rangley.td_meet_status;
select * from rangley.vw_notification_type;

select 
* from rangley.vw_users;

select * from rangley.tb_content_violations;


-- Verify meets are marked as deleted (status_id = 7)
SELECT m.meet_id, m.name, m.meet_status_id, m.change_reason
FROM rangley.vw_meets m 
JOIN rangley.vw_meet_ids mi ON mi.meet_id = m.meet_id
JOIN rangley.vw_meet_change_stamps_desc mcsd ON mcsd.meet_id = m.meet_id AND mcsd.change_stamp = m.change_stamp
WHERE mi.created_by_user_id = 5;

-- Verify user is completely gone
SELECT COUNT(*) FROM rangley.tb_users WHERE user_id = 5;

-- Check if any orphaned data remains
SELECT COUNT(*) FROM rangley.tb_meet_participants WHERE user_id = 5;
SELECT COUNT(*) FROM rangley.tb_user_inboxes WHERE user_id = 5;



/*


select * from rangley.rangley_fn_vw_meet_participants(16);

	
*/

select
	 mp.participant_id 
	,mp.meet_id 
	,mp.user_id 
	,u.uuid
	,mp.participant_status_id 
from rangley.vw_meet_participants mp
join rangley.vw_users u on u.user_id = mp.user_id;

select * from rangley.vw_notifications;

select * from rangley.vw_user_inboxes;

SELECT
    u.display_name                AS recipient_name,
        c.display_name                AS creator_name,
    ui.notification_id,
    nt.name                       AS notification_name,
    n.notification_type_id,
    n.meet_id
FROM rangley.vw_user_inboxes      AS ui
JOIN rangley.vw_notifications     AS n  ON n.notification_id = ui.notification_id
JOIN rangley.vw_notification_type AS nt ON nt.notification_type_id = n.notification_type_id
JOIN rangley.vw_users             AS u  ON u.user_id = ui.user_id
LEFT JOIN rangley.vw_users        AS c  ON c.user_id = n.created_by_user_id;


select
	m.name
from rangley.vw_up_to_date_meets um
join rangley.vw_meets m on
	m.meet_id = um.meet_id
and m.change_stamp = um.change_stamp;


select
	 m.meet_id
	,mi.created_by_user_id
	,m.name
	,u.display_name
from rangley.vw_meets m
join rangley.vw_meet_ids mi on
	mi.meet_id = m.meet_id
join rangley.vw_users u on
	u.user_id = mi.created_by_user_id;

delete from rangley.tb_users u where u.user_id between 40 and 467;


EXPLAIN (ANALYZE, BUFFERS)
SELECT 1
FROM rangley.tb_meet_participants mp
WHERE mp.meet_id = $1 AND mp.user_id = $2;


EXPLAIN (ANALYZE, BUFFERS)
SELECT COUNT(*) FROM rangley.tb_meet_participants
WHERE meet_id = $1 AND participant_status_id IN (6,7);


*/