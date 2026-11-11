select * from read_parquet('{{ var("landing") }}/codall_eventos/dt=*/*.parquet')
