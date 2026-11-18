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


## Caminho C: Microsoft Fabric (Dataflow Gen2 + Lakehouse + Direct Lake)
Roda sem Power BI Desktop, tudo no navegador (workspace de teste Fabric, 60 dias).
1. Dataflow Gen2 `df_gold_csv` com as consultas de `fabric/operacao_auditoria.pq` e `fabric/radar_auditoria.pq` (CSV publico, tipos explicitos, coluna de auditoria `carga_em`).
2. Destino: Lakehouse `lh_plataforma_viva`, metodo Substituir; atualizacao diaria agendada.
3. Modelo semantico em Direct Lake sobre as duas tabelas, com as medidas de `fabric/medidas_fabric.dax`.
4. Relatorio de 2 paginas (resumo da operacao e cobertura media por tecnologia).

Limites: o link do relatorio e privado do workspace (sem link publico) e o teste do Fabric expira; os artefatos do Fabric nao sao versionados, so as consultas e medidas acima.
