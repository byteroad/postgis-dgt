import os
import sys
import hashlib
import argparse
import geopandas as gpd
from sqlalchemy import create_engine, text
from sqlalchemy.engine import URL

# Command-line arguments parser
parser = argparse.ArgumentParser(description='Upload a shapefile/geopackage to PostgreSQL if modified.')
parser.add_argument('--database', default='geodb', help='Name of the PostgreSQL database')
parser.add_argument('--user', required=True, help='PostgreSQL username')
parser.add_argument('--password', required=False, help='PostgreSQL password')
parser.add_argument('--host', default='localhost', help='PostgreSQL host, default is localhost')
parser.add_argument('--port', default='5432', help='PostgreSQL port, default is 5432')
parser.add_argument('--table', default='none', help='Table name to create from the shapefile/geopackage')
parser.add_argument('--primary_key', default='objectid', help='Column name to use as the primary key for the new table')
parser.add_argument('--input', default=None, help='Path to the shapefile or geopackage file to import')
args = parser.parse_args()

DATABASE = args.database
USER = args.user
PASSWORD = args.password
HOST = args.host
PORT = args.port
TABLE = args.table
INPUT_FILE = args.input
PRIMARY_KEY = args.primary_key

# 1. Handle missing or 'None' file input gracefully
if not INPUT_FILE or INPUT_FILE == 'None' or not os.path.exists(INPUT_FILE):
    print(f"[WARNING] Input file '{INPUT_FILE}' was not found. Skipping import for table '{TABLE}'.")
    sys.exit(0)

def calculate_input_hash(filepath):
    """Calculate MD5 hash of input file (and sidecars if shapefile)."""
    hasher = hashlib.md5()
    files_to_hash = [filepath]

    # If shapefile, include sidecar files (.dbf, .shx, .prj, .cpg) in hash calculation
    if filepath.endswith('.shp'):
        base_path = os.path.splitext(filepath)[0]
        for ext in ['.dbf', '.shx', '.prj', '.cpg', '.sbn', '.sbx']:
            sidecar = base_path + ext
            if os.path.exists(sidecar):
                files_to_hash.append(sidecar)

    for fpath in sorted(files_to_hash):
        with open(fpath, 'rb') as f:
            while chunk := f.read(65536):
                hasher.update(chunk)
    return hasher.hexdigest()

try:
    file_hash = calculate_input_hash(INPUT_FILE)
    file_mtime = os.path.getmtime(INPUT_FILE)
except Exception as e:
    print(f"[WARNING] Error reading input file '{INPUT_FILE}': {e}. Skipping.", file=sys.stderr)
    sys.exit(0)

# Establish database connection using URL builder for safe parameter handling
try:
    connection_url = URL.create(
        "postgresql+psycopg2",
        username=USER,
        password=PASSWORD,
        host=HOST,
        port=int(PORT),
        database=DATABASE,
    )
    engine = create_engine(connection_url)

    # 2. Check persistent import tracker table & enable postgis extension
    with engine.connect() as conn:
        conn.execute(text("CREATE EXTENSION IF NOT EXISTS postgis;"))
        conn.execute(text("""
            CREATE TABLE IF NOT EXISTS public._import_tracker (
                table_name VARCHAR PRIMARY KEY,
                file_path VARCHAR,
                file_hash VARCHAR,
                file_mtime DOUBLE PRECISION,
                imported_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
        """))
        conn.commit()

        result = conn.execute(
            text("SELECT file_hash FROM public._import_tracker WHERE table_name = :table"),
            {"table": TABLE}
        ).fetchone()

        if result and result[0] == file_hash:
            print(f"[INFO] Table '{TABLE}' is already up-to-date with file '{INPUT_FILE}' (hash: {file_hash}). Skipping import.")
            sys.exit(0)

    # Import shapefile or geopackage to PostgreSQL
    print(f"[INFO] File '{INPUT_FILE}' changed or not imported yet. Reading geodataframe...")
    if INPUT_FILE.endswith('.shp'):
        gdf = gpd.read_file(INPUT_FILE)
    elif INPUT_FILE.endswith('.gpkg'):
        gdf = gpd.read_file(INPUT_FILE, layer=0)
    else:
        print(f"[WARNING] Unsupported file format for '{INPUT_FILE}'. Please provide a shapefile (.shp) or geopackage (.gpkg).", file=sys.stderr)
        sys.exit(0)

    # Check projection and convert to EPSG:4326 if necessary
    if gdf.crs is not None and gdf.crs.to_epsg() != 4326:
        print(f"[INFO] Converting CRS from {gdf.crs} to EPSG:4326...")
        gdf = gdf.to_crs(epsg=4326)

    if PRIMARY_KEY in gdf.columns:
        print(f"[INFO] Using data column '{PRIMARY_KEY}' as primary key.")
        gdf = gdf.set_index(PRIMARY_KEY, drop=True)
    else:
        print(
            f"[INFO] '{PRIMARY_KEY}' not found as a column in the source data. "
            f"Using auto-generated row index as '{PRIMARY_KEY}' instead."
        )

    # Write GeoDataFrame to PostgreSQL
    print(f"[INFO] Writing geodataframe to PostGIS table '{TABLE}'...")
    gdf.to_postgis(TABLE, engine, if_exists='replace', index=True, index_label=PRIMARY_KEY, chunksize=10000)

    # Explictly adding Primary Key
    with engine.connect() as conn:
        print(f"[INFO] Adding primary key constraint on '{PRIMARY_KEY}'...")
        conn.execute(text(f'ALTER TABLE public."{TABLE}" ADD PRIMARY KEY ("{PRIMARY_KEY}");'))
        conn.commit()

    # Update tracker table
    with engine.connect() as conn:
        conn.execute(
            text("""
                INSERT INTO public._import_tracker (table_name, file_path, file_hash, file_mtime, imported_at)
                VALUES (:table, :file_path, :file_hash, :file_mtime, NOW())
                ON CONFLICT (table_name) DO UPDATE SET
                    file_path = EXCLUDED.file_path,
                    file_hash = EXCLUDED.file_hash,
                    file_mtime = EXCLUDED.file_mtime,
                    imported_at = NOW();
            """),
            {
                "table": TABLE,
                "file_path": INPUT_FILE,
                "file_hash": file_hash,
                "file_mtime": file_mtime
            }
        )
        conn.commit()

    print(f"[SUCCESS] Table '{TABLE}' created/updated successfully from file '{INPUT_FILE}'.")
except Exception as e:
    print(f"[ERROR] Unable to import '{INPUT_FILE}' to table '{TABLE}': {e}", file=sys.stderr)
    sys.exit(1)