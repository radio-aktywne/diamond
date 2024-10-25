#!/bin/bash

# Activate runtime shell
# shellcheck source=/dev/null
. /env/activate

# Set permissions
chown --recursive database: data/

# Run as non-root user
# Use tini to handle signals
exec su-exec database tini -- "$@"
