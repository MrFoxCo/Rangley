-- snake_case Postgres views under schema rangley

DROP VIEW IF EXISTS rangley.vw_meet_category_id_and_name;
DROP VIEW IF EXISTS rangley.vw_meet_card_data;
DROP VIEW IF EXISTS rangley.vw_latest_meet_versions;
DROP VIEW IF EXISTS rangley.vw_version_features;
DROP VIEW IF EXISTS rangley.vw_particpant_status;
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
DROP VIEW IF EXISTS rangley.vw_meet_change_stamps;
DROP VIEW IF EXISTS rangley.vw_meet_coordinates;
DROP VIEW IF EXISTS rangley.vw_meets;

CREATE OR REPLACE VIEW rangley.vw_meets AS 
SELECT
     meet_id
    ,change_stamp
    ,name
    ,description
    ,change_reason
    ,meet_category_id
    ,max_capacity
    ,dttm_start_utc
    ,dttm_end_utc
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

CREATE OR REPLACE VIEW rangley.vw_meet_change_stamps AS
SELECT
     change_stamp
    ,meet_id
    ,meet_status_id
    ,dttm_modified_utc
    ,modified_by_user_id
FROM rangley.tb_meet_change_stamps;

CREATE OR REPLACE VIEW rangley.vw_meet_ids AS
SELECT
     meet_id
    ,meet_coordinate_id
    ,created_by_user_id
    ,dttm_created_utc
FROM rangley.tb_meet_ids;

CREATE OR REPLACE VIEW rangley.vw_users AS
SELECT
     user_id
    ,username
    ,first_name
    ,last_name
    ,cellphone
    ,email
    ,dttm_created_utc
    ,dttm_modified_utc
    ,uid
FROM rangley.tb_users;

CREATE OR REPLACE VIEW rangley.vw_notifications AS
SELECT
     notification_id
    ,notification_type_id
    ,meet_id
    ,user_id
    ,dttm_sent_utc
    ,dttm_opened_utc
    ,uid
FROM rangley.tb_notifications;

CREATE OR REPLACE VIEW rangley.vw_user_inboxes AS
SELECT
     meet_notification_id
    ,dttm_received_utc
    ,dttm_opened_utc
    ,uid
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
    ,uid
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

-- preserving your original spelling "particpant"
CREATE OR REPLACE VIEW rangley.vw_particpant_status AS
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

CREATE OR REPLACE VIEW rangley.vw_latest_meet_versions AS
WITH latest AS (
  SELECT meet_id, MAX(change_stamp) AS change_stamp
  FROM rangley.vw_meets
  GROUP BY meet_id
)
SELECT meet_id, change_stamp
FROM latest;

CREATE OR REPLACE VIEW rangley.vw_meet_card_data AS
SELECT
     m.meet_id
    ,m.change_stamp
    ,COALESCE(mcs.meet_status_id, 0) AS meet_status_id
    ,ma.latitude
    ,ma.longitude
    ,ma.region_latitude
    ,ma.region_longitude
    ,m.dttm_start_utc
    ,m.dttm_end_utc
    ,m.name
    ,mc.name AS category_name
    ,m.description
    ,m.max_capacity
    ,mi.created_by_user_id
    ,u.first_name
    ,u.last_name
FROM rangley.vw_latest_meet_versions l
JOIN rangley.vw_meets m
  ON m.meet_id = l.meet_id
 AND m.change_stamp = l.change_stamp
LEFT JOIN rangley.tb_meet_change_stamps mcs
  ON mcs.meet_id = l.meet_id
 AND mcs.change_stamp = l.change_stamp
JOIN rangley.vw_meet_ids mi
  ON mi.meet_id = l.meet_id
JOIN rangley.vw_meet_coordinates ma
  ON ma.meet_coordinate_id = mi.meet_coordinate_id
JOIN rangley.vw_users u
  ON u.user_id = mi.created_by_user_id
JOIN rangley.vw_meet_category mc
  ON mc.meet_category_id = m.meet_category_id;

CREATE OR REPLACE VIEW rangley.vw_meet_category_id_and_name AS
SELECT meet_category_id, name
FROM rangley.vw_meet_category;
