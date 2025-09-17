CREATE OR REPLACE FUNCTION rangley.rangley_fn_i_send_notification_multi_by_id
(
     p_type_id             INT2
    ,p_meet_id             INT8
    ,p_created_by_user_id  INT8
    ,p_recipient_user_ids  INT8[]
    ,p_payload_extra       JSONB DEFAULT '{}'::jsonb
)
RETURNS TABLE (user_id BIGINT, notification_id BIGINT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_meet_uuid UUID;
    v_meet_name VARCHAR(50);
    v_meet_start TIMESTAMPTZ;
    v_meet_end   TIMESTAMPTZ;
    v_category_name TEXT;
    v_meet_category_id INT2;
    v_lat FLOAT8; 
	v_lon FLOAT8;
    v_payload JSONB;
    r_user_id BIGINT;
    v_notif_id BIGINT;
BEGIN
    IF p_type_id = 0 THEN
        RAISE EXCEPTION 'notification_type_id 0 (NULL_VALUE) is not sendable';
    END IF;

    -- Pull best-effort meet context (ok if not found)
    SELECT 
		 um.meet_id_uuid
		,um.name			,um.dttm_start_utc	 ,um.dttm_end_utc
		,um.category_name	,um.meet_category_id
		,um.latitude		,um.longitude
	INTO 
		 v_meet_uuid
		,v_meet_name		,v_meet_start		 ,v_meet_end
		,v_category_name	,v_meet_category_id
		,v_lat				,v_lon
  	FROM rangley.vw_up_to_date_meets um
 	WHERE um.meet_id = p_meet_id;

    v_payload :=
        jsonb_build_object(
            'notification_type_id', p_type_id,
            'meet_id', p_meet_id,
            'meet_id_uuid', v_meet_uuid,
            'meet_name', v_meet_name,
            'meet_start', v_meet_start,
            'meet_end',   v_meet_end,
            'meet_location', jsonb_build_object('latitude', v_lat, 'longitude', v_lon),
            'category_name', v_category_name,
            'meet_category_id', v_meet_category_id,
            'created_by_user_id', p_created_by_user_id
        ) || COALESCE(p_payload_extra, '{}'::jsonb);

    FOR r_user_id IN
        SELECT DISTINCT u.user_id
          FROM unnest(p_recipient_user_ids) AS x(user_id)
          JOIN rangley.vw_users u ON u.user_id = x.user_id
         WHERE x.user_id IS NOT NULL
    LOOP
        INSERT INTO rangley.tb_notifications
		(
			 notification_type_id	,meet_id
			,created_by_user_id		,payload_jso
		)
        VALUES
		(
			 p_type_id				,p_meet_id
			,p_created_by_user_id	,v_payload
		)
        RETURNING notification_id INTO v_notif_id;

        INSERT INTO rangley.tb_user_inboxes
		(
			user_id, notification_id
		)
        VALUES
		(
			r_user_id, v_notif_id
		);

        user_id 		:= r_user_id;
        notification_id := v_notif_id;
        RETURN NEXT;
    END LOOP;

    RETURN;
END;
$$;
