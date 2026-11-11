select * from read_parquet('{{ var("landing") }}/pontes_requisitos/dt=*/*.parquet')
