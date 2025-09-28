-- Function to validate display names for profanity and inappropriate content
-- Returns JSON with validation status and optional message
-- Display names don't need to be unique but must be appropriate

CREATE OR REPLACE FUNCTION rangley.rgl_fn_validate_display_name(
    p_display_name TEXT
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_result JSON;
    v_display_name_clean TEXT;
    v_display_name_lower TEXT;
BEGIN
    -- Trim whitespace but preserve case and internal spaces
    v_display_name_clean := TRIM(p_display_name);
    v_display_name_lower := LOWER(v_display_name_clean);
    
    -- Basic validation
    IF v_display_name_clean IS NULL OR LENGTH(v_display_name_clean) = 0 THEN
        RETURN json_build_object(
            'valid', FALSE,
            'reason', 'display_name_empty',
            'message', 'Display name cannot be empty'
        );
    END IF;
    
    -- Check minimum length
    IF LENGTH(v_display_name_clean) < 1 THEN
        RETURN json_build_object(
            'valid', FALSE,
            'reason', 'display_name_too_short',
            'message', 'Display name must be at least 1 character'
        );
    END IF;
    
    -- Check maximum length (more generous than username)
    IF LENGTH(v_display_name_clean) > 50 THEN
        RETURN json_build_object(
            'valid', FALSE,
            'reason', 'display_name_too_long',
            'message', 'Display name must be 50 characters or less'
        );
    END IF;
    
    -- Check for excessive whitespace (more than 2 consecutive spaces)
    IF v_display_name_clean ~ '\s{3,}' THEN
        RETURN json_build_object(
            'valid', FALSE,
            'reason', 'display_name_excessive_whitespace',
            'message', 'Display name cannot contain excessive whitespace'
        );
    END IF;
    
    -- Check for leading/trailing whitespace (should be trimmed already, but double-check)
    IF v_display_name_clean ~ '^\s|\s$' THEN
        RETURN json_build_object(
            'valid', FALSE,
            'reason', 'display_name_whitespace_edges',
            'message', 'Display name cannot start or end with spaces'
        );
    END IF;
    
    -- Check for control characters and other problematic Unicode
    IF v_display_name_clean ~ '[\x00-\x1F\x7F-\x9F]' THEN
        RETURN json_build_object(
            'valid', FALSE,
            'reason', 'display_name_control_chars',
            'message', 'Display name contains invalid characters'
        );
    END IF;
    
    -- Check against explicit profanity and inappropriate content
    IF v_display_name_lower ~ '\b(fuck|shit|bitch|damn|hell|ass|bastard|slut|whore|fag|retard|nigger|chink|spic|cunt|cock|dick|penis|vagina|pussy|tits|boobs|sex|porn|xxx|nude|naked)\b' THEN
        RAISE LOG 'Rejected inappropriate display name: %', v_display_name_clean;
        RETURN json_build_object(
            'valid', FALSE,
            'reason', 'display_name_inappropriate',
            'message', 'Display name contains inappropriate content'
        );
    END IF;
    
    -- Check for common profanity obfuscations (more permissive than username)
    IF v_display_name_lower ~ 'f[u_0*][c_*][k_*]|sh[i1!][t7]|b[i1!]tch|[a@4]ss[h]?[o0]le|d[a@4]mn|h[e3]ll|wh[o0]r[e3]|sl[u_][t7]|n[i1!]gg[e3a@]r|f[a@4]g{1,2}[o0e3]?t|r[e3]t[a@4]rd' THEN
        RAISE LOG 'Rejected obfuscated inappropriate display name: %', v_display_name_clean;
        RETURN json_build_object(
            'valid', FALSE,
            'reason', 'display_name_inappropriate',
            'message', 'Display name contains inappropriate content'
        );
    END IF;
    
    -- Check for violent or threatening content
    IF v_display_name_lower ~ '\b(kill|murder|rape|terrorist|bomb|gun|shoot|stab|hate|nazi|hitler|isis|jihad|suicide)\b' THEN
        RAISE LOG 'Rejected violent display name: %', v_display_name_clean;
        RETURN json_build_object(
            'valid', FALSE,
            'reason', 'display_name_violent',
            'message', 'Display name contains inappropriate content'
        );
    END IF;
    
    -- Check for drug-related content
    IF v_display_name_lower ~ '\b(cocaine|heroin|meth|crack|weed|marijuana|cannabis|drug|drugs|dealer|addict|high|stoned|blazed)\b' THEN
        RAISE LOG 'Rejected drug-related display name: %', v_display_name_clean;
        RETURN json_build_object(
            'valid', FALSE,
            'reason', 'display_name_inappropriate',
            'message', 'Display name contains inappropriate content'
        );
    END IF;
    
    -- Check for impersonation attempts (official roles/titles)
    IF v_display_name_lower ~ '\b(admin|administrator|moderator|mod|staff|official|rangley|support|founder|ceo|manager|employee|representative|team)\b' THEN
        RAISE LOG 'Rejected impersonation attempt in display name: %', v_display_name_clean;
        RETURN json_build_object(
            'valid', FALSE,
            'reason', 'display_name_impersonation',
            'message', 'Display name cannot impersonate official roles'
        );
    END IF;
    
    -- Check for contact information (prevent doxxing/spam)
    IF v_display_name_lower ~ '\b(\+?[1-9][0-9]{7,14}|[0-9]{10})\b' THEN
        RETURN json_build_object(
            'valid', FALSE,
            'reason', 'display_name_contains_phone',
            'message', 'Display name cannot contain phone numbers'
        );
    END IF;
    
    IF v_display_name_lower ~ '\b[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}\b' THEN
        RETURN json_build_object(
            'valid', FALSE,
            'reason', 'display_name_contains_email',
            'message', 'Display name cannot contain email addresses'
        );
    END IF;
    
    -- Check for URLs/links
    IF v_display_name_lower ~ '\b(https?://|www\.|\.com|\.org|\.net|\.gov|\.edu)\b' THEN
        RETURN json_build_object(
            'valid', FALSE,
            'reason', 'display_name_contains_url',
            'message', 'Display name cannot contain URLs or web addresses'
        );
    END IF;
    
    -- Check for excessive repetition (aaaaaaa, 1111111, etc.)
    IF v_display_name_clean ~ '(.)\1{6,}' THEN
        RETURN json_build_object(
            'valid', FALSE,
            'reason', 'display_name_excessive_repetition',
            'message', 'Display name cannot contain excessive character repetition'
        );
    END IF;
    
    -- Check for only numbers (might be confused with IDs)
    IF v_display_name_clean ~ '^[0-9\s]+$' THEN
        RETURN json_build_object(
            'valid', FALSE,
            'reason', 'display_name_only_numbers',
            'message', 'Display name cannot contain only numbers'
        );
    END IF;
    
    -- Check for only special characters
    IF v_display_name_clean ~ '^[^a-zA-Z0-9\s]+$' THEN
        RETURN json_build_object(
            'valid', FALSE,
            'reason', 'display_name_only_special_chars',
            'message', 'Display name must contain at least one letter or number'
        );
    END IF;
    
    -- Display name is valid
    RETURN json_build_object(
        'valid', TRUE,
        'reason', 'display_name_valid',
        'message', 'Display name is acceptable'
    );
    
EXCEPTION
    WHEN OTHERS THEN
        -- Log the error but don't expose internal details
        RAISE LOG 'Error in fn_validate_display_name: %', SQLERRM;
        RETURN json_build_object(
            'valid', FALSE,
            'reason', 'validation_failed',
            'message', 'Unable to validate display name'
        );
END;
$$;

-- Grant execute permission to your app role
-- GRANT EXECUTE ON FUNCTION rangley.fn_validate_display_name(TEXT) TO your_app_role;

-- Example usage:
-- SELECT rangley.fn_validate_display_name('John Smith'); -- valid
-- SELECT rangley.fn_validate_display_name('Admin User'); -- impersonation
-- SELECT rangley.fn_validate_display_name('F*ck This'); -- profanity
-- SELECT rangley.fn_validate_display_name('Call me at 555-1234'); -- contact info
-- SELECT rangley.fn_validate_display_name(''); -- empty
-- SELECT rangley.fn_validate_display_name('aaaaaaaaa'); -- excessive repetition