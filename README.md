# Marketing Analytics Pipeline

An end-to-end data engineering portfolio project that ingests automotive marketing data, transforms it into a cloud data warehouse, automatically orchestrates it, and delivers business insights via a dashboard.

---

## Business Problem

An automotive company spends money on ads across 16 marketing channels — Search Engine, Online Video, Social Media, Finance Partnerships, and Third Party Listings.

The pipeline answers these exact business questions:
- **CPC** (Cost Per Click) = Ad Spend / Total Clicks
- **CAC** (Customer Acquisition Cost) = Ad Spend / Total Sales
- **ROI** (Return on Investment) = Profit / Ad Spend
- **First-Touch Attribution** — which channel gets credit when a user clicks multiple ads before buying?

---

## Architecture

```
CSV Files (6 files, 175K+ rows)
         ↓  Python ingest script
Snowflake RAW schema        ← exact copy of the source, no changes
         ↓  dbt staging models
Snowflake STAGING schema    ← cleaned, typed, validated
         ↓  dbt mart model
Snowflake MARTS schema      ← CPC, CAC, ROI, first-touch attribution
         ↓  Airflow DAG (daily schedule)
         ↓  GitHub Actions CI/CD (on every push)
Tableau Dashboard           ← channel performance insights
```

Follows the **Medallion Architecture** — industry standard 3-layer data design (RAW → STAGING → MARTS).

---

## Tech Stack

| Tool | Role |
|------|------|
| Python | Reads CSVs, loads to Snowflake RAW |
| Snowflake | Cloud data warehouse — stores all 3 layers |
| dbt | SQL transformations, 16 data quality tests, lineage |
| Apache Airflow | Orchestration — daily DAG with task dependency management |
| GitHub Actions | CI/CD — dbt compile and test on every push |
| Tableau | Business dashboard — channel performance insights |

---

## Data

Synthetic automotive marketing data with realistic funnel dropoff ratios:

| File | Rows | Description |
|------|------|-------------|
| clicks.csv | 155,000 | Users who clicked an ad |
| locks.csv | 12,423 | Users who started a purchase |
| sales.csv | 1,250 | Completed purchases |
| spend.csv | 5,840 | Daily ad spend per channel |
| ad_channels.csv | 16 | Channel ID to name mapping |
| vehicles.csv | 40 | Vehicle make/model/profit margin |

Funnel: **155K clicks → 12.4K locks → 1.25K sales = 0.8% click-to-sale rate**

---

## Pipeline DAG

The Airflow DAG runs daily and executes 3 tasks in sequence:

dbt_run_staging → dbt_run_marts → dbt_test

If any task fails, downstream tasks do not run — preventing bad data from reaching the MARTS layer.

---

## dbt Models

**Staging layer** (6 views in STAGING schema):
- `stg_ad_channels` — channel ID to name mapping
- `stg_clicks` — 155K click events, cleaned and typed
- `stg_locks` — lock events with user journey tracking
- `stg_sales` — completed sales with vehicle details
- `stg_spend` — daily spend per channel
- `stg_vehicles` — vehicle profit margin data

**Mart layer** (1 table in MARTS schema):
- `mart_channel_performance` — CPC, CAC, ROI, first-touch attribution aggregated per channel

**Data quality:** 16 dbt tests covering not-null checks, referential integrity, and accepted values — all passing.

---

## Dashboard

Built in Tableau using data from `MART_CHANNEL_PERFORMANCE`:

![Dashboard](https://github.com/ujwalakavya/marketing-pipeline/blob/main/Dashboard.png)

4 visuals:
- ROI by channel
- CPC by channel
- CAC by channel
- Sales volume by channel

With an interactive channel filter to drill down by marketing category.

---

## Project Structure

```
marketing-pipeline/
├── .github/
│   └── workflows/
│       └── dbt_ci.yml                      ← GitHub Actions CI/CD
├── airflow-docker/
│   ├── dags/
│   │   └── marketing_pipeline.py           ← Airflow DAG
│   ├── docker-compose.yaml
│   └── .env                                ← credentials (gitignored)
├── ingest/
│   └── load_raw.py                         ← Python ingest script
├── marketing_dbt/
│   ├── macros/
│   │   └── generate_schema_name.sql
│   ├── models/
│   │   ├── staging/                        ← 6 staging models
│   │   └── marts/
│   │       └── mart_channel_performance.sql
│   └── dbt_project.yml
├── data/
│   └── .gitkeep
├── dashboard.png
└── README.md
```

---

## Setup Instructions

### Prerequisites
- Python 3.9+
- Docker Desktop
- Snowflake account
- dbt-snowflake installed

### Run locally

```bash
# Clone the repo
git clone https://github.com/ujwalakavya/marketing-pipeline.git
cd marketing-pipeline

# Set up virtual environment
python3 -m venv venv
source venv/bin/activate
pip install dbt-snowflake pandas snowflake-connector-python

# Set credentials
export SNOWFLAKE_USER='your_username'
export SNOWFLAKE_PASSWORD='your_password'

# Load data to Snowflake RAW
python3 ingest/load_raw.py

# Run dbt transformations
cd marketing_dbt
dbt run --select staging
dbt run --select marts
dbt test
```

### Run with Airflow

```bash
cd airflow-docker
docker compose up -d
# Open http://localhost:8080
# Login: airflow / airflow
# Trigger marketing_pipeline DAG
```

---

## Resume Bullet

> Engineered an end-to-end marketing analytics pipeline on Snowflake + dbt + Airflow — processing 155K+ automotive click events through a medallion architecture with first-touch attribution, CPC/CAC/ROI metrics, 16 dbt data quality tests, GitHub Actions CI/CD, and Tableau dashboard.

---

## Author

Ujwala Kavya Jayarama

