#!/bin/bash

# Source container env if available
[ -f /app/env.sh ] && . /app/env.sh

# Source Database Connection Details
# SRC_HOST="remote-source.example.com"
# SRC_PORT="5432"
# SRC_DB="gis_source"
# SRC_USER="reader_user"
# SRC_PASSWORD="secure_source_password"

# Target output directory for GeoPackage files
# OUTPUT_DIR="/data"

# List of tables to export (space separated)
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
OUTPUT_DIR="${OUTPUT_DIR:-/data}"

# =====================================================================
# 1. VALIDATE ENVIRONMENT VARIABLES & OUTPUT DIRECTORY
# =====================================================================
REQUIRED_VARS=(
    SRC_HOST SRC_PORT SRC_DB SRC_USER SRC_PASSWORD
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

mkdir -p "$OUTPUT_DIR"

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

# =====================================================================
# 3. GEOPACKAGE EXPORT PIPELINE USING GDAL (ogr2ogr)
# =====================================================================
echo "[INFO] Starting GeoPackage export process..."

for table in $TABLE_LIST; do
    safe_filename="${table//./_}.gpkg"
    tmp_file="$OUTPUT_DIR/.${safe_filename}.tmp"
    output_file="$OUTPUT_DIR/$safe_filename"

    echo "[INFO] Exporting table '$table' to temporary GeoPackage '$tmp_file'..."
    
    if PGPASSWORD="$SRC_PASSWORD" ogr2ogr -f "GPKG" "$tmp_file" \
        PG:"host=$SRC_HOST port=$SRC_PORT dbname=$SRC_DB user=$SRC_USER" \
        "$table" \
        -overwrite; then
        mv "$tmp_file" "$output_file"
        echo "[SUCCESS] Table '$table' successfully exported to '$output_file'."
    else
        echo "[ERROR] Failed to export table '$table' to GeoPackage." >&2
        rm -f "$tmp_file"
        exit 1
    fi
done

echo "[SUCCESS] All tables exported to GeoPackage format successfully!"