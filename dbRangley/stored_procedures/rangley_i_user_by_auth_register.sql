-- DROP PROCEDURE IF EXISTS rangley.rangley_i_user(text, text, text, text, text, int4, int4);

CREATE OR REPLACE PROCEDURE rangley.rangley_i_by_auth_register
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
AS $procedure$
DECLARE
    v_digits 			text;
    v_e164   			text;
	email_proof_reg_ex 	text := '^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$';
    _state text; _msg 	text; _detail text; _hint text; _ctx text;
BEGIN
    -- OUT sentinel
    is_success := false;

    IF p_email IS NULL AND p_cellphone IS NULL THEN
        RAISE LOG '[ERRO] Insert aborted: neither email nor cellphone provided';
        RAISE EXCEPTION USING
            ERRCODE = '22023',
            MESSAGE = '[ERRO] Provide at least one of email or cellphone';
    ELSE
        p_email 	:= lower(NULLIF(btrim(p_email),''));
        p_cellphone := NULLIF(btrim(p_cellphone),'');

	    -- Clean Email and Cellphone formats whicever is present
	    IF p_email IS NOT NULL AND p_email !~* email_proof_reg_ex THEN
	        RAISE LOG '[ERRO] Bad email format: email=%', p_email;
	        RAISE EXCEPTION USING
	            ERRCODE = '22023',
	            MESSAGE = '[ERRO] Email format looks invalid',
	            DETAIL  = format('email=%s', p_email),
	            HINT    = 'Expected like name@example.com';
	    END IF;
	
	    IF p_cellphone IS NOT NULL THEN
	        v_digits := regexp_replace(p_cellphone, '\D', '', 'g');
	        IF length(v_digits) = 10 THEN
	            v_e164 := '+1' || v_digits;
	        ELSIF length(v_digits) = 11 AND substr(v_digits,1,1) = '1' THEN
	            v_e164 := '+' || v_digits;
	        ELSIF length(v_digits) BETWEEN 8 AND 15 AND substr(v_digits,1,1) <> '0' THEN
	            v_e164 := '+' || v_digits;
	        ELSE
	            RAISE LOG '[ERRO] Bad phone format: raw=% digits=%',
					p_cellphone, v_digits;
	            RAISE EXCEPTION USING
	                ERRCODE = '22023',
	                MESSAGE = '[ERRO] Cellphone invalid',
	                DETAIL  = format('raw=%s; digits=%s', p_cellphone, v_digits),
	                HINT    = 'Expect E.164 format, example: +13125550123';
	        END IF;
	    END IF;

    END IF;

    -- ===== Required core fields
    IF 	   p_cognito_sub 	IS NULL 
		OR p_username 		IS NULL 
		OR p_display_name 	IS NULL 
		OR p_dob 			IS NULL THEN
        RAISE LOG '[ERRO] Insert aborted: missing required fields';
        RAISE EXCEPTION USING
            ERRCODE = '22023',
            MESSAGE = 
			E'[ERRO] Missing one or more required fields [username/display_name/dob]',
            DETAIL  = format('username=%s display_name=%s dob=%s',
				p_cognito_sub, p_username, p_display_name, p_dob),
            HINT    = 'Provide all required fields.';
    END IF;

    -- ===== Normalize (empty -> NULL where appropriate)
    IF p_cognito_sub  IS NOT NULL THEN 
		p_cognito_sub  := NULLIF(btrim(p_cognito_sub),  ''); END IF;
    IF p_username     IS NOT NULL THEN 
		p_username     := lower(NULLIF(btrim(p_username),'')); 	END IF;
    IF p_display_name IS NOT NULL THEN 
		p_display_name := NULLIF(btrim(p_display_name),''); 	END IF;
    IF p_first_name   IS NOT NULL THEN 
		p_first_name   := NULLIF(btrim(p_first_name),  ''); END IF;
    IF p_last_name    IS NOT NULL THEN 
		p_last_name    := NULLIF(btrim(p_last_name),   ''); END IF;

    -- DOB checks (table also has a CHECK; this keeps app errors friendly)
    IF p_dob > CURRENT_DATE THEN
        RAISE LOG '[ERRO] DOB in future: dob=%', p_dob;
        RAISE EXCEPTION USING 
			ERRCODE='22023', MESSAGE='[ERRO] DOB cannot be in the future';
    END IF;
    IF p_dob > CURRENT_DATE - INTERVAL '13 years' THEN
        RAISE LOG '[ERRO] Underage: dob=%', p_dob;
        RAISE EXCEPTION USING 
			ERRCODE='22023', MESSAGE='[ERRO] Must be at least 13 years old';
    END IF;

    -- Optional preflight (friendlier than pure unique_violation; DB still the backstop)
    IF EXISTS (SELECT 1 FROM rangley.tb_users WHERE lower(username)=p_username) THEN
        RAISE EXCEPTION USING ERRCODE='23505',
            MESSAGE='[ERRO] Username already taken',
            DETAIL = format('username=%s', p_username),
            HINT   = 'Pick a different username.';
    END IF;

    IF p_email IS NOT NULL AND EXISTS
	(SELECT 1 FROM rangley.tb_users WHERE lower(email)=p_email) THEN
        RAISE EXCEPTION USING ERRCODE='23505',
            MESSAGE='[ERRO] Email already in use',
            DETAIL = format('email=%s', p_email),
            HINT   = 'Use a different email.';
    END IF;

    IF v_e164 IS NOT NULL AND EXISTS
	(SELECT 1 FROM rangley.tb_users WHERE cellphone=v_e164) THEN
        RAISE EXCEPTION USING ERRCODE='23505',
            MESSAGE='[ERRO] Cellphone already in use',
            DETAIL = format('cellphone=%s', v_e164),
            HINT   = 'Use a different number.';
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
	ON CONFLICT (cognito_sub) DO NOTHING;

	RAISE LOG '[INFO] User Inserted';
	is_success := true;

