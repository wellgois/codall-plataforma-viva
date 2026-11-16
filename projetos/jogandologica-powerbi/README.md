# Jogando Lógica — Medidas DAX (Projeto da Semana)

## Objetivo
Aplicar 5 medidas DAX clássicas de BI (**YTD, variação mês a mês,
ranking, média móvel, participação %**) sobre os dados **reais** do
projeto Jogando Lógica (dados em `ap_postgres:/ap_saas`, views `bi_*`),
documentando cada uma com: regra de negócio, DAX e prova de equivalência
em SQL — sem depender de dataset público e sem expor dados pessoais.

## Fonte de dados (real)
- Container: `ap_postgres` | db `ap_saas` | schema `public`
- Fato: `bi_fato_atividade` — 8.410 linhas, período **2026-04-27 →
  2026-11-16**, **513 alunos** distintos.
- Dimensões: `bi_dim_data` (106 dias), `bi_dim_aluno`, `bi_dim_escola`,
  `bi_dim_disciplina`, `bi_dim_jogo`.
- Tipos de atividade (soma de pontos): sessao=4,59M | logika=478k | dever=55,7k.
- Agregado mensal de pontos:

| mês       | pontos    | atividades |
|-----------|-----------|------------|
| 2026-04   |    50.950 |        821 |
| 2026-05   |   791.275 |      1.080 |
| 2026-06   |   200.232 |        526 |
| 2026-07   | 2.832.478 |      2.046 |
| 2026-08   |   549.918 |      1.482 |
| 2026-09   |   298.544 |        946 |
| 2026-10   |   366.627 |        809 |
| 2026-11*  |    37.333 |        700 |

*Mês corrente (parcial) — relevante para YoY/YTD e para MoM sem viés
de mês fechado; em produção, o MoM do mês corrente deve ser comparado
com o mesmo intervalo do mês anterior (ver "Limites").

## As 5 medidas (arquivo `dax/05_medidas_core.dax`)

### 1. Pontos YTD
```
Pontos YTD = TOTALYTD ( [Total Pontos], bi_dim_data[data] )
```
- Acumula pontos desde 1º/jan do ano em contexto.
- Requer `bi_dim_data` marcada como *Date table* no Power BI
  (`Mark as date table`), com coluna `data` contínua (26 linhas × 4
  colunas, cobrindo 2026-04-27..2026-11-16).
- Uso: cartão "acumulado do ano" e linha por mês no gráfico de barras.

### 2. Variação mês a mês (MoM %)
```
Pontos MoM % =
VAR atual    = [Total Pontos]
VAR anterior = CALCULATE ( [Total Pontos], DATEADD ( bi_dim_data[data], -1, MONTH ) )
RETURN DIVIDE ( atual - anterior, anterior )
```
- `DIVIDE` evita divisão por zero no primeiro mês.
- **Decisão:** manter a medida sem `IF(ano_atual="", ...)`, porque o
  visual já filtra pelo calendário; a lógica de ano novo fica nas
  páginas. Para MoM "no mês fechado", trocar por `PREVIOUSMONTH`.

### 3. Ranking Aluno
```
Ranking Aluno = RANKX ( ALLSELECTED ( bi_dim_aluno[aluno_id] ),
                        [Total Pontos], , DESC, Dense )
```
- `ALLSELECTED` respeita os filtros do visual (turma/escola/período).
- `Dense` evita buracos em empate.
- Uso: tabela de alunos com coluna de posição + "Top 10".

### 4. Média móvel de 3 meses (MM3M)
```
Pontos MM3M =
VAR fim    = MAX ( bi_dim_data[data] )
VAR janela = DATESINPERIOD ( bi_dim_data[data], fim, -3, MONTH )
RETURN DIVIDE (
    CALCULATE ( [Total Pontos], janela ),
    CALCULATE ( DISTINCTCOUNT ( bi_dim_data[ano_mes] ), janela )
)
```
- Divide pela **contagem real de meses** na janela (não por 3 fixo),
  senão o início da série infla artificialmente para baixo.
