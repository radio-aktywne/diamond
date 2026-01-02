# Configuration for the credentials
credentials:
  # Configuration for main user credentials
  user:
    # Password for the main user
    password: {{ env.Getenv "DIAMOND__CREDENTIALS__USER__PASSWORD" "password" | strings.Quote }}

# Configuration for the server
server:
  # Host to run the server on
  host: {{ env.Getenv "DIAMOND__SERVER__HOST" "0.0.0.0" | strings.Quote }}

  # Port to run the server on
  port: {{ env.Getenv "DIAMOND__SERVER__PORT" "20010" | conv.ToInt }}
