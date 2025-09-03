-- DROP PROCEDURE IF EXISTS rangley.rangley_i_user(text, text, text, text, text, int4, int4);

CREATE OR REPLACE PROCEDURE rangley.rangley_i_user_by_auth_register
(
    
    -- OUTPUT Params
     OUT 	is_success 		boolean 

    -- INPUT Params
    ,IN     p_cognito_sub   text -- THE MOST IMPORTANT THING IT'S LIKE FOR SESSION TOKENS
    ,IN  	p_username   	varchar(50)
    ,IN  	p_display_name  varchar(50)
    ,IN  	p_cellphone  	varchar(16)
    ,IN  	p_email      	varchar(256)
    ,IN		p_dob			DATE
    
    ,IN     p_first_name 	varchar(50) default ''::varchar(50)
    ,IN     p_last_name 	varchar(50) default ''::varchar(50)
)
LANGUAGE plpgsql
/*

-- works
DO $$
DECLARE result boolean;
BEGIN
  CALL rangley.rangley_i_user_by_auth_register(
    result,
    'arn.asdfasdfa.com',
    'hthoreua',
    'h thoreua',
    '+17731239999',
    NULL,
    '1999-01-01',
    NULL,
    NULL
  );

END $$;

DO $$
DECLARE result boolean;
BEGIN
  CALL rangley.rangley_i_user_by_auth_register
  (
  	 result
    ,'a.asldjfalsdkj.banana'
    ,'HISISWORKING'
    ,'ORKING '
    ,'+10881112222'
    ,'baana@f.com'
    ,'1999-01-01'
    ,'trry'
    ,'lwson'
  );

END $$;

select * from rangley.vw_users;



*/
AS $procedure$
DECLARE
    v_digits 			text;
    v_e164   			text;
	email_reg_ex 		text := '^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$';
    _state text; _msg 	text; _detail text; _hint text; _ctx text;
BEGIN
    is_success := false;

    -- Required fields
    IF p_cognito_sub IS NULL OR p_username IS NULL OR p_display_name IS NULL OR p_dob IS NULL THEN
        RAISE EXCEPTION USING
        ERRCODE='22023',
        MESSAGE=
            '[ERRO] Missing one or more required fields [cognito_sub/username/display_name/dob]',
        DETAIL = format(
            'cognito_sub=%s username=%s display_name=%s dob=%s',
            p_cognito_sub, p_username, p_display_name, p_dob);
    END IF;

    -- Need at least one of email/cellphone
    IF (p_email IS NULL OR btrim(p_email) = '')
        AND (p_cellphone IS NULL OR btrim(p_cellphone) = '') THEN
        RAISE EXCEPTION USING
            ERRCODE='22023', MESSAGE='[ERRO] Provide at least one of email or cellphone';
    END IF;

    -- Normalize core fields
    p_cognito_sub  := NULLIF(btrim(p_cognito_sub), '');
    p_username     := lower(NULLIF(btrim(p_username), ''));
    p_display_name := NULLIF(btrim(p_display_name), '');

    -- Names: optional, store empty string (avoids NOT NULL hits)
    p_first_name   := COALESCE(btrim(p_first_name), '');
    p_last_name    := COALESCE(btrim(p_last_name),  '');

    -- Email
    IF p_email IS NOT NULL AND btrim(p_email) <> '' THEN
        p_email := lower(btrim(p_email));
        IF p_email !~* email_reg_ex THEN
            RAISE EXCEPTION USING
            ERRCODE='22023',
            MESSAGE='[ERRO] Email format looks invalid',
            DETAIL = format('email=%s', p_email),
            HINT   = 'Expected like name@example.com';
        END IF;
    ELSE
        p_email := NULL;
    END IF;

    -- Phone → E.164
    IF p_cellphone IS NOT NULL AND btrim(p_cellphone) <> '' THEN
        v_digits := regexp_replace(p_cellphone, '\D', '', 'g');
        IF length(v_digits) = 10 THEN
            v_e164 := '+1' || v_digits;
        ELSIF length(v_digits) = 11 AND substr(v_digits,1,1) = '1' THEN
            v_e164 := '+' || v_digits;
        ELSIF length(v_digits) BETWEEN 8 AND 15 AND substr(v_digits,1,1) <> '0' THEN
            v_e164 := '+' || v_digits;
        ELSE
            RAISE EXCEPTION USING
            ERRCODE='22023',
            MESSAGE='[ERRO] Cellphone invalid',
            DETAIL = format('raw=%s; digits=%s', p_cellphone, v_digits),
            HINT   = 'Expect E.164 format, example: +13125550123';
        END IF;
    ELSE
        v_e164 := NULL;
    END IF;

    -- DOB checks
    IF p_dob > CURRENT_DATE THEN
        RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='[ERRO] DOB cannot be in the future';
    END IF;
    IF p_dob > CURRENT_DATE - INTERVAL '13 years' THEN
        	RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='[ERRO] Must be at least 13 years old';
    END IF;

    -- Friendly uniqueness preflight
    IF EXISTS (SELECT 1 FROM rangley.tb_users WHERE lower(username)=p_username) THEN
    	RAISE EXCEPTION USING ERRCODE='23505', MESSAGE='[ERRO] Username already taken', DETAIL = format('username=%s', p_username);
    END IF;
    IF p_email IS NOT NULL AND EXISTS (SELECT 1 FROM rangley.tb_users WHERE lower(email)=p_email) THEN
    	RAISE EXCEPTION USING ERRCODE='23505', MESSAGE='[ERRO] Email already in use', DETAIL = format('email=%s', p_email);
    END IF;
    IF v_e164 IS NOT NULL AND EXISTS (SELECT 1 FROM rangley.tb_users WHERE cellphone=v_e164) THEN
        	RAISE EXCEPTION USING ERRCODE='23505', MESSAGE='[ERRO] Cellphone already in use', DETAIL = format('cellphone=%s', v_e164);
    END IF;


	-- insert (respect unique on cognito_sub)
	INSERT INTO rangley.tb_users
    (
		 cognito_sub
		,username
		,display_name
		,first_name
		,last_name
		,cellphone
		,email
		,dob
	)
  	VALUES
    (
		 p_cognito_sub
		,p_username
		,p_display_name
		,p_first_name
		,p_last_name
		,v_e164
		,p_email
		,p_dob
	)
	RETURNING user_id INTO v_user_id;
	
	GET DIAGNOSTICS v_rows = ROW_COUNT;   -- 1 = inserted, 0 = conflict/no insert
	
	IF v_rows = 0 THEN
	  SELECT user_id INTO v_user_id
	  FROM rangley.tb_users
	  WHERE cognito_sub = p_cognito_sub;
	END IF;
	
	RAISE LOG '[INFO] auth_register rows=% user_id=% sub=% username=%',
	  v_rows, COALESCE(v_user_id,-1), p_cognito_sub, p_username;

EXCEPTION
    WHEN OTHERS THEN
    -- optional: capture for logging
        GET STACKED DIAGNOSTICS
          _state  = RETURNED_SQLSTATE,
          _msg    = MESSAGE_TEXT,
          _detail = PG_EXCEPTION_DETAIL,
          _hint   = PG_EXCEPTION_HINT,
          _ctx    = PG_EXCEPTION_CONTEXT;

        RAISE LOG '[ERRO] %: % | detail: % | hint: % | ctx: %',
          _state, _msg, COALESCE(_detail,'(none)'),
          COALESCE(_hint,'(none)'), COALESCE(_ctx,'(none)');

        RAISE;  -- rethrow EXACTLY the same error

END;
$procedure$;