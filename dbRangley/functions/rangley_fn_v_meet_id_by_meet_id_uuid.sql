CREATE OR REPLACE FUNCTION rangley.get_meet_id_by_uuid(p_meet_id_uuid UUID)
RETURNS TABLE
(
    meet_id INT8
)
LANGUAGE plpgsql
STABLE
AS $fn$
/*
Example usage:
select uuid from rangley.vw_meets();
select * from rangley.get_meet_id_by_uuid('your-uuid-here');
*/
DECLARE
    v_rid UUID := gen_random_uuid(); -- for log correlation
    v_result_count INT;
BEGIN

    -- validate input
    IF p_meet_id_uuid IS NULL THEN
        RAISE LOG '[ERRO][rid=%] invalid meet_id_uuid: NULL', v_rid;
        RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='[ERRO] invalid meet_id_uuid (cannot be NULL)';
    END IF;

    -- perform lookup and return results
    RETURN QUERY
    SELECT mi.meet_id
    FROM rangley.vw_meet_ids mi
    WHERE mi.uuid = p_meet_id_uuid;
    
    -- check if we found any results
    GET DIAGNOSTICS v_result_count = ROW_COUNT;
    
    IF v_result_count = 0 THEN
        RAISE LOG '[ERRO][rid=%] meet_id_uuid:[%] not found.', v_rid, p_meet_id_uuid;
        RAISE EXCEPTION USING ERRCODE='P0002', MESSAGE='[ERRO] meet_id_uuid not found';
    END IF;
    
    RAISE LOG '[INFO][rid=%] returned meet_id for uuid:[%]', v_rid, p_meet_id_uuid;

END;
$fn$;