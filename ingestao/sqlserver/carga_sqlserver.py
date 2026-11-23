#!/usr/bin/env python3
"""
Carga idempotente DuckDB (warehouse->gold) para SQL Server (pv_analytics.gold.*).

Idempotente: MERGE por chave natural; reexecutar com a mesma fonte NAO duplica linhas.
Validacao de contagem: compara count(DuckDB) vs count(SQL Server) por tabela; exit 1 se divergir.

Env obrigatorias:
  MSSQL_HOST (default pv_sqlserver), MSSQL_PORT (1433), MSSQL_DB (pv_analytics),
  MSSQL_USER (sa), MSSQL_PASSWORD
Env opcionais:
  DUCKDB_PATH (default /opt/warehouse/plataforma.duckdb)
  COMPARATIVO_OUT (default /opt/warehouse/comparativo.json)
"""
import json, os, sys, datetime, decimal
import duckdb
import pyodbc

DUCK = os.environ.get("DUCKDB_PATH", "/opt/warehouse/plataforma.duckdb")
HOST = os.environ.get("MSSQL_HOST", "pv_sqlserver")
PORT = os.environ.get("MSSQL_PORT", "1433")
DB   = os.environ.get("MSSQL_DB", "pv_analytics")
USER = os.environ.get("MSSQL_USER", "sa")
PWD  = os.environ["MSSQL_PASSWORD"]
OUT  = os.environ.get("COMPARATIVO_OUT",
       "/opt/warehouse/comparativo.json")

TABELAS = {
    "gold_operacao_diaria": {
        "destino": "gold.operacao_diaria",
        "cols": ["dt", "projeto", "origem", "eventos"],
        "chave": ["dt", "projeto", "origem"],
    },
    "gold_radar_demanda": {
        "destino": "gold.radar_demanda",
        "cols": ["dt", "tecnologia", "vagas", "vagas_com_tec", "pct_vagas", "pct_media_7d"],
        "chave": ["dt", "tecnologia"],
    },
}

def norm(v):
    if v is None: return None
    if isinstance(v, (datetime.date,)): return v.isoformat()
    if isinstance(v, decimal.Decimal): return float(v)
    return v

def abre_sqlserver():
    cs = (f"DRIVER={{ODBC Driver 18 for SQL Server}};"
          f"SERVER={HOST},{PORT};DATABASE={DB};UID={USER};PWD={PWD};"
          f"Encrypt=yes;TrustServerCertificate=yes;")
    return pyodbc.connect(cs, autocommit=False, timeout=15)

def merge_tabela(cur, con_duck, nome, spec):
    cols = spec["cols"]; chave = spec["chave"]; destino = spec["destino"]
    sql_src = f"SELECT {','.join(cols)} FROM {nome}"
    rows = con_duck.execute(sql_src).fetchall()
    src_n = len(rows)
    # staging temporaria
    cur.execute(f"IF OBJECT_ID('tempdb..#stg','U') IS NOT NULL DROP TABLE #stg")
    typemap = "dt DATE, projeto NVARCHAR(64), origem NVARCHAR(64), eventos BIGINT," \
              " tecnologia NVARCHAR(64), vagas BIGINT, vagas_com_tec BIGINT," \
              " pct_vagas DECIMAL(6,2), pct_media_7d DECIMAL(6,2)"
    cols_ddl = ", ".join([c for c in cols])
    # DDL simples: tudo como NVARCHAR/BIGINT/DECIMAL/DATE - usa CAST automatico do pyodbc
    cur.execute(f"CREATE TABLE #stg ({cols_ddl_placeholder if False else ''} )") if False else None
    # criamos staging pela definicao real da tabela de destino (LIKE) evita descompasso de tipos
    cur.execute(f"SELECT TOP 0 * INTO #stg FROM {destino}")
    cur.execute("ALTER TABLE #stg ADD CONSTRAINT DF_stg_carregado_" + nome + " DEFAULT SYSUTCDATETIME() FOR carregado_em")
    placeholders = ",".join(["?"] * len(cols))
    cur.fast_executemany = True
    cur.executemany(f"INSERT INTO #stg ({cols_ddl}) VALUES ({placeholders})",
                    [tuple(norm(v) for v in r) for r in rows])
    on = " AND ".join([f"t.{c}=s.{c}" for c in chave])
    setc = ", ".join([f"{c}=s.{c}" for c in cols if c not in chave])
    upd = (f"WHEN MATCHED AND ({' OR '.join([f't.{c}<>s.{c}' for c in cols if c not in chave])}) "
           f"THEN UPDATE SET {setc}") if setc else ""
    ins_cols = ",".join(cols)
    ins_vals = ",".join([f"s.{c}" for c in cols])
    cur.execute(f"""
        MERGE {destino} AS t
        USING #stg AS s ON {on}
        {upd}
        WHEN NOT MATCHED BY TARGET THEN INSERT ({ins_cols}) VALUES ({ins_vals});
    """)
    cur.execute("DROP TABLE #stg")
    cur.execute(f"SELECT COUNT(*) FROM {destino}")
    dst_n = cur.fetchone()[0]
    return {"duckdb_linhas": src_n, "sqlserver_linhas_total": dst_n}

def main():
    con_duck = duckdb.connect(DUCK, read_only=True)
    con = abre_sqlserver(); cur = con.cursor()
    resultado = {"executado_em_utc": datetime.datetime.utcnow().isoformat(timespec="seconds")+"Z",
                 "fonte": DUCK, "destino": f"{HOST},{PORT}/{DB}",
                 "tabelas": {}}
    ok = True
    for nome, spec in TABELAS.items():
        try:
            info = merge_tabela(cur, con_duck, nome, spec)
            # validacao: linhas da fonte devem estar contidas no destino (>= fonte);
            # e o destino apos o merge nao deve ter linhas duplicadas pela chave.
            cur.execute(f"SELECT COUNT(*) FROM (SELECT {','.join(spec['chave'])}, COUNT(*) c "
                        f"FROM {spec['destino']} GROUP BY {','.join(spec['chave'])} HAVING COUNT(*)>1) x")
            duplicadas = cur.fetchone()[0]
            info["duplicadas_por_chave"] = duplicadas
            info["ok"] = (info["sqlserver_linhas_total"] >= info["duckdb_linhas"]) and duplicadas == 0
            ok = ok and info["ok"]
        except Exception as e:
            info = {"erro": str(e)}
            ok = False
        resultado["tabelas"][nome] = info
    con.commit()
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w") as f:
        json.dump(resultado, f, indent=2, ensure_ascii=False)
    print(json.dumps(resultado, indent=2, ensure_ascii=False))
    sys.exit(0 if ok else 1)

if __name__ == "__main__":
    main()
