CREATE OR REPLACE PROCEDURE rangley.rangley_d_user_by_cognito_sub
( 
 	 OUT is_success boolean
    ,IN p_cognito_sub TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_user_id INT8;
    v_username VARCHAR(50);
    v_display_name VARCHAR(50);
    v_meet_record RECORD;
    v_new_change_stamp INT8;
    v_meet_coordinate_id INT8;
    v_deleted_meets_count INT := 0;
    v_notifications_deleted INT := 0;
    v_participations_deleted INT := 0;
    
    -- Status constants
    v_deleted_status_id INT2 := 7;
BEGIN
    -- Get user details
    SELECT u.user_id, u.username, u.display_name 
    INTO v_user_id, v_username, v_display_name
    FROM rangley.vw_users u
    WHERE u.cognito_sub = p_cognito_sub;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'User with cognito_sub % not found', p_cognito_sub;
    END IF;
    
    RAISE NOTICE 'Starting deletion process for user: % (ID: %)', v_username, v_user_id;
    
    -- ========================================
    -- STEP 1: Mark all owned meets as deleted
    -- ========================================
    FOR v_meet_record IN
        SELECT 
            mi.meet_id,
            m.meet_coordinate_id,
            m.name AS meet_name,
            m.meet_status_id
        FROM rangley.vw_meet_ids mi
        JOIN rangley.vw_meet_change_stamps_desc mcsd ON mcsd.meet_id = mi.meet_id
        JOIN rangley.vw_meets m ON m.meet_id = mcsd.meet_id AND m.change_stamp = mcsd.change_stamp
        WHERE mi.created_by_user_id = v_user_id
        AND m.meet_status_id NOT IN (2, 3, 7) -- Not already cancelled, postponed, or deleted
    LOOP
        -- Create new change stamp
        INSERT INTO rangley.tb_change_stamps (meet_id, modified_by_user_id)
        VALUES (v_meet_record.meet_id, v_user_id)
        RETURNING change_stamp INTO v_new_change_stamp;
        
        -- Insert new meet record with deleted status
        INSERT INTO rangley.tb_meets (
            meet_id, 
            change_stamp, 
            meet_coordinate_id,
            meet_status_id,
            name,
            description,
            change_reason,
            meet_category_id,
            max_capacity,
            dttm_start_utc,
            dttm_end_utc,
            uuid
        )
        SELECT 
            m.meet_id,
            v_new_change_stamp,
            m.meet_coordinate_id,
            v_deleted_status_id, -- Set to deleted
            m.name,
            m.description,
            'Owner account deleted', -- Change reason
            m.meet_category_id,
            m.max_capacity,
            m.dttm_start_utc,
            m.dttm_end_utc,
            m.uuid
        FROM rangley.vw_meets m
        JOIN rangley.vw_meet_change_stamps_desc mcsd ON mcsd.meet_id = m.meet_id AND mcsd.change_stamp = m.change_stamp
        WHERE m.meet_id = v_meet_record.meet_id;
        
        v_deleted_meets_count := v_deleted_meets_count + 1;
        RAISE NOTICE 'Marked meet "%" (ID: %) as deleted', v_meet_record.meet_name, v_meet_record.meet_id;
    END LOOP;
    
    -- ========================================
    -- STEP 2: Handle participations in meets owned by others
    -- ========================================
    
    -- First, notify other participants in meets that will be deleted due to this user being the owner
    -- (This creates notifications for meet cancellations)
    FOR v_meet_record IN
        SELECT DISTINCT
            mp.meet_id,
            mp.user_id AS participant_user_id,
            m.name AS meet_name
        FROM rangley.tb_meet_participants mp
        JOIN rangley.vw_meet_ids mi ON mi.meet_id = mp.meet_id
        JOIN rangley.vw_meet_change_stamps_desc mcsd ON mcsd.meet_id = mp.meet_id
        JOIN rangley.vw_meets m ON m.meet_id = mcsd.meet_id AND m.change_stamp = mcsd.change_stamp
        WHERE mi.created_by_user_id = v_user_id  -- Meets owned by user being deleted
        AND mp.user_id != v_user_id              -- Other participants (not the owner)
        AND mp.participant_status_id IN (4,6,7)  -- Invited, Accepted, or Owner status
        AND m.meet_status_id NOT IN (2,3,7)     -- Active meets only
    LOOP
        -- Create cancellation notification for each affected participant
        INSERT INTO rangley.tb_notifications (notification_type_id, meet_id, created_by_user_id, payload_json)
        VALUES (
            3, -- Meet Cancelled notification type
            v_meet_record.meet_id,
            v_user_id, -- Still the deleted user as creator for audit purposes
            jsonb_build_object(
                'meet_name', v_meet_record.meet_name,
                'cancellation_reason', 'Meet owner account was deleted',
                'action_required', 'none'
            )
        );
        
        -- Add to participant's inbox
        INSERT INTO rangley.tb_user_inboxes (user_id, notification_id)
        VALUES (v_meet_record.participant_user_id, currval('rangley.tb_notifications_notification_id_seq'));
        
    END LOOP;
    
    -- Remove user from all meet participations (both owned and participated)
    DELETE FROM rangley.tb_meet_participants
    WHERE user_id = v_user_id;
    
    GET DIAGNOSTICS v_participations_deleted = ROW_COUNT;
    RAISE NOTICE 'Removed user from % meet participations', v_participations_deleted;
    
    -- ========================================
    -- STEP 3: Clean up notifications and inbox
    -- ========================================
    
    -- Delete from user's inbox first
    DELETE FROM rangley.tb_user_inboxes
    WHERE user_id = v_user_id;
    
    -- Delete notifications created by this user
    DELETE FROM rangley.tb_user_inboxes
    WHERE notification_id IN (
        SELECT notification_id 
        FROM rangley.tb_notifications 
        WHERE created_by_user_id = v_user_id
    );
    
    DELETE FROM rangley.tb_notifications
    WHERE created_by_user_id = v_user_id;
    
    GET DIAGNOSTICS v_notifications_deleted = ROW_COUNT;
    RAISE NOTICE 'Deleted % notifications created by user', v_notifications_deleted;
    
    -- ========================================
    -- STEP 4: Delete privacy settings
    -- ========================================
    DELETE FROM rangley.tb_user_privacy_settings
    WHERE user_id = v_user_id;
    
    RAISE NOTICE 'Deleted privacy settings for user';
    
    -- ========================================
    -- STEP 5: Delete the user record
    -- ========================================
    DELETE FROM rangley.tb_users
    WHERE user_id = v_user_id;
    
    RAISE NOTICE 'Deleted user record for: %', v_username;
    
    -- ========================================
    -- FINAL SUMMARY
    -- ========================================
    RAISE NOTICE 'User deletion completed successfully:';
    RAISE NOTICE '  - User: % (ID: %)', v_username, v_user_id;
    RAISE NOTICE '  - Meets marked as deleted: %', v_deleted_meets_count;
    RAISE NOTICE '  - Participations removed: %', v_participations_deleted;
    RAISE NOTICE '  - Notifications deleted: %', v_notifications_deleted;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'User deletion failed for %: %', v_username, SQLERRM;
END;
$$;