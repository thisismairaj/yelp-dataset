"""Yelp star-schema semantic model generator. Reuses the exact, debugged M-query and
TMDL shapes from the BRFSS dashboard (D:\\data-lab2\\power-bi\\generate_model.py) - same
Trial workspace, same host/warehouse, so no new manual Power BI sample step was needed
this time. The one genuinely new piece: `relationships.tmdl` - BRFSS's gold tables were
all pre-aggregated and self-contained, so that project never needed a join. This one
does, since it's a real fact/dim star schema.
"""
import uuid, os

HOST = "dbc-93916528-90f8.cloud.databricks.com"
HTTP_PATH = "/sql/1.0/warehouses/6cd9ffe6ba1a7c82"
BASE = os.path.dirname(os.path.abspath(__file__))
TABLES_DIR = os.path.join(BASE, "yelp_dashboard.SemanticModel", "definition", "tables")


def tag():
    return str(uuid.uuid4())


def m_block(steps, final_var):
    let_ind = "\t" * 3
    step_ind = "\t" * 4
    lines = [f"{let_ind}let"]
    for i, step in enumerate(steps):
        suffix = "," if i < len(steps) - 1 else ""
        lines.append(f"{step_ind}{step}{suffix}")
    lines.append(f"{let_ind}in")
    lines.append(f"{step_ind}{final_var}")
    return "\n".join(lines)


def m_source(schema, table, kind="Table"):
    steps = [
        f'Source = DatabricksMultiCloud.Catalogs("{HOST}", "{HTTP_PATH}", [Catalog=null, Database=null, QueryTags=null, EnableAutomaticProxyDiscovery=null, Implementation="2.0", Protocol=null])',
        'workspace_Database = Source{[Name="workspace",Kind="Database"]}[Data]',
        f'{schema}_Schema = workspace_Database{{[Name="{schema}",Kind="Schema"]}}[Data]',
        f'{table}_View = {schema}_Schema{{[Name="{table}",Kind="{kind}"]}}[Data]',
    ]
    return m_block(steps, f"{table}_View")


def col_block(name, dtype, is_numeric, summarize="sum", extra=""):
    fmt = "\n\t\tformatString: 0" if dtype == "int64" else ""
    ann = '\n\n\t\tannotation PBI_FormatHint = {"isGeneralNumber":true}' if dtype == "double" else ""
    return f'''	column {name}
		dataType: {dtype}{fmt}
		lineageTag: {tag()}
		summarizeBy: {summarize if is_numeric else "none"}
		sourceColumn: {name}
{extra}
		annotation SummarizationSetBy = Automatic{ann}
'''


def write_table(table_name, schema, columns, measures="", sort_by=None):
    """columns: list of (name, dtype, is_numeric). measures: pre-built measure block text."""
    sort_by = sort_by or {}
    body = f"table {table_name}\n\tlineageTag: {tag()}\n\n"
    for name, dtype, is_numeric in columns:
        extra = f"\t\tsortByColumn: {sort_by[name]}\n" if name in sort_by else ""
        body += col_block(name, dtype, is_numeric, extra=extra) + "\n"
    if measures:
        body += measures + "\n"
    body += (
        f"\tpartition {table_name} = m\n\t\tmode: import\n\t\tsource =\n"
        f"{m_source(schema, table_name)}\n\n"
        f"\tannotation PBI_ResultType = Table\n"
    )
    with open(os.path.join(TABLES_DIR, f"{table_name}.tmdl"), "w", encoding="utf-8") as fh:
        fh.write(body)


def measure(name, dax, fmt):
    return f"\tmeasure '{name}' = ```\n\t\t\t{dax}\n\t\t\t```\n\t\tformatString: {fmt}\n\t\tlineageTag: {tag()}\n"


# ---- fact_business ------------------------------------------------------------------
write_table("fact_business", "yelp_gold", [
    ("business_id", "string", False), ("name", "string", False), ("city", "string", False),
    ("state", "string", False), ("postal_code", "string", False),
    ("latitude", "double", True), ("longitude", "double", True),
    ("stars", "double", True), ("review_count", "int64", True), ("is_open", "int64", True),
], measures=(
    measure("Avg Business Rating", "AVERAGE(fact_business[stars])", "0.00") + "\n" +
    measure("Closure Rate %",
            "DIVIDE(CALCULATE(COUNTROWS(fact_business), fact_business[is_open] = 0), COUNTROWS(fact_business))",
            "0.0%") + "\n" +
    measure("Business Count", "COUNTROWS(fact_business)", "0")
))

