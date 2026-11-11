-- Percentual de vagas do dia que pedem cada tecnologia, com media movel de 7 dias.
with vagas_dia as (
    select dt, count(distinct vaga_hash) as vagas from {{ ref('silver_requisitos') }} group by 1
),
tec_dia as (
    select dt, tecnologia, count(distinct vaga_hash) as vagas_com_tec
    from {{ ref('silver_requisitos') }} group by 1, 2
)
select
    t.dt, t.tecnologia, v.vagas, t.vagas_com_tec,
    round(100.0 * t.vagas_com_tec / v.vagas, 1) as pct_vagas,
    round(avg(100.0 * t.vagas_com_tec / v.vagas) over (
        partition by t.tecnologia order by t.dt rows between 6 preceding and current row), 1) as pct_media_7d
from tec_dia t join vagas_dia v using (dt)
