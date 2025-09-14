CREATE OR REPLACE FUNCTION rangley.rangley_fn_v_meet_id_by_meet_id_uuid(p_meet_id_uuid UUID)
RETURNS TABLE
(
    meet_id INT8
)
LANGUAGE plpgsql
STABLE
AS $fn$
DECLARE
    v_rid UUID := gen_random_uuid(); -- for log correlation
BEGIN

    -- validate input
    IF p_meet_id_uuid IS NULL THEN
        RAISE LOG '[ERRO][rid=%] invalid meet_id_uuid: NULL', v_rid;
        RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='[ERRO] invalid meet_id_uuid (cannot be NULL)';
    END IF;

    -- validate existence (use the view to honor any filters/soft-deletes)
    IF NOT EXISTS (SELECT 1 FROM rangley.vw_meet_ids v WHERE v.uuid = p_meet_id_uuid) THEN
        RAISE LOG '[ERRO][rid=%] meet_id_uuid:[%] not found.', v_rid, p_meet_id_uuid;
        RAISE EXCEPTION USING ERRCODE='P0002', MESSAGE='[ERRO] meet_id_uuid not found';
    END IF;

    -- return row
    RETURN QUERY
    SELECT mi.meet_id
    FROM rangley.vw_meet_ids mi
    WHERE mi.uuid = p_meet_id_uuid;

    RAISE LOG '[INFO][rid=%] returned meet_id for uuid:[%]', v_rid, p_meet_id_uuid;

END;
$fn$;