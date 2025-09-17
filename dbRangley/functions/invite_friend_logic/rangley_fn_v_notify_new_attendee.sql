CREATE OR REPLACE FUNCTION rangley.rangley_fn_v_notify_new_attendee
(
     p_meet_id          INT8
    ,p_attendee_user_id INT8
    ,p_notify_user_ids  INT8[]   -- other participants to broadcast to
)
RETURNS table
(
	user_id BIGINT, notification_id BIGINT
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT * FROM rangley.rangley_fn_i_send_notification_multi_by_id
(
        p_type_id            => 4,   -- New Attendee
        p_meet_id            => p_meet_id,
        p_created_by_user_id => p_attendee_user_id,
        p_recipient_user_ids => p_notify_user_ids,
        p_payload_extra      => jsonb_build_object(
            'user_id', p_attendee_user_id
        )
    );
END;
$$;
