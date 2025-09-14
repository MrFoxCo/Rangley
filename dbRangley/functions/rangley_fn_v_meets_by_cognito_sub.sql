-- DROP FUNCTION IF EXISTS rangley.rangley_fn_v_meets(text);

CREATE OR REPLACE FUNCTION rangley.rangley_fn_v_meets_by_cognito_sub(p_cognito_sub text)
RETURNS TABLE
(
  meet_id_uuid			UUID,
  meet_uuid           	UUID,
  change_stamp        	int8,      -- match Swift Int64
  meet_status_id      	int2,      -- match Swift Int16
  latitude            	float8,
  longitude           	float8,
  region_latitude     	float8,
  region_longitude    	float8,
  region_radius       	float8,
  dttm_start_utc      	timestamptz,
  dttm_end_utc        	timestamptz,
  name                	varchar(50),
  category_name      	varchar(50),
  description         	varchar(50),
  max_capacity        	int4,
  created_by_user_uuid  UUID,
  display_name        	varchar(50),
  is_owner            	boolean
)
LANGUAGE sql
STABLE
AS $$
WITH me AS (
  SELECT rangley.rangley_fn_v_user_uuid_by_cognito_sub(p_cognito_sub) AS requester_uuid
)
SELECT
  m.meet_id_uuid,
  m.meet_uuid,
  m.change_stamp,
  m.meet_status_id,
  m.latitude,
  m.longitude,
  m.region_latitude,
  m.region_longitude,
  m.region_radius,
  m.dttm_start_utc,
  m.dttm_end_utc,
  m.name,
  m.category_name,
  m.description,
  m.max_capacity,
  m.created_by_user_uuid,
  m.display_name,
  (m.created_by_user_uuid = me.requester_uuid) AS is_owner
FROM rangley.vw_meets_accessible AS m
CROSS JOIN me;
$$;