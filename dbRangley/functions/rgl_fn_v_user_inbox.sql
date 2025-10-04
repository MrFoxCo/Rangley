-- ============================================
-- GET USER INBOX (READING FROM VIEWS)
-- ============================================
CREATE OR REPLACE FUNCTION rangley.rgl_fn_v_user_inbox
(
    p_cognito_sub text,
    p_limit       int DEFAULT 50
)
RETURNS table
(
    notification_id      bigint,
    notification_type_id int2,
    notification_type    varchar(50),
    meet_id_uuid         uuid,
    created_by_user_uuid uuid,
    created_by_username  varchar(50),
    created_by_display_name varchar(50),
    payload_json         jsonb,
    dttm_created_utc     timestamptz,
    dttm_received_utc    timestamptz,
    dttm_opened_utc      timestamptz,
    is_read              boolean
)
LANGUAGE sql
STABLE
AS $$
    SELECT 
         n.notification_id
        ,n.notification_type_id
        ,nt.name AS notification_type
        ,mi.uuid AS meet_id_uuid
        ,u.uuid AS created_by_user_uuid
        ,u.username AS created_by_username
        ,u.display_name AS created_by_display_name
        ,n.payload_json
        ,n.dttm_created_utc
        ,ui.dttm_received_utc
        ,ui.dttm_opened_utc
        ,(ui.dttm_opened_utc IS NOT NULL) AS is_read
    FROM rangley.vw_user_inboxes ui
    JOIN rangley.vw_notifications n USING (notification_id)
    JOIN rangley.vw_notification_type nt ON nt.notification_type_id = n.notification_type_id
    JOIN rangley.vw_users u ON u.user_id = n.created_by_user_id
    LEFT JOIN rangley.vw_meet_ids mi ON mi.meet_id = n.meet_id
    WHERE ui.user_id = (
        SELECT user_id FROM rangley.vw_users WHERE cognito_sub = p_cognito_sub
    )
    ORDER BY ui.dttm_received_utc DESC
    LIMIT LEAST(GREATEST(p_limit, 1), 100);  -- Clamp between 1 and 100
$$;