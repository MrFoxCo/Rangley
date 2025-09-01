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
INSERT INTO rangley.td_meet_category (meet_category_id, name) VALUES (2, 'Party');
INSERT INTO rangley.td_meet_category (meet_category_id, name) VALUES (3, 'Food');
INSERT INTO rangley.td_meet_category (meet_category_id, name) VALUES (4, 'Planned Trip');
INSERT INTO rangley.td_meet_category (meet_category_id, name) VALUES (5, 'Spontaneous');
INSERT INTO rangley.td_meet_category (meet_category_id, name) VALUES (6, 'Custom');

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
INSERT INTO rangley.td_participant_status (participant_status_id, name) VALUES (4, 'Pending');
INSERT INTO rangley.td_participant_status (participant_status_id, name) VALUES (5, 'Invited');

-- Notification Types
INSERT INTO rangley.td_notification_type (notification_type_id, name) VALUES (0, 'NULL_VALUE');
INSERT INTO rangley.td_notification_type (notification_type_id, name) VALUES (1, 'Meet Created');
INSERT INTO rangley.td_notification_type (notification_type_id, name) VALUES (2, 'Meet Updated');
INSERT INTO rangley.td_notification_type (notification_type_id, name) VALUES (3, 'Meet Cancelled');
INSERT INTO rangley.td_notification_type (notification_type_id, name) VALUES (4, 'New Attendee');
INSERT INTO rangley.td_notification_type (notification_type_id, name) VALUES (5, 'Attendee Left');
INSERT INTO rangley.td_notification_type (notification_type_id, name) VALUES (6, 'Meet Reminder');
INSERT INTO rangley.td_notification_type (notification_type_id, name) VALUES (7, 'System Alert');

select * from rangley.td_meet_category;