EXCEPTION
    WHEN unique_violation THEN
        GET STACKED DIAGNOSTICS
            _state=RETURNED_SQLSTATE, _msg=MESSAGE_TEXT,
            _detail=PG_EXCEPTION_DETAIL, 
			_hint=PG_EXCEPTION_HINT, _ctx=PG_EXCEPTION_CONTEXT;

        RAISE LOG '[ERRO] unique_violation (%): % | detail: % | hint: % | ctx: %',
            _state, _msg, 
			COALESCE(_detail,'(none)'), 
			COALESCE(_hint,'(none)'), COALESCE(_ctx,'(none)');

        RAISE EXCEPTION USING
            ERRCODE = _state,
            MESSAGE = '[ERRO] Duplicate detected inserting tb_users',
            DETAIL  = COALESCE(_detail,'(none)'),
            HINT    = COALESCE(_hint, 
					'Check unique constraints [cognito_sub/username/email/cellphone]');

    WHEN check_violation THEN
        GET STACKED DIAGNOSTICS
            _state=RETURNED_SQLSTATE, _msg=MESSAGE_TEXT,
            _detail=PG_EXCEPTION_DETAIL, 
			_hint=PG_EXCEPTION_HINT, _ctx=PG_EXCEPTION_CONTEXT;

        RAISE LOG '[ERRO] check_violation (%): % | detail: % | hint: % | ctx: %',
            _state, _msg, 
			COALESCE(_detail,'(none)'), 
			COALESCE(_hint,'(none)'), COALESCE(_ctx,'(none)');

        RAISE EXCEPTION USING
            ERRCODE = _state,
            MESSAGE = '[ERRO] Row failed a CHECK constraint inserting tb_users',
            DETAIL  = COALESCE(_detail,'(none)'),
            HINT    = COALESCE(_hint, 'Review table constraints and input values.');

    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS
            _state=RETURNED_SQLSTATE, _msg=MESSAGE_TEXT,
            _detail=PG_EXCEPTION_DETAIL, 
			_hint=PG_EXCEPTION_HINT, _ctx=PG_EXCEPTION_CONTEXT;

        RAISE LOG '[ERRO] unhandled_exception (%): % | detail: % | hint: % | ctx: %',
            _state, _msg, 
			COALESCE(_detail,'(none)'), 
			COALESCE(_hint,'(none)'), COALESCE(_ctx,'(none)');

        RAISE EXCEPTION USING
            ERRCODE = _state,
            MESSAGE = '[ERRO] Unexpected failure in rangley_i_auth_register',
            DETAIL  = COALESCE(_detail,'(none)'),
            HINT    = COALESCE(_hint, 'Check server logs for full context.');
END;
$procedure$;