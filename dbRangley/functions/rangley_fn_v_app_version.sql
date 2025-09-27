CREATE OR REPLACE FUNCTION rangley.rangley_fn_v_app_version
(
    p_app_version_int INT4
)
RETURNS TABLE (
    is_supported 		BOOLEAN,
    latest_version 		INT4,
    supported_features 	INT4[]
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_latest_version INT4;
BEGIN
    -- Get the latest version available
    SELECT MAX(version) INTO v_latest_version
    FROM rangley.vw_version_features;
    
    -- Check if the provided version is supported
    IF EXISTS (SELECT 1 FROM rangley.vw_version_features WHERE version = p_app_version_int) THEN
        -- Version is supported - return features for this version
        RETURN QUERY
        SELECT 
            TRUE as is_supported,
            v_latest_version as latest_version,
            ARRAY_AGG(feature_id ORDER BY feature_id) as supported_features
        FROM rangley.vw_version_features 
        WHERE version = p_app_version_int;
    ELSE
        -- Version not supported
        RETURN QUERY
        SELECT 
            FALSE as is_supported,
            v_latest_version as latest_version,
            ARRAY[]::INT4[] as supported_features;
    END IF;
END;
$$;

-- Test the function with version 1.0.0 (10000)
--SELECT * FROM rangley.rangley_fn_v_app_version(10000);
--
-- Test with unsupported version 0.9.0 (9000) 
--SELECT * FROM rangley.rangley_fn_v_app_version(9000);