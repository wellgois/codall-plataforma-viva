let
    Fonte = Csv.Document(Web.Contents("https://codall.site/plataforma/gold/gold_operacao_diaria.csv"), [Delimiter=",", Encoding=65001, QuoteStyle=QuoteStyle.Csv]),
    Cabecalho = Table.PromoteHeaders(Fonte, [PromoteAllScalars=true]),
    Tipos = Table.TransformColumnTypes(Cabecalho, {{"dt", type date}, {"projeto", type text}, {"origem", type text}, {"eventos", Int64.Type}}, "en-US"),
    // Coluna de auditoria: precisa de tipo explicito, senao o Lakehouse descarta a coluna
    Auditoria = Table.AddColumn(Tipos, "carga_em", each DateTime.LocalNow(), type datetime)
in
    Auditoria
