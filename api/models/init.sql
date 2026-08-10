-- DevOps Project Database Initialization
CREATE DATABASE IF NOT EXISTS crud_app CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE crud_app;

CREATE TABLE IF NOT EXISTS users (
  id       INT AUTO_INCREMENT PRIMARY KEY,
  name     VARCHAR(100)  NOT NULL,
  email    VARCHAR(150)  NOT NULL UNIQUE,
  password VARCHAR(255)  NOT NULL,
  role     ENUM('admin','editor','viewer') NOT NULL DEFAULT 'viewer',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_email (email),
  INDEX idx_role  (role)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Create application user with minimum permissions
CREATE USER IF NOT EXISTS 'appuser'@'%' IDENTIFIED BY '${APP_DB_PASSWORD}';
GRANT SELECT, INSERT, UPDATE, DELETE ON crud_app.* TO 'appuser'@'%';
FLUSH PRIVILEGES;
