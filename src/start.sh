#!/bin/sh

### Constants

datadir=data/postgres/

### Temporary files and directories

tmpconfig="$(mktemp --suffix=.yaml)"
tmpsetup="$(mktemp --suffix=.sql)"
tmpsocketdir="$(mktemp --directory)"

### Functions

# Cleanup function to remove temporary files and directories
cleanup() {
	rm --recursive --force "${tmpconfig}" "${tmpsetup}" "${tmpsocketdir}"
}

# Function to check if database is initialized
isinitialized() {
	if [ -s "${1}/PG_VERSION" ]; then
		printf '%s' true
	else
		printf '%s' false
	fi
}

# Reusable generic database initialization function
init() {
	initdb --pgdata="${1}" \
		--encoding=UTF8 \
		--locale=C \
		--username=postgres \
		--auth-local=trust \
		--auth-host=password
}

# Main database initialization function
initialize() {
	echo 'Initializing data directory...'
	if ! init "${1}"; then
		echo 'Failed to initialize data directory!'
		exit 1
	fi
}

# Function to get major version of PostgreSQL that the data is compatible with
getdatamajor() {
	tr --delete '[:space:]' <"${1}/PG_VERSION"
}

# Function to get major version of PostgreSQL binary
getbinmajor() {
	postgres --version | tr '[:blank:]' '\n' | tail --lines=1 | cut --delimiter='.' --fields=1 | tr --delete '[:space:]'
}

# Function to get PostgreSQL directory for a specific major version
getpgdir() {
	eval echo "\${POSTGRES${1}}"
}

# Upgrade function
upgrade() {
	echo "Data directory contains data for PostgreSQL ${2}, but current PostgreSQL binary is ${3}!"

	olddir="$(getpgdir "${2}")"

	if [ -z "${olddir}" ]; then
		echo "No PostgreSQL ${2} binary available!"
		echo 'Automatic upgrade cannot be performed!'
		echo 'Please upgrade the database manually!'
		exit 1
	fi

	echo "Upgrading data directory to PostgreSQL ${3}..."

	oldbindir="${olddir}/bin/"
	# shellcheck disable=SC2312
	newbindir="$(dirname "$(command -v postgres)")/"

	newdatadir=data/postgres.new/

	# Initialize new data directory
	rm --recursive --force "${newdatadir}"
	mkdir --parents "${newdatadir}"

	if ! init "${newdatadir}"; then
		echo 'Failed to initialize new data directory!'
		exit 1
	fi

	fulloldbindir="$(realpath "${oldbindir}")"
	fullnewbindir="$(realpath "${newbindir}")"
	fullolddatadir="$(realpath "${1}")"
	fullnewdatadir="$(realpath "${newdatadir}")"
	currentdir="$(pwd)"
	tmpdir="$(mktemp --directory)"

	cd "${tmpdir}" || exit 1

	# Copy data with adjustments
	if ! pg_upgrade \
		--old-bindir="${fulloldbindir}" \
		--new-bindir="${fullnewbindir}" \
		--old-datadir="${fullolddatadir}" \
		--new-datadir="${fullnewdatadir}" \
		--username=postgres \
		--link \
		; then
		echo 'Failed to upgrade data directory!'
		cd "${currentdir}" || exit 1
		rm --recursive --force "${newdatadir}" "${tmpdir}"
		exit 1
	fi

	cd "${currentdir}" || exit 1

	rm --recursive --force "${1}" "${tmpdir}"
	mv "${newdatadir}" "${1}"
}

# Function to fill values in the configuration file
fillconfig() {
	gomplate \
		--file src/config.yaml.tpl \
		--out "${1}"
}

# Function to fill values in the dynamic setup file
fillsetup() {
	gomplate \
		--file src/setup/dynamic.sql.tpl \
		--datasource config="${1}" \
		--out "${2}"
}

# Function to setup ignoring signals
ignoresignals() {
	for signal in INT TERM HUP QUIT; do
		trap '' "${signal}"
	done
}

# Function to start PostgreSQL
startpostgres() {
	echo 'Starting PostgreSQL...'

	# shellcheck disable=SC2312
	postgres \
		-h "$(yq eval '.server.host' "${1}")" \
		-p "$(yq eval '.server.port' "${1}")" \
		-k "${2}" \
		-D "${3}" \
		&
}

# Function to setup signal handling
handlesignals() {
	for signal in INT TERM HUP QUIT; do
		trap 'kill -'"${signal}"' '"${1}"'; wait '"${1}"'; status=$?; cleanup; exit "${status}"' "${signal}"
	done
}

# Function to wait until PostgreSQL is ready
waituntilready() {
	retries=30
	interval=1

	for i in $(seq 1 "${retries}"); do
		if [ "${i}" -eq "${retries}" ]; then
			echo 'Could not connect to PostgreSQL!'
			exit 1
		fi

		# shellcheck disable=SC2312
		if pg_isready \
			--host="${2}" \
			--port="$(yq eval '.server.port' "${1}")" \
			--username=postgres \
			--dbname=postgres \
			--quiet \
			; then
			echo 'Connected to PostgreSQL!'
			break
		else
			echo 'Waiting for connection to PostgreSQL...'
			sleep "${interval}"
		fi
	done
}

# Static setup function
staticsetup() {
	echo 'Running static setup...'

	# shellcheck disable=SC2312
	psql \
		--host="${2}" \
		--port="$(yq eval '.server.port' "${1}")" \
		--username=postgres \
		--dbname=postgres \
		--file=src/setup/static.sql
}

# Dynamic setup function
dynamicsetup() {
	echo 'Running dynamic setup...'

	# shellcheck disable=SC2312
	psql \
		--host="${2}" \
		--port="$(yq eval '.server.port' "${1}")" \
		--username=postgres \
		--dbname=postgres \
		--file="${3}"
}

# Function to wait for PostgreSQL to exit and handle cleanup
waitandcleanup() {
	wait "${1}"
	status=$?

	# Cleanup temporary files and directories
	cleanup

	exit "${status}"
}

### Main script execution

# Make sure the directory exists
mkdir --parents "${datadir}"

# Check if database is already initialized
initialized="$(isinitialized "${datadir}")"

# Initialize data directory if not already initialized
if [ "${initialized}" = false ]; then
	initialize "${datadir}"
else
	datamajor="$(getdatamajor "${datadir}")"
	binmajor="$(getbinmajor)"

	# Upgrade data directory if necessary
	if [ "${datamajor}" != "${binmajor}" ]; then
		upgrade "${datadir}" "${datamajor}" "${binmajor}"
	fi
fi

# Fill values in the configuration file
fillconfig "${tmpconfig}"

# Fill values in dynamic setup file
fillsetup "${tmpconfig}" "${tmpsetup}"

# Temporarily ignore signals
ignoresignals

# Start PostgreSQL in the background
startpostgres "${tmpconfig}" "${tmpsocketdir}" "${datadir}"

# Setup signal handling
pid=$!
handlesignals "${pid}"

# Wait for PostgreSQL to start
waituntilready "${tmpconfig}" "${tmpsocketdir}"

# Setup the database statically if not already initialized
if [ "${initialized}" = false ]; then
	staticsetup "${tmpconfig}" "${tmpsocketdir}"
fi

# Setup the database dynamically
dynamicsetup "${tmpconfig}" "${tmpsocketdir}" "${tmpsetup}"

echo 'PostgreSQL is ready!'

# Wait for PostgreSQL to exit
waitandcleanup "${pid}"
