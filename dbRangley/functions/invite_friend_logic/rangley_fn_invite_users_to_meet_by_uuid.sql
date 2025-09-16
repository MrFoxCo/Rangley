-- ================================================================
-- UUID-BASED INVITATION FUNCTION (for API convenience)
-- ================================================================
CREATE OR REPLACE FUNCTION rangley.rangley_fn_invite_users_to_meet_by_uuid(
    p_meet_uuid UUID,
    p_inviter_user_uuid UUID,
    p_invitee_user_uuids UUID[],
    p_invitation_message TEXT DEFAULT NULL
)
RETURNS TABLE (
    user_uuid UUID,
    username VARCHAR(50),
    invitation_status TEXT,
    notification_id BIGINT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_meet_id BIGINT;
    v_inviter_user_id BIGINT;
    v_invitee_user_ids BIGINT[];
    v_result RECORD;
BEGIN
    -- Convert meet UUID to ID
    SELECT meet_id INTO v_meet_id
    FROM rangley.vw_meet_ids
    WHERE uuid = p_meet_uuid;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Meet with UUID % not found', p_meet_uuid;
    END IF;

    -- Convert inviter UUID to ID
    SELECT user_id INTO v_inviter_user_id
    FROM rangley.vw_users
    WHERE uuid = p_inviter_user_uuid;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Inviter with UUID % not found', p_inviter_user_uuid;
    END IF;

    -- Convert invitee UUIDs to IDs
    SELECT array_agg(user_id) INTO v_invitee_user_ids
    FROM rangley.vw_users
    WHERE uuid = ANY(p_invitee_user_uuids);

    -- Call the main function
    FOR v_result IN
        SELECT * FROM rangley.rangley_invite_users_to_meet(
            v_meet_id,
            v_inviter_user_id,
            v_invitee_user_ids,
            p_invitation_message
        )
    LOOP
        RETURN QUERY
        SELECT 
            u.uuid,
            v_result.username,
            v_result.invitation_status,
            v_result.notification_id
        FROM rangley.vw_users u
        WHERE u.user_id = v_result.user_id;
    END LOOP;
END;
$$;
