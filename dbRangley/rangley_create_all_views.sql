-- snake_case Postgres views under schema rangley

DROP VIEW IF EXISTS rangley.vw_meet_category_id_and_name CASCADE;
DROP VIEW IF EXISTS rangley.vw_version_features CASCADE;
DROP VIEW IF EXISTS rangley.vw_versions CASCADE;
DROP VIEW IF EXISTS rangley.vw_features CASCADE;
DROP VIEW IF EXISTS rangley.vw_version_statuses CASCADE;

DROP VIEW IF EXISTS rangley.vw_participant_status CASCADE;
DROP VIEW IF EXISTS rangley.vw_meet_status CASCADE;
DROP VIEW IF EXISTS rangley.vw_meet_category CASCADE;
DROP VIEW IF EXISTS rangley.vw_sub_category CASCADE;

DROP VIEW IF EXISTS rangley.vw_stock_assets CASCADE;
DROP VIEW IF EXISTS rangley.vw_notification_type CASCADE;

DROP VIEW IF EXISTS rangley.vw_notifications CASCADE;
DROP VIEW IF EXISTS rangley.vw_user_inboxes CASCADE;
DROP VIEW IF EXISTS rangley.vw_meet_participants CASCADE;


DROP VIEW IF EXISTS rangley.vw_users CASCADE;
DROP VIEW IF EXISTS rangley.vw_meet_ids CASCADE;
DROP VIEW IF EXISTS rangley.vw_change_stamps CASCADE;
DROP VIEW IF EXISTS rangley.vw_meet_change_stamps_desc CASCADE;
DROP VIEW IF EXISTS rangley.vw_up_to_date_meets CASCADE;
DROP VIEW IF EXISTS rangley.vw_meet_coordinates CASCADE;
DROP VIEW IF EXISTS rangley.vw_meets CASCADE;
DROP VIEW IF exists rangley.vw_user_privacy_settings cascade;


DROP VIEW IF EXISTS rangley.vw_friend_request_status CASCADE;
DROP VIEW IF EXISTS rangley.vw_friend_requests CASCADE;
DROP VIEW IF EXISTS rangley.vw_friendships CASCADE;
DROP VIEW IF EXISTS rangley.vw_user_meets_created_stats CASCADE;
DROP VIEW IF EXISTS rangley.vw_user_meets_attended_stats CASCADE;
DROP VIEW IF EXISTS rangley.vw_user_friend_count CASCADE;
DROP VIEW IF EXISTS rangley.vw_user_profile CASCADE;
DROP VIEW IF EXISTS rangley.vw_user_friendships CASCADE;
DROP VIEW IF EXISTS rangley.vw_meet_groups CASCADE;
DROP VIEW IF EXISTS rangley.vw_meet_group_members CASCADE;
DROP VIEW IF EXISTS rangley.vw_meet_group_invitations CASCADE;

DROP VIEW IF EXISTS rangley.vw_rate_limit_tier CASCADE;
DROP VIEW IF EXISTS rangley.vw_llm_model CASCADE;
DROP VIEW IF EXISTS rangley.vw_ai_conversation CASCADE;
DROP VIEW IF EXISTS rangley.vw_ai_interaction CASCADE;


DROP VIEW IF EXISTS rangley.vw_ai_created_meets CASCADE;
DROP VIEW IF EXISTS rangley.vw_prompt_version_performance CASCADE;
DROP VIEW IF EXISTS rangley.vw_daily_ai_usage CASCADE;
DROP VIEW IF EXISTS rangley.vw_user_ai_costs CASCADE;



-- =====================================================================
-- RANGLEY BASE VIEWS (1:1 Table Mirrors)
-- =====================================================================
-- Purpose: Create base views that mirror tables exactly
-- Pattern: Always query views, never query tables directly
-- Benefits: Consistent access layer, easier schema evolution, security
-- =====================================================================

CREATE OR REPLACE VIEW rangley.vw_version_statuses AS
SELECT
     status_id , status
FROM rangley.te_version_statuses;


CREATE OR REPLACE VIEW rangley.vw_versions AS
SELECT
     version
    ,status_id
    ,dttm_created_utc
    ,dttm_released_utc
    ,dttm_deprecated_utc
from rangley.td_versions;


CREATE OR REPLACE VIEW rangley.vw_version_features AS
SELECT
     version, feature_id 
