-- DROP FUNCTION IF EXISTS rangley.rangley_fn_v_meets;

CREATE OR REPLACE FUNCTION rangley.rangley_fn_v_meets()
RETURNS TABLE
(
     meet_id            int8
    ,change_stamp       int4
    ,meet_status_id     int4
    ,latitude           float8
    ,longitude          float8
    ,region_latitude    float8
    ,region_longitude   float8
    ,region_radius      float8
    ,dttm_start_utc     timestamptz
    ,dttm_end_utc       timestamptz
    ,name               varchar(50)
    ,category_name      varchar(50)
    ,description        varchar(50)
    ,max_capacity       int4
    ,created_by_user_id int8
    ,display_name       varchar(50)
)
LANGUAGE sql
STABLE
AS $function$
    SELECT
         meet_id
        ,change_stamp
        ,meet_status_id
        ,latitude
        ,longitude
        ,region_latitude
        ,region_longitude
        ,region_radius
        ,dttm_start_utc
        ,dttm_end_utc
        ,name
        ,category_name
        ,description
        ,max_capacity
        ,created_by_user_id
        ,display_name
    FROM rangley.vw_meets_accessible
$function$;
