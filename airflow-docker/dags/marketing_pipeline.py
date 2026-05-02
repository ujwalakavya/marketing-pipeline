from airflow import DAG
from airflow.operators.bash import BashOperator
from datetime import datetime, timedelta

default_args = {
    'owner': 'ujwala',
    'retries': 1,
    'retry_delay': timedelta(minutes=2),
}

with DAG(
    dag_id='marketing_pipeline',
    default_args=default_args,
    description='Marketing analytics pipeline: staging → marts → test',
    schedule_interval='@daily',
    start_date=datetime(2024, 1, 1),
    catchup=False,
    tags=['marketing', 'daily'],
) as dag:

    dbt_staging = BashOperator(
        task_id='dbt_run_staging',
        bash_command='cd /opt/airflow/marketing_dbt && /home/airflow/.local/bin/dbt run --select staging',
    )

    dbt_marts = BashOperator(
        task_id='dbt_run_marts',
        bash_command='cd /opt/airflow/marketing_dbt && /home/airflow/.local/bin/dbt run --select marts',
    )

    dbt_test = BashOperator(
        task_id='dbt_test',
        bash_command='cd /opt/airflow/marketing_dbt && /home/airflow/.local/bin/dbt test',
    )

    dbt_staging >> dbt_marts >> dbt_test