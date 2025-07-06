-- Set password for the main user
ALTER USER "user"
WITH
  PASSWORD '{{ ( ds "config" ).credentials.user.password }}';
