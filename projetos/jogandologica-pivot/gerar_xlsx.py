#!/usr/bin/env python3
"""Gera xlsx AGREGADO a partir dos CSVs anonimizados em /root/dados-jogandologica.
Saida: /root/dados-jogandologica/jogandologica-pivot.xlsx
Nunca inclui nome de aluno, escola, turma, titulo nem id real — so aluno_ref.
Abas: sessoes, jogos, agregado, analise (esta ultima com formulas Excel reais:
SUMIFS, COUNTIFS, AVERAGEIFS, INDEX/MATCH, LARGE e percentual de acerto).
Sem XLOOKUP (compatibilidade). Openpyxl nao cria Tabela Dinamica nativa."""
import csv, os, sys
DAT = os.environ.get("DAT", "/root/dados-jogandologica")
try:
    from openpyxl import Workbook
    from openpyxl.styles import Font, PatternFill
    from openpyxl.utils import get_column_letter
except ImportError:
    sys.exit("openpyxl ausente: pip install openpyxl")

def load(name):
    p = os.path.join(DAT, name)
    if not os.path.exists(p):
        return [], []
    with open(p, newline="", encoding="utf-8") as f:
        r = csv.reader(f)
        rows = list(r)
    return (rows[0] if rows else []), rows[1:]

wb = Workbook()
hdr_font = Font(bold=True, color="FFFFFF")
hdr_fill = PatternFill("solid", fgColor="305496")

def add_sheet(ws, headers, body):
    ws.append(headers)
    for row in body:
        out = []
        for v in row:
            if v in ("", None):
                out.append(v)
                continue
            try:
                out.append(int(v))
            except ValueError:
                try:
                    out.append(float(v))
                except ValueError:
                    out.append(v)
        ws.append(out)
    for c in ws[1]:
        c.font = hdr_font
        c.fill = hdr_fill
    for i, h in enumerate(headers, 1):
        ws.column_dimensions[ws.cell(row=1, column=i).column_letter].width = max(12, len(h) + 2)

ws1 = wb.active
ws1.title = "sessoes"
h, b = load("sessoes_anon.csv")
add_sheet(ws1, h, b)

ws2 = wb.create_sheet("jogos")
h, b = load("jogos_anon.csv")
add_sheet(ws2, h, b)

ws3 = wb.create_sheet("agregado")
h, b = load("agregado_aluno_jogo.csv")
add_sheet(ws3, h, b)

# --- aba "analise": KPIs + ranking + ficha de jogo, tudo por FORMULA ---
ws4 = wb.create_sheet("analise")
ws4["A1"] = "KPIs globais"
ws4["A1"].font = hdr_font
ws4["A1"].fill = hdr_fill

kpis = [
    ("Total de sessoes",     '=IFERROR(COUNTA(sessoes!A:A)-1,0)'),
    ("Pontuacao total",      '=IFERROR(SUM(sessoes!D:D),0)'),
    ("Acertos totais",       '=IFERROR(SUM(sessoes!E:E),0)'),
    ("Erros totais",         '=IFERROR(SUM(sessoes!F:F),0)'),
    ("Percentual acerto",    '=IFERROR(IF((B4+B5)=0,0,B4/(B4+B5)),0)'),
    ("Tempo medio concluido",'=IFERROR(AVERAGEIFS(sessoes!H:H,sessoes!H:H,"conclu*"),0)'),
    ("Sessoes em andamento", '=IFERROR(COUNTIFS(sessoes!H:H,"em_andamento"),0)'),
    ("Sessoes concluidas",   '=IFERROR(COUNTIFS(sessoes!H:H,"conclu*"),0)'),
]
for i, (lbl, fx) in enumerate(kpis, start=2):
    ws4.cell(row=i, column=1, value=lbl)
    ws4.cell(row=i, column=2, value=fx)
ws4["B6"].number_format = "0.00%"
ws4["B7"].number_format = "0.00"

# cabecalho do ranking
rank_hdr = ["pos","pontos_total","jogo_id","tipo","nivel","sessoes","acertos","erros","pct_acerto"]
rank_col = 4
ws4.cell(row=rank_col-1, column=1, value="Ranking top 10 jogos por pontuacao")
ws4.cell(row=rank_col-1, column=1).font = hdr_font
ws4.cell(row=rank_col-1, column=1).fill = hdr_fill
for j, name in enumerate(rank_hdr, start=1):
    c = ws4.cell(row=rank_col, column=j, value=name)
    c.font = hdr_font
    c.fill = hdr_fill

