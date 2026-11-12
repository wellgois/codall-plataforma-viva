# Treino do Codall: currículo e comparativo com/sem licoes

Objetivo: medir se as licoes guardadas fazem o Codall acertar mais, em vez de supor. Nada de producao: tudo em `/tmp/treino*`, sem reinicio, sem ler `.env`.

## Teto e parada
- Teto de gasto: US$ 1,50/dia (~8 mi de tokens; custo medido no DeepSeek: ~US$ 0,18 por milhao de tokens).
- Parar apos 3 falhas seguidas ou ao estourar o teto; avisar o Wellgois.

## Protocolo A/B (pareado)
1. Escolher uma licao L (ex.: "o banco do ap-saas chama-se ap_saas") e uma tarefa T que so se resolve bem sabendo L.
2. Rodada B (sem licao): arquivar L (mover para `disabled`, com backup), rodar T, anotar resultado.
3. Rodada A (com licao): restaurar L, rodar T de novo (mesmo enunciado), anotar.
4. Registrar por rodada: acertou (criterio objetivo, conferido por mim), numero de rodadas, comandos com falha, tokens.
5. Repetir para pelo menos 10 pares (licao, tarefa) antes de concluir; embaralhar a ordem A/B entre pares para nao confundir com cansaco do contexto.
6. Analise: teste dos sinais/Wilcoxon pareado. Com menos de 10 pares: so descrever, nao concluir.

Cuidados: licao restaurada ao fim de cada par; tarefa deve ter resposta verificavel; nao reaproveitar a mesma conversa (limpar contexto entre A e B).

## Currículo (engenharia de dados com IA e ML)
1. Perfilamento e limpeza de CSV com pandas (nulos, tipos, duplicatas).
2. Modelo dbt com teste de qualidade em DuckDB.
3. ETL em Python idempotente.
4. DAG de Airflow que passa na checagem de sintaxe.
5. Engenharia de atributos e treino com scikit-learn (separacao treino/teste).
6. Avaliacao de modelo para dado desbalanceado (metrica correta).
7. Deteccao de vazamento de dados (data leakage) em exemplo com erro.
8. Mini RAG: embeddings simples e busca por similaridade em documentos locais.
9. Contrato de dados e validacao de esquema.
10. Diagnostico de erro de producao simulado, com causa-raiz.

Cada tarefa tem criterio objetivo (saida real, `diff`, teste que passa/falha). "N/A" conta como nao feito.

## Registro
Resultados por rodada em `docs/treino-resultados.csv` (colunas: data, par, condicao A/B, acertou, rodadas, falhas, tokens).
