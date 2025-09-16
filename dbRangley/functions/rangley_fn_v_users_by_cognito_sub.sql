CREATE OR REPLACE FUNCTION rangley.rangley_fn_v_users_by_cognito_sub
(
     p_searching_cognito_sub  text
    ,p_usernames              text[] DEFAULT NULL
    ,p_emails                 text[] DEFAULT NULL
    ,p_phones                 text[] DEFAULT NULL
)
RETURNS table
(
    user_uuid     uuid,
    username      varchar(50),
    display_name  varchar(50),
    matched_by    text[],
    can_invite    boolean
)
LANGUAGE sql
STABLE
AS $$
WITH me AS (
  SELECT u.user_id
  FROM rangley.tb_users u
  WHERE u.cognito_sub = p_searching_cognito_sub
),
san AS (
  SELECT
    CASE WHEN p_usernames IS NULL THEN NULL
         ELSE ARRAY(SELECT lower(btrim(x)) FROM unnest(p_usernames) AS x) END AS usernames_san,
    CASE WHEN p_emails   IS NULL THEN NULL
         ELSE ARRAY(SELECT lower(btrim(x)) FROM unnest(p_emails)   AS x) END AS emails_san,
    CASE WHEN p_phones   IS NULL THEN NULL
         ELSE ARRAY(SELECT regexp_replace(x, '\D', '', 'g') FROM unnest(p_phones) AS x) END AS phones_san
),
rows AS (
  SELECT
      u.user_id,
      u.uuid,
      u.username,
      u.display_name,
      -- normalize DB phone to digits-only for matching
      regexp_replace(COALESCE(u.cellphone,''), '\D', '', 'g') AS phone_db,
      -- raw hits (inputs)
      (san.usernames_san IS NOT NULL AND lower(u.username) = ANY (san.usernames_san)) AS hit_username,
      (san.emails_san    IS NOT NULL AND lower(u.email)    = ANY (san.emails_san))    AS hit_email,
      (san.phones_san    IS NOT NULL) AS phones_were_supplied,
      -- privacy flags (defaults: username TRUE, email/phone FALSE)
      COALESCE(ps.discoverable_by_username, TRUE)  AS allow_username,
      COALESCE(ps.discoverable_by_email,    FALSE) AS allow_email,
      COALESCE(ps.discoverable_by_phone,    FALSE) AS allow_phone,
      san.phones_san
  FROM rangley.vw_users u
  LEFT JOIN rangley.tb_user_privacy_settings ps ON ps.user_id = u.user_id
  CROSS JOIN san
  WHERE NOT EXISTS (SELECT 1 FROM me WHERE me.user_id = u.user_id)
)
SELECT
    r.uuid AS user_uuid,
    r.username,
    r.display_name,
    ARRAY_REMOVE(ARRAY[
        CASE WHEN r.hit_username AND r.allow_username THEN 'username' END,
        CASE WHEN r.hit_email    AND r.allow_email    THEN 'email'    END,
        CASE WHEN r.phones_were_supplied
                  AND r.allow_phone
                  AND r.phone_db = ANY (r.phones_san) THEN 'phone' END
    ], NULL) AS matched_by,
    (
      (r.hit_username AND r.allow_username) OR
      (r.hit_email    AND r.allow_email)    OR
      (r.phones_were_supplied AND r.allow_phone AND r.phone_db = ANY (r.phones_san))
    ) AS can_invite
FROM rows r
WHERE
    (r.hit_username OR r.hit_email OR (r.phones_were_supplied AND r.phone_db = ANY (r.phones_san)))
  AND (
      (r.hit_username AND r.allow_username) OR
      (r.hit_email    AND r.allow_email)    OR
      (r.phones_were_supplied AND r.allow_phone AND r.phone_db = ANY (r.phones_san))
  )
ORDER BY lower(r.display_name), lower(r.username);
$$;
