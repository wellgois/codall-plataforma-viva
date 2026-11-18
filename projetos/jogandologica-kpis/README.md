# JogandoLógica — Dashboard de KPIs de engajamento

Dashboard de KPIs construído sobre os dados **reais** da plataforma JogandoLógica
(plataforma educacional de jogos), reaproveitando a camada dimensional `bi_*` já
criada em [`../jogandologica-powerbi`](../jogandologica-powerbi). Nenhum dataset público e nenhum dado pessoal de aluno.

## O que o dashboard responde
- Quanto a plataforma é usada: atividades, participantes distintos e sessões de jogo.
- Como o uso evolui por mês e por tipo de atividade (sessão, dever, lógika, trabalho).
- Quantos participantes ficam ativos em cada mês.
- Em quais dias da semana o uso se concentra.
- Qual a taxa de acerto por tipo de atividade e quais jogos têm mais sessões, tempo médio e acerto.

## Como funciona
```
bi_fato_atividade (Postgres)  ->  sql/kpis.sql  ->  dashboard/kpis.json
                                                  ->  dashboard/index.html (autocontido)
```
- `sql/kpis.sql`: uma consulta somente leitura que devolve **um documento JSON agregado**.
- `scripts/gerar_dashboard.sh`: roda a consulta no container `ap_postgres`, grava `kpis.json` e injeta os dados no `template.html`, gerando `index.html`.
- `dashboard/index.html`: página única, sem biblioteca externa e sem requisição de rede (gráficos em SVG, tema claro/escuro automático). Abre direto no navegador.
- As "leituras automáticas" do rodapé são calculadas pelo próprio JavaScript a partir dos dados, então não envelhecem com texto escrito à mão.

## Decisões
- **Contagem de atividades em vez de pontos.** Os pontos têm escalas muito diferentes entre tipos (as sessões somam milhões e os deveres milhares) e um pico em julho distorce qualquer gráfico. Atividades e participantes são comparáveis.
- **Participantes distintos, nunca nomes.** A consulta devolve só contagens; não há identificador de aluno no JSON.
- **Taxa de acerto = acertos ÷ (acertos + erros)**, só sobre atividades que têm tentativas.
- **Tempo médio só com sessões entre 1 s e 1 h**, para não deixar sessões esquecidas abertas inflarem a média.
- **HTML autocontido** para o resultado funcionar sem servidor, e fácil de publicar.

## Limites
- É um **retrato estático**: os números valem para o momento de `gerado_em`. Para atualizar, rode `scripts/gerar_dashboard.sh` de novo.
- O último mês do período é **parcial**; não compare com mês fechado.
- Cobre só o JogandoLógica. Os dados do euprofessor (APIA) ficam para uma próxima versão, porque estão em outro esquema e pedem outra camada de views.
- Cada tipo de atividade tem uma qualidade de dado diferente (por exemplo, "lógika" identifica equipes, não alunos), então "participantes distintos" soma alunos e equipes.

## Como reproduzir
```
cd /opt/plataforma-viva/projetos/jogandologica-kpis
bash scripts/gerar_dashboard.sh
```
Requer `docker`, o container `ap_postgres` e `python3`.
