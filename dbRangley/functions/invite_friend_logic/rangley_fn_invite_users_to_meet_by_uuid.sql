CREATE OR REPLACE FUNCTION rangley.rangley_fn_i_invite_users_to_meet_by_meet_id_uuid
(
     p_meet_id_uuid 		UUID
    ,p_inviter_user_uuid 	UUID
    ,p_invitee_user_uuids 	UUID[]
    ,p_invitation_message 	TEXT DEFAULT NULL
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
    v_meet_id INT8;
    v_inviter_user_id INT8;
    r RECORD;
BEGIN
    SELECT
		mi.meet_id
	INTO 
		v_meet_id
    FROM rangley.vw_meet_ids mi
	WHERE mi.uuid = p_meet_id_uuid;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Meet with UUID % not found', p_meet_id_uuid;
    END IF;

    SELECT u.user_id INTO v_inviter_user_id
    FROM rangley.vw_users u
    WHERE u.uuid = p_inviter_user_uuid;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Inviter with UUID % not found', p_inviter_user_uuid;
    END IF;

    -- preserve order and unknowns
    FOR r IN
        SELECT
        	 iu.uuid AS invitee_uuid
        	,u.user_id
        	,u.uuid AS user_uuid
        FROM unnest(p_invitee_user_uuids) WITH ORDINALITY AS iu(uuid, ord)
        LEFT JOIN rangley.vw_users u ON
        	u.uuid = iu.uuid
        ORDER BY iu.ord
    LOOP
        IF r.user_id IS NULL THEN
            -- echo input UUID for client mapping
            user_uuid := r.invitee_uuid;
            username := NULL;
            invitation_status := 'user_not_found';
            notification_id := NULL;
            RETURN NEXT;
        ELSE
			RETURN QUERY
			SELECT
				 r.user_uuid
				,x.username
				,x.invitation_status
				,x.notification_id
			FROM rangley.rangley_fn_i_invite_users_to_meet
			(
				 v_meet_id
				,v_inviter_user_id
				,ARRAY[r.user_id]
				,p_invitation_message
			) AS x;
        END IF;
    END LOOP;

    RETURN;
END;
$$;
