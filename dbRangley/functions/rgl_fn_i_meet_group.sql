-- ============================================
-- CREATE MEET GROUP (WITH CONTENT VALIDATION)
-- ============================================
CREATE OR REPLACE FUNCTION rangley.rgl_fn_i_meet_group
(
    p_cognito_sub TEXT,
    p_group_name TEXT,
    p_image_reference TEXT DEFAULT 'person.3.fill'
)
RETURNS TABLE
(
    success BOOLEAN,
    message TEXT,
    meet_group_id INT8,
    validation_failed BOOLEAN,
    validation_reason TEXT,
    validation_message TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_user_id INT8;
    v_meet_group_id INT8;
    v_validation_result JSON;
    v_group_name_clean TEXT;
BEGIN
    -- Get user ID
    SELECT user_id INTO v_user_id
    FROM rangley.vw_users
    WHERE cognito_sub = p_cognito_sub;

    IF v_user_id IS NULL THEN
        RETURN QUERY SELECT FALSE, 'User not found'::TEXT, NULL::INT8, FALSE, NULL::TEXT, NULL::TEXT;
        RETURN;
    END IF;

    -- Clean the group name
    v_group_name_clean := trim(p_group_name);

    -- Basic validation
    IF p_group_name IS NULL OR v_group_name_clean = '' THEN
        RETURN QUERY SELECT FALSE, 'Group name cannot be empty'::TEXT, NULL::INT8, FALSE, NULL::TEXT, NULL::TEXT;
        RETURN;
    END IF;

    IF length(v_group_name_clean) > 50 THEN
        RETURN QUERY SELECT FALSE, 'Group name too long (max 50 characters)'::TEXT, NULL::INT8, FALSE, NULL::TEXT, NULL::TEXT;
        RETURN;
    END IF;

    -- Content validation - validate meet group name for inappropriate content
    SELECT rangley.rgl_fn_validate_meet_group_name(v_group_name_clean, v_user_id)
      INTO v_validation_result;

    -- Check if content validation failed
    IF (v_validation_result->>'valid')::boolean = FALSE THEN
        -- Log and return validation failure
        RAISE LOG '[INFO] Meet group creation aborted: inappropriate content detected (reason: %, user_id: %)', 
            v_validation_result->>'reason', v_user_id;
        
        RETURN QUERY SELECT 
            FALSE, 
            (v_validation_result->>'message')::TEXT, 
            NULL::INT8,
            TRUE,  -- validation_failed
            (v_validation_result->>'reason')::TEXT,  -- validation_reason
            (v_validation_result->>'message')::TEXT;  -- validation_message
        RETURN;
    END IF;

    RAISE LOG '[INFO] Content validation passed for meet group creation by user_id=%', v_user_id;

    -- Check for duplicate group name
    IF EXISTS (
        SELECT 1 FROM rangley.vw_meet_groups
        WHERE created_by_user_id = v_user_id
        AND lower(name) = lower(v_group_name_clean)
    ) THEN
        RETURN QUERY SELECT FALSE, 'You already have a group with this name'::TEXT, NULL::INT8, FALSE, NULL::TEXT, NULL::TEXT;
        RETURN;
    END IF;

    -- Create the group
    INSERT INTO rangley.tb_meet_groups (created_by_user_id, name, image_type, image_reference)
    VALUES (v_user_id, v_group_name_clean, 'stock', p_image_reference)
    RETURNING rangley.tb_meet_groups.meet_group_id INTO v_meet_group_id;

    -- Add owner as a member
    INSERT INTO rangley.tb_meet_group_members (meet_group_id, user_id)
    VALUES (v_meet_group_id, v_user_id);

    RAISE LOG '[INFO] Created meet_group_id=% by user_id=%', v_meet_group_id, v_user_id;

    RETURN QUERY SELECT TRUE, 'Meet group created successfully'::TEXT, v_meet_group_id, FALSE, NULL::TEXT, NULL::TEXT;

EXCEPTION
    WHEN OTHERS THEN
        RAISE LOG '[ERRO] Unexpected error in rgl_fn_i_meet_group: %', SQLERRM;
        RETURN QUERY SELECT FALSE, ('Error: ' || SQLERRM)::TEXT, NULL::INT8, FALSE, NULL::TEXT, NULL::TEXT;
END;
$$;


/*

Participant Status ID

0 NULL_VALUE
3 Maybe
4 Invited
5 Declined
6 Accepted
7 Owner
8 Left
9 Removed


Notification Type ID

0 NULL_VALUE
1 Meet Created
2 Meet Updated
3 Meet Cancelled
4 New Attendee
5 Attendee Left
6 Meet Reminder
7 System Alert
8 Meet Invitation Received
9 Meet Invitation Accepted
10 Meet Invitation Declined
11 Meet Invitation Expired
12 Meet Full
13 Meet Role Changed
14 Meet Location Changed
15 Friend Request Received
16 Friend Request Accepted
17 Friend Request Declined
18 Meet Deleted

Meet Status ID

0 NULL_VALUE
1 Active
2 Cancelled
3 Postponed
4 Completed
5 Draft
6 Full
7 Deleted

Stock Assets ID

1 person.3.fill meet_group Default
2 basketball.fill meet_group Basketball
3 football.fill meet_group Football
4 fork.knife meet_group Dining
5 book.fill meet_group Study
6 figure.run meet_group Fitness
7 gamecontroller.fill meet_group Gaming
8 music.note meet_group Music
9 airplane meet_group Travel
10 cup.and.saucer.fill meet_group Coffee
11 film.fill meet_group Movies
12 paintbrush.fill meet_group Art
13 leaf.fill meet_group Outdoors
14 brain.head.profile meet_group Mental Health
15 heart.fill meet_group Social
16 wineglass.fill meet_group Drinks
17 tennis.racket meet_group Tennis

*/