from rangley.te_version_features;


CREATE OR REPLACE VIEW rangley.vw_meets AS 
SELECT
     meet_id
    ,change_stamp
    ,meet_coordinate_id
    ,meet_status_id
    ,name
    ,description
    ,change_reason
    ,meet_category_id
    ,max_capacity
    ,dttm_start_utc
    ,dttm_end_utc
    ,uuid
    ,created_by_ai
    ,ai_interaction_id
FROM rangley.tb_meets;


CREATE OR REPLACE VIEW rangley.vw_meet_coordinates AS
SELECT
     meet_coordinate_id
    ,latitude
    ,longitude
    ,region_latitude
    ,region_longitude
    ,region_radius
FROM rangley.tb_meet_coordinates;


CREATE OR REPLACE VIEW rangley.vw_change_stamps AS
SELECT
     change_stamp
    ,meet_id
    ,dttm_modified_utc
    ,modified_by_user_id
FROM rangley.tb_change_stamps;


CREATE OR REPLACE VIEW rangley.vw_meet_ids AS
SELECT
     meet_id
    ,created_by_user_id
    ,dttm_created_utc
    ,uuid
FROM rangley.tb_meet_ids;


CREATE OR REPLACE VIEW rangley.vw_users AS
SELECT
     user_id
    ,cognito_sub
    ,username
    ,display_name
    ,first_name
    ,last_name
    ,cellphone
    ,email
    ,dob
    ,dttm_created_utc
    ,dttm_modified_utc
    ,uuid
    ,rate_limit_tier_id
FROM rangley.tb_users;


CREATE OR REPLACE VIEW rangley.vw_user_privacy_settings AS
SELECT
     user_id 					
    ,discoverable_by_username 	
    ,discoverable_by_phone 		
    ,discoverable_by_email 		
    ,show_full_name 			
    ,allow_invites_from_anyone 	
    ,dttm_created_utc			
    ,dttm_modified_utc 			
FROM rangley.tb_user_privacy_settings;


CREATE OR REPLACE VIEW rangley.vw_notifications AS
SELECT
     notification_id
    ,notification_type_id
    ,meet_id
    ,created_by_user_id
    ,payload_json
    ,dttm_created_utc
FROM rangley.tb_notifications;


CREATE OR REPLACE VIEW rangley.vw_user_inboxes AS
SELECT
     user_id
    ,notification_id
    ,dttm_received_utc
    ,dttm_opened_utc
FROM rangley.tb_user_inboxes;

-- TODO FIX THIS TABLE DON'T NEED THE PRIMARY KEY PROBABLY

CREATE OR REPLACE VIEW rangley.vw_meet_participants as 
SELECT
     participant_id
    ,meet_id
    ,user_id
    ,participant_status_id
    ,dttm_invited_utc
    ,dttm_accepted_utc
    ,dttm_left_utc
    ,dttm_created_utc
    ,dttm_modified_utc
FROM rangley.tb_meet_participants;


CREATE OR REPLACE VIEW rangley.vw_stock_assets AS
SELECT
     asset_id
    ,asset_name
    ,asset_category
    ,display_name
    ,description
    ,file_extension
    ,sort_order
    ,is_active
    ,dttm_created_utc
    ,created_by
    ,dttm_modified_utc
    ,modified_by
FROM rangley.td_stock_assets;


CREATE OR REPLACE VIEW rangley.vw_notification_type AS
SELECT 
     notification_type_id
    ,name
    ,dttm_created_utc
    ,created_by
    ,dttm_modified_utc
    ,modified_by
FROM rangley.td_notification_type;


CREATE OR REPLACE VIEW rangley.vw_sub_category AS
SELECT 
     sub_category_id
    ,meet_category_id
    ,name
    ,created_by
    ,dttm_modified_utc
    ,modified_by
FROM rangley.td_sub_category;


CREATE OR REPLACE VIEW rangley.vw_meet_category AS
SELECT 
     meet_category_id
    ,name
    ,dttm_created_utc
    ,created_by
    ,dttm_modified_utc
    ,modified_by
FROM rangley.td_meet_category;


CREATE OR REPLACE VIEW rangley.vw_features AS
SELECT feature_id, name
FROM rangley.td_features;


