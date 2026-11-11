select dt, projeto, origem, sum(qtd) as eventos
from {{ ref('silver_eventos') }}
group by 1, 2, 3
