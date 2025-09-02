do $$
declare
result int;
begin
	CALL rangley.rangley_m_user
	(
		 result
		,4
		,NULL
		,'Macthew'
		,NULL
		,NULL
		,NULL
		,NULL
		,NULL
	);
end $$;

select * from rangley.vw_users;