CREATE OR REPLACE VIEW rangley.vw_meet_status AS
SELECT 
     meet_status_id
    ,name
    ,dttm_created_utc
    ,created_by
    ,dttm_modified_utc
    ,modified_by
FROM rangley.td_meet_status;

-- preserving your original spelling "particpant"

CREATE OR REPLACE VIEW rangley.vw_participant_status AS
SELECT 
     participant_status_id
    ,name
    ,dttm_created_utc
    ,created_by
    ,dttm_modified_utc
    ,modified_by
FROM rangley.td_participant_status;



-- Friend system base views
CREATE OR REPLACE VIEW rangley.vw_friend_request_status AS
SELECT 
     friend_request_status_id
    ,name
    ,dttm_created_utc
    ,created_by
FROM rangley.td_friend_request_status;


CREATE OR REPLACE VIEW rangley.vw_friend_requests AS
SELECT 
     friend_request_id
    ,requester_user_id
    ,recipient_user_id
    ,friend_request_status_id
    ,dttm_created_utc
    ,dttm_responded_utc
    ,dttm_modified_utc
FROM rangley.tb_friend_requests;


CREATE OR REPLACE VIEW rangley.vw_friendships AS
SELECT 
     friendship_id
    ,user_id_a
    ,user_id_b
    ,dttm_created_utc
FROM rangley.tb_friendships;

CREATE OR REPLACE VIEW rangley.vw_meet_groups AS
SELECT 
    meet_group_id,
    name,
    created_by_user_id,
    image_type,
    image_reference, 
    image_url,
    dttm_created_utc,
    dttm_modified_utc
FROM rangley.tb_meet_groups;



CREATE OR REPLACE VIEW rangley.vw_meet_group_members AS
SELECT
     meet_group_id
    ,user_id
    ,dttm_added_utc
FROM rangley.tb_meet_group_members;


-- View for invitations
CREATE OR REPLACE VIEW rangley.vw_meet_group_invitations AS
SELECT
     invitation_id
    ,meet_group_id
    ,invited_user_id
    ,invited_by_user_id
    ,status
    ,dttm_invited_utc
    ,dttm_responded_utc
FROM rangley.tb_meet_group_invitations;


CREATE OR REPLACE VIEW rangley.vw_version_features AS
SELECT version, feature_id
FROM rangley.te_version_features;



-- =====================================================================
-- END - RANGLEY BASE VIEWS (1:1 Table Mirrors)
-- =====================================================================






-- ============================================
-- COMPUTED/AGGREGATE VIEWS
-- ============================================


CREATE OR REPLACE VIEW rangley.vw_meet_change_stamps_desc AS
SELECT DISTINCT ON (meet_id)
  meet_id,
  change_stamp
FROM rangley.tb_meets
ORDER BY meet_id, change_stamp DESC;


CREATE OR REPLACE VIEW rangley.vw_up_to_date_meets AS
select
     mcsd.meet_id                    -- add this for procedure use
    ,mi.uuid as meet_id_uuid
    ,m.meet_coordinate_id            -- add this for procedure use
    ,m.change_stamp
    ,m.uuid as meet_uuid   
    ,COALESCE(m.meet_status_id, 0) AS meet_status_id
    ,ma.latitude
    ,ma.longitude
    ,ma.region_latitude
    ,ma.region_longitude
    ,ma.region_radius
    ,m.dttm_start_utc
    ,m.dttm_end_utc
    ,m.name
    ,mc.name AS category_name
    ,m.meet_category_id
    ,m.description
    ,m.max_capacity
    ,u.uuid as created_by_user_uuid
    ,u.display_name
FROM rangley.vw_meet_change_stamps_desc mcsd
JOIN rangley.vw_meets m
  ON m.meet_id = mcsd.meet_id
 AND m.change_stamp = mcsd.change_stamp
LEFT JOIN rangley.vw_change_stamps cs
  ON cs.meet_id = mcsd.meet_id
 AND cs.change_stamp = mcsd.change_stamp
JOIN rangley.vw_meet_ids mi
  ON mi.meet_id = mcsd.meet_id
JOIN rangley.vw_meet_coordinates ma
  ON ma.meet_coordinate_id = m.meet_coordinate_id
JOIN rangley.vw_users u
  ON u.user_id = mi.created_by_user_id
JOIN rangley.vw_meet_category mc
  ON mc.meet_category_id = m.meet_category_id
