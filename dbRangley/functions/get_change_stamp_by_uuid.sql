CREATE OR REPLACE FUNCTION rangley.get_change_stamp_by_uuid(p_change_stamp_uuid UUID)
RETURNS TABLE
(
    change_stamp INT8
)
LANGUAGE plpgsql
STABLE
AS $fn$
/*
Example usage:
select uuid from rangley.vw_change_stamps();
select * from rangley.get_change_stamp_by_uuid('your-uuid-here');
*/
DECLARE
    v_rid UUID := gen_random_uuid(); -- for log correlation
    v_result_count INT;
BEGIN

    -- validate input
    IF p_change_stamp_uuid IS NULL THEN
        RAISE LOG '[ERRO][rid=%] invalid change_stamp_uuid: NULL', v_rid;
        RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='[ERRO] invalid change_stamp_uuid (cannot be NULL)';
    END IF;

    -- perform lookup and return results
    RETURN QUERY
    SELECT cs.change_stamp
    FROM rangley.vw_change_stamps cs
    WHERE cs.uuid = p_change_stamp_uuid;
    
    -- check if we found any results
    GET DIAGNOSTICS v_result_count = ROW_COUNT;
    
    IF v_result_count = 0 THEN
        RAISE LOG '[ERRO][rid=%] change_stamp_uuid:[%] not found.', v_rid, p_change_stamp_uuid;
        RAISE EXCEPTION USING ERRCODE='P0002', MESSAGE='[ERRO] change_stamp_uuid not found';
    END IF;
    
    RAISE LOG '[INFO][rid=%] returned change_stamp for uuid:[%]', v_rid, p_change_stamp_uuid;

END;
$fn$;