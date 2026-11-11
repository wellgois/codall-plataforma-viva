# Postmortem: primeira execucao da DAG falhou (pyarrow, numpy e permissao)

Data: 11/11/2026. Severidade: baixa (ambiente novo, sem execucao agendada perdida).
Formato sem culpados.

## Resumo
A primeira execucao da DAG falhou em `validar_contratos`; depois, em `dbt_build`.
Tres causas encadeadas, descobertas uma por vez.

## Causas
1. **Parquet novo, leitor velho.** O host gravava parquet com pyarrow 26; o do Airflow e mais antigo e
   nao le as estatisticas de tamanho (`Repetition level histogram size mismatch`).
2. **Correcao errada.** Atualizar o pyarrow no container exigiu numpy 2, e o Airflow 2.10 fixa numpy 1.x
   (`pyarrow requires NumPy 2.0 or newer`).
3. **Permissao.** O volume do warehouse pertencia ao root e o dbt (usuario `airflow`) nao conseguia abrir o DuckDB.

## Correcoes
- pyarrow do host fixado em `>=16,<18`, compativel com o container.
- Imagem do Airflow sem atualizar pyarrow/numpy (comentario no Dockerfile explica o motivo).
- `chown` do volume no script de subida; limite de memoria do webserver ajustado (93% de uso).

## Aprendizado
O contrato de dados valida colunas e tipos, mas nao a versao do formato de arquivo. Entre as
acoes da Fase 2: teste de leitura cruzada (escrever no host, ler no container) no CI.
