-- ============================================
-- CLEAR USER INBOX (MARK ALL AS READ/DISMISS)
-- ============================================
CREATE OR REPLACE FUNCTION rangley.rgl_fn_clear_user_inbox
(
    p_cognito_sub TEXT
)
RETURNS TABLE
(
    success BOOLEAN,
    message TEXT,
    cleared_count INT4
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_user_id INT8;
    v_deleted_count INT4;
BEGIN
    SELECT user_id INTO v_user_id
    FROM rangley.vw_users
    WHERE cognito_sub = p_cognito_sub;
    
    IF v_user_id IS NULL THEN
        RETURN QUERY SELECT FALSE, 'User not found'::TEXT, 0::INT4;
        RETURN;
    END IF;
    
    -- Only delete informational notifications, preserve actionable ones
    DELETE FROM rangley.tb_user_inboxes ui
    WHERE ui.user_id = v_user_id
      AND ui.notification_id IN (
          SELECT n.notification_id 
          FROM rangley.tb_notifications n
          WHERE n.notification_type_id NOT IN (8, 15)  -- Keep invitations and friend requests
      );
    
    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
    
    RETURN QUERY SELECT TRUE, 'Inbox cleared successfully'::TEXT, v_deleted_count;
    
EXCEPTION
    WHEN OTHERS THEN
        RETURN QUERY SELECT FALSE, ('Error: ' || SQLERRM)::TEXT, 0::INT4;
END;
$$;

/*

meet status table
0    NULL_VALUE
1    Active
2    Cancelled
3    Postponed
4    Completed
5    Draft
6    Full
7    Deleted

notification type
0     NULL_VALUE
1     Meet Created
2     Meet Updated
3     Meet Cancelled
4     New Attendee
5     Attendee Left
6     Meet Reminder
7     System Alert
8     Meet Invitation Received
9     Meet Invitation Accepted
10    Meet Invitation Declined
11    Meet Invitation Expired
12    Meet Full
13    Meet Role Changed
14    Meet Location Changed
15    Friend Request Received
16    Friend Request Accepted
17    Friend Request Declined

participant status
3 	 maybe
4    Invited
5    Declined
6    Accepted
7    Owner
8    Left
9    Removed

*/