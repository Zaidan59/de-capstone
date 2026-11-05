"""Data Engineering capstone sample: Airflow -> Apache Hop CLI.

Runs a bundled Hop workflow against synthetic sample PostgreSQL.
Connection metadata `lab-postgres` must first be created in Hop GUI and
available in the mounted project metadata directory.
"""
from datetime import datetime, timedelta
from airflow.sdk import DAG
from airflow.providers.standard.operators.bash import BashOperator

HOP_CMD = (
    'cd /opt/hop && ./hop-run.sh -j capstone-local -e docker-local '
    '-r local -f /opt/lab/workspace/hop-project/workflows/wf_load_sales.hwf'
)
with DAG(
    dag_id='capstone_hop_sample',
    start_date=datetime(2026, 10, 1),
    schedule=None,
    catchup=False,
    max_active_runs=1,
    default_args={'retries': 1, 'retry_delay': timedelta(minutes=1)},
    tags=['capstone', 'apache-hop'],
) as dag:
    run_hop = BashOperator(task_id='run_hop_workflow', bash_command=HOP_CMD)
    verify = BashOperator(
        task_id='report_completion',
        bash_command='echo "Airflow task and Hop CLI finished"',
    )
    run_hop >> verify
