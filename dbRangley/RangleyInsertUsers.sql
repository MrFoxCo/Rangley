-- seed row: id = 0
INSERT INTO rangley.tb_users (user_id,cognito_sub, username, display_name, first_name, last_name, email, dob)
OVERRIDING SYSTEM VALUE
VALUES (0, 'NULL_VALUE', 'NULL_VALUE','NULL_VALUE', 'NULL_VALUE', 'NULL_VALUE', 'NULL@email.com','1999-01-01');

-- admin with explicit id = 1
INSERT INTO rangley.tb_users (cognito_sub, username, display_name, email, dob)
VALUES ('NULL_VALUE1','Admin', 'Rangley Admin', 'anthony@mrfoxco.com','1999-01-01');

-- regular insert (let identity generate userid)
INSERT INTO rangley.tb_users (cognito_sub, username, display_name, cellphone, email, dob)
VALUES ('NULL_VALUE2','anthonyguzzardo', 'Anthony Guzzardo', '+17737060003', 'anthony@gmail.com','1998-09-24');

INSERT INTO rangley.tb_users (cognito_sub, username, display_name, cellphone, email, dob)
VALUES ('NULL_VALUE3','psychadelicsteve', 'Steve Schulte','+1773123442', 'steve@gmail.com','2002-03-13');


select * from rangley.vw_users;