---
slug: /usage
title: Usage
---

## Connecting to the database

You can use any SQL client to connect to the database.
The default connection string is:

```text
postgresql://user:password@localhost:20010/database
```

## Web UI

You can use the web UI to inspect the details of the database.
By default, it is available at [`https://localhost:20011`](https://localhost:20011).
It is only available via HTTPS and uses a self-signed certificate,
so you will probably need to add a security exception in your browser.
