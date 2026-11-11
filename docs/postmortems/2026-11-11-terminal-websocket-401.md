# Postmortem: terminal do Codall recusava conexao (WebSocket 401)

Data: 11/11/2026. Severidade: media (sem perda de dados). Duracao: cerca de 15 min de diagnostico.
Formato sem culpados.

## Resumo
Depois de uma sessao de seguranca e de um restart do Codall, o terminal web ficou em
"reconectando" mesmo com login valido. O restante do site funcionava.

## Linha do tempo (horario de Brasilia)
- 05:26 login refeito; paginas HTTP normais; WebSocket `/ws/terminal` falha no handshake.
- 05:32 logs do processo sem erro de WebSocket: o Node estava de pe.
- 05:36 handshake direto na porta 3000 devolve 401 (Node saudavel); nginx tem os cabecalhos de upgrade corretos.
- 05:38 `NODE_ENV=production` e `USE_HTTPS=true` confirmam cookie de sessao `secure`.
- 05:39 correcao aplicada; terminal conecta.

## Causa raiz
O cookie de sessao e `secure`. O codigo do terminal chama o middleware de sessao direto na
requisicao de upgrade, sem o contexto HTTPS do Express. O middleware entao descarta a sessao e o
terminal responde 401.

## O que funcionou
Isolar camada por camada (navegador, nginx, Node) com um teste de handshake de uma linha.

## O que deu errado
Dois comandos de diagnostico falharam por aspas curvas inseridas pelo terminal web. Passamos a
publicar scripts no repositorio e executa-los por nome.

## Acoes
- Marcar a requisicao de upgrade como vinda do proxy TLS (feito, com backup do arquivo).
- Script versionado: `infra/ops/corrige-ws-terminal.sh`.
- Pendente: teste automatizado de handshake autenticado no smoke do Codall.
