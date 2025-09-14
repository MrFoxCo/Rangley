-- snake_case Postgres views under schema rangley

DROP VIEW IF EXISTS rangley.vw_meet_category_id_and_name;
DROP VIEW IF EXISTS rangley.vw_meets_accessible;
DROP VIEW IF EXISTS rangley.vw_meet_changestamps_desc;
DROP VIEW IF EXISTS rangley.vw_version_features;
DROP VIEW IF EXISTS rangley.vw_participant_status;
DROP VIEW IF EXISTS rangley.vw_meet_status;
DROP VIEW IF EXISTS rangley.vw_features;
DROP VIEW IF EXISTS rangley.vw_meet_category;
DROP VIEW IF EXISTS rangley.vw_sub_category;
DROP VIEW IF EXISTS rangley.vw_notification_type;
DROP VIEW IF EXISTS rangley.vw_meet_icon;
DROP VIEW IF EXISTS rangley.vw_meet_participants;
DROP VIEW IF EXISTS rangley.vw_user_inboxes;
DROP VIEW IF EXISTS rangley.vw_notifications;
DROP VIEW IF EXISTS rangley.vw_users;
DROP VIEW IF EXISTS rangley.vw_meet_ids;
DROP VIEW IF EXISTS rangley.vw_change_stamps;
DROP VIEW IF EXISTS rangley.vw_meet_coordinates;
DROP VIEW IF EXISTS rangley.vw_meets;

CREATE OR REPLACE VIEW rangley.vw_meets AS 
SELECT
     meet_id
    ,change_stamp
    ,meet_coordinate_id
    ,meet_status_id
    ,name
    ,description
    ,change_reason
    ,meet_category_id
    ,max_capacity
    ,dttm_start_utc
    ,dttm_end_utc
    ,uuid
FROM rangley.tb_meets;

CREATE OR REPLACE VIEW rangley.vw_meet_coordinates AS
SELECT
     meet_coordinate_id
    ,latitude
    ,longitude
    ,region_latitude
    ,region_longitude
    ,region_radius
FROM rangley.tb_meet_coordinates;

CREATE OR REPLACE VIEW rangley.vw_change_stamps AS
SELECT
     change_stamp
    ,meet_id
    ,dttm_modified_utc
    ,modified_by_user_id
FROM rangley.tb_change_stamps;

CREATE OR REPLACE VIEW rangley.vw_meet_ids AS
SELECT
     meet_id
    ,created_by_user_id
    ,dttm_created_utc
    ,uuid
FROM rangley.tb_meet_ids;

CREATE OR REPLACE VIEW rangley.vw_users AS
SELECT
     user_id
    ,cognito_sub
    ,username
    ,display_name
    ,first_name
    ,last_name
    ,cellphone
    ,email
    ,dob
    ,dttm_created_utc
    ,dttm_modified_utc
    ,uuid
FROM rangley.tb_users;

CREATE OR REPLACE VIEW rangley.vw_notifications AS
SELECT
     notification_id
    ,notification_type_id
    ,meet_id
    ,created_by_user_id
    ,payload_json
    ,dttm_created_utc
FROM rangley.tb_notifications;

CREATE OR REPLACE VIEW rangley.vw_user_inboxes AS
select
	 user_id
    ,notification_id
    ,dttm_received_utc
    ,dttm_opened_utc
FROM rangley.tb_user_inboxes;

CREATE OR REPLACE VIEW rangley.vw_meet_participants AS
SELECT
     participant_id
    ,meet_id
    ,user_id
    ,participant_status_id
    ,dttm_joined_utc
    ,dttm_left_utc
    ,dttm_created_utc
    ,dttm_modified_utc
FROM rangley.tb_meet_participants;

CREATE OR REPLACE VIEW rangley.vw_meet_icon AS
SELECT 
     meet_icon_id
    ,name
    ,file_type
    ,dttm_created_utc
    ,created_by
    ,dttm_modified_utc
    ,modified_by
FROM rangley.td_meet_icon;

CREATE OR REPLACE VIEW rangley.vw_notification_type AS
SELECT 
     notification_type_id
    ,name
    ,dttm_created_utc
    ,created_by
    ,dttm_modified_utc
    ,modified_by
FROM rangley.td_notification_type;

CREATE OR REPLACE VIEW rangley.vw_sub_category AS
SELECT 
     sub_category_id
    ,meet_category_id
    ,name
    ,created_by
    ,dttm_modified_utc
    ,modified_by
FROM rangley.td_sub_category;

CREATE OR REPLACE VIEW rangley.vw_meet_category AS
SELECT 
     meet_category_id
    ,name
    ,dttm_created_utc
    ,created_by
    ,dttm_modified_utc
    ,modified_by
FROM rangley.td_meet_category;

CREATE OR REPLACE VIEW rangley.vw_features AS
SELECT feature_id, name
FROM rangley.td_features;

CREATE OR REPLACE VIEW rangley.vw_meet_status AS
SELECT 
     meet_status_id
    ,name
    ,dttm_created_utc
    ,created_by
    ,dttm_modified_utc
    ,modified_by
FROM rangley.td_meet_status;


CREATE OR REPLACE VIEW rangley.vw_participant_status AS
SELECT 
     participant_status_id
    ,name
    ,dttm_created_utc
    ,created_by
    ,dttm_modified_utc
    ,modified_by
FROM rangley.td_participant_status;

CREATE OR REPLACE VIEW rangley.vw_version_features AS
SELECT version, feature_id
FROM rangley.te_version_features;

CREATE OR REPLACE VIEW rangley.vw_meet_changestamps_desc AS
SELECT DISTINCT ON (meet_id)
  meet_id,
  change_stamp
FROM rangley.tb_meets
ORDER BY meet_id, change_stamp DESC;


-- this grabs us every single meet that is live?? might be a little
-- overkill
CREATE OR REPLACE VIEW rangley.vw_meets_accessible AS
SELECT
  m.uuid as meet_uuid,
  m.change_stamp,
  COALESCE(m.meet_status_id, 0) AS meet_status_id,
  coord.latitude,
  coord.longitude,
  coord.region_latitude,
  coord.region_longitude,
  coord.region_radius,
  m.dttm_start_utc,
  m.dttm_end_utc,
  m.name,
  cat.name AS category_name,
  m.description,
  m.max_capacity,
  u.uuid as created_by_user_uuid,
  u.display_name
FROM rangley.vw_meet_changestamps_desc mcd
JOIN rangley.tb_meets m
  USING (meet_id, change_stamp)      -- guarantees exact latest row
JOIN rangley.vw_meet_ids mi
  ON mi.meet_id = m.meet_id
JOIN rangley.vw_meet_coordinates coord
  ON coord.meet_coordinate_id = m.meet_coordinate_id
JOIN rangley.vw_users u
  ON u.user_id = mi.created_by_user_id
JOIN rangley.vw_meet_category cat
  ON cat.meet_category_id = m.meet_category_id
WHERE
  -- exclude only the hard states you said you store
  m.meet_status_id IS DISTINCT FROM 2   -- Cancelled
  AND m.meet_status_id IS DISTINCT FROM 3   -- Postponed
  AND m.meet_status_id IS DISTINCT FROM 7   -- Deleted
  AND m.dttm_end_utc >= now();              -- not ended yet

  
CREATE OR REPLACE VIEW rangley.vw_meet_category_id_and_name AS
SELECT meet_category_id, name
FROM rangley.vw_meet_category;
