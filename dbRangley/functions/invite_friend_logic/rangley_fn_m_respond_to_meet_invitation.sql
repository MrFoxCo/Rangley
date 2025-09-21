CREATE OR REPLACE FUNCTION rangley.rangley_fn_m_respond_to_meet_invitation
(
  p_cognito_sub        text,
  p_meet_id            int8,
  p_response_status_id int2
)
RETURNS TABLE
(
  success         boolean,
  message         text,
  participant_id_out bigint,
  old_status_id   int2,
  new_status_id   int2
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_user_id          bigint;
  v_participant_id   bigint;
  v_old_status_id    int2;
  v_meet_creator_id  bigint;
  v_notification_id  bigint;

  v_status_invited   int2 := 4;
  v_status_accepted  int2 := 6;
  v_status_declined  int2 := 5;
  v_status_maybe     int2 := 3;
  v_status_owner     int2 := 7;
  v_status_left      int2 := 8;
  v_status_removed   int2 := 9;

  v_ntype_accepted   int2 := 9;
  v_ntype_declined   int2 := 10;
  v_notification_type_id int2;
BEGIN
  SELECT u.user_id
    INTO v_user_id
    FROM rangley.vw_users AS u
   WHERE u.cognito_sub = p_cognito_sub;

  IF v_user_id IS NULL THEN
    RETURN QUERY SELECT FALSE, 'User not found'::text, NULL::bigint, NULL::int2, NULL::int2;
    RETURN;
  END IF;

  IF p_response_status_id NOT IN (v_status_accepted, v_status_declined, v_status_maybe) THEN
    RETURN QUERY SELECT FALSE, 'Invalid response status'::text, NULL::bigint, NULL::int2, NULL::int2;
    RETURN;
  END IF;

  SELECT mp.participant_id, mp.participant_status_id
    INTO v_participant_id, v_old_status_id
    FROM rangley.tb_meet_participants AS mp
   WHERE mp.meet_id = p_meet_id
     AND mp.user_id = v_user_id;

  IF v_participant_id IS NULL THEN
    RETURN QUERY SELECT FALSE, 'No participant record for this meet'::text, NULL::bigint, NULL::int2, NULL::int2;
    RETURN;
  END IF;

  IF v_old_status_id IN (v_status_owner, v_status_left, v_status_removed) THEN
    RETURN QUERY SELECT FALSE, 'Cannot respond in current state'::text, v_participant_id, v_old_status_id, NULL::int2;
    RETURN;
  END IF;

  SELECT mi.created_by_user_id
    INTO v_meet_creator_id
    FROM rangley.vw_meet_ids AS mi
   WHERE mi.meet_id = p_meet_id;

  IF v_meet_creator_id IS NULL THEN
    RETURN QUERY SELECT FALSE, 'Meet not found'::text, v_participant_id, v_old_status_id, NULL::int2;
    RETURN;
  END IF;

  UPDATE rangley.tb_meet_participants AS mp
     SET participant_status_id = p_response_status_id,
         dttm_accepted_utc = CASE WHEN p_response_status_id = v_status_accepted THEN NOW() ELSE NULL END,
         dttm_modified_utc = NOW()
   WHERE mp.participant_id = v_participant_id;

  v_notification_type_id := CASE
    WHEN p_response_status_id = v_status_accepted THEN v_ntype_accepted
    WHEN p_response_status_id = v_status_declined THEN v_ntype_declined
    ELSE NULL
  END;

  IF v_notification_type_id IS NOT NULL
     AND v_meet_creator_id IS NOT NULL
     AND v_meet_creator_id <> v_user_id THEN
    INSERT INTO rangley.tb_notifications AS n
      (notification_type_id, meet_id, created_by_user_id, payload_json)
    VALUES
      (v_notification_type_id, p_meet_id, v_user_id,
       jsonb_build_object(
         'respondent_user_id', v_user_id,
         'response_status_id', p_response_status_id,
         'response_timestamp', NOW()))
    RETURNING n.notification_id INTO v_notification_id;

    INSERT INTO rangley.tb_user_inboxes AS ui (user_id, notification_id)
    VALUES (v_meet_creator_id, v_notification_id);
  END IF;

  RETURN QUERY SELECT TRUE, 'Response recorded successfully'::text,
                       v_participant_id, v_old_status_id, p_response_status_id;
EXCEPTION
  WHEN OTHERS THEN
    RETURN QUERY SELECT FALSE, ('Error: ' || SQLERRM)::text, NULL::bigint, NULL::int2, NULL::int2;
END;
$$;
