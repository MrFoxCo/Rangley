CREATE OR REPLACE FUNCTION rangley.rgl_fn_v_user_profile_by_uuid
(
    p_user_uuid uuid
)
RETURNS table
(
    user_uuid               	uuid,
    username                	varchar(50),
    display_name            	varchar(50),
    member_since            	timestamptz,
    meets_created           	INT8,
    meets_attended          	INT8,
    friend_count            	INT8,
    discoverable_by_username 	boolean,
    discoverable_by_phone   	boolean,
    discoverable_by_email   	boolean,
    show_full_name          	boolean,
    allow_invites_from_anyone 	boolean
)
LANGUAGE sql
STABLE
AS $$
    SELECT 
         user_uuid
        ,username
        ,display_name
        ,member_since
        ,meets_created
        ,meets_attended
        ,friend_count
        ,discoverable_by_username
        ,discoverable_by_phone
        ,discoverable_by_email
        ,show_full_name
        ,allow_invites_from_anyone
    FROM rangley.vw_user_profile
    WHERE user_uuid = p_user_uuid;
$$;