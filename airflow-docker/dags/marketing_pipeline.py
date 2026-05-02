from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.operators.bash import BashOperator
from datetime import datetime, timedelta
import subprocess
import sys

default_args = {
    'owner': 'ujwala',
    'retries': 1,
    'retry_delay': timedelta(minutes=2),
}

def run_ingest():
    result = subprocess.run(
        [sys.executable, '/opt/airflow/ingest/load_raw.py'],
        capture_output=True, text=True
    )
    print(result.stdout)
    if result.returncode != 0:
        raise Exception(result.stderr)

with DAG(
    dag_id='marketing_pipeline',
    default_args=default_args,
    description='Marketing analytics pipeline: ingest → staging → marts → test',
    schedule_interval='@daily',
    start_date=datetime(2024, 1, 1),
    catchup=False,
    tags=['marketing', 'daily'],
) as dag:

    ingest = PythonOperator(
        task_id='ingest_csv_to_snowflake',
        python_callable=run_ingest,
    )

    dbt_staging = BashOperator(
        task_id='dbt_run_staging',
        bash_command='cd /opt/airflow/marketing_dbt && dbt run --select staging',
    )

    dbt_marts = BashOperator(
        task_id='dbt_run_marts',
        bash_command='cd /opt/airflow/marketing_dbt && dbt run --select marts',
    )

    dbt_test = BashOperator(
        task_id='dbt_test',
        bash_command='cd /opt/airflow/marketing_dbt && dbt test',
    )

    ingest >> dbt_staging >> dbt_marts >> dbt_test