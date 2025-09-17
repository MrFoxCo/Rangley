CREATE OR REPLACE FUNCTION rangley.rangley_fn_v_notify_invitation_declined
(
     p_meet_id          INT8
    ,p_declining_user   INT8
    ,p_notify_user_ids  INT8[]   -- owners/hosts to inform
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
        p_type_id            => 10,  -- Meet Invitation Declined
        p_meet_id            => p_meet_id,
        p_created_by_user_id => p_declining_user,
        p_recipient_user_ids => p_notify_user_ids,
        p_payload_extra      => jsonb_build_object(
            'declined_by_user_id', p_declining_user
        )
    );
END;
$$;
