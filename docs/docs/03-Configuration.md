---
slug: /config
title: Configuration
---

## Environment variables

You can configure the database at runtime using various environment variables:

- `DIAMOND__SERVER__HOST` -
  host to listen for connections on
  (default: `0.0.0.0`)
- `DIAMOND__SERVER__PORTS__SQL` -
  port to listen for SQL connections on
  (default: `20010`)
- `DIAMOND__SERVER__PORTS__HTTP` -
  port to listen for HTTP connections on
  (default: `20011`)
- `DIAMOND__SERVER__PORTS__RPC` -
  port to listen for RPC connections on
  (default: `20012`)
- `DIAMOND__CREDENTIALS__ROOT__PASSWORD` -
  password for the root user
  (default: `password`)
- `DIAMOND__CREDENTIALS__USER__PASSWORD` -
  password for the main user
  (default: `password`)
