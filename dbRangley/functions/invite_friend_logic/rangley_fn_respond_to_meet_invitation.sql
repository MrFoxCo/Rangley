-- ================================================================
-- RESPOND TO INVITATION
-- ================================================================
CREATE OR REPLACE FUNCTION rangley.rangley_fn_respond_to_meet_invitation(
    p_meet_id BIGINT,
    p_user_id BIGINT,
    p_response VARCHAR(20) -- 'accept', 'decline', 'maybe'
)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
DECLARE
    v_new_status_id INT2;
    v_notification_payload JSONB;
BEGIN
    -- Map response to status ID
    v_new_status_id := CASE p_response
        WHEN 'accept' THEN 2  -- accepted
        WHEN 'decline' THEN 3 -- declined  
        WHEN 'maybe' THEN 4   -- maybe
        ELSE NULL
    END;

    IF v_new_status_id IS NULL THEN
        RAISE EXCEPTION 'Invalid response: %. Must be accept, decline, or maybe', p_response;
    END IF;

    -- Update participant status
    UPDATE rangley.tb_meet_participants
    SET 
        participant_status_id = v_new_status_id,
        dttm_modified_utc = now()
    WHERE 
        meet_id = p_meet_id 
        AND user_id = p_user_id
        AND participant_status_id = 1; -- Only update if currently invited

    IF FOUND AND p_response = 'accept' THEN
        -- Create notification for host about acceptance
        v_notification_payload := jsonb_build_object(
            'meet_id', p_meet_id,
            'user_id', p_user_id,
            'response', p_response,
            'responded_at', now()
        );
        
        INSERT INTO rangley.tb_notifications (
            notification_type_id,
            meet_id,
            created_by_user_id,
            payload_json
        )
        VALUES (
            4, -- participant_joined
            p_meet_id,
            p_user_id,
            v_notification_payload
        );
    END IF;

    RETURN FOUND;
END;
$$;
