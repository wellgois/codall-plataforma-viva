-- modelo.sql — documento do modelo estrela.
-- Roda como SELECTs descritivos; não cria nada.

SELECT 'bi_dim_data.data_sk          -> bi_fato_atividade.data_sk'       AS relacao
UNION ALL SELECT 'bi_dim_aluno.aluno_sk        -> bi_fato_atividade.aluno_sk'
UNION ALL SELECT 'bi_dim_jogo.jogo_sk          -> bi_fato_atividade.jogo_sk'
UNION ALL SELECT 'bi_dim_escola.escola_sk      -> bi_dim_aluno.escola_sk (bridge)'
UNION ALL SELECT 'bi_dim_disciplina.disciplina -> bi_fato_atividade.disciplina';

-- Cobertura e volumetria (para conferir os KPIs).
SELECT
  (SELECT COUNT(*) FROM bi_fato_atividade)                     AS fato_linhas,
  (SELECT COUNT(DISTINCT aluno_sk) FROM bi_fato_atividade)     AS alunos,
  (SELECT COUNT(DISTINCT jogo_sk)  FROM bi_fato_atividade)     AS jogos,
  (SELECT SUM(pontos)     FROM bi_fato_atividade)              AS pontos_total,
  (SELECT SUM(acertos)    FROM bi_fato_atividade)              AS acertos_total,
  (SELECT SUM(tentativas) FROM bi_fato_atividade)              AS tentativas_total,
  (SELECT MIN(data_sk)    FROM bi_fato_atividade)              AS data_min,
  (SELECT MAX(data_sk)    FROM bi_fato_atividade)              AS data_max;
EOF
