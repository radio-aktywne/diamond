-- Set password for the main user
ALTER USER "user"
WITH
  PASSWORD '{{ ( ds "config" ).credentials.user.password }}';

-- Grant create database privileges to the main user
ALTER USER "user"
WITH
  CREATEDB;

-- Connect to the main database
\connect "database"

-- Enable UUID generation
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
