-- ===== SEED DATA (snake_case) =====

-- Features
INSERT INTO rangley.td_features (feature_id, name) VALUES (0, 'NULL_VALUE');
INSERT INTO rangley.td_features (feature_id, name) VALUES (1, 'Create Meet');
INSERT INTO rangley.td_features (feature_id, name) VALUES (2, 'Join Meet');

INSERT INTO rangley.te_version_features (version, feature_id) VALUES (1, 1);
INSERT INTO rangley.te_version_features (version, feature_id) VALUES (1, 2);

-- Meet Categories
INSERT INTO rangley.td_meet_category (meet_category_id, name) VALUES (0, 'NULL_VALUE');
INSERT INTO rangley.td_meet_category (meet_category_id, name) VALUES (1, 'Activity');
INSERT INTO rangley.td_meet_category (meet_category_id, name) VALUES (2, 'Sports');
INSERT INTO rangley.td_meet_category (meet_category_id, name) VALUES (3, 'Outdoors');
INSERT INTO rangley.td_meet_category (meet_category_id, name) VALUES (4, 'Social');
INSERT INTO rangley.td_meet_category (meet_category_id, name) VALUES (5, 'Music');
INSERT INTO rangley.td_meet_category (meet_category_id, name) VALUES (6, 'Food');
INSERT INTO rangley.td_meet_category (meet_category_id, name) VALUES (7, 'Planned Trip');
INSERT INTO rangley.td_meet_category (meet_category_id, name) VALUES (8, 'Spontaneous');
INSERT INTO rangley.td_meet_category (meet_category_id, name) VALUES (9, 'Custom');

-- Sub Categories
INSERT INTO rangley.td_sub_category (sub_category_id, meet_category_id, name) VALUES (0, 0, 'NULL_VALUE');
-- Activity
INSERT INTO rangley.td_sub_category (sub_category_id, meet_category_id, name) VALUES (1, 1, 'Sport');
INSERT INTO rangley.td_sub_category (sub_category_id, meet_category_id, name) VALUES (2, 1, 'Fitness');
INSERT INTO rangley.td_sub_category (sub_category_id, meet_category_id, name) VALUES (3, 1, 'Art');
INSERT INTO rangley.td_sub_category (sub_category_id, meet_category_id, name) VALUES (4, 1, 'Work Session');
INSERT INTO rangley.td_sub_category (sub_category_id, meet_category_id, name) VALUES (5, 1, 'Study Group');
-- Party
INSERT INTO rangley.td_sub_category (sub_category_id, meet_category_id, name) VALUES (6,  2, 'Birthday');
INSERT INTO rangley.td_sub_category (sub_category_id, meet_category_id, name) VALUES (7,  2, 'Holiday');
INSERT INTO rangley.td_sub_category (sub_category_id, meet_category_id, name) VALUES (8,  2, 'Wedding');
INSERT INTO rangley.td_sub_category (sub_category_id, meet_category_id, name) VALUES (9,  2, 'Night Out');
INSERT INTO rangley.td_sub_category (sub_category_id, meet_category_id, name) VALUES (10, 2, 'Drinks');
-- Food
INSERT INTO rangley.td_sub_category (sub_category_id, meet_category_id, name) VALUES (11, 3, 'Breakfast');
INSERT INTO rangley.td_sub_category (sub_category_id, meet_category_id, name) VALUES (12, 3, 'Lunch');
INSERT INTO rangley.td_sub_category (sub_category_id, meet_category_id, name) VALUES (13, 3, 'Dinner');
INSERT INTO rangley.td_sub_category (sub_category_id, meet_category_id, name) VALUES (14, 3, 'Dessert');
INSERT INTO rangley.td_sub_category (sub_category_id, meet_category_id, name) VALUES (15, 3, 'Cafe / Tea');
-- Planned Trip
INSERT INTO rangley.td_sub_category (sub_category_id, meet_category_id, name) VALUES (16, 4, 'Golf Trip');
INSERT INTO rangley.td_sub_category (sub_category_id, meet_category_id, name) VALUES (17, 4, 'Ski Trip');
INSERT INTO rangley.td_sub_category (sub_category_id, meet_category_id, name) VALUES (18, 4, 'Music Festival');
INSERT INTO rangley.td_sub_category (sub_category_id, meet_category_id, name) VALUES (19, 4, 'Beach Trip');
INSERT INTO rangley.td_sub_category (sub_category_id, meet_category_id, name) VALUES (20, 4, 'Game Day');
INSERT INTO rangley.td_sub_category (sub_category_id, meet_category_id, name) VALUES (21, 4, 'Lake House');

