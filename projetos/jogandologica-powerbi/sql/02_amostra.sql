SELECT 'fato' AS bloco, tipo_atividade, count(*) AS linhas, count(distinct aluno_sk) AS alunos, coalesce(sum(pontos),0) AS pontos FROM bi_fato_atividade GROUP BY 1,2
UNION ALL SELECT 'dims', 'escola', count(*), null::bigint, null::bigint FROM bi_dim_escola
UNION ALL SELECT 'dims', 'disciplina', count(*), null::bigint, null::bigint FROM bi_dim_disciplina
UNION ALL SELECT 'dims', 'jogo', count(*), null::bigint, null::bigint FROM bi_dim_jogo
UNION ALL SELECT 'dims', 'aluno', count(*), null::bigint, null::bigint FROM bi_dim_aluno
UNION ALL SELECT 'dims', 'data', count(*), null::bigint, null::bigint FROM bi_dim_data
ORDER BY 1,2;
