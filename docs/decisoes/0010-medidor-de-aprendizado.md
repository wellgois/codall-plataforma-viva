# 0010 - Medidor de aprendizado do Codall

Data: 2026-11-12. Status: aceita.

## Contexto
Foi perguntado se o Codall aprende e retem o que e ensinado, com previsao em numeros. Nao havia definicao de "100%" nem registro historico: com 3 dias de dados qualquer previsao seria inventada.

## Decisao
- O vigia grava um livro de eventos (`/opt/erros/aprendizado.jsonl`) a cada incidente, correcao aplicada e reversao.
- Licoes: quando uma correcao e aplicada, a assinatura do erro e a correcao ficam guardadas (`licoes.json`). Se o mesmo erro volta, a correcao e reaproveitada sem nova chamada a IA; se volta depois de corrigido, o relatorio avisa que a correcao nao resolveu a causa.
- `aprendizado.py` calcula por semana e acumulado: autonomia, diagnostico por IA, recorrencia, eficacia das correcoes e reuso de licoes. Relatorio semanal no Telegram.
- Previsao so com 4+ semanas com 3+ incidentes: regressao linear com intervalo de 95%. Sem isso, o relatorio diz "dados insuficientes". Se o intervalo inclui zero, diz "sem tendencia clara".

## Limites
- Mede o que o vigia faz, nao o conhecimento geral do Codall nem o trabalho feito por outros agentes.
- Volume baixo de incidentes e bom para os apps, mas deixa a estatistica fraca; o relatorio avisa quando ha menos de 10 incidentes.
- Teste: `operacao/vigia/teste_aprendizado.sh` (livro sintetico) e o teste do vigia, que agora cobre reincidencia e reuso de licao.
