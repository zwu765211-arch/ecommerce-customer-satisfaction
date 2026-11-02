-- Olist E-Commerce Analysis | First revision
-- MySQL 8.0.16 or later. Execution order:
-- 00 -> 01 -> 01-1 -> 02 -> 03 -> 04 -> 05 -> 06.
-- Use one Workbench connection during CSV staging and loading.
-- Fresh build: 01 creates tables; 01-1 loads five revised clean CSVs.
-- Existing databases require a separately reviewed migration; this sequence is for a fresh build.
SELECT VERSION() AS mysql_version,
    CURRENT_USER() AS connected_user,
    @@character_set_server AS server_character_set,
    @@session.sql_mode AS session_sql_mode,
    @@global.local_infile AS local_infile_enabled;

-- Strict mode makes INSERT reject invalid conversions instead of hiding them.
-- This changes this connection only, not the global server configuration.
SET SESSION sql_mode =
    'STRICT_TRANS_TABLES,ONLY_FULL_GROUP_BY,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';
SET NAMES utf8mb4;
CREATE DATABASE IF NOT EXISTS olist_ecommerce
    CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE olist_ecommerce;
SELECT DATABASE() AS active_database;

