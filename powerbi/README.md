# Power BI sobre a camada gold

Duas formas de conectar, da mais simples para a mais completa. Nenhuma expoe dado pessoal: so as tabelas gold agregadas (radar com k >= 5 e operacao diaria).

## Caminho A: CSV publico (funciona hoje, custo zero)
Os CSV ficam em `https://codall.site/plataforma/gold/` e sao regerados todo dia as 05:45.
1. Power BI Desktop > Obter dados > Consulta em branco > Editor Avancado.
2. Cole o conteudo de `radar.pq` (e, para a operacao, `operacao.pq`).
3. Fechar e aplicar. Atualizar dados baixa o CSV do dia.

## Caminho B: Athena (apos abrir a conta AWS)
1. `infra/terraform` cria bucket, catalogo Glue e o workgroup `plataforma-viva-bi` (limite de 100 MB lidos por consulta).
2. Instale o driver ODBC do Athena e crie um DSN apontando para o workgroup e o banco `plataforma_viva`.
3. Obter dados > ODBC > tabelas `gold_radar_demanda` e `gold_operacao_diaria`.
4. Use as medidas de `medidas.dax`.

## Painel sugerido (uma pagina)
- Cartao: vagas analisadas (ultimo dia) e data de referencia.
- Barras horizontais: `pct_vagas` por `tecnologia` no ultimo dia, ordenadas.
- Linhas: `pct_media_7d` por `tecnologia` (segmentacao para 3 a 5 tecnologias).
- Colunas empilhadas: `eventos` por dia e `projeto` (operacao dos produtos).

O arquivo .pbix nao e versionado (binario, pode embutir cache de dados). Este diretorio guarda tudo que o recria: consultas M e medidas DAX.
