CREATE OR REPLACE FUNCTION rangley.rangley_fn_v_notify_attendee_left
(
     p_meet_id          INT8
    ,p_leaving_user_id  INT8
    ,p_notify_user_ids  INT8[]   -- owners/hosts (and/or other attendees)
    ,p_reason           TEXT DEFAULT NULL  -- 'left', 'kicked', etc.
    ,p_by_user_id       INT8 DEFAULT NULL  -- who removed them (if any)
)
RETURNS TABLE (user_id BIGINT, notification_id BIGINT)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT * FROM rangley.rangley_fn_i_send_notification_multi_by_id(
        p_type_id            => 5,   -- Attendee Left
        p_meet_id            => p_meet_id,
        p_created_by_user_id => COALESCE(p_by_user_id, p_leaving_user_id),
        p_recipient_user_ids => p_notify_user_ids,
        p_payload_extra      => jsonb_build_object(
            'user_id',    p_leaving_user_id,
            'reason',     p_reason,
            'by_user_id', p_by_user_id
        )
    );
END;
$$;
