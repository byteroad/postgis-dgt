#!/bin/bash

# Source Database Connection Details
# SRC_HOST="remote-source.example.com"
# SRC_PORT="5432"
# SRC_DB="gis_source"
# SRC_USER="reader_user"
# SRC_PASSWORD="secure_source_password"

# Destination Database Connection Details
# DST_HOST="localhost"
# DST_PORT="5432"
# DST_DB="gis_destination"
# DST_USER="postgres"
# DST_PASSWORD="local_destination_password"

# List of tables to synchronize (space separated)
# TABLE_LIST="schema.table1 schema.table2 schema.table3"

# Tentatives if some connection fails
# RETRY_COUNT="5"
# Seconds to wait between retries if a connection fails
# RETRY_DELAY="10"

# =====================================================================
# 0. SET DEFAULT VALUES
# =====================================================================
RETRY_COUNT="${RETRY_COUNT:-5}"
RETRY_DELAY="${RETRY_DELAY:-10}"

# =====================================================================
# 1. VALIDATE ENVIRONMENT VARIABLES
# =====================================================================
REQUIRED_VARS=(
    SRC_HOST SRC_PORT SRC_DB SRC_USER SRC_PASSWORD
    DST_HOST DST_PORT DST_DB DST_USER DST_PASSWORD
    TABLE_LIST RETRY_COUNT RETRY_DELAY
)

echo "[INFO] Validating environment variables..."
MISSING_VARS=0
for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var}" ]; then
        echo "[ERROR] Environment variable '$var' is not set!" >&2
        MISSING_VARS=1
    fi
done

if [ "$MISSING_VARS" -ne 0 ]; then
    echo "[FATAL] Missing required system variables. Aborting." >&2
    exit 1
fi

# =====================================================================
# 2. CONNECTIVITY CHECK FUNCTION WITH RETRIES
# =====================================================================
check_connection() {
    local label=$1
    local host=$2
    local port=$3
    local db=$4
    local user=$5
    local pass=$6
    local attempt=1

    while [ $attempt -le "$RETRY_COUNT" ]; do
        echo "[INFO] Checking connection to $label (Attempt $attempt/$RETRY_COUNT)..."
        
        # Runs a quick query to guarantee both network availability and authentication success
        if PGPASSWORD="$pass" psql -h "$host" -p "$port" -U "$user" -d "$db" -c "SELECT 1;" >/dev/null 2>&1; then
            echo "[SUCCESS] Connected to $label."
            return 0
        fi
        
        echo "[WARNING] Connection to $label failed."
        if [ $attempt -lt "$RETRY_COUNT" ]; then
            echo "[INFO] Retrying in ${RETRY_DELAY} seconds..."
            sleep "$RETRY_DELAY"
        fi
        attempt=$((attempt + 1))
    done

    echo "[ERROR] Connection to $label failed after $RETRY_COUNT attempts." >&2
    return 1
}

# Run connectivity checks
if ! check_connection "Source Database" "$SRC_HOST" "$SRC_PORT" "$SRC_DB" "$SRC_USER" "$SRC_PASSWORD"; then
    echo "[FATAL] Source database is unreachable." >&2
    exit 1
fi

if ! check_connection "Destination Database" "$DST_HOST" "$DST_PORT" "$DST_DB" "$DST_USER" "$DST_PASSWORD"; then
    echo "[FATAL] Destination database is unreachable." >&2
    exit 1
fi

# =====================================================================
# 3. DUMP AND RESTORE PIPELINE
# =====================================================================
TEMP_DIR=$(mktemp -d)
# Clean up temporary files even if the script crashes or is terminated prematurely
trap 'echo "[INFO] Cleaning up temporary files..."; rm -rf "$TEMP_DIR"' EXIT

echo "[INFO] Starting backup phase..."

# Phase 3a: Local Dump (No changes made to destination yet)
for table in $TABLE_LIST; do
    # Replace dots with underscores to support schema-qualified names safely in file names
    safe_filename="${table//./_}.dump"
    local_dump_file="$TEMP_DIR/$safe_filename"

    echo "[INFO] Dumping table '$table' from source..."
    if ! PGPASSWORD="$SRC_PASSWORD" pg_dump \
        -h "$SRC_HOST" \
        -p "$SRC_PORT" \
        -U "$SRC_USER" \
        -d "$SRC_DB" \
        -t "$table" \
        -Fc \
        -f "$local_dump_file" 2>&1; then
        echo "[ERROR] Failed to dump table '$table' from source database." >&2
        exit 1
    fi
done

echo "[INFO] All dumps completed successfully. Starting restore phase..."

# Phase 3b: Tight Delete-and-Import on Destination
for table in $TABLE_LIST; do
    safe_filename="${table//./_}.dump"
    local_dump_file="$TEMP_DIR/$safe_filename"

    echo "[INFO] Check the schema of '$table' exists in the destination..."
    schema_name="public"
    if [[ "$table" == *.* ]]; then
        schema_name="${table%%.*}"
    fi

    if ! PGPASSWORD="$DST_PASSWORD" psql \
        -h "$DST_HOST" \
        -p "$DST_PORT" \
        -U "$DST_USER" \
        -d "$DST_DB" \
        -c "CREATE SCHEMA IF NOT EXISTS $schema_name;" >/dev/null 2>&1; then
        echo "[ERROR] Failed to create schema '$schema_name' on destination database." >&2
        exit 1
    fi

    echo "[INFO] Dropping and restoring table '$table' on destination..."
    if ! PGPASSWORD="$DST_PASSWORD" pg_restore \
        -h "$DST_HOST" \
        -p "$DST_PORT" \
        -U "$DST_USER" \
        -d "$DST_DB" \
        --clean \
        --if-exists \
        "$local_dump_file" 2>&1; then
        echo "[ERROR] Failed to restore table '$table' to destination database." >&2
        exit 1
    fi
    echo "[SUCCESS] Table '$table' successfully synced."
done

echo "[SUCCESS] All tables synchronized successfully!"