let
    Fonte = Csv.Document(Web.Contents("https://codall.site/plataforma/gold/gold_radar_demanda.csv"), [Delimiter=",", Encoding=65001, QuoteStyle=QuoteStyle.Csv]),
    Cabecalho = Table.PromoteHeaders(Fonte, [PromoteAllScalars=true]),
    Tipos = Table.TransformColumnTypes(Cabecalho, {{"dt", type date}, {"tecnologia", type text}, {"vagas", Int64.Type}, {"vagas_com_tec", Int64.Type}, {"pct_vagas", type number}, {"pct_media_7d", type number}}, "en-US")
in
    Tipos
