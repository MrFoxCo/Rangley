do $$
declare
result boolean;
begin
	CALL rangley.rangley_i_user_by_auth_register
	(
		 result::boolean
		,'arn.fbana.com'::text
		,'ivanakatikinabagovinanana'::varchar(50)
		,'ivanakatikina bagovinanana'::varchar(50)
		,'+17731237777'::varchar(16)
		,'a@a.com'::varchar(256)
		,'1999-01-01'::date
		,NULL::varchar(50)
		,NULL::varchar(50)
	);
end $$;



DO $$
DECLARE result boolean;
BEGIN
  CALL rangley.rangley_i_user_by_auth_register(
    result,
    'arn.fbana.com',
    'carlsbad',
    'carls bad',
    '+17331237777',
    NULL,
    '1999-01-01',
    NULL,
    NULL
  );

END $$;



select * from rangley.vw_users;


/*

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
*/