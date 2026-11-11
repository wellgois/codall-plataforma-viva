# 0004 - Radar publico e curriculo verificavel com privacidade por construcao

Data: 2026-11-11. Status: aceita.

## Contexto
A vitrine precisa mostrar dado real de mercado e um curriculo com prova, sem expor pessoas, empresas ou lacunas do autor.

## Decisao
- O radar publica so agregados da camada gold (percentual por tecnologia, tendencia, senioridade, volume), nunca titulo, empresa, link ou hash de vaga.
- K-anonimato: grupo com menos de 5 vagas e suprimido (tecnologia) ou agrupado em "outras" (senioridade).
- "Cole sua vaga" roda inteiro no navegador (nenhum envio ao servidor) e compara a vaga com o mercado; nao ha comparacao com as habilidades do autor, entao nenhuma lacuna e exposta.
- O curriculo lista habilidade -> prova (codigo, teste, numero ao vivo); nada sem link.
- `auditoria_privacidade.py` roda no CI e antes de cada publicacao na VPS e bloqueia: e-mail, telefone, CPF, valor em reais, "salario", link de vaga, token longo, IP, e qualquer campo fora da lista no radar.json.

## Consequencias
- Publicacao automatica diaria as 05:40, so se a auditoria passar.
- Amostra pequena e sinalizada na propria pagina.
- A lista de campos permitidos e fixa: acrescentar um campo exige alterar o auditor e esta decisao.

## Evidencia
Teste positivo: paginas e radar.json passam. Teste negativo: e-mail, valor, link de vaga e campos extras sao reprovados (codigo de saida 1).
