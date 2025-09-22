CREATE OR REPLACE FUNCTION rangley.rangley_fn_v_user_inbox_notifications_by_cog_sub
(
  p_cognito_sub text
)
RETURNS TABLE 
(
   notification_id                 BIGINT
  ,notification_type_id            INT2
  ,notification_name               VARCHAR(50)
  ,meet_id_uuid                    UUID
  ,creator_display_name            VARCHAR(50)
  ,payload_json                    JSONB
  ,dttm_notification_created_utc   TIMESTAMPTZ
  ,dttm_received_utc               TIMESTAMPTZ
  ,dttm_opened_utc                 TIMESTAMPTZ
  ,is_read                         BOOLEAN
)
LANGUAGE plpgsql
AS $$
/*
	Maybe consider a way to display deleted meet notifications
-- Maybe (no notification sent)
SELECT * FROM rangley.rangley_fn_v_user_inbox_notifications_by_cog_sub(
  'a11b5510-2051-703c-eb7b-34ff537736ce');
*/
BEGIN
  RETURN QUERY
  SELECT
     n.notification_id
    ,n.notification_type_id
    ,nt.name AS notification_name
    ,utdm.meet_id_uuid
    ,creator.display_name AS creator_display_name
    ,n.payload_json
    ,n.dttm_created_utc AS dttm_notification_created_utc
    ,ui.dttm_received_utc
    ,ui.dttm_opened_utc
    ,(ui.dttm_opened_utc IS NOT NULL) AS is_read
  FROM rangley.vw_user_inboxes AS ui
  JOIN rangley.vw_notifications    AS n   ON
 	n.notification_id = ui.notification_id
  JOIN rangley.vw_notification_type AS nt ON 
	nt.notification_type_id = n.notification_type_id
  JOIN rangley.vw_users            AS recipient ON 
	recipient.user_id = ui.user_id
  -- Only keep notifications whose meet is still “up to date” (future/active)
  JOIN rangley.vw_up_to_date_meets AS utdm ON 
	utdm.meet_id = n.meet_id
  LEFT JOIN rangley.vw_users       AS creator ON 
	creator.user_id = n.created_by_user_id
  WHERE recipient.cognito_sub = p_cognito_sub
  ORDER BY ui.dttm_received_utc DESC;
END;
$$;