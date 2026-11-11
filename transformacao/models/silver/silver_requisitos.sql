-- Normaliza o texto livre do requisito em uma tecnologia canonica.
with base as (
    select distinct dt, vaga_hash, fonte_tipo, titulo_vaga, requisito_nome, requisito_tipo
    from {{ ref('bronze_pontes_requisitos') }}
)
select
    dt, vaga_hash, fonte_tipo, titulo_vaga, requisito_nome, requisito_tipo,
    case
        when lower(requisito_nome) like '%airflow%' then 'Airflow'
        when lower(requisito_nome) like '%spark%' then 'Spark'
        when lower(requisito_nome) like '%databricks%' then 'Databricks'
        when lower(requisito_nome) like '%kafka%' then 'Kafka'
        when lower(requisito_nome) like '%dbt%' then 'dbt'
        when lower(requisito_nome) like '%aws%' then 'AWS'
        when lower(requisito_nome) like '%azure%' then 'Azure'
        when lower(requisito_nome) like '%gcp%' or lower(requisito_nome) like '%bigquery%' then 'GCP'
        when lower(requisito_nome) like '%delta%' or lower(requisito_nome) like '%lakehouse%' then 'Lakehouse'
        when lower(requisito_nome) like '%sql%' then 'SQL'
        when lower(requisito_nome) like '%python%' then 'Python'
        when lower(requisito_nome) like '%ci/cd%' or lower(requisito_nome) like '%docker%' then 'CI/CD'
        when lower(requisito_nome) like '%governan%' or lower(requisito_nome) like '%lgpd%' then 'Governanca'
        when lower(requisito_nome) like '%qualidade%' then 'Qualidade'
        when lower(requisito_nome) like '%power bi%' then 'Power BI'
        when lower(requisito_nome) like '%ingl%' then 'Ingles'
        else 'Outros'
    end as tecnologia,
    case
        when lower(titulo_vaga) like '%junior%' or lower(titulo_vaga) like '%jr%' then 'junior'
        when lower(titulo_vaga) like '%senior%' or lower(titulo_vaga) like '%sr%' then 'senior'
        when lower(titulo_vaga) like '%pleno%' then 'pleno'
        else 'nao_informado'
    end as senioridade
from base
