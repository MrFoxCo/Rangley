CREATE OR REPLACE FUNCTION rangley.rangley_fn_i_additional_participants_to_meet_by_meet_id_uuid
(
	 p_cognito_sub TEXT
	,p_meet_id_uuid UUID
	,p_inviter_user_uuid UUID
	,p_additional_invitee_user_uuids UUID[]
	,p_invitation_message TEXT DEFAULT NULL
)
RETURNS TABLE
(
	 user_uuid 				  UUID
	,username 				  VARCHAR(50)
	,invitation_status 		  TEXT
	,returned_notification_id BIGINT
)
LANGUAGE plpgsql
AS $$
DECLARE
	v_meet_id INT8;
	v_inviter_user_id INT8;
	v_requester_user_id INT8;
	v_invitee_user_ids INT8[];
	r RECORD;
BEGIN
	-- Validate cognito_sub and get requester user_id
	SELECT u.user_id INTO v_requester_user_id
	FROM rangley.vw_users u
	WHERE u.cognito_sub = p_cognito_sub;
	
	IF NOT FOUND THEN
		RAISE EXCEPTION 'Invalid cognito_sub: %', p_cognito_sub;
	END IF;
	
	-- Validate that requester matches inviter
	IF p_inviter_user_uuid != (SELECT uuid FROM rangley.vw_users WHERE user_id = v_requester_user_id) THEN
		RAISE EXCEPTION 'Inviter UUID does not match authenticated user';
	END IF;
	-- Convert meet UUID to ID
	SELECT mi.meet_id INTO v_meet_id
	FROM rangley.vw_meet_ids mi
	WHERE mi.uuid = p_meet_id_uuid;
	
	IF NOT FOUND THEN
		RAISE EXCEPTION 'Meet with UUID % not found', p_meet_id_uuid;
	END IF;
	
	-- Convert inviter UUID to ID (should match v_requester_user_id)
	v_inviter_user_id := v_requester_user_id;
	
	-- Convert all invitee UUIDs to user IDs, preserving order
	FOR r IN
		SELECT 
			iu.uuid AS invitee_uuid,
			u.user_id,
			iu.ord
		FROM unnest(p_additional_invitee_user_uuids) WITH ORDINALITY AS iu(uuid, ord)
		LEFT JOIN rangley.vw_users u ON u.uuid = iu.uuid
		ORDER BY iu.ord
		LOOP
		IF r.user_id IS NULL THEN
			-- User not found - return error for this UUID
			user_uuid := r.invitee_uuid;
			username := NULL;
			invitation_status := 'user_not_found';
			returned_notification_id := NULL;
			RETURN NEXT;
		ELSE
			-- User found - add to array and call core function for this single user
			RETURN QUERY
			SELECT 
			r.invitee_uuid AS user_uuid,
			x.username,
			x.invitation_status,
			x.returned_notification_id
			FROM rangley.rangley_fn_i_invite_users_to_meet(
			v_meet_id,
			v_inviter_user_id,
			ARRAY[r.user_id],
			p_invitation_message
			) x;
		END IF;
	END LOOP;
	
	RETURN;
END;
$$;





