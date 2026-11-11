"""DAG diaria: contratos -> dbt build. Os extratores rodam no host (somente leitura)
e depositam parquet em landing/ antes das 04:30; esta DAG so valida e transforma."""
from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.bash import BashOperator

with DAG(
    dag_id="plataforma_viva_diaria",
    schedule="0 5 * * *",
    start_date=datetime(2026, 11, 1),
    catchup=False,
    max_active_runs=1,
    default_args={"retries": 2, "retry_delay": timedelta(minutes=10)},
    tags=["plataforma-viva", "lakehouse"],
) as dag:
    contratos = BashOperator(
        task_id="validar_contratos",
        bash_command="python /opt/ingestao/validar_contrato.py /opt/landing /opt/contratos",
    )
    dbt = BashOperator(
        task_id="dbt_build",
        bash_command="cd /opt/transformacao && dbt build --exclude tag:stream --profiles-dir . --target-path /tmp/dbt-target --log-path /tmp/dbt-logs",
    )
    contratos >> dbt
