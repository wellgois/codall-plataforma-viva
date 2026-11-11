let
    Fonte = Csv.Document(Web.Contents("https://codall.site/plataforma/gold/gold_operacao_diaria.csv"), [Delimiter=",", Encoding=65001, QuoteStyle=QuoteStyle.Csv]),
    Cabecalho = Table.PromoteHeaders(Fonte, [PromoteAllScalars=true]),
    Tipos = Table.TransformColumnTypes(Cabecalho, {{"dt", type date}, {"projeto", type text}, {"origem", type text}, {"eventos", Int64.Type}}, "en-US")
in
    Tipos
