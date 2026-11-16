# BI JogandoLogica - Power BI (PostgreSQL public)

Fonte: ap_postgres, DB ap_saas, user ap_user, schema public.
Views ja aplicadas em producao (sufixo bi_):
- bi_fato_atividade (sessao + dever + logika + trabalho)
- bi_dim_aluno, bi_dim_escola, bi_dim_disciplina, bi_dim_jogo, bi_dim_data

Reaplicar:
  docker exec -i ap_postgres psql -U ap_user -d ap_saas -v ON_ERROR_STOP=1 < sql/01a_dims.sql
  docker exec -i ap_postgres psql -U ap_user -d ap_saas -v ON_ERROR_STOP=1 < sql/01b_fato.sql

Conectar no Power BI (Desktop):
  Servidor: 127.0.0.1:5432
  Banco: ap_saas (opcional: usar a view public.bi_fato_atividade com user ap_user)
  Modelo: estrela - fato bi_fato_atividade, dims bi_dim_*

Medidas DAX: ver dax/medidas.dax

Validar: bash validar.sh
