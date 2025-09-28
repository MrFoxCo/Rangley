-- Function to check if a username is available
-- Returns JSON with availability status and optional message

CREATE OR REPLACE FUNCTION rangley.rgl_fn_check_username_availability(
    p_username TEXT
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_result JSON;
    v_exists BOOLEAN := FALSE;
    v_username_clean TEXT;
BEGIN
    -- Normalize the username (trim whitespace, lowercase)
    v_username_clean := LOWER(TRIM(p_username));
    
    -- Basic validation
    IF v_username_clean IS NULL OR LENGTH(v_username_clean) = 0 THEN
        RETURN json_build_object(
            'available', FALSE,
            'reason', 'username_empty',
            'message', 'Username cannot be empty'
        );
    END IF;
    
    -- Check minimum length (adjust as needed)
    IF LENGTH(v_username_clean) < 3 THEN
        RETURN json_build_object(
            'available', FALSE,
            'reason', 'username_too_short',
            'message', 'Username must be at least 3 characters'
        );
    END IF;
    
    -- Check maximum length (adjust as needed)
    IF LENGTH(v_username_clean) > 30 THEN
        RETURN json_build_object(
            'available', FALSE,
            'reason', 'username_too_long',
            'message', 'Username must be 30 characters or less'
        );
    END IF;
    
    -- Check for valid characters (alphanumeric, underscore, hyphen)
    IF v_username_clean !~ '^[a-z0-9_-]+$' THEN
        RETURN json_build_object(
            'available', FALSE,
            'reason', 'username_invalid_chars',
            'message', 'Username can only contain letters, numbers, underscores, and hyphens'
        );
    END IF;
    
    -- Check for leading/trailing underscores or hyphens
    IF v_username_clean ~ '^[_-]|[_-]$' THEN
        RETURN json_build_object(
            'available', FALSE,
            'reason', 'username_invalid_format',
            'message', 'Username cannot start or end with underscore or hyphen'
        );
    END IF;
    
    -- Check for consecutive special characters
    IF v_username_clean ~ '[_-]{2,}' THEN
        RETURN json_build_object(
            'available', FALSE,
            'reason', 'username_invalid_format',
            'message', 'Username cannot contain consecutive underscores or hyphens'
        );
    END IF;
    
    -- Check if username looks like a phone number (improved regex)
    IF v_username_clean ~ '^(\+?[1-9][0-9]{7,14}|[0-9]{10})$' THEN
        RETURN json_build_object(
            'available', FALSE,
            'reason', 'username_looks_like_phone',
            'message', 'Username cannot resemble a phone number'
        );
    END IF;
    
    -- Check if username looks like an email (improved regex)
    IF v_username_clean ~ '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$' THEN
        RETURN json_build_object(
            'available', FALSE,
            'reason', 'username_looks_like_email',
            'message', 'Username cannot resemble an email address'
        );
    END IF;
    
    -- Check against reserved/restricted usernames
    IF v_username_clean = ANY(ARRAY[
        -- App-specific reserved names
        'rangley', 'admin', 'administrator', 'moderator', 'mod', 'support', 'help',
        'official', 'staff', 'team', 'founder', 'ceo', 'api', 'app', 'bot',
        'system', 'service', 'notification', 'notifications', 'noreply', 'no-reply',
        'info', 'contact', 'feedback', 'security', 'privacy', 'legal', 'terms',
        'welcome', 'onboarding', 'guest', 'user', 'test', 'demo', 'example',
        'null', 'undefined', 'anonymous', 'anon', 'public', 'private',
        
        -- Technical/security terms
        'root', 'sudo', 'superuser', 'www', 'ftp', 'mail', 'email', 'smtp',
        'http', 'https', 'ssl', 'tls', 'dns', 'cdn', 'cache', 'config',
        'database', 'db', 'sql', 'backup', 'logs', 'analytics', 'metrics',
        'webhook', 'endpoint', 'server', 'cluster', 'node', 'localhost',
        
        -- Social platform patterns
        'discover', 'explore', 'trending', 'popular', 'featured', 'promoted',
        'verified', 'premium', 'pro', 'plus', 'settings', 'preferences',
        'profile', 'account', 'dashboard', 'timeline', 'feed', 'home',
        'search', 'browse', 'filter', 'sort', 'view', 'edit', 'delete',
        'create', 'new', 'add', 'remove', 'update', 'save', 'cancel',
        'confirm', 'submit', 'upload', 'download', 'share', 'invite',
        'join', 'leave', 'follow', 'unfollow', 'block', 'unblock',
        'report', 'flag', 'hide', 'mute', 'unmute', 'like', 'unlike',
        'favorite', 'unfavorite', 'bookmark', 'unbookmark',
        
        -- Meet/event specific terms
        'meet', 'meets', 'event', 'events', 'gathering', 'meetup', 'meetups',
        'location', 'venue', 'host', 'organizer', 'participant', 'attendee',
        'invite', 'invitation', 'rsvp', 'checkin', 'checkout', 'nearby',
        'map', 'maps', 'gps', 'location', 'coordinates', 'radius',
        'category', 'categories', 'tag', 'tags', 'group', 'groups',
        
        -- Potentially offensive/problematic
        'hitler', 'nazi', 'terrorist', 'jihad', 'isis', 'suicide', 'kill',
        'murder', 'rape', 'porn', 'xxx', 'sex', 'drug', 'drugs', 'cocaine',
        'heroin', 'meth', 'crack', 'weed', 'marijuana', 'cannabis',
        'fuck', 'shit', 'bitch', 'damn', 'hell', 'ass', 'bastard',
        'slut', 'whore', 'fag', 'retard', 'nigger', 'chink', 'spic',
        
        -- Common exploits/attacks
        'script', 'javascript', 'eval', 'exec', 'select', 'drop', 'insert',
        'update', 'delete', 'union', 'inject', 'xss', 'csrf', 'token',
        'session', 'cookie', 'auth', 'login', 'logout', 'password', 'pwd',
        'reset', 'recover', 'forgot', 'change', 'verify', 'activate'
    ]) THEN
        RAISE LOG 'Rejected reserved username attempt: %', v_username_clean;
        RETURN json_build_object(
            'available', FALSE,
            'reason', 'username_reserved',
            'message', 'This username is not available'
        );
    END IF;
    
    -- Check for common profanity obfuscations
    IF v_username_clean ~ 'f[u_0][c_][k_]|sh[i1][t]|b[i1]tch|[a@]ss|d[a@]mn|h[e3]ll|wh[o0]r[e3]|sl[u_]t' THEN
        RAISE LOG 'Rejected inappropriate username attempt: %', v_username_clean;
        RETURN json_build_object(
            'available', FALSE,
            'reason', 'username_inappropriate',
            'message', 'Username contains inappropriate content'
        );
    END IF;
    
    -- Check if username already exists (case-insensitive)
    SELECT EXISTS(
        SELECT 1 
        FROM rangley.vw_users 
        WHERE LOWER(username) = v_username_clean
    ) INTO v_exists;
    
    IF v_exists THEN
        RETURN json_build_object(
            'available', FALSE,
            'reason', 'username_taken',
            'message', 'This username is already taken'
        );
    END IF;
    
    -- Username is available
    RETURN json_build_object(
        'available', TRUE,
        'reason', 'username_available',
        'message', 'Username is available'
    );
    
EXCEPTION
    WHEN OTHERS THEN
        -- Log the error but don't expose internal details
        RAISE LOG 'Error in fn_check_username_availability: %', SQLERRM;
        RETURN json_build_object(
            'available', FALSE,
            'reason', 'check_failed',
            'message', 'Unable to check username availability'
        );
END;
$$;

-- Grant execute permission to your app role
-- GRANT EXECUTE ON FUNCTION rangley.fn_check_username_availability(TEXT) TO your_app_role;

-- Create index for performance
CREATE INDEX IF NOT EXISTS idx_users_lower_username ON rangley.tb_users (LOWER(username));

-- Example usage:
-- SELECT rangley.fn_check_username_availability('testuser123');
-- SELECT rangley.fn_check_username_availability(''); -- empty
-- SELECT rangley.fn_check_username_availability('ab'); -- too short
-- SELECT rangley.fn_check_username_availability('user@email.com'); -- looks like email
-- SELECT rangley.fn_check_username_availability('+1234567890'); -- looks like phone