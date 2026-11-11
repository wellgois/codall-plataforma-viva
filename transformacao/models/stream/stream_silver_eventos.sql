{{ config(tags=['stream'], materialized='table') }}
-- Deduplica por event_id: o mesmo evento reenviado ou reprocessado conta uma vez.
select event_id, ts, dt, origem, projeto, categoria, qtd
from (
    select *, row_number() over (partition by event_id order by ts) as rn
    from {{ ref('stream_bronze_eventos') }}
) where rn = 1