-- Meet Status
INSERT INTO rangley.td_meet_status (meet_status_id, name) VALUES (0, 'NULL_VALUE');
INSERT INTO rangley.td_meet_status (meet_status_id, name) VALUES (1, 'Active');
INSERT INTO rangley.td_meet_status (meet_status_id, name) VALUES (2, 'Cancelled');
INSERT INTO rangley.td_meet_status (meet_status_id, name) VALUES (3, 'Postponed');
INSERT INTO rangley.td_meet_status (meet_status_id, name) VALUES (4, 'Completed');
INSERT INTO rangley.td_meet_status (meet_status_id, name) VALUES (5, 'Draft');
INSERT INTO rangley.td_meet_status (meet_status_id, name) VALUES (6, 'Full');
INSERT INTO rangley.td_meet_status (meet_status_id, name) VALUES (7, 'Deleted');

-- Participant Status (fixed typo: participant)
INSERT INTO rangley.td_participant_status (participant_status_id, name) VALUES (0, 'NULL_VALUE');
INSERT INTO rangley.td_participant_status (participant_status_id, name) VALUES (1, 'Attending');
INSERT INTO rangley.td_participant_status (participant_status_id, name) VALUES (2, 'Not Attending');
INSERT INTO rangley.td_participant_status (participant_status_id, name) VALUES (3, 'Maybe');
INSERT INTO rangley.td_participant_status (participant_status_id, name) VALUES (4, 'Invited');
INSERT INTO rangley.td_participant_status (participant_status_id, name) VALUES (5, 'Declined');
INSERT INTO rangley.td_participant_status (participant_status_id, name) VALUES (6, 'Accepted');
INSERT INTO rangley.td_participant_status (participant_status_id, name) VALUES (7, 'Owner');
INSERT INTO rangley.td_participant_status (participant_status_id, name) VALUES (8, 'Left');
INSERT INTO rangley.td_participant_status (participant_status_id, name) VALUES (9, 'Removed');

delete from rangley.td_participant_status;


-- Notification Types
INSERT INTO rangley.td_notification_type (notification_type_id, name) VALUES (0, 'NULL_VALUE');
INSERT INTO rangley.td_notification_type (notification_type_id, name) VALUES (1, 'Meet Created');
INSERT INTO rangley.td_notification_type (notification_type_id, name) VALUES (2, 'Meet Updated');
INSERT INTO rangley.td_notification_type (notification_type_id, name) VALUES (3, 'Meet Cancelled');
INSERT INTO rangley.td_notification_type (notification_type_id, name) VALUES (4, 'New Attendee');
INSERT INTO rangley.td_notification_type (notification_type_id, name) VALUES (5, 'Attendee Left');
INSERT INTO rangley.td_notification_type (notification_type_id, name) VALUES (6, 'Meet Reminder');
INSERT INTO rangley.td_notification_type (notification_type_id, name) VALUES (7, 'System Alert');

INSERT INTO rangley.td_notification_type (notification_type_id, name) VALUES (8, 'Meet Invitation Received');
INSERT INTO rangley.td_notification_type (notification_type_id, name) VALUES (9, 'Meet Invitation Accepted');
INSERT INTO rangley.td_notification_type (notification_type_id, name) VALUES (10, 'Meet Invitation Declined');
INSERT INTO rangley.td_notification_type (notification_type_id, name) VALUES (11, 'Meet Invitation Expired');
INSERT INTO rangley.td_notification_type (notification_type_id, name) VALUES (12, 'Meet Full');
INSERT INTO rangley.td_notification_type (notification_type_id, name) VALUES (13, 'Meet Role Changed');
INSERT INTO rangley.td_notification_type (notification_type_id, name) VALUES (14, 'Meet Location Changed');
INSERT INTO rangley.td_notification_type (notification_type_id, name) VALUES
(15, 'Friend Request Received'),
(16, 'Friend Request Accepted'),
(17, 'Friend Request Declined')
ON CONFLICT (notification_type_id) DO NOTHING;
INSERT INTO rangley.td_notification_type (notification_type_id, name) VALUES (18, 'Meet Deleted');
INSERT INTO rangley.td_notification_type (notification_type_id, name, created_by)
VALUES (19, 'Meet Group Invitation Received', 'system');

INSERT INTO rangley.td_notification_type (notification_type_id, name, created_by)
VALUES (20, 'Meet Group Invitation Accepted', 'system');

INSERT INTO rangley.td_notification_type (notification_type_id, name, created_by)
VALUES (21, 'Meet Group Invitation Declined', 'system');

select * from  rangley.td_violation_categories;

