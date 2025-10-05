select * from rangley.vw_up_to_date_meets;

select * from rangley.vw_meet_ids;

select * from rangley.vw_users;

select * from rangley.vw_meets;

select * from rangley.vw_participant_status;

select * from rangley.vw_notification_type;

select * from rangley.vw_meet_status;

select * from rangley.vw_stock_assets;


select * from rangley.vw_user_inboxes where user_id = 2;

select * from rangley.vw_notifications;`

select * from rangley.vw_friend_requests;

select * FROM rangley.vw_friend_request_status;

select * FROM rangley.vw_meet_group_members;

select * FROM rangley.vw_meet_groups;



delete FROM rangley.vw_meet_group_members;


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



DELETE FROM rangley.tb_user_inboxes ui
WHERE ui.notification_id IN (
    SELECT n.notification_id
    FROM rangley.tb_notifications n
    JOIN rangley.tb_meet_participants mp 
        ON mp.meet_id = n.meet_id 
        AND mp.user_id = ui.user_id
    WHERE n.notification_type_id = 8  -- Meet Invitation Received
      AND mp.participant_status_id IN (5, 6, 8, 9)  -- Declined, Accepted, Left, Removed
);


-- Delete all friend requests (both directions) for users you're currently friends with
DELETE FROM rangley.tb_friend_requests fr
WHERE EXISTS (
    SELECT 1 FROM rangley.tb_friendships f
    WHERE (f.user_id_a = fr.requester_user_id AND f.user_id_b = fr.recipient_user_id)
       OR (f.user_id_a = fr.recipient_user_id AND f.user_id_b = fr.requester_user_id)
);