TOP = 10
for k in range(TOP):
    r = rank_col + 1 + k
    ws4.cell(row=r, column=1, value=k + 1)
    ws4.cell(row=r, column=2, value='=IFERROR(LARGE(agregado!F:F,A%d),0)' % r)
    ws4.cell(row=r, column=3, value='=IFERROR(INDEX(agregado!B:B,MATCH(B%d,agregado!F:F,0)),"")' % r)
    ws4.cell(row=r, column=4, value='=IFERROR(INDEX(jogos!B:B,MATCH(C%d,jogos!A:A,0)),"")' % r)
    ws4.cell(row=r, column=5, value='=IFERROR(INDEX(jogos!C:C,MATCH(C%d,jogos!A:A,0)),"")' % r)
    ws4.cell(row=r, column=6, value='=IFERROR(SUMIFS(agregado!C:C,agregado!B:B,C%d),0)' % r)
    ws4.cell(row=r, column=7, value='=IFERROR(SUMIFS(agregado!D:D,agregado!B:B,C%d),0)' % r)
    ws4.cell(row=r, column=8, value='=IFERROR(SUMIFS(agregado!E:E,agregado!B:B,C%d),0)' % r)
    ws4.cell(row=r, column=9, value='=IFERROR(IF((G%d+H%d)=0,0,G%d/(G%d+H%d)),0)' % (r, r, r, r, r))
    ws4.cell(row=r, column=9).number_format = "0.00%"

# ficha de um jogo-alvo por INDEX/MATCH
base = rank_col + 1 + TOP + 2
ws4.cell(row=base-1, column=1, value="Ficha do jogo-alvo (INDEX/MATCH)").font = hdr_font
ws4.cell(row=base-1, column=1).fill = hdr_fill
ws4.cell(row=base,    column=1, value="jogo_alvo_id")
ws4.cell(row=base,    column=2, value='=IFERROR(INDEX(jogos!A:A,2),"")')
ws4.cell(row=base+1,  column=1, value="tipo")
ws4.cell(row=base+1,  column=2, value='=IFERROR(INDEX(jogos!B:B,MATCH(B%d,jogos!A:A,0)),"")' % base)
ws4.cell(row=base+2,  column=1, value="nivel")
ws4.cell(row=base+2,  column=2, value='=IFERROR(INDEX(jogos!C:C,MATCH(B%d,jogos!A:A,0)),"")' % base)
ws4.cell(row=base+3,  column=1, value="sessoes")
ws4.cell(row=base+3,  column=2, value='=IFERROR(COUNTIFS(sessoes!B:B,B%d),0)' % base)
ws4.cell(row=base+4,  column=1, value="pontuacao")
ws4.cell(row=base+4,  column=2, value='=IFERROR(SUMIFS(sessoes!D:D,sessoes!B:B,B%d),0)' % base)
ws4.cell(row=base+5,  column=1, value="pct_acerto")
ws4.cell(row=base+5,  column=2,
    value='=IFERROR(IF((SUMIFS(sessoes!E:E,sessoes!B:B,B%d)+SUMIFS(sessoes!F:F,sessoes!B:B,B%d))=0,0,'
          'SUMIFS(sessoes!E:E,sessoes!B:B,B%d)/(SUMIFS(sessoes!E:E,sessoes!B:B,B%d)+SUMIFS(sessoes!F:F,sessoes!B:B,B%d))),0)'
          % (base, base, base, base, base))
ws4.cell(row=base+5,  column=2).number_format = "0.00%"
ws4.cell(row=base+6,  column=1, value="sessoes_via_agregado")
ws4.cell(row=base+6,  column=2, value='=IFERROR(INDEX(agregado!C:C,MATCH(B%d,agregado!B:B,0)),0)' % base)

for i, w in enumerate([24, 18, 40, 14, 12, 12, 12, 12, 12], start=1):
    ws4.column_dimensions[get_column_letter(i)].width = w

out = os.path.join(DAT, "jogandologica-pivot.xlsx")
wb.save(out)
os.chmod(out, 0o600)
print(f"[OK] {out} ({os.path.getsize(out)} bytes) abas={wb.sheetnames}")
