CREATE OR REPLACE FUNCTION rangley.rangley_fn_m_update_participant_status
(
    p_cognito_sub text,
    p_meet_id_uuid UUID,
    p_target_user_uuid UUID,
    p_new_status_id int2
)
RETURNS TABLE
(
    success boolean,
    message text,
    participant_id_out bigint,
    old_status_id int2,
    new_status_id int2
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_meet_id bigint;
    v_requesting_user_id bigint;
    v_target_user_id bigint;
    v_participant_id bigint;
    v_old_status_id int2;
    v_is_owner boolean := FALSE;
    
    v_status_removed int2 := 9;
    v_status_owner int2 := 7;
BEGIN
    -- Get requesting user and meet IDs
    SELECT u.user_id INTO v_requesting_user_id
    FROM rangley.vw_users u WHERE u.cognito_sub = p_cognito_sub;
    
    SELECT m.meet_id INTO v_meet_id
    FROM rangley.vw_meet_ids m WHERE m.uuid = p_meet_id_uuid;
    
    SELECT u.user_id INTO v_target_user_id
    FROM rangley.vw_users u WHERE u.uuid = p_target_user_uuid;
    
    -- Verify requesting user is owner
    SELECT EXISTS(
        SELECT 1 FROM rangley.tb_meet_participants mp
        WHERE mp.meet_id = v_meet_id 
        AND mp.user_id = v_requesting_user_id 
        AND mp.participant_status_id = v_status_owner
    ) INTO v_is_owner;
    
    IF NOT v_is_owner THEN
        RETURN QUERY SELECT FALSE, 'Only owners can update participant status'::text, 
                           NULL::bigint, NULL::int2, NULL::int2;
        RETURN;
    END IF;
    
    -- Get target participant info
    SELECT mp.participant_id, mp.participant_status_id
    INTO v_participant_id, v_old_status_id
    FROM rangley.tb_meet_participants mp
    WHERE mp.meet_id = v_meet_id AND mp.user_id = v_target_user_id;
    
    -- Can't remove the owner or someone already removed
    IF v_old_status_id = v_status_owner THEN
        RETURN QUERY SELECT FALSE, 'Cannot remove the owner'::text, 
                           v_participant_id, v_old_status_id, NULL::int2;
        RETURN;
    END IF;
    
    -- Update the participant status
    UPDATE rangley.tb_meet_participants 
    SET participant_status_id = p_new_status_id,
        dttm_modified_utc = NOW()
    WHERE participant_id = v_participant_id;
    


	-- Clean up invitation notification if user is being removed
	IF p_new_status_id = v_status_removed THEN
	    WITH deleted_notifications AS (
	        DELETE FROM rangley.tb_notifications n
	        WHERE n.meet_id = v_meet_id
	          AND n.notification_type_id = 8  -- Meet Invitation Received
	          AND n.notification_id IN (
	              SELECT ui.notification_id 
	              FROM rangley.tb_user_inboxes ui 
	              WHERE ui.user_id = v_target_user_id
	          )
	        RETURNING n.notification_id
	    )
	    DELETE FROM rangley.tb_user_inboxes ui
	    USING deleted_notifications dn
	    WHERE ui.notification_id = dn.notification_id;
	END IF;


    RETURN QUERY SELECT TRUE, 'Participant status updated successfully'::text,
                        v_participant_id, v_old_status_id, p_new_status_id;
END;
$$;