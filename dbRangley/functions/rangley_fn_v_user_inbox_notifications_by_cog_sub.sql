CREATE OR REPLACE FUNCTION rangley.rangley_fn_v_user_inbox_notifications_by_cognito_sub
(
    p_cognito_sub text
)
RETURNS TABLE
(
     notification_id BIGINT
    ,notification_type_id INT2
    ,notification_name VARCHAR(50)
    ,participant_status_id INT2  
    ,meet_id_uuid UUID
    ,creator_display_name VARCHAR(50)
    ,payload_json JSONB
    ,dttm_notification_created_utc TIMESTAMPTZ
    ,dttm_received_utc TIMESTAMPTZ
    ,dttm_opened_utc TIMESTAMPTZ
    ,is_read BOOLEAN
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
         n.notification_id
        ,n.notification_type_id
        ,nt.name AS notification_name
        ,mp.participant_status_id 
        ,utdm.meet_id_uuid
        ,creator.display_name AS creator_display_name
        ,n.payload_json
        ,n.dttm_created_utc AS dttm_notification_created_utc
        ,ui.dttm_received_utc
        ,ui.dttm_opened_utc
        ,(ui.dttm_opened_utc IS NOT NULL) AS is_read
    FROM rangley.vw_user_inboxes AS ui
    JOIN rangley.vw_notifications AS n ON
        n.notification_id = ui.notification_id
    JOIN rangley.vw_notification_type AS nt ON
        nt.notification_type_id = n.notification_type_id
    JOIN rangley.vw_users AS recipient ON
        recipient.user_id = ui.user_id
    JOIN rangley.vw_up_to_date_meets AS utdm ON
        utdm.meet_id = n.meet_id
    LEFT JOIN rangley.vw_users AS creator ON
        creator.user_id = n.created_by_user_id
    LEFT JOIN rangley.tb_meet_participants AS mp ON  -- ADD THIS JOIN
        mp.meet_id = utdm.meet_id 
        AND mp.user_id = recipient.user_id
    WHERE recipient.cognito_sub = p_cognito_sub
    ORDER BY ui.dttm_received_utc DESC;
END;
$$;

/*

{
"meet_id": 123,
 "meet_end": "2025-09-27T15:48:04+00:00",
  "meet_name": "wabbit hunting",
   "meet_start": "2025-09-22T14:48:04+00:00", 
   "meet_id_uuid": "f0b9d1d2-f47f-4277-b7de-cc0f311583cb", 
   "category_name": "Activity", 
   "meet_location": {"latitude": 41.984702430934014, "longitude": -87.68324789956196},
    "action_required": "respond_to_invitation", 
    "meet_category_id": 1,
     "invitation_message": "", 
     "invited_by_user_id": 6
     }
Raw payload_json: AXsibWVldF9pZCI6IDEyMiwgIm1lZXRfZW5kIjogIjIwMjUtMTAtMDVUMTU6NDc6MDQrMDA6MDAiLCAibWVldF9uYW1lIjogIkN1YnRvYmVyIEZlc3QiLCAibWVldF9zdGFydCI6ICIyMDI1LTA5LTIyVDE0OjQ3OjA0KzAwOjAwIiwgIm1lZXRfaWRfdXVpZCI6ICI0ZmFmMjFlNS1iOGZjLTQwOWYtOTdmMC01NmNmNTc0ZTcyNDEiLCAiY2F0ZWdvcnlfbmFtZSI6ICJBY3Rpdml0eSIsICJtZWV0X2xvY2F0aW9uIjogeyJsYXRpdHVkZSI6IDQxLjk0ODgwOTI3MTQ2Mjc0LCAibG9uZ2l0dWRlIjogLTg3LjY1NTkwMTE5NDgwNDAzfSwgImFjdGlvbl9yZXF1aXJlZCI6ICJyZXNwb25kX3RvX2ludml0YXRpb24iLCAibWVldF9jYXRlZ29yeV9pZCI6IDEsICJpbnZpdGF0aW9uX21lc3NhZ2UiOiAiIiwgImludml0ZWRfYnlfdXNlcl9pZCI6IDR9
Base64 decoded: 
{
"meet_id": 122,
 "meet_end": "2025-10-05T15:47:04+00:00",
  "meet_name": "Cubtober Fest", "meet_start":
   "2025-09-22T14:47:04+00:00",
    "meet_id_uuid": "4faf21e5-b8fc-409f-97f0-56cf574e7241",
     "category_name": "Activity",
      "meet_location": {"latitude": 41.94880927146274, "longitude": -87.65590119480403}, 
      "action_required": "respond_to_invitation", 
      "meet_category_id": 1, "invitation_message": "",
       "invited_by_user_id": 4
       }
 */



