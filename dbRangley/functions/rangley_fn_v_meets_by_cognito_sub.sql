-- DROP FUNCTION IF EXISTS rangley.rangley_fn_v_meets(text);

CREATE OR REPLACE FUNCTION rangley.rangley_fn_v_meets_by_cognito_sub(p_cognito_sub text)
RETURNS TABLE
(
  meet_id_uuid			UUID,
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
  utdm.meet_id_uuid,
  utdm.meet_status_id,
  utdm.latitude,
  utdm.longitude,
  utdm.region_latitude,
  utdm.region_longitude,
  utdm.region_radius,
  utdm.dttm_start_utc,
  utdm.dttm_end_utc,
  utdm.name,
  utdm.category_name,
  utdm.description,
  utdm.max_capacity,
  utdm.created_by_user_uuid,
  utdm.display_name,
  (utdm.created_by_user_uuid = me.requester_uuid) AS is_owner
FROM rangley.vw_up_to_date_meets AS utdm
CROSS JOIN me;
$$;