select u.name, us.display_name  from rangley.vw_up_to_date_meets u
join rangley.vw_meet_ids mi on mi.meet_id = u.meet_id 
join rangley.vw_users us on us.user_id = mi.created_by_user_id ;


select * from rangley.te_version_features;


INSERT INTO rangley.td_features (feature_id, name) VALUES (13, 'meet groups');
INSERT INTO rangley.te_version_features (version, feature_id) VALUES (20000, 13);

INSERT INTO rangley.td_versions (version, status_id) VALUES (20001, 2);


select * from rangley.te_version_statuses;

select * from rangley.td_features;
select * from rangley.td_versions;

UPDATE rangley.td_versions 
SET dttm_created_utc = '2025-09-01'::TIMESTAMPTZ 
WHERE version = 10000;


select * from rangley.vw_meet_ids;

select * from rangley.vw_users;


select * from rangley.vw_meets;

select * from rangley.vw_up_to_date_meets;

select * from rangley.vw_participant_status;

select * from rangley.td_meet_category;

select * from rangley.vw_notification_type;

select * from rangley.vw_meet_status;

select * from rangley.vw_stock_assets;

select * from rangley.td_violation_categories;

select * from rangley.tb_content_violations;


select * from rangley.vw_user_inboxes where user_id  in (2,4);

select * from rangley.vw_user_inboxes where user_id  in (4);

select * from rangley.vw_notifications where created_by_user_id in (2,4) order by dttm_created_utc desc;


select * from rangley.vw_friend_requests;

select * FROM rangley.vw_friend_request_status;

select * FROM rangley.vw_meet_group_members;

select * FROM rangley.vw_meet_groups;

SELECT COUNT(DISTINCT m.meet_id)
FROM rangley.vw_meets m
JOIN rangley.vw_meet_ids vm ON vm.meet_id = m.meet_id
JOIN rangley.vw_users us     ON us.user_id = vm.created_by_user_id
WHERE us.user_id = 2;


select * from rangley.vw_meet_ids;

UPDATE rangley.tb_users
SET dob = DATE '1969-12-31',
    dttm_modified_utc = NOW()
WHERE user_id = 25;



select 
	 user_id
	,display_name, username
	,dttm_created_utc AT TIME ZONE 'America/Chicago'
	,dob ,cellphone
from rangley.vw_users
where user_id > 15 
order by dttm_created_utc desc;


/*
 
 I'll help you create this movie meet! Since

you've given me flexibility on the theater and

time, I'll set it for a typical evening showtime at

7:00 PM local time (which converts to UTC).

The movie runtime is approximately 2 hours.
 
 * */
select * from rangley.tb_content_violations;
select * from rangley.td_violation_categories;


select * from rangley.vw_up_to_date_meets;

select * from rangley.vw_meet_ids where meet_id = 426;
select * from rangley.vw_meets where meet_id = 426;
select * from rangley.vw_meet_coordinates where meet_coordinate_id = 440;
