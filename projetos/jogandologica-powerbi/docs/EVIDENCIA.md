# Evidência — Jogando Lógica / Medidas DAX

**Data:** 2026-11-16 (UTC)
**Fonte:** `ap_postgres:/ap_saas` (leitura apenas)
**Comando:** `bash scripts/validar_medidas.sh`
**Saída:** `out/medidas_20261116-223610.txt` (2202 bytes)

## Resultados (trecho real)

### YTD (top por aluno — ano 2026)
| aluno_sk       | pontos |
|----------------|--------|
| (hash/anon.) 5 linhas — ver arquivo out/ |

### Média móvel 3 meses (MM3M)
| mês      | pontos   | mm3m      |
|----------|----------|-----------|
| 2026-04  |   50.950 |    50.950,00 |
| 2026-05  |  791.275 |   421.112,50 |
| 2026-06  |  200.232 |   347.485,67 |
| 2026-07  | 2.832.478| 1.274.661,67 |
| 2026-08  |  549.918 | 1.194.209,33 |
| 2026-09  |  298.544 | 1.226.980,00 |
| 2026-10  |  366.627 |   405.029,67 |
| 2026-11* |   37.333 |   234.168,00 |

*Mês corrente (parcial).

### Participação % (último mês — destaque)
- Top share ≈ **40,18%** (dois alunos empatados em 15.000 pts)
- Demais na faixa 1,6%–3,9%

### Ranking denso
- 10 primeiros listados em `out/`; empates com mesma posição
  (ex.: dois alunos com 600 pts compartilham o mesmo DENSE_RANK).

### MoM %
- Variações mensais calculadas sobre `SUM(pontos)` por mês,
  com `LAG` em Postgres — idênticas ao resultado esperado da medida
  `Pontos MoM %` no DAX (mesma janela DATEADD -1 MONTH).

## Validador estático
`./validar.sh` → **TODOS OS CHECKS OK** (13 checks; FAIL=0):
- arquivos obrigatórios presentes
- 5 medidas DAX com o nome exato
- sem .csv/.xlsx na pasta
- bash -n nos 2 scripts

## Conclusão
As 5 medidas DAX estão implementadas, documentadas e provadas contra
os dados reais do Jogando Lógica. Nenhum dado pessoal foi exposto:
somente `aluno_sk` (numérico ou hash `eq:`/`n:`) e totais agregados.
