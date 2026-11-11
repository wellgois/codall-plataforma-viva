select dt, origem, projeto, categoria, sum(qtd) as qtd
from {{ ref('bronze_codall_eventos') }}
group by 1, 2, 3, 4