-- Insert violation categories
INSERT INTO rangley.td_violation_categories (violation_category_id, name, description) VALUES
(1, 'content_true_threats', 'True threats and incitement to violence'),
(2, 'content_slurs_hate_speech', 'Racial, ethnic, and religious slurs'),
(3, 'content_sexually_explicit', 'Sexually explicit and harassing content'),
(4, 'content_illegal_activity', 'Illegal activity and drug references'),
(5, 'content_aggressive_profanity', 'Extreme profanity with aggressive context'),
(6, 'content_predatory', 'Predatory or inappropriate targeting'),
(7, 'content_extremist_conspiracy', 'Extremist and conspiracy content'),
(8, 'content_spam_scam', 'Spam and scam patterns'),
(9, 'content_doxxing_harassment', 'Doxxing and harassment patterns'),
(10, 'content_discriminatory_professional', 'Professional context violations'),
(11, 'content_terrorism', 'Terrorism and violent extremism'),
(12, 'content_child_exploitation', 'Child sexual abuse and exploitation'),
(13, 'content_human_trafficking', 'Human trafficking and forced labor'),
(14, 'content_drug_distribution', 'Drug manufacturing and distribution'),
(15, 'content_illegal_weapons', 'Weapons and illegal firearms'),
(16, 'content_prostitution', 'Prostitution and sexual services'),
(17, 'content_organized_crime', 'Organized crime and racketeering'),
(18, 'content_financial_crime', 'Financial crimes and fraud'),
(19, 'content_cybercrime', 'Cybercrime and hacking'),
(20, 'content_hate_crime', 'Hate crimes and discriminatory violence'),
(21, 'content_kidnapping', 'Kidnapping and abduction'),
(22, 'content_animal_cruelty', 'Animal cruelty and illegal animal activities'),
(23, 'content_sexual_crime', 'Sexual crimes'),
(24, 'content_environmental_crime', 'Environmental crimes'),
(25, 'content_immigration_crime', 'Border and immigration crimes');




select * from rangley.td_meet_category;


INSERT INTO rangley.td_friend_request_status (friend_request_status_id, name) VALUES
(1, 'Pending'),
(2, 'Accepted'),
(3, 'Declined'),
(4, 'Blocked'),
(5, 'Cancelled');



INSERT INTO rangley.td_stock_assets (asset_id, asset_name, asset_category, display_name, file_extension, sort_order) VALUES
(1, 'person.3.fill', 'meet_group', 'Default', 'symbol', 0),
(2, 'basketball.fill', 'meet_group', 'Basketball', 'symbol', 1),
(3, 'football.fill', 'meet_group', 'Football', 'symbol', 2),
(4, 'fork.knife', 'meet_group', 'Dining', 'symbol', 3),
(5, 'book.fill', 'meet_group', 'Study', 'symbol', 4),
(6, 'figure.run', 'meet_group', 'Fitness', 'symbol', 5),
(7, 'gamecontroller.fill', 'meet_group', 'Gaming', 'symbol', 6),
(8, 'music.note', 'meet_group', 'Music', 'symbol', 7),
(9, 'airplane', 'meet_group', 'Travel', 'symbol', 8),
(10, 'cup.and.saucer.fill', 'meet_group', 'Coffee', 'symbol', 9),
(11, 'film.fill', 'meet_group', 'Movies', 'symbol', 10),
(12, 'paintbrush.fill', 'meet_group', 'Art', 'symbol', 11),
(13, 'leaf.fill', 'meet_group', 'Outdoors', 'symbol', 12),
(14, 'brain.head.profile', 'meet_group', 'Mental Health', 'symbol', 13),
(15, 'heart.fill', 'meet_group', 'Social', 'symbol', 14);
(16, 'wineglass.fill', 'meet_group', 'Drinks', 'symbol', 15),
(17, 'tennis.racket', 'meet_group', 'Tennis', 'symbol', 16);



INSERT INTO rangley.te_version_statuses VALUES
    (1, 'active'),
    (2, 'pending'),
    (3, 'deprecated');






-- Insert default rate limit tiers (idempotent)
INSERT INTO rangley.td_rate_limit_tier
(
	rate_limit_tier_id, tier_name, requests_per_hour, requests_per_day
) 
VALUES
    (1, 'free', 10, 50),
    (2, 'premium', 50, 200),
    (3, 'enterprise', 200, 1000)
ON CONFLICT (rate_limit_tier_id) DO UPDATE SET
    tier_name = EXCLUDED.tier_name,
    requests_per_hour = EXCLUDED.requests_per_hour,
    requests_per_day = EXCLUDED.requests_per_day,
    dttm_modified_utc = now(),
    modified_by = CURRENT_USER;

