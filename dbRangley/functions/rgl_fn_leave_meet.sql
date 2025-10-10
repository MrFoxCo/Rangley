-- ============================================
-- LEAVE MEET (Dedicated Function)
-- ============================================
CREATE OR REPLACE FUNCTION rangley.rgl_fn_leave_meet
(
    p_cognito_sub text,
    p_meet_id_uuid uuid
)
RETURNS table
(
    success boolean,
    message text,
    participant_id_out INT8,
    old_status_id int2
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_meet_id INT8;
    v_user_id INT8;
    v_participant_id INT8;
    v_old_status_id int2;
    v_meet_creator_id INT8;
    v_notification_id INT8;
    
    v_status_left int2 := 8;
    v_status_owner int2 := 7;
    v_ntype_left int2 := 5;  -- "Attendee Left" notification type
BEGIN
    -- Get user ID
    SELECT u.user_id
    INTO v_user_id
    FROM rangley.vw_users AS u
    WHERE u.cognito_sub = p_cognito_sub;
    
    IF v_user_id IS NULL THEN
        RETURN QUERY SELECT FALSE, 'User not found'::text, NULL::bigint, NULL::int2;
        RETURN;
    END IF;
    
    -- Get meet ID
    SELECT m.meet_id
    INTO v_meet_id
    FROM rangley.vw_meet_ids AS m
    WHERE m.uuid = p_meet_id_uuid;
    
    IF v_meet_id IS NULL THEN
        RETURN QUERY SELECT FALSE, 'Meet not found'::text, NULL::bigint, NULL::int2;
        RETURN;
    END IF;
    
    -- Get participant record
    SELECT mp.participant_id, mp.participant_status_id
    INTO v_participant_id, v_old_status_id
    FROM rangley.tb_meet_participants AS mp
    WHERE mp.meet_id = v_meet_id
    AND mp.user_id = v_user_id;
    
    IF v_participant_id IS NULL THEN
        RETURN QUERY SELECT FALSE, 'Not a participant of this meet'::text, NULL::bigint, NULL::int2;
        RETURN;
    END IF;
    
    -- Can't leave if you're the owner
    IF v_old_status_id = v_status_owner THEN
        RETURN QUERY SELECT FALSE, 'Owners cannot leave their own meet'::text, v_participant_id, v_old_status_id;
        RETURN;
    END IF;
    
    -- Can't leave if already left or removed
    IF v_old_status_id IN (8, 9) THEN
        RETURN QUERY SELECT FALSE, 'Already left or removed from this meet'::text, v_participant_id, v_old_status_id;
        RETURN;
    END IF;
    
    -- Update participant status to "left"
    UPDATE rangley.tb_meet_participants AS mp
    SET participant_status_id = v_status_left,
        dttm_left_utc = NOW(),
        dttm_modified_utc = NOW()
    WHERE mp.participant_id = v_participant_id;
    

	-- Delete notifications and inbox entries for this user's meet invitations
	WITH deleted_notifications AS (
	    DELETE FROM rangley.tb_notifications n
	    WHERE n.meet_id = v_meet_id
	      AND n.notification_type_id = 8
	      AND n.notification_id IN (
	          SELECT ui.notification_id 
	          FROM rangley.tb_user_inboxes ui 
	          WHERE ui.user_id = v_user_id
	      )
	    RETURNING n.notification_id
	)
	DELETE FROM rangley.tb_user_inboxes ui
	USING deleted_notifications dn
	WHERE ui.notification_id = dn.notification_id;


    
    -- Get meet creator to notify them
    SELECT mi.created_by_user_id
    INTO v_meet_creator_id
    FROM rangley.vw_meet_ids AS mi
    WHERE mi.meet_id = v_meet_id;
    
    -- Notify the meet creator that someone left
    IF v_meet_creator_id IS NOT NULL AND v_meet_creator_id <> v_user_id THEN
        INSERT INTO rangley.tb_notifications AS n
        (notification_type_id, meet_id, created_by_user_id, payload_json)
        VALUES
        (v_ntype_left, v_meet_id, v_user_id,
         jsonb_build_object(
             'left_user_id', v_user_id,
             'left_timestamp', NOW()))
        RETURNING n.notification_id INTO v_notification_id;
        
        INSERT INTO rangley.tb_user_inboxes AS ui (user_id, notification_id)
        VALUES (v_meet_creator_id, v_notification_id);
    END IF;
    
    RETURN QUERY SELECT TRUE, 'Successfully left the meet'::text, v_participant_id, v_old_status_id;
    
EXCEPTION
    WHEN OTHERS THEN
        RETURN QUERY SELECT FALSE, ('Error: ' || SQLERRM)::text, NULL::bigint, NULL::int2;
END;
$$;