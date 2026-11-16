CREATE OR REPLACE VIEW bi_fato_atividade AS
SELECT 'sessao'::text AS tipo_atividade, s.id::text AS atividade_id,
       s.aluno_id::text AS aluno_sk, s.jogo_id AS jogo_sk, NULL::text AS disciplina,
       to_char(coalesce(s.iniciado_em,s.finalizado_em),'YYYYMMDD')::int AS data_sk,
       s.pontuacao AS pontos, s.acertos, s.erros,
       (COALESCE(s.acertos,0)+COALESCE(s.erros,0)) AS tentativas,
       s.tempo_gasto_segundos AS segundos, s.status
FROM jogos_educativos_sessoes s
UNION ALL
SELECT 'dever', d.id::text, COALESCE(NULLIF(d.aluno_id::text,''), 'n:'||substr(md5(d.aluno_nome),1,12)), NULL, COALESCE(d.disciplina,'(n/d)'),
       to_char(coalesce(d.iniciado_em,d.created_at),'YYYYMMDD')::int,
       COALESCE(d.pontos,d.pontos_jogo,0)::int, d.acertos, d.erros,
       (COALESCE(d.acertos,0)+COALESCE(d.erros,0)), d.tempo_gasto_secs, d.status
FROM dever_missoes d
UNION ALL
SELECT 'logika', l.id::text, 'eq:'||substr(md5(l.equipe_nome),1,12), NULL, '(n/d)',
       to_char(coalesce(l.lancada_em,l.created_at),'YYYYMMDD')::int,
       COALESCE(l.pontos,0), l.acertos,
       GREATEST(COALESCE(l.total,0)-COALESCE(l.acertos,0),0),
       COALESCE(l.total,0), l.tempo, l.status
FROM logika_missoes l
UNION ALL
SELECT 'trabalho', t.id::text, t.aluno_id::text, NULL, '(n/d)',
       to_char(coalesce(t.data_entrega,t.created_at),'YYYYMMDD')::int,
       COALESCE(t.pontos_jogo,0), NULL::int, NULL::int, NULL::int, NULL::int, t.status
FROM trabalhos_entregas t;
