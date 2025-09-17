CREATE OR REPLACE FUNCTION rangley.rangley_fn_v_notify_invitation_received
(
     p_meet_id            INT8
    ,p_inviter_user_id    INT8
    ,p_invitee_user_ids   INT8[]
    ,p_invitation_message TEXT DEFAULT NULL
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
         p_type_id            => 8   -- Meet Invitation Received
        ,p_meet_id            => p_meet_id
        ,p_created_by_user_id => p_inviter_user_id
        ,p_recipient_user_ids => p_invitee_user_ids
        ,p_payload_extra      => jsonb_build_object(
            'invited_by_user_id', p_inviter_user_id,
            'invitation_message', p_invitation_message,
            'action_required',    'respond_to_invitation'
        )
    );
END;
$$;
