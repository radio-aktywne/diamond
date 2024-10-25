-- Set password for the root user
ALTER USER "root"
WITH
  PASSWORD '${DIAMOND__CREDENTIALS__ROOT__PASSWORD:-password}';

-- Create the main user
CREATE USER IF NOT EXISTS "user";

-- Set password for the main user
ALTER USER "user"
WITH
  PASSWORD '${DIAMOND__CREDENTIALS__USER__PASSWORD:-password}';

-- Grant create database privileges to the main user
ALTER USER "user"
WITH
  CREATEDB;

-- Create the database
CREATE DATABASE IF NOT EXISTS "database";

-- Grant all privileges to the main user on the database
GRANT ALL ON DATABASE "database" TO "user";
