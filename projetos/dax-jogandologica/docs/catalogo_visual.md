# Catálogo de Visuais — Dashboard JogandoLógica

Cada bloco = 1 visual do Power BI Desktop. Campos prontos para arrastar.

## Página 1 — Visão Executiva
| Visual | Tipo | Eixo / Categoria | Valores |
|---|---|---|---|
| KPI Pontos | Cartão | – | `Total Pontos` |
| KPI Alunos | Cartão | – | `Alunos Distintos` |
| KPI Taxa de Acerto | Cartão | – | `Taxa de Acerto %` |
| Evolução diária | Linha | `bi_dim_data[data]` | `Total Pontos`, `Pontos Ultimos 30 Dias` |
| Top 10 Jogos | Barra horizontal | `bi_fato_atividade[jogo_sk]` | `Total Pontos` (TopN 10) |
| Faixa de Engajamento | Rosca | `Faixa Engajamento` | `Alunos Distintos` |

## Página 2 — Alunos (IDs anonimizados)
| Visual | Tipo | Eixo | Valores |
|---|---|---|---|
| Ranking alunos | Tabela | `aluno_sk` | `Ranking Aluno`, `Total Pontos`, `Taxa de Acerto %`, `Faixa Engajamento` |
| Tempo médio | Barra | `aluno_sk` | `Media Minutos/Atividade` |
| Ativos vs total | Cartão multi | – | `Alunos Ativos no Mes`, `% Ativos / Total` |

## Página 3 — Jogos / Módulos
| Visual | Tipo | Eixo | Valores |
|---|---|---|---|
| Ranking jogos | Barra | `jogo_sk` | `Ranking Jogo`, `Total Atividades`, `Pontos Ultimos 7 Dias` |
| Status | Rosca | `bi_fato_atividade[status]` | `Total Atividades` |
| % sessões finalizadas | Cartão | – | `%Sessoes Finalizadas` |

## Página 4 — Calendário / Tendência
| Visual | Tipo | Eixo | Valores |
|---|---|---|---|
| YTD acumulado | Área empilhada | `bi_dim_data[data]` | `Pontos YTD` |
| MoM % | Coluna + linha | `bi_dim_data[mes_nome]` | `Pontos MoM %` |
| Semana vs semana | Linha | `bi_dim_data[semana_ano]` | `Pontos WoW %` |

> Todos os nomes de campo batem com `dax/medidas.dax` e `sql/modelo.sql`.
EOF
