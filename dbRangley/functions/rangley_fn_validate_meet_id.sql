
CREATE OR REPLACE FUNCTION rangley.rangley_fn_validate_meet_id(p_meet_status_id bigint)
RETURNS int
LANGUAGE plpgsql
AS $$
DECLARE
  num_returned int := 0;
BEGIN
  SELECT COUNT(*) INTO num_returned
  FROM rangley.vw_meet_ids
  WHERE meet_id = p_meet_status_id;

  IF num_returned = 0 THEN
    RETURN -1;            -- not found
  END IF;

  RETURN 1;               -- found
END;
$$;
