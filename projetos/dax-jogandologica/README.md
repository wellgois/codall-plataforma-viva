# dax-jogandologica

Dashboard **Power BI** modelado sobre os dados reais da Plataforma Viva (projeto JogandoLógica),
lido direto do schema analítico `bi_*` do Postgres `ap_saas`.

## Objetivo
Entregar modelo estrela, medidas DAX e processo de validação para que qualquer analista
reconecte no Power BI Desktop e monte o dashboard — ou rode as medidas em qualquer engine DAX
(Power BI, Tabular Editor, DAX Studio, Excel PowerPivot).

## Fonte de dados (real, em produção)
- Postgres `ap_saas` (container `ap_postgres`), schema analítico já populado:
  - `bi_fato_atividade` — grão = 1 sessão/atividade do aluno
  - `bi_dim_aluno`      — dimensão aluno (pseudonimizada: `aluno_nome` = "Aluno <hash>")
  - `bi_dim_jogo`       — dimensão jogo/módulo
  - `bi_dim_escola`     — dimensão escola
  - `bi_dim_disciplina` — dimensão disciplina
  - `bi_dim_data`       — calendário (ano, mês, dia, semana)
- Origem primária: `logika_missoes` (4.309 linhas, período 2026-04-28 → 2026-11-16).
- Volumetria verificada em `prova.txt`.

## Modelo estrela
```
           bi_dim_data (data_sk int YYYYMMDD)
                 │ 1:N
bi_dim_aluno ──N:1── bi_fato_atividade ──N:1── bi_dim_jogo
                 │ 1:N
             bi_dim_escola / bi_dim_disciplina
```
Fato: `pontos, acertos, erros, tentativas, segundos`.
Chaves: `aluno_sk, jogo_sk, data_sk, disciplina`.

## Anonimização (regra dura)
- Nada de PII na pasta publicada.
- `sql/extract_snapshot.sql` **não seleciona** `aluno_nome` nem `escola_nome`;
  exporta apenas `aluno_sk` e `escola_sk` (hashes já pseudonimizados).
- O CSV gerado fica em `out/`, ignorado pelo `.gitignore` raiz (`projetos/**/*.csv`).
- Publicam-se apenas: esquema + SQL + DAX + README + catálogo de visuais.

## Medidas DAX
25 medidas em `dax/medidas.dax`:
- Volume: Total Pontos, Total Atividades, Alunos Distintos, Jogos Distintos
- Qualidade: Acertos, Erros, Tentativas, Taxa de Acerto %
- Tempo: Minutos Totais, Média Minutos/Atividade
- Tendência: Pontos YTD, Pontos MoM %, Pontos WoW %, Últimos 7/30 Dias
- Ranking: Ranking Aluno, Ranking Jogo
- Engajamento: Faixa Engajamento, % Ativos/Total, Alunos Ativos no Mês, Média Tentativas/Aluno, %Sessões Finalizadas

## Como usar (Power BI Desktop)
1. Conectar ao Postgres `ap_saas` (host do servidor, user `ap_user`).
2. Carregar as 6 tabelas `bi_*` (fato + 5 dimensões).
3. Marcar `bi_dim_data` como **Tabela de Datas** em `data`.
4. Criar relacionamentos 1:N — cada dimensão aponta para o fato por `*_sk`/`data_sk`.
5. Colar as medidas de `dax/medidas.dax`.
6. Aplicar os visuais descritos em `docs/catalogo_visual.md`.

## Como validar os números
```
bash scripts/validar.sh
```
Compara soma de pontos, taxa de acerto e cobertura no Postgres com o que o Power BI deve mostrar.

## Limites e o que NÃO foi entregue
- **`.pbix` não é gerado** (ferramenta proprietária; não automatizável server-side).
  README + `sql/modelo.sql` + `dax/medidas.dax` reconstroem o arquivo em < 30 min.
- **Publicação automática no Power BI Service** não implementada (exige tenant + credenciais).
- **Dashboards visuais** entregues como `docs/catalogo_visual.md` (especificação do visual);
  não há PNG/PDF.

## Decisões
1. **Fonte = `bi_*`** (schema analítico já modelado), não o SQLite de teste
   `/opt/jogandologica-api/data/jogandologica.db` (que tem 1 linha fictícia).
2. **Sem PII**: `aluno_nome`/`escola_nome` ficam fora da extração e da pasta publicada.
3. **DAX em arquivo texto** (`.dax`), não em `.pbix`, para versionar no Git.
4. **IDs são hashes**: `aluno_sk` e `escola_sk` já vêm assim do ETL do JogandoLógica.
EOF
