SET character_set_server = utf8;
SET character_set_database = utf8;
CREATE DATABASE IF NOT EXISTS ske DEFAULT CHARACTER SET utf8;

/*
    メンバーごとの1日の更新数
    メンバーごとの1月の更新数
    メンバーごとの1日の文字数
    メンバーごとの1月の文字数
*/
USE ske

DROP TABLE IF EXISTS `member`;
CREATE TABLE IF NOT EXISTS `member` (
   id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    display_name VARCHAR(256) NOT NULL,
    is_active TINYINT UNSIGNED NOT NULL DEFAULT 1,
    is_kenkyuusei TINYINT UNSIGNED NOT NULL DEFAULT 0,
    created_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL
) ENGINE=InnoDB;

DROP TABLE IF EXISTS `blog_update_history`;
CREATE TABLE IF NOT EXISTS `blog_update_history` (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    member_id INT UNSIGNED NOT NULL,
    title VARCHAR(512) NOT NULL, 
    body TEXT NOT NULL,
    blog_update_time DATETIME NOT NULL,
    created_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL,
    UNIQUE INDEX(member_id, blog_update_time)
) ENGINE=InnoDB;

DROP TABLE IF EXISTS `blog_rotation`;
CREATE TABLE IF NOT EXISTS `blog_rotation` (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    member_id INT UNSIGNED NOT NULL,
    sort INT UNSIGNED NOT NULL,
    turn TINYINT UNSIGNED NOT NULL,
    created_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL,
    INDEX(member_id)
) ENGINE=InnoDB;

-- turnはとりあえず
INSERT INTO `blog_rotation` (member_id, turn, sort, created_at) VALUES 
(49, 0, 1, NOW()),
(50, 0, 2, NOW()),
(51, 0, 3, NOW()),
(52, 0, 4, NOW()),
(53, 0, 5, NOW()),
(54, 0, 6, NOW()),
(55, 0, 7, NOW()),
(56, 0, 8, NOW()),
(57, 0, 9, NOW());