- Suaviza o pico de julho (2,83M) sem apagar sinal: MM3M(jul) > MM3M(ago).

### 5. Participação % (share do aluno no mês)
```
Participação % =
VAR linha    = [Total Pontos]
VAR totalMes = CALCULATE ( [Total Pontos],
                           ALLSELECTED ( bi_dim_aluno ),
                           VALUES ( bi_dim_data[ano_mes] ) )
RETURN DIVIDE ( linha, totalMes )
```
- `ALLSELECTED(bi_dim_aluno)` **remove o filtro do próprio aluno**
  mantendo o do período — sem isso o share é sempre 100%.
- `VALUES(ano_mes)` mantém o mês para calcular o denominador certo.
- Uso: gráfico de "share por aluno" com legenda mensal.

## Estrutura da pasta (o que é publicado)
```
jogandologica-powerbi/
├── README.md                       (este arquivo)
├── dax/
│   ├── medidas.dax                 (original, 20 linhas — suporte)
│   └── 05_medidas_core.dax         (5 medidas obrigatórias + apoio)
├── sql/
│   ├── 01a_dims.sql                (views bi_dim_*)
│   ├── 02_amostra.sql              (creates das views com contagem)
│   └── 10_medidas_equivalencia.sql (equivalência em Postgres)
├── scripts/
│   └── validar_medidas.sh          (roda as 5 consultas e gera out/)
├── validar.sh                      (validador geral da pasta)
├── docs/
│   └── README.md                   (nota técnica interna)
└── out/                            (gerado, *NÃO versionado*)
```
`out/` é ignorado pelo `.gitignore` do repositório
(`projetos/**/out/`, `*.xlsx`, `*.csv`) — **só código e documentação
vão para o GitHub**.

## Como reproduzir
```
cd /opt/plataforma-viva/projetos/jogandologica-powerbi
bash scripts/validar_medidas.sh        # gera out/medidas_<ts>.txt
```

## Decisões
1. **Dados reais, sem dataset público** — fonte é o `ap_saas` já em
   produção; nenhuma amostra sintética.
2. **Sem dados pessoais no GitHub** — `scripts/*.py` original e
   planilhas ficam em `out/` (gitignore) ou `.bak-*`. Nenhum `.xlsx/
   .csv` é versionado; consultas só devolvem `aluno_sk` (hash).
3. **DAX nativo do Power BI, SQL equivalente** — cada medida tem prova
   em Postgres em `sql/10_medidas_equivalencia.sql`; a diferença entre
   os dois resultados é a "prova" de que a medida DAX está correta.
4. **Mês corrente é parcial** — MoM do mês em curso é comparado com
   mês fechado no visual principal; aviso em cartão.
5. **Não alteramos o app Jogando Lógica** — só leitura nas views `bi_*`.
6. **Duas referências de "Total Pontos"**: contexto do visual
   (compartilhado) e janela móvel (MM3M); YTD segue o calendário.

## Limites
- Não temos acesso ao `.pbix` publicado: a "medida publicada" é
  documentada aqui para colagem no Power BI Service/Desktop. A prova de
  corretude é a equivalência SQL.
- `Dense` no ranking é escolha (empates 1,1,2). Para "positions 1..N"
  use `RANKX(..., Skip)`.
- MoM depende de dois meses fechados; em tabelas diárias use
  `PREVIOUSMONTH`.
- Sem licença Power BI, não há medida executada no serviço; isso está
  fora do escopo do VPS.

## Evidência (pasta publicada)
- `out/medidas_<ts>.txt` — saída real das 5 consultas (gerada por
  `scripts/validar_medidas.sh`).
- `bin/pedir-restart.sh` **NÃO é usado aqui** (nada do codall muda).

## Registro de execução
- Dia 1: escopo — escolhido Jogando Lógica (dados reais mensais).
- Dia 2: núcleo — 5 medidas em `dax/05_medidas_core.dax`.
- Dia 3: testes — equivalência SQL e `scripts/validar_medidas.sh`.
- Dia 4: documentação — este README.
- Dia 5: publicado no repositório `codall-plataforma-viva`.
