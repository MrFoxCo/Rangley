-- Only show meets the requester created OR has accepted
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
  SELECT
      u.user_id        AS requester_user_id,
      u.uuid           AS requester_uuid
  FROM rangley.vw_users u
  WHERE u.cognito_sub = p_cognito_sub
)
SELECT
  utdm.meet_id_uuid,
  utdm.meet_status_id,
  utdm.change_stamp,
  utdm.latitude,
  utdm.longitude,
  utdm.region_latitude,
  utdm.region_longitude,
  utdm.region_radius,
  utdm.dttm_start_utc,
  utdm.dttm_end_utc,
  utdm.name,
  utdm.category_name,
  utdm.meet_category_id,
  utdm.description,
  utdm.max_capacity,
  utdm.created_by_user_uuid,
  utdm.display_name,
  (utdm.created_by_user_uuid = me.requester_uuid) AS is_owner
FROM rangley.vw_up_to_date_meets AS utdm
JOIN me
  ON TRUE
LEFT JOIN rangley.tb_meet_participants mp
  ON mp.meet_id = utdm.meet_id
 AND mp.user_id = me.requester_user_id
 AND mp.participant_status_id = 6      -- Accepted
WHERE
      utdm.created_by_user_uuid = me.requester_uuid
   OR mp.participant_id IS NOT NULL;
$$;
