-- ============================================
-- CLEANUP: REMOVE UNFRIENDED USERS FROM GROUPS
-- ============================================
CREATE OR REPLACE FUNCTION rangley.rgl_fn_cleanup_friend_groups_on_unfriend
(
    p_user_id_a INT8,
    p_user_id_b INT8
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
    -- Remove user_id_b from all of user_id_a's groups
    DELETE FROM rangley.tb_friend_group_members
    WHERE friend_group_id IN (
        SELECT friend_group_id 
        FROM rangley.tb_friend_groups 
        WHERE created_by_user_id = p_user_id_a
    )
    AND user_id = p_user_id_b;
    
    -- Remove user_id_a from all of user_id_b's groups
    DELETE FROM rangley.tb_friend_group_members
    WHERE friend_group_id IN (
        SELECT friend_group_id 
        FROM rangley.tb_friend_groups 
        WHERE created_by_user_id = p_user_id_b
    )
    AND user_id = p_user_id_a;
END;
$$;