#!/bin/sh

# Configuration
host="${DIAMOND__SERVER__HOST:-0.0.0.0}"
sqlport="${DIAMOND__SERVER__PORTS__SQL:-20010}"
httpport="${DIAMOND__SERVER__PORTS__HTTP:-20011}"
rpcport="${DIAMOND__SERVER__PORTS__RPC:-20012}"

retries=30
interval=1

datadir=data/
certsdir="${datadir}/certs/"
storedir="${datadir}/store/"

tmpinit=$(mktemp --suffix=.sql)

# Make sure the directories exists
mkdir --parents "${datadir}" "${certsdir}" "${storedir}"

# Replace environment variables in init file and save to temporary file
envsubst <src/init.sql >"${tmpinit}"

# Remove old certificates
rm --force "${certsdir:?}"/*

# Generate certificates
cockroachdb \
	connect \
	init \
	--sql-addr="${host}:${sqlport}" \
	--advertise-sql-addr="localhost:${sqlport}" \
	--http-addr="${host}:${httpport}" \
	--advertise-http-addr="localhost:${httpport}" \
	--listen-addr="${host}:${rpcport}" \
	--advertise-addr="localhost:${rpcport}" \
	--certs-dir="${certsdir}" \
	--single-node \
	>/dev/null

cockroachdb \
	cert \
	create-client \
	root \
	--certs-dir="${certsdir}" \
	--ca-key="${certsdir}/ca-client.key" \
	>/dev/null

# Start CockroachDB in the background
cockroachdb \
	start-single-node \
	--sql-addr="${host}:${sqlport}" \
	--advertise-sql-addr="localhost:${sqlport}" \
	--http-addr="${host}:${httpport}" \
	--advertise-http-addr="localhost:${httpport}" \
	--listen-addr="${host}:${rpcport}" \
	--advertise-addr="localhost:${rpcport}" \
	--certs-dir="${certsdir}" \
	--accept-sql-without-tls \
	--store="path=${storedir}" \
	&

echo 'Setting up...'

# Wait for CockroachDB to start up
for i in $(seq 1 "${retries}"); do
	if [ "${i}" -eq "${retries}" ]; then
		echo 'Could not connect to CockroachDB!'
		exit 1
	fi

	if cockroachdb \
		sql \
		--certs-dir="${certsdir}" \
		--port="${sqlport}" \
		--execute="" \
		>/dev/null 2>&1 \
		; then
		echo 'Connected to CockroachDB!'
		break
	else
		echo 'Waiting for connection to CockroachDB...'
		sleep "${interval}"
	fi
done

# Setup database
cockroachdb sql \
	--certs-dir="${certsdir}" \
	--port="${sqlport}" \
	--file="${tmpinit}"

echo 'Setup complete!'

# Wait for CockroachDB to exit
wait

# Cleanup
rm --force "${tmpinit}"
