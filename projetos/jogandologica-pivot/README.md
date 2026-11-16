# jogandologica-pivot

Projeto Excel avancado sobre a base anonimizada JogandoLogica. Le CSVs do
diretorio fora do repo (`/root/dados-jogandologica`, chmod 600) e produz um
xlsx com **formulas reais** Excel/LibreOffice, sem dados pessoais.

## Abas do xlsx (`jogandologica-pivot.xlsx`)
- **sessoes** — 1 linha por sessao (`id_jogo, aluno_ref, pontuacao, acertos,
  erros, tempo_seg, status, iniciado, finalizado`)
- **jogos** — catalogo (`id, tipo, nivel, tamanho, tempo_min, pontos_max,
  status, catalogo, criado`)
- **agregado** — por (`aluno_ref, jogo_id`): sessoes, acertos, erros, pontos,
  tempo_medio_seg
- **analise** — painel com KPIs, ranking top 10 e ficha do jogo-alvo,
  todos por **formula** (89 celulas com string iniciando por `=`)

## Formulas usadas na aba `analise`
KPIs globais (coluna B):
- `=COUNTA(sessoes!A:A)-1` — total de sessoes
- `=SUM(sessoes!D:D)` — pontuacao total
- `=SUM(sessoes!E:E)` / `=SUM(sessoes!F:F)` — acertos / erros
- `=IFERROR(B4/(B4+B5),0)` — **percentual de acerto** (formatado `0.00%`)
- `=AVERAGEIFS(sessoes!H:H,sessoes!H:H,"conclu*")` — tempo medio concluido
- `=COUNTIFS(sessoes!H:H,"em_andamento")` / `=COUNTIFS(sessoes!H:H,"conclu*")`

Ranking top 10 (linhas 5..14, colunas A..I):
- `=LARGE(agregado!F:F,A5)` — k-esimo maior total de pontos
- `=INDEX(agregado!B:B,MATCH(B5,agregado!F:F,0))` — jogo_id do k-esimo
- `=INDEX(jogos!B:B,MATCH(C5,jogos!A:A,0))` — tipo (via **INDEX/MATCH**)
- `=INDEX(jogos!C:C,MATCH(C5,jogos!A:A,0))` — nivel
- `=SUMIFS(agregado!C:C,agregado!B:B,C5)` — sessoes por jogo
- `=SUMIFS(agregado!D:D,agregado!B:B,C5)` / `SUMIFS(...E:E...)` — acertos / erros
- `=IF((G5+H5)=0,0,G5/(G5+H5))` — percentual de acerto do jogo

Ficha do jogo-alvo (A17..B23) — via **INDEX/MATCH**:
- `tipo` / `nivel` = `INDEX(jogos!B:B,MATCH(B17,jogos!A:A,0))` etc.
- `sessoes` = `COUNTIFS(sessoes!B:B,B17)`
- `pontuacao` = `SUMIFS(sessoes!D:D,sessoes!B:B,B17)`
- `pct_acerto` = `SUMIFS(acertos)/(SUMIFS(acertos)+SUMIFS(erros))`
- `sessoes_via_agregado` = `INDEX(agregado!C:C,MATCH(B17,agregado!B:B,0))`

**Sem XLOOKUP** (compativel com Excel 2016+ e LibreOffice).

## Limite conhecido
- `openpyxl` **nao cria Tabela Dinamica nativa** (PivotTable). A aba `analise`
  entrega os mesmos agregados por **formula** (SUMIFS/COUNTIFS/AVERAGEIFS +
  LARGE/INDEX/MATCH), mas nao ha slicer nem `Refresh` de PivotTable.
- O xlsx **nao traz valores cacheados**: abra no Excel/LibreOffice (ou rode
  `soffice --headless --convert-to xlsx`) para que as formulas calculem.

## Tabelas fonte (confirmadas em 2026-11-16)
- `jogos_educativos(id, tipo, nivel, tamanho, tempo_minutos, pontos_max, status, catalogo, created_at, aluno_id, ...)`
- `jogos_educativos_sessoes(id, jogo_id, aluno_id, pontuacao, acertos, erros, tempo_gasto_segundos, status, iniciado_em, finalizado_em, ...)`

`aluno_id` e um inteiro sem FK com `students.id` (text). Nao ha join direto.

## Como rodar
Requer `docker exec ap_postgres psql -U ap_user -d ap_saas` funcionando
e `openpyxl` instalado no host (pip).

```bash
DAT=/root/dados-jogandologica bash extrair.sh
DAT=/root/dados-jogandologica python3 gerar_xlsx.py
```

## Saidas (em $PASTA_DADOS, chmod 600)
- `sessoes_anon.csv`         — sessao por linha, com `aluno_ref` sequencial
- `jogos_anon.csv`           — jogos (sem titulo/aluno)
- `agregado_aluno_jogo.csv`  — por (aluno_ref, jogo_id): sessoes, acertos, erros, pontos, tempo medio
- `jogandologica-pivot.xlsx` — **4 abas** (sessoes, jogos, agregado, analise)

## Higiene
- Pasta publicada tem so `README.md`, `.gitignore`, `extrair.sh`, `gerar_xlsx.py`.
- CSVs/xlsx/pycache antigos: movidos para `/root/_lixeira/<TS>-jlp/` (reversivel).
- Backups *.bak-<TS> gerados pelo painel: ignorados pelo git.
- Nunca coloque `DATABASE_URL`, `.env`, CSV bruto ou xlsx com dados de aluno
  dentro desta pasta.
