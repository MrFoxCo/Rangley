-- ============================================
-- UPDATE MEET GROUP IMAGE
-- ============================================
CREATE OR REPLACE FUNCTION rangley.rgl_fn_m_meet_group_image
(
    p_cognito_sub TEXT,
    p_meet_group_id INT8,
    p_image_reference TEXT
)
RETURNS TABLE
(
    success BOOLEAN,
    message TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_user_id INT8;
    v_group_owner_id INT8;
BEGIN
    -- Get user ID
    SELECT user_id INTO v_user_id
    FROM rangley.vw_users
    WHERE cognito_sub = p_cognito_sub;

    IF v_user_id IS NULL THEN
        RETURN QUERY SELECT FALSE, 'User not found'::TEXT;
        RETURN;
    END IF;

    -- Verify group exists and user owns it
    SELECT created_by_user_id INTO v_group_owner_id
    FROM rangley.vw_meet_groups
    WHERE meet_group_id = p_meet_group_id;

    IF v_group_owner_id IS NULL THEN
        RETURN QUERY SELECT FALSE, 'Meet group not found'::TEXT;
        RETURN;
    END IF;

    IF v_group_owner_id != v_user_id THEN
        RETURN QUERY SELECT FALSE, 'You do not own this meet group'::TEXT;
        RETURN;
    END IF;

    -- Verify the asset exists (for stock images only)
    IF NOT EXISTS (
        SELECT 1 FROM rangley.vw_stock_assets 
        WHERE asset_name = p_image_reference 
        AND asset_category = 'meet_group'
        AND is_active = TRUE
    ) THEN
        RETURN QUERY SELECT FALSE, 'Invalid image reference'::TEXT;
        RETURN;
    END IF;

    -- Update image (always stock for now)
    UPDATE rangley.tb_meet_groups
    SET image_type = 'stock',
        image_reference = p_image_reference,
        image_url = NULL,
        dttm_modified_utc = now()
    WHERE meet_group_id = p_meet_group_id;

    RETURN QUERY SELECT TRUE, 'Group image updated successfully'::TEXT;

EXCEPTION
    WHEN OTHERS THEN
        RETURN QUERY SELECT FALSE, ('Error: ' || SQLERRM)::TEXT;
END;
$$;