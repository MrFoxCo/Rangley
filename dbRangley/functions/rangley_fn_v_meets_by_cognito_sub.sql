CREATE OR REPLACE FUNCTION rangley.rangley_fn_v_meets_by_cognito_sub(p_cognito_sub text)
RETURNS TABLE
(
  meet_id_uuid uuid,
  meet_status_id int2,
  change_stamp int8,
  latitude float8,
  longitude float8,
  region_latitude float8,
  region_longitude float8,
  region_radius float8,
  dttm_start_utc timestamptz,
  dttm_end_utc timestamptz,
  name varchar(50),
  category_name varchar(50),
  meet_category_id int2,
  description varchar(50),
  max_capacity int4,
  created_by_user_uuid uuid,
  display_name varchar(50),
  is_owner boolean,
  participant_details json,   -- stays json to match your signature
  accepted_count int4
)
LANGUAGE sql
STABLE
AS $$
WITH me AS (
  SELECT u.user_id AS requester_user_id, u.uuid AS requester_uuid
  FROM rangley.vw_users u
  WHERE u.cognito_sub = p_cognito_sub
),
base AS (
  SELECT v.*, me.requester_user_id, me.requester_uuid
  FROM rangley.vw_up_to_date_meets v
  JOIN me ON TRUE
  WHERE
        v.created_by_user_uuid = me.requester_uuid
     OR EXISTS (
          SELECT 1
          FROM rangley.tb_meet_participants mp
          WHERE mp.meet_id = v.meet_id
            AND mp.user_id = me.requester_user_id
            AND mp.participant_status_id IN (1,3,6,7)   -- align if needed
       )
)
SELECT
  b.meet_id_uuid,
  b.meet_status_id,
  b.change_stamp,
  b.latitude,
  b.longitude,
  b.region_latitude,
  b.region_longitude,
  b.region_radius,
  b.dttm_start_utc,
  b.dttm_end_utc,
  b.name,
  b.category_name,
  b.meet_category_id,
  b.description,
  b.max_capacity,
  b.created_by_user_uuid,
  b.display_name,

  (ms.my_status = 7) AS is_owner,

  CASE WHEN ms.my_status = 7 THEN
    COALESCE((
      SELECT COALESCE(
        jsonb_agg(
          jsonb_build_object(
            'user_uuid', u.uuid,
            'display_name', u.display_name,
            'participant_status_id', mp.participant_status_id
          )
          ORDER BY mp.participant_status_id DESC, u.display_name
        ),
        '[]'::jsonb
      )
      FROM rangley.tb_meet_participants mp
      JOIN rangley.vw_users u ON u.user_id = mp.user_id
      WHERE mp.meet_id = b.meet_id
        AND mp.participant_status_id IN (4,5,6,7)  -- Invited, Declined, Accepted, Owner
    ), '[]'::jsonb)::json
  ELSE NULL
  END AS participant_details,

  COALESCE((
    SELECT COUNT(*)::int4
    FROM rangley.tb_meet_participants mp
    WHERE mp.meet_id = b.meet_id
      AND mp.participant_status_id IN (6,7)
  ), 0)::int4 AS accepted_count

FROM base b
-- Hoist my_status once and reuse everywhere
LEFT JOIN LATERAL (
  SELECT mp.participant_status_id AS my_status
  FROM rangley.tb_meet_participants mp
  WHERE mp.meet_id = b.meet_id
    AND mp.user_id = b.requester_user_id
  ORDER BY mp.participant_status_id DESC
  LIMIT 1
) ms ON TRUE;
$$;
