select * from rangley.vw_up_to_date_meets;

select * from rangley.vw_meet_ids;

select * from rangley.vw_users;

select * from rangley.vw_meets;

select * from rangley.vw_participant_status;

select * from rangley.vw_notification_type;

select * from rangley.vw_meet_status;


select * from rangley.vw_user_inboxes where user_id = 2;


UPDATE rangley.tb_users
SET dob = DATE '1968-02-19',
    dttm_modified_utc = NOW()
WHERE user_id = 21;


select * from rangley.tb_content_violations;

SELECT dob::text FROM rangley.tb_users WHERE username = 'anthonyguzzardo';




delete from rangley.tb_users where user_id in (9);


SELECT 
    dob,
    encode(dob::text::bytea, 'hex') as hex_bytes,
    length(dob::text) as length
FROM rangley.vw_users 
WHERE user_id = 36;



select user_id, display_name, dob from rangley.vw_users order by dttm_created_utc desc;


