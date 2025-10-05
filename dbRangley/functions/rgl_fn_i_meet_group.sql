-- ============================================
-- CREATE MEET GROUP (UPDATED)
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
    meet_group_id INT8
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_user_id INT8;
    v_meet_group_id INT8;
BEGIN
    -- Get user ID
    SELECT user_id INTO v_user_id
    FROM rangley.vw_users
    WHERE cognito_sub = p_cognito_sub;

    IF v_user_id IS NULL THEN
        RETURN QUERY SELECT FALSE, 'User not found'::TEXT, NULL::INT8;
        RETURN;
    END IF;

    -- Validate group name
    IF p_group_name IS NULL OR trim(p_group_name) = '' THEN
        RETURN QUERY SELECT FALSE, 'Group name cannot be empty'::TEXT, NULL::INT8;
        RETURN;
    END IF;

    IF length(trim(p_group_name)) > 50 THEN
        RETURN QUERY SELECT FALSE, 'Group name too long (max 50 characters)'::TEXT, NULL::INT8;
        RETURN;
    END IF;

    -- Check for duplicate group name
    IF EXISTS (
        SELECT 1 FROM rangley.vw_meet_groups
        WHERE created_by_user_id = v_user_id
        AND lower(name) = lower(trim(p_group_name))
    ) THEN
        RETURN QUERY SELECT FALSE, 'You already have a group with this name'::TEXT, NULL::INT8;
        RETURN;
    END IF;

    -- Create the group
    INSERT INTO rangley.tb_meet_groups (created_by_user_id, name, image_type, image_reference)
    VALUES (v_user_id, trim(p_group_name), 'stock', p_image_reference)
    RETURNING rangley.tb_meet_groups.meet_group_id INTO v_meet_group_id;


	-- Add owner as a member
	INSERT INTO rangley.tb_meet_group_members (meet_group_id, user_id)
	VALUES (v_meet_group_id, v_user_id);


    RETURN QUERY SELECT TRUE, 'Meet group created successfully'::TEXT, v_meet_group_id;

EXCEPTION
    WHEN OTHERS THEN
        RETURN QUERY SELECT FALSE, ('Error: ' || SQLERRM)::TEXT, NULL::INT8;
END;
$$;


/*


Participant Status ID

0	NULL_VALUE
3	Maybe
4	Invited
5	Declined
6	Accepted
7	Owner
8	Left
9	Removed




Notification Type ID

0	NULL_VALUE
1	Meet Created
2	Meet Updated
3	Meet Cancelled
4	New Attendee
5	Attendee Left
6	Meet Reminder
7	System Alert
8	Meet Invitation Received
9	Meet Invitation Accepted
10	Meet Invitation Declined
11	Meet Invitation Expired
12	Meet Full
13	Meet Role Changed
14	Meet Location Changed
15	Friend Request Received
16	Friend Request Accepted
17	Friend Request Declined
18	Meet Deleted

Meet Status ID

0	NULL_VALUE
1	Active
2	Cancelled
3	Postponed
4	Completed
5	Draft
6	Full
7	Deleted

Stock Assets ID


1	person.3.fill		meet_group	Default
2	basketball.fill		meet_group	Basketball
3	football.fill		meet_group	Football
4	fork.knife			meet_group	Dining
5	book.fill			meet_group	Study
6	figure.run			meet_group	Fitness
7	gamecontroller.fill	meet_group	Gaming
8	music.note			meet_group	Music
9	airplane			meet_group	Travel
10	cup.and.saucer.fill	meet_group	Coffee
11	film.fill			meet_group	Movies
12	paintbrush.fill		meet_group	Art
13	leaf.fill			meet_group	Outdoors
14	brain.head.profile	meet_group	Mental Health
15	heart.fill			meet_group	Social
16	wineglass.fill		meet_group	Drinks
17	tennis.racket		meet_group	Tennis





*/

