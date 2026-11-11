{{ config(tags=['stream'], materialized='table') }}
select date_trunc('minute', ts) as minuto, projeto, origem, categoria, sum(qtd) as eventos
from {{ ref('stream_silver_eventos') }}
group by 1, 2, 3, 4
