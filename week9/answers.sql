-- Create your tables, views, functions and procedures here!
CREATE SCHEMA social;
USE social;

-- the tables:
CREATE TABLE users (
    user_id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    email VARCHAR(100),
    created_on TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE sessions (
    session_id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    user_id INT UNSIGNED,
    created_on TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_on TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id)
);

CREATE TABLE friends (
    user_friend_id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    user_id INT UNSIGNED,
    friend_id INT UNSIGNED,
    FOREIGN KEY (user_id) REFERENCES users(user_id),
    FOREIGN KEY (friend_id) REFERENCES users(user_id)
);

CREATE TABLE posts (
    post_id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    user_id INT UNSIGNED,
    created_on TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_on TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    content TEXT,
    FOREIGN KEY (user_id) REFERENCES users(user_id)
);

CREATE TABLE notifications (
    notification_id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    user_id INT UNSIGNED,
    post_id INT UNSIGNED,
    FOREIGN KEY (user_id) REFERENCES users(user_id),
    FOREIGN KEY (post_id) REFERENCES posts(post_id)
);

-- the view: - Not sure what to order these by, so I'l wait and see if I get FAILS.
CREATE VIEW notification_posts AS
	SELECT n.user_id, u.first_name, u.last_name, p.post_id, p.content 
    FROM notifications AS n
	LEFT JOIN users AS u ON n.user_id = u.user_id
	LEFT JOIN posts AS p ON n.post_id = p.post_id;

-- When a new user is added, create a notification for everyone that states "{first_name} 
-- {last_name} just joined!" (for example: "Jeromy Streets just joined!").
DELIMITER ;;
CREATE PROCEDURE add_new_user(IN first_name VARCHAR(30), IN last_name VARCHAR(30), IN email VARCHAR(30))
BEGIN
    INSERT INTO users(first_name, last_name, email) VALUES(first_name, last_name, email);
    SET @new_user_id = LAST_INSERT_ID(); -- getting the last inserted record, I had to look this one up
    INSERT INTO notifications(user_id, post_id)
    SELECT u.user_id, NULL FROM users u WHERE u.user_id <> @new_user_id;
END ;;
DELIMITER ;

-- Every 10 seconds, remove all sessions that haven't been updated in the last 2 hours.
DELIMITER ;;
CREATE EVENT remove_old_sessions
	ON SCHEDULE EVERY 10 SECOND
	DO
		DELETE FROM sessions s WHERE s.updated_on < DATE_SUB(NOW(), INTERVAL 2 HOUR); -- not sure about this one
;;
DELIMITER ; -- UPDATE: I made a mistake after all XD(END;;)

-- add_post(user_id, content): Create a procedure that adds a post 
-- and creates notifications for all of the user's friends.
DELIMITER ;;
CREATE PROCEDURE add_post(IN user_id INT UNSIGNED, IN content TEXT)
BEGIN
    INSERT INTO posts(user_id, content) VALUES(user_id, content);
    SET @new_post_id = LAST_INSERT_ID(); -- getting the last inserted record, I had to look this one up
    INSERT INTO notifications(user_id, post_id)
    SELECT f.friend_id, @new_post_id FROM friends f WHERE f.user_id = user_id;
END ;;
DELIMITER ;
