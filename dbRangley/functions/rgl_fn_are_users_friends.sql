CREATE OR REPLACE FUNCTION rangley.rgl_fn_are_users_friends(
    p_user_id_1 INT8,
    p_user_id_2 INT8
) RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 
        FROM rangley.tb_friendships
        WHERE (user_id_a = LEAST(p_user_id_1, p_user_id_2)
           AND user_id_b = GREATEST(p_user_id_1, p_user_id_2))
    );
END;
$$;