// Conjunto fixo de tarefas de regressao do Codall. Cada tarefa pede uma funcao Python
// (so biblioteca padrao) e um teste oculto confere a resposta. Sem rede, sem segredos.
const T = (id, nome, assunto, prompt, teste) => ({ id, nome, assunto, prompt, teste });

module.exports = [
  T('t01', 'Limpeza de linhas CSV', 'pandas/limpeza',
    'Funcao limpar(linhas): recebe lista de strings (linhas de CSV "id,nome"), remove linhas vazias ou so com espacos, remove duplicatas exatas mantendo a primeira ocorrencia e a ordem, e devolve a lista.',
    `from sol import limpar
assert limpar(["1,a","","1,a","2,b","  ","2,b","3,c"])==["1,a","2,b","3,c"]
assert limpar([])==[]
print("ok")`),
  T('t02', 'Upsert idempotente', 'ETL',
    'Funcao carregar(conn, linhas): conn e sqlite3.Connection; cria (se nao existir) a tabela pedidos(id INTEGER PRIMARY KEY, valor REAL) e faz upsert das tuplas (id, valor) de linhas, de modo que rodar duas vezes nao duplica e um id repetido atualiza o valor.',
    `import sqlite3
from sol import carregar
c=sqlite3.connect(":memory:")
carregar(c,[(1,10.0),(2,20.0)]); carregar(c,[(1,10.0),(2,20.0)]); carregar(c,[(2,99.0)])
assert c.execute("select count(*) from pedidos").fetchone()[0]==2
assert c.execute("select valor from pedidos where id=2").fetchone()[0]==99.0
print("ok")`),
  T('t03', 'Metricas para dado desbalanceado', 'ML/avaliacao',
    'Funcao metricas(y_true, y_pred): listas de 0/1; devolve dicionario com chaves accuracy, precision, recall, f1 (float). Se o denominador for zero, o valor e 0.0.',
    `from sol import metricas
m=metricas([0]*95+[1]*5,[0]*100)
assert abs(m["accuracy"]-0.95)<1e-9 and m["recall"]==0.0 and m["precision"]==0.0 and m["f1"]==0.0
m=metricas([1,1,0,0],[1,0,1,0])
assert abs(m["precision"]-0.5)<1e-9 and abs(m["recall"]-0.5)<1e-9 and abs(m["f1"]-0.5)<1e-9
print("ok")`),
  T('t04', 'Deteccao de vazamento treino/teste', 'ML/leakage',
    'Funcao tem_vazamento(treino, teste): listas de ids de linhas; devolve True se algum id aparece nas duas listas, senao False.',
    `from sol import tem_vazamento
assert tem_vazamento([1,2,3],[3,4]) is True
assert tem_vazamento([1,2],[3,4]) is False
assert tem_vazamento([],[1]) is False
print("ok")`),
  T('t05', 'Busca por similaridade', 'RAG',
    'Funcao melhor_doc(consulta, docs): docs e lista de strings; use similaridade de cosseno entre vetores de contagem de palavras (minusculas, separadas por espaco) e devolva o indice do documento mais parecido (em empate, o menor indice).',
    `from sol import melhor_doc
docs=["python pandas dados","nginx servidor proxy","airflow dag tarefa agenda"]
assert melhor_doc("servidor nginx",docs)==1
assert melhor_doc("dag airflow",docs)==2
assert melhor_doc("pandas",docs)==0
print("ok")`),
  T('t06', 'Contrato de dados', 'qualidade',
    'Funcao violacoes(registros): registros e lista de dicts com id, valor, status. Regras: id inteiro e unico, valor numero >= 0, status em {"novo","pago","cancelado"}. Devolve a lista com o indice (posicao na lista) de cada registro que viola ao menos uma regra, em ordem crescente; para id repetido, so o segundo registro em diante viola.',
    `from sol import violacoes
r=[{"id":1,"valor":10,"status":"novo"},{"id":1,"valor":5,"status":"pago"},{"id":2,"valor":-1,"status":"pago"},{"id":3,"valor":4,"status":"x"},{"id":"4","valor":1,"status":"novo"},{"id":5,"valor":0,"status":"cancelado"}]
assert violacoes(r)==[1,2,3,4]
print("ok")`),
  T('t07', 'Estrutura de DAG por AST', 'orquestracao',
    'Funcao contar_dependencias(codigo): recebe codigo Python como string e devolve quantas vezes aparece o operador >> (ast.RShift), usando o modulo ast. Nao execute o codigo.',
    `from sol import contar_dependencias
assert contar_dependencias("a >> b >> c\\nx = 1")==2
assert contar_dependencias("x = 8 >> 1")==1
assert contar_dependencias("print(1)")==0
print("ok")`),
  T('t08', 'Diagnostico por log', 'producao',
    'Funcao inicio_saturacao(linhas): linhas de log como "HH:MM pool_available=N latencia=Xms"; devolve o horario (string HH:MM) da primeira linha com pool_available=0, ou None se nao houver.',
    `from sol import inicio_saturacao
l=["09:00 pool_available=5 latencia=10ms","10:00 pool_available=0 latencia=900ms","11:00 pool_available=0 latencia=2000ms"]
assert inicio_saturacao(l)=="10:00"
assert inicio_saturacao(l[:1]) is None
print("ok")`),
  T('t09', 'Mascara de dados pessoais', 'governanca/LGPD',
    'Funcao mascarar_cpf(texto): substitui todo CPF no formato 000.000.000-00 por ***.***.***-NN, onde NN sao os dois ultimos digitos originais. O resto do texto fica igual.',
    `from sol import mascarar_cpf
assert mascarar_cpf("CPF 123.456.789-09 ok")=="CPF ***.***.***-09 ok"
assert mascarar_cpf("a 111.222.333-44 e 555.666.777-88")=="a ***.***.***-44 e ***.***.***-88"
assert mascarar_cpf("sem cpf 12345")=="sem cpf 12345"
print("ok")`),
  T('t10', 'Heranca de add_header no nginx', 'infra',
    'Funcao cabecalhos(server_headers, location_headers): ambos sao dicts de cabecalhos definidos com add_header no nivel server e no nivel location. Pela regra do nginx, se a location define qualquer add_header, ela substitui todos os do server (nao ha heranca); senao herda os do server. Devolve o dict efetivo da location.',
    `from sol import cabecalhos
s={"X-Frame-Options":"DENY"}
assert cabecalhos(s,{"Cache-Control":"no-store"})=={"Cache-Control":"no-store"}
assert cabecalhos(s,{})==s
assert cabecalhos({},{"A":"1"})=={"A":"1"}
print("ok")`),
];