WHERE
  -- exclude only the hard states you said you store
  m.meet_status_id IS DISTINCT FROM 2   -- Cancelled
  AND m.meet_status_id IS DISTINCT FROM 3   -- Postponed
  AND m.meet_status_id IS DISTINCT FROM 7   -- Deleted
  AND m.dttm_end_utc >= now();              -- not ended yet


CREATE OR REPLACE VIEW rangley.vw_meet_category_id_and_name AS
SELECT meet_category_id, name
FROM rangley.vw_meet_category;



-- ============================================
-- PROFILE STATS HELPER VIEWS
-- ============================================

CREATE OR REPLACE VIEW rangley.vw_user_meets_created_stats AS
SELECT 
     mi.created_by_user_id AS user_id
    ,COUNT(DISTINCT mi.meet_id) AS meets_created_count
FROM rangley.vw_meet_ids mi
JOIN rangley.vw_meet_change_stamps_desc mcsd 
    ON mcsd.meet_id = mi.meet_id
JOIN rangley.vw_meets m 
    ON m.meet_id = mcsd.meet_id 
    AND m.change_stamp = mcsd.change_stamp
WHERE m.dttm_end_utc < now()
  AND m.meet_status_id NOT IN (2, 3, 5, 7)
GROUP BY mi.created_by_user_id;


CREATE OR REPLACE VIEW rangley.vw_user_meets_attended_stats AS
SELECT 
     mp.user_id
    ,COUNT(DISTINCT mp.meet_id) AS meets_attended_count
FROM rangley.vw_meet_participants mp
JOIN rangley.vw_meet_change_stamps_desc mcsd 
    ON mcsd.meet_id = mp.meet_id
JOIN rangley.vw_meets m 
    ON m.meet_id = mcsd.meet_id 
    AND m.change_stamp = mcsd.change_stamp
WHERE (
        mp.participant_status_id = 7
        OR (
            mp.participant_status_id = 6
            AND mp.dttm_accepted_utc IS NOT NULL
        )
      )
  AND m.dttm_end_utc < now()
  AND m.meet_status_id NOT IN (2, 3, 5, 7)
GROUP BY mp.user_id;


CREATE OR REPLACE VIEW rangley.vw_user_friend_count AS
SELECT 
     user_id
    ,COUNT(*) AS friend_count
FROM (
    SELECT user_id_a AS user_id FROM rangley.vw_friendships
    UNION ALL
    SELECT user_id_b AS user_id FROM rangley.vw_friendships
) friends
GROUP BY user_id;


-- ============================================
-- MAIN USER PROFILE VIEW
-- ============================================

CREATE OR REPLACE VIEW rangley.vw_user_profile AS
SELECT 
     u.user_id
    ,u.uuid AS user_uuid
    ,u.username
    ,u.display_name
    ,u.first_name
    ,u.last_name
    ,u.dttm_created_utc AS member_since
    ,COALESCE(mc.meets_created_count, 0) AS meets_created
    ,COALESCE(ma.meets_attended_count, 0) AS meets_attended
    ,COALESCE(fc.friend_count, 0) AS friend_count
    ,ps.discoverable_by_username
    ,ps.discoverable_by_phone
    ,ps.discoverable_by_email
    ,ps.show_full_name
    ,ps.allow_invites_from_anyone
FROM rangley.vw_users u
LEFT JOIN rangley.vw_user_meets_created_stats mc ON mc.user_id = u.user_id
LEFT JOIN rangley.vw_user_meets_attended_stats ma ON ma.user_id = u.user_id
LEFT JOIN rangley.vw_user_friend_count fc ON fc.user_id = u.user_id
LEFT JOIN rangley.vw_user_privacy_settings ps ON ps.user_id = u.user_id;


-- ============================================
-- ENRICHED FRIEND VIEWS
-- ============================================

CREATE OR REPLACE VIEW rangley.vw_user_friendships AS
SELECT 
     f.friendship_id
    ,f.user_id_a AS user_id
    ,f.user_id_b AS friend_user_id
    ,u.username AS friend_username
    ,u.display_name AS friend_display_name
    ,u.uuid AS friend_uuid
    ,f.dttm_created_utc AS friends_since
FROM rangley.vw_friendships f
JOIN rangley.vw_users u ON u.user_id = f.user_id_b

