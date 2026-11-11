"""DAG de stream: a cada 2 min valida o contrato dos eventos e roda so os modelos
com tag stream, em um DuckDB proprio (nao disputa o arquivo com a DAG diaria)."""
from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.bash import BashOperator

with DAG(
    dag_id="plataforma_viva_stream",
    schedule="*/2 * * * *",
    start_date=datetime(2026, 11, 1),
    catchup=False,
    max_active_runs=1,
    default_args={"retries": 1, "retry_delay": timedelta(minutes=1)},
    tags=["plataforma-viva", "streaming"],
) as dag:
    contrato = BashOperator(
        task_id="validar_contrato_stream",
        bash_command="python /opt/ingestao/validar_contrato.py /opt/landing /opt/contratos/stream",
    )
    dbt = BashOperator(
        task_id="dbt_build_stream",
        env={"DUCKDB_PATH": "/opt/warehouse/stream.duckdb"},
        append_env=True,
        bash_command="cd /opt/transformacao && dbt build --select tag:stream --profiles-dir . --target-path /tmp/dbt-target-stream --log-path /tmp/dbt-logs-stream",
    )
    contrato >> dbt
