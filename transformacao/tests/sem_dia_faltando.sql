-- falha se houver buraco de datas na janela observada
with d as (select min(dt) a, max(dt) b, count(distinct dt) n from {{ ref('silver_requisitos') }})
select * from d where (b - a) + 1 <> n
