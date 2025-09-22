-- Only show meets the requester created OR is a current participant in
CREATE OR REPLACE FUNCTION rangley.rangley_fn_v_meets_by_cognito_sub(p_cognito_sub text)
RETURNS TABLE
(
   meet_id_uuid           uuid,
   meet_status_id         int2,
   change_stamp           int8,
   latitude               float8,
   longitude              float8,
   region_latitude        float8,
   region_longitude       float8,
   region_radius          float8,
   dttm_start_utc         timestamptz,
   dttm_end_utc           timestamptz,
   name                   varchar(50),
   category_name          varchar(50),
   meet_category_id       int2,
   description            varchar(50),
   max_capacity           int4,
   created_by_user_uuid   uuid,
   display_name           varchar(50),
   is_owner               boolean
)
LANGUAGE sql
STABLE
AS $$
WITH me AS (
  SELECT u.user_id AS requester_user_id,
         u.uuid    AS requester_uuid
  FROM rangley.vw_users u
  WHERE u.cognito_sub = p_cognito_sub
)
SELECT
   v.meet_id_uuid,
   v.meet_status_id,
   v.change_stamp,
   v.latitude,
   v.longitude,
   v.region_latitude,
   v.region_longitude,
   v.region_radius,
   v.dttm_start_utc,
   v.dttm_end_utc,
   v.name,
   v.category_name,
   v.meet_category_id,
   v.description,
   v.max_capacity,
   v.created_by_user_uuid,
   v.display_name,
   --  owner ONLY if your participant row is status 7
   EXISTS (
     SELECT 1
     FROM rangley.tb_meet_participants mp
     WHERE mp.meet_id = v.meet_id
       AND mp.user_id = me.requester_user_id
       AND mp.participant_status_id = 7
   ) AS is_owner
FROM rangley.vw_up_to_date_meets v
JOIN me ON TRUE
WHERE
      -- include meets you created
      v.created_by_user_uuid = me.requester_uuid
   -- or meets you’re currently participating in
   OR EXISTS (
        SELECT 1
        FROM rangley.tb_meet_participants mp
        WHERE mp.meet_id = v.meet_id
          AND mp.user_id = me.requester_user_id
          AND mp.participant_status_id IN (1,3,6,7)
   );
$$;
