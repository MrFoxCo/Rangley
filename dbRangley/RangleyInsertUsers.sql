-- seed row: id = 0
INSERT INTO rangley.tb_users (user_id,cognito_sub, username, display_name, first_name, last_name, email, dob)
OVERRIDING SYSTEM VALUE
VALUES (0, 'NULL_VALUE', 'NULL_VALUE','NULL_VALUE', 'NULL_VALUE', 'NULL_VALUE', 'NULL@email.com','1999-01-01');

-- admin with explicit id = 1
INSERT INTO rangley.tb_users (cognito_sub, username, display_name, email, dob)
VALUES ('NULL_VALUE1','Admin', 'Rangley Admin', 'anthony@mrfoxco.com','1999-01-01');



select * from rangley.vw_users;

UPDATE rangley.tb_users
SET dttm_modified_utc = now()
WHERE user_id = 2;