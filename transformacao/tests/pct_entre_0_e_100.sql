select * from {{ ref('gold_radar_demanda') }} where pct_vagas < 0 or pct_vagas > 100