# ---- dim_category + bridge -----------------------------------------------------------
write_table("dim_category", "yelp_gold", [
    ("category_id", "int64", True), ("category_name", "string", False),
])
write_table("bridge_business_category", "yelp_gold", [
    ("business_id", "string", False), ("category_id", "int64", True),
])

# ---- dim_attribute + bridge -----------------------------------------------------------
write_table("dim_attribute", "yelp_gold", [
    ("attribute_id", "int64", True), ("attribute_name", "string", False),
])
write_table("bridge_business_attribute", "yelp_gold", [
    ("business_id", "string", False), ("attribute_id", "int64", True), ("attribute_value", "string", False),
])

# ---- fact_review -----------------------------------------------------------------------
write_table("fact_review", "yelp_gold", [
    ("review_id", "string", False), ("business_id", "string", False), ("user_id", "string", False),
    ("stars", "double", True), ("useful", "int64", True), ("funny", "int64", True), ("cool", "int64", True),
    ("review_date", "dateTime", False),
], measures=(
    measure("Avg Review Rating", "AVERAGE(fact_review[stars])", "0.00") + "\n" +
    measure("Review Count", "COUNTROWS(fact_review)", "0")
))

# ---- fact_user -------------------------------------------------------------------------
write_table("fact_user", "yelp_gold", [
    ("user_id", "string", False), ("name", "string", False), ("review_count", "int64", True),
    ("elite_year_count", "int64", True), ("is_elite_ever", "boolean", False),
    ("friend_count", "int64", True), ("fans", "int64", True), ("average_stars", "double", True),
], measures=(
    measure("Avg User Review Count", "AVERAGE(fact_user[review_count])", "0.0") + "\n" +
    measure("User Count", "COUNTROWS(fact_user)", "0")
))

# ---- relationships.tmdl: the one genuinely new piece vs. the BRFSS dashboard ----------
relationships = [
    ("bridge_business_category", "business_id", "fact_business", "business_id"),
    ("bridge_business_category", "category_id", "dim_category", "category_id"),
    ("bridge_business_attribute", "business_id", "fact_business", "business_id"),
    ("bridge_business_attribute", "attribute_id", "dim_attribute", "attribute_id"),
    ("fact_review", "business_id", "fact_business", "business_id"),
    ("fact_review", "user_id", "fact_user", "user_id"),
]
rel_body = ""
for from_table, from_col, to_table, to_col in relationships:
    rel_body += (
        f"relationship {tag()}\n"
        f"\tfromColumn: {from_table}.{from_col}\n"
        f"\ttoColumn: {to_table}.{to_col}\n\n"
    )
with open(os.path.join(BASE, "yelp_dashboard.SemanticModel", "definition", "relationships.tmdl"), "w", encoding="utf-8") as f:
    f.write(rel_body)

# ---- model.tmdl ------------------------------------------------------------------------
all_tables = ["fact_business", "dim_category", "bridge_business_category",
              "dim_attribute", "bridge_business_attribute", "fact_review", "fact_user"]
order = "[" + ", ".join(f'"{t}"' for t in all_tables) + "]"
model = f'''model Model
	culture: en-US
	defaultPowerBIDataSourceVersion: powerBI_V3
	sourceQueryCulture: en-PK
	valueFilterBehavior: independent
	dataAccessOptions
		legacyRedirects
		returnErrorValuesAsNull

annotation __PBI_TimeIntelligenceEnabled = 1

annotation PBI_QueryOrder = {order}

annotation PBI_ProTooling = ["DevMode"]

''' + "".join(f"ref table {t}\n" for t in all_tables) + '''
ref cultureInfo en-US
'''
with open(os.path.join(BASE, "yelp_dashboard.SemanticModel", "definition", "model.tmdl"), "w", encoding="utf-8") as f:
    f.write(model)

print(f"Model generator done: {len(all_tables)} tables, {len(relationships)} relationships.")
