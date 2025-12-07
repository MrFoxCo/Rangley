CREATE OR REPLACE FUNCTION rangley.rangley_fn_v_app_version
(
    p_app_version_int INT4
)
RETURNS TABLE (
    is_supported BOOLEAN,
    latest_version INT4,
    supported_features INT4[]
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_latest_version INT4;
    v_user_status_id INT2;
BEGIN
    -- Get the latest ACTIVE or PENDING version (status_id IN (1, 2))
    SELECT version INTO v_latest_version
    FROM rangley.td_versions
    WHERE status_id IN (1, 2)
    ORDER BY version DESC
    LIMIT 1;

    -- Check the status of the provided version
    SELECT status_id INTO v_user_status_id
    FROM rangley.td_versions
    WHERE version = p_app_version_int;

    -- Support both 'active' (1) and 'pending' (2) versions
    IF v_user_status_id IN (1, 2) THEN
        RETURN QUERY
        SELECT
            TRUE as is_supported,
            v_latest_version as latest_version,
            COALESCE(ARRAY_AGG(feature_id ORDER BY feature_id) FILTER (WHERE feature_id IS NOT NULL), ARRAY[]::INT4[]) as supported_features
        FROM rangley.te_version_features
        WHERE version = p_app_version_int;
    ELSE
        -- Version is deprecated (3) or doesn't exist (NULL)
        RETURN QUERY
        SELECT
            FALSE as is_supported,
            v_latest_version as latest_version,
            ARRAY[]::INT4[] as supported_features;
    END IF;
END;
$$;