UNION ALL

SELECT 
     f.friendship_id
    ,f.user_id_b AS user_id
    ,f.user_id_a AS friend_user_id
    ,u.username AS friend_username
    ,u.display_name AS friend_display_name
    ,u.uuid AS friend_uuid
    ,f.dttm_created_utc AS friends_since
FROM rangley.vw_friendships f
JOIN rangley.vw_users u ON u.user_id = f.user_id_a;


CREATE OR REPLACE VIEW rangley.vw_friend_requests_enriched AS
SELECT 
     fr.friend_request_id
    ,fr.requester_user_id
    ,req.username AS requester_username
    ,req.display_name AS requester_display_name
    ,req.uuid AS requester_uuid
    ,fr.recipient_user_id
    ,rec.username AS recipient_username
    ,rec.display_name AS recipient_display_name
    ,rec.uuid AS recipient_uuid
    ,fr.friend_request_status_id
    ,frs.name AS request_status
    ,fr.dttm_created_utc
    ,fr.dttm_responded_utc
FROM rangley.vw_friend_requests fr
JOIN rangley.vw_users req ON req.user_id = fr.requester_user_id
JOIN rangley.vw_users rec ON rec.user_id = fr.recipient_user_id
JOIN rangley.vw_friend_request_status frs ON frs.friend_request_status_id = fr.friend_request_status_id;


-- Mirror: td_rate_limit_tier
CREATE OR REPLACE VIEW rangley.vw_rate_limit_tier AS
SELECT 
     rate_limit_tier_id
    ,tier_name
    ,requests_per_hour
    ,requests_per_day
    ,dttm_created_utc
    ,created_by
    ,dttm_modified_utc
    ,modified_by
FROM rangley.td_rate_limit_tier;

COMMENT ON VIEW rangley.vw_rate_limit_tier IS 
'Base view mirroring td_rate_limit_tier. Always query this view instead of the table directly.';


-- Mirror: td_llm_model
CREATE OR REPLACE VIEW rangley.vw_llm_model AS
SELECT 
     llm_model_id
    ,provider
    ,model_name
    ,cost_per_1k_input_tokens
    ,cost_per_1k_output_tokens
    ,dttm_created_utc
    ,created_by
    ,dttm_modified_utc
    ,modified_by
FROM rangley.td_llm_model;

COMMENT ON VIEW rangley.vw_llm_model IS 
'Base view mirroring td_llm_model. Always query this view instead of the table directly.';


-- =====================================================================
-- MAIN AI TABLE VIEWS
-- =====================================================================

-- Mirror: tb_ai_conversation
CREATE OR REPLACE VIEW rangley.vw_ai_conversation AS
SELECT 
     conversation_id
    ,user_id
    ,feature_name
    ,title
    ,status
    ,dttm_created_utc
    ,dttm_modified_utc
    ,dttm_closed_utc
FROM rangley.tb_ai_conversation;

COMMENT ON VIEW rangley.vw_ai_conversation IS 
'Base view mirroring tb_ai_conversation. Always query this view instead of the table directly.';


-- Mirror: tb_ai_interaction
CREATE OR REPLACE VIEW rangley.vw_ai_interaction AS
SELECT 
     ai_interaction_id
    ,user_id
    ,conversation_id
    ,llm_model_id
    ,prompt_version
    ,feature_name
    ,conversation_turn
    ,prompt
    ,response
    ,prompt_tokens
    ,response_tokens
    ,total_tokens
    ,cost_usd
    ,duration_ms
    ,status
    ,error_message
    ,metadata
    ,dttm_created_utc
FROM rangley.tb_ai_interaction;

COMMENT ON VIEW rangley.vw_ai_interaction IS 
'Base view mirroring tb_ai_interaction. Always query this view instead of the table directly.';


-- =====================================================================
-- STEP 8: ANALYTICS VIEWS
-- =====================================================================

