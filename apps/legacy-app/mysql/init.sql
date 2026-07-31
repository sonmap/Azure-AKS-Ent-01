CREATE DATABASE IF NOT EXISTS legacydb CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE legacydb;

CREATE TABLE IF NOT EXISTS customer (
  customer_id BIGINT NOT NULL AUTO_INCREMENT,
  customer_name VARCHAR(100) NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (customer_id)
);

INSERT INTO customer (customer_name) VALUES ('AKS Migration Test User');
