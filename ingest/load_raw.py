# ─────────────────────────────────────────────
# load_raw.py
# PURPOSE: Load all 6 CSV files into Snowflake RAW schema
# WHY: RAW layer = exact copy of source data, no transformations
#      This is the foundation of the medallion architecture
# ─────────────────────────────────────────────

import snowflake.connector
from snowflake.connector.pandas_tools import write_pandas
import pandas as pd
import os
import warnings
warnings.filterwarnings('ignore')

# ── CONCEPT: We use environment variables for credentials
# Never hardcode passwords in Python files
# They get committed to GitHub and exposed publicly
print("Connecting to Snowflake...")

conn = snowflake.connector.connect(
    user=os.environ["SNOWFLAKE_USER"],
    password=os.environ["SNOWFLAKE_PASSWORD"],
    account="JICPOWL-QIB81371",
    warehouse="MARKETING_WH",
    database="MARKETING_DB",
    schema="RAW"
)

print("✅ Connected successfully")

# ── CONCEPT: This dictionary maps table names to file paths
# Key   = what the table will be called in Snowflake
# Value = where the CSV file lives on your Mac
csv_files = {
    "RAW_AD_CHANNELS": "data/ad_channels.csv",
    "RAW_VEHICLES":    "data/vehicles.csv",
    "RAW_SPEND":       "data/spend.csv",
    "RAW_CLICKS":      "data/clicks.csv",
    "RAW_LOCKS":       "data/locks.csv",
    "RAW_SALES":       "data/sales.csv"
}

cursor = conn.cursor()

# ── Tell Snowflake which database/schema to use
cursor.execute("USE DATABASE MARKETING_DB")
cursor.execute("USE SCHEMA RAW")
cursor.execute("USE WAREHOUSE MARKETING_WH")

# ── Loop through each file and load it
for table_name, file_path in csv_files.items():
    print(f"\n{'─'*50}")
    print(f"Loading: {file_path} → {table_name}")

    # ── CONCEPT: encoding='utf-8-sig' handles BOM characters
    # Some CSV files have an invisible character at the start
    # (called BOM) — this removes it automatically
    df = pd.read_csv(file_path, encoding='utf-8-sig')

    # ── CONCEPT: Snowflake stores column names in UPPERCASE by default
    # write_pandas matches DataFrame columns to Snowflake columns
    # Both must be uppercase to match — this is the key fix
    df.columns = [
        c.strip().upper().replace(' ', '_')
        for c in df.columns
    ]

    print(f"  Columns : {list(df.columns)}")
    print(f"  Rows    : {len(df):,}")

    # ── Create table with UPPERCASE column names
    # No quotes around column names = Snowflake treats them as uppercase
    col_defs = ", ".join([f"{c} VARCHAR" for c in df.columns])
    cursor.execute(
        f'CREATE OR REPLACE TABLE {table_name} ({col_defs})'
    )

    # ── CONCEPT: write_pandas is Snowflake's bulk loader
    # Much faster than INSERT row by row
    # 155K clicks would take 10+ mins with INSERT
    # write_pandas does it in seconds using a temp stage
    success, nchunks, nrows, _ = write_pandas(
        conn=conn,
        df=df,
        table_name=table_name,
        database="MARKETING_DB",
        schema="RAW",
        quote_identifiers=False  # False = uppercase matching (Snowflake default)
    )

    if success:
        print(f"  ✅ Loaded {nrows:,} rows in {nchunks} chunk(s)")
    else:
        print(f"  ❌ Failed — check connection and try again")

cursor.close()
conn.close()

print(f"\n{'═'*50}")
print("✅ All 6 tables loaded to MARKETING_DB.RAW")
print("Next step: verify in Snowflake with SHOW TABLES")