-- User AI cost summary view
CREATE OR REPLACE VIEW rangley.vw_user_ai_costs AS
SELECT 
     user_id
    ,COUNT(*) AS total_requests
    ,SUM(CASE WHEN status = 'success' THEN 1 ELSE 0 END) AS successful_requests
    ,SUM(CASE WHEN status = 'error' THEN 1 ELSE 0 END) AS failed_requests
    ,SUM(CASE WHEN status = 'rate_limited' THEN 1 ELSE 0 END) AS rate_limited_requests
    ,SUM(prompt_tokens) AS total_prompt_tokens
    ,SUM(response_tokens) AS total_response_tokens
    ,SUM(total_tokens) AS total_tokens
    ,SUM(cost_usd) AS total_cost_usd
    ,AVG(duration_ms) AS avg_duration_ms
    ,MIN(dttm_created_utc) AS first_request
    ,MAX(dttm_created_utc) AS last_request
FROM rangley.tb_ai_interaction
GROUP BY user_id;

-- Daily AI usage summary view
CREATE OR REPLACE VIEW rangley.vw_daily_ai_usage AS
SELECT 
     DATE(dttm_created_utc) AS usage_date
    ,COUNT(*) AS total_requests
    ,COUNT(DISTINCT user_id) AS unique_users
    ,SUM(CASE WHEN status = 'success' THEN 1 ELSE 0 END) AS successful_requests
    ,SUM(total_tokens) AS total_tokens
    ,SUM(cost_usd) AS total_cost_usd
    ,AVG(duration_ms) AS avg_duration_ms
    ,AVG(conversation_turn) AS avg_conversation_turns
FROM rangley.tb_ai_interaction
GROUP BY DATE(dttm_created_utc)
ORDER BY usage_date DESC;

-- Prompt version performance view (for A/B testing)
CREATE OR REPLACE VIEW rangley.vw_prompt_version_performance AS
SELECT 
     prompt_version
    ,COUNT(*) AS total_requests
    ,COUNT(DISTINCT user_id) AS unique_users
    ,SUM(CASE WHEN status = 'success' THEN 1 ELSE 0 END) AS successful_requests
    ,ROUND(100.0 * SUM(CASE WHEN status = 'success' THEN 1 ELSE 0 END) / COUNT(*), 2) AS success_rate_pct
    ,AVG(conversation_turn) AS avg_conversation_turns
    ,AVG(duration_ms) AS avg_duration_ms
    ,SUM(cost_usd) AS total_cost_usd
    ,MIN(dttm_created_utc) AS first_used
    ,MAX(dttm_created_utc) AS last_used
FROM rangley.tb_ai_interaction
GROUP BY prompt_version
ORDER BY prompt_version DESC;

-- AI-created meets analysis view
CREATE OR REPLACE VIEW rangley.vw_ai_created_meets AS
SELECT 
     m.meet_id
    ,m.name
    ,m.dttm_start_utc
    ,m.meet_category_id
    ,mc.name AS category_name
    ,mi.created_by_user_id
    ,u.username AS creator_username
    ,ai.conversation_turn
    ,ai.cost_usd
    ,ai.dttm_created_utc AS ai_interaction_time
FROM rangley.tb_meets m
JOIN rangley.tb_meet_ids mi ON m.meet_id = mi.meet_id
JOIN rangley.tb_users u ON mi.created_by_user_id = u.user_id
LEFT JOIN rangley.td_meet_category mc ON m.meet_category_id = mc.meet_category_id
LEFT JOIN rangley.tb_ai_interaction ai ON m.ai_interaction_id = ai.ai_interaction_id
WHERE m.created_by_ai = TRUE
  AND m.change_stamp = (
      SELECT MAX(change_stamp) 
      FROM rangley.tb_meets 
      WHERE meet_id = m.meet_id
  )
ORDER BY m.dttm_start_utc DESC;


-- =====================================================================
-- RANGLEY AI BASE VIEWS (1:1 Table Mirrors)
-- =====================================================================
-- Purpose: Create base views that mirror AI tables exactly
-- Pattern: Always query views, never query tables directly
-- Benefits: Consistent access layer, easier schema evolution, security
-- =====================================================================

-- =====================================================================
-- LOOKUP TABLE VIEWS
-- =====================================================================

-- Mirror: td_rate_limit_tier
CREATE OR REPLACE VIEW rangley.vw_rate_limit_tier AS
SELECT 
     rate_limit_tier_id
    ,tier_name
    ,requests_per_hour
    ,requests_per_day
    ,dttm_created_utc
    ,created_by
    ,dttm_modified_utc
    ,modified_by
FROM rangley.td_rate_limit_tier;

COMMENT ON VIEW rangley.vw_rate_limit_tier IS 
'Base view mirroring td_rate_limit_tier. Always query this view instead of the table directly.';


-- Mirror: td_llm_model
CREATE OR REPLACE VIEW rangley.vw_llm_model AS
SELECT 
     llm_model_id
    ,provider
    ,model_name
    ,cost_per_1k_input_tokens
    ,cost_per_1k_output_tokens
    ,dttm_created_utc
    ,created_by
    ,dttm_modified_utc
    ,modified_by
FROM rangley.td_llm_model;

COMMENT ON VIEW rangley.vw_llm_model IS 
'Base view mirroring td_llm_model. Always query this view instead of the table directly.';


-- =====================================================================
-- MAIN AI TABLE VIEWS
-- =====================================================================

-- Mirror: tb_ai_conversation
CREATE OR REPLACE VIEW rangley.vw_ai_conversation AS
SELECT 
     conversation_id
    ,user_id
    ,feature_name
    ,title
    ,status
    ,dttm_created_utc
    ,dttm_modified_utc
    ,dttm_closed_utc
FROM rangley.tb_ai_conversation;

COMMENT ON VIEW rangley.vw_ai_conversation IS 
'Base view mirroring tb_ai_conversation. Always query this view instead of the table directly.';


-- Mirror: tb_ai_interaction
CREATE OR REPLACE VIEW rangley.vw_ai_interaction AS
SELECT 
     ai_interaction_id
    ,user_id
    ,conversation_id
    ,llm_model_id
    ,prompt_version
    ,feature_name
    ,conversation_turn
    ,prompt
    ,response
    ,prompt_tokens
    ,response_tokens
    ,total_tokens
    ,cost_usd
    ,duration_ms
    ,status
    ,error_message
    ,metadata
    ,dttm_created_utc
FROM rangley.tb_ai_interaction;

COMMENT ON VIEW rangley.vw_ai_interaction IS 
'Base view mirroring tb_ai_interaction. Always query this view instead of the table directly.';


-- =====================================================================
-- VALIDATION
-- =====================================================================

-- Verify all base views exist
DO $$
DECLARE
    missing_views TEXT[];
BEGIN
    SELECT ARRAY_AGG(view_name)
    INTO missing_views
    FROM (VALUES 
        ('vw_rate_limit_tier'),
        ('vw_llm_model'),
        ('vw_ai_conversation'),
        ('vw_ai_interaction')
    ) AS expected(view_name)
    WHERE NOT EXISTS (
        SELECT 1 FROM information_schema.views
        WHERE table_schema = 'rangley'
        AND table_name = expected.view_name
    );
    
    IF missing_views IS NOT NULL THEN
        RAISE EXCEPTION 'Missing base views: %', array_to_string(missing_views, ', ');
    END IF;
    
    RAISE NOTICE '✅ All AI base views created successfully';
END $$;

-- Test queries to ensure views work
SELECT 'Base Views Row Counts:' AS test_section;

SELECT 
    'vw_rate_limit_tier' AS view_name,
    COUNT(*) AS row_count
FROM rangley.vw_rate_limit_tier
UNION ALL
SELECT 
    'vw_llm_model' AS view_name,
    COUNT(*) AS row_count
FROM rangley.vw_llm_model
UNION ALL
SELECT 
    'vw_ai_conversation' AS view_name,
    COUNT(*) AS row_count
FROM rangley.vw_ai_conversation
UNION ALL
SELECT 
    'vw_ai_interaction' AS view_name,
    COUNT(*) AS row_count
FROM rangley.vw_ai_interaction;

-- =====================================================================
-- USAGE EXAMPLES
-- =====================================================================

/*
-- DON'T DO THIS (querying tables directly):
SELECT * FROM rangley.tb_ai_interaction WHERE user_id = 123;
SELECT * FROM rangley.td_rate_limit_tier WHERE tier_name = 'premium';

-- DO THIS (querying views):
SELECT * FROM rangley.vw_ai_interaction WHERE user_id = 123;
SELECT * FROM rangley.vw_rate_limit_tier WHERE tier_name = 'premium';

-- Benefits:
-- 1. Consistent access pattern across entire codebase
-- 2. Can add computed columns to views without changing table
-- 3. Can swap underlying table structure without breaking queries
-- 4. Grant permissions to views only, not tables (better security)
-- 5. Views can join related data transparently if needed later
*/
