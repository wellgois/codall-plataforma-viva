{{ config(tags=['stream']) }}
select * from read_parquet('{{ var("landing") }}/stream_eventos/dt=*/*.parquet')
