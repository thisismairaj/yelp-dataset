"""Yelp dashboard report generator. Same proven visual JSON shapes as the BRFSS
dashboard (D:\\data-lab2\\power-bi\\generate_report.py) - cardVisual, lineChart,
clusteredColumnChart, textbox, the objects.title fix, the Measure-vs-Aggregation field
shape. No new visual types needed this time.
"""
import json, os, shutil, uuid

BASE = os.path.dirname(os.path.abspath(__file__))
PAGE_DIR = os.path.join(BASE, "yelp_dashboard.Report", "definition", "pages", "088fe004e3007d66e09d")
VIS_DIR = os.path.join(PAGE_DIR, "visuals")

SCHEMA = "https://developer.microsoft.com/json-schemas/fabric/item/report/definition/visualContainer/2.12.0/schema.json"


def gid():
    return uuid.uuid4().hex[:20]


def col_ref(table, col):
    return {"Column": {"Expression": {"SourceRef": {"Entity": table}}, "Property": col}}


def agg(table, col, func=0):
    return {"Aggregation": {"Expression": col_ref(table, col), "Function": func}}


def measure_ref(table, measure):
    return {"Measure": {"Expression": {"SourceRef": {"Entity": table}}, "Property": measure}}


def projection(field, query_ref, native_ref):
    return {"field": field, "queryRef": query_ref, "nativeQueryRef": native_ref}


def measure_projection(table, measure):
    return projection(measure_ref(table, measure), f"{table}.{measure}", measure)


def category_projection(table, col):
    return projection(col_ref(table, col), f"{table}.{col}", col)


def sort_desc_by_measure(table, measure):
    return {"sort": [{"field": measure_ref(table, measure), "direction": "Descending"}], "isDefaultSort": True}


def esc_dax_string(s):
    return s.replace("'", "''")


def set_title(visual_body, text):
    visual_body.setdefault("objects", {})["title"] = [{
        "properties": {"text": {"expr": {"Literal": {"Value": f"'{esc_dax_string(text)}'"}}}}
    }]
    return visual_body


def visual_json(name, x, y, w, h, z, tab_order, visual_body, filters=None):
    body = {"$schema": SCHEMA, "name": name,
            "position": {"x": x, "y": y, "z": z, "height": h, "width": w, "tabOrder": tab_order},
            "visual": visual_body}
    if filters:
        body["filterConfig"] = {"filters": filters}
    return body


def write_visual(container_id, body):
    d = os.path.join(VIS_DIR, container_id)
    os.makedirs(d, exist_ok=True)
    with open(os.path.join(d, "visual.json"), "w", encoding="utf-8") as f:
        json.dump(body, f, indent=2)


if os.path.isdir(VIS_DIR):
    shutil.rmtree(VIS_DIR)
os.makedirs(VIS_DIR, exist_ok=True)

visuals = []

# 1. Title
title_id = gid()
title_body = {"visualType": "textbox", "objects": {"general": [{"properties": {"paragraphs": [{
    "textRuns": [{"value": "Yelp Open Dataset — Business, Review & User Analytics (star schema)",
                  "textStyle": {"fontWeight": "bold", "fontSize": "20px"}}]}]}}]}}
visuals.append((title_id, visual_json(title_id, 20, 8, 1880, 40, 0, 0, title_body)))

# 2-6. KPI cards
card_specs = [
    ("Avg Business Rating", "fact_business", "Avg Business Rating"),
    ("Business Count", "fact_business", "Business Count"),
    ("Closure Rate %", "fact_business", "Closure Rate %"),
    ("Avg Review Rating", "fact_review", "Avg Review Rating"),
    ("Review Count", "fact_review", "Review Count"),
]
for (title, table, meas), cx in zip(card_specs, [20, 400, 780, 1160, 1540]):
    cid = gid()
    body = {"visualType": "cardVisual",
            "query": {"queryState": {"Data": {"projections": [measure_projection(table, meas)]}}},
            "drillFilterOtherVisuals": True}
    set_title(body, title)
    filters = [{"name": gid(), "field": measure_ref(table, meas), "type": "Advanced"}]
    visuals.append((cid, visual_json(cid, cx, 60, 360, 130, 1, len(visuals), body, filters)))

# 7. Avg stars by category (x=20, y=210, 600x350)
cat_id = gid()
cat_body = {"visualType": "clusteredColumnChart", "query": {"queryState": {
    "Category": {"projections": [category_projection("dim_category", "category_name")]},
    "Y": {"projections": [measure_projection("fact_business", "Avg Business Rating")]},
}, "sortDefinition": sort_desc_by_measure("fact_business", "Avg Business Rating")},
    "drillFilterOtherVisuals": True}
set_title(cat_body, "Avg rating by category")
visuals.append((cat_id, visual_json(cat_id, 20, 210, 600, 350, 1, len(visuals), cat_body)))

# 8. Closure rate by category (x=640, y=210, 600x350)
clo_id = gid()
clo_body = {"visualType": "clusteredColumnChart", "query": {"queryState": {
    "Category": {"projections": [category_projection("dim_category", "category_name")]},
    "Y": {"projections": [measure_projection("fact_business", "Closure Rate %")]},
}, "sortDefinition": sort_desc_by_measure("fact_business", "Closure Rate %")},
    "drillFilterOtherVisuals": True}
set_title(clo_body, "Closure rate by category")
visuals.append((clo_id, visual_json(clo_id, 640, 210, 600, 350, 1, len(visuals), clo_body)))

# 9. Avg review rating trend by date (x=1260, y=210, 640x350)
trend_id = gid()
trend_body = {"visualType": "lineChart", "query": {"queryState": {
    "Category": {"projections": [category_projection("fact_review", "review_date")]},
    "Y": {"projections": [measure_projection("fact_review", "Avg Review Rating")]},
}}, "drillFilterOtherVisuals": True}
set_title(trend_body, "Avg review rating over time")
visuals.append((trend_id, visual_json(trend_id, 1260, 210, 640, 350, 1, len(visuals), trend_body)))

# 10. Avg stars by attribute value (x=20, y=580, 600x320) - filtered to OutdoorSeating
attr_id = gid()
attr_body = {"visualType": "clusteredColumnChart", "query": {"queryState": {
    "Category": {"projections": [category_projection("bridge_business_attribute", "attribute_value")]},
    "Y": {"projections": [measure_projection("fact_business", "Avg Business Rating")]},
}}, "drillFilterOtherVisuals": True}
set_title(attr_body, "Avg rating by attribute value (use the slicer to pick an attribute)")
visuals.append((attr_id, visual_json(attr_id, 20, 580, 600, 320, 1, len(visuals), attr_body)))

# 11. Attribute name slicer (x=640, y=580, 600x100) - so the chart above is usable
attr_slicer_id = gid()
attr_slicer_body = {"visualType": "slicer", "query": {"queryState": {
    "Values": {"projections": [category_projection("dim_attribute", "attribute_name")]},
}}, "objects": {"general": [{"properties": {}}]}}
set_title(attr_slicer_body, "Attribute")
visuals.append((attr_slicer_id, visual_json(attr_slicer_id, 640, 580, 600, 100, 1, len(visuals), attr_slicer_body)))

# 12. Elite vs non-elite avg review count (x=640, y=700, 600x200)
elite_id = gid()
elite_body = {"visualType": "clusteredColumnChart", "query": {"queryState": {
    "Category": {"projections": [category_projection("fact_user", "is_elite_ever")]},
    "Y": {"projections": [measure_projection("fact_user", "Avg User Review Count")]},
}}, "drillFilterOtherVisuals": True}
set_title(elite_body, "Avg reviews written: elite vs non-elite users")
visuals.append((elite_id, visual_json(elite_id, 640, 700, 600, 200, 1, len(visuals), elite_body)))

# 13. Caveat textbox (x=1260, y=580, 640x320)
caveat_id = gid()
caveat_body = {"visualType": "textbox", "objects": {"general": [{"properties": {"paragraphs": [{
    "textRuns": [{"value": (
        "Star schema: fact_business, fact_review, fact_user + dim_category/dim_attribute "
        "via bridge tables (many-to-many). Avg Business Rating and Avg Review Rating are "
        "genuine averages (AVERAGE, not a sum-of-ratio) since stars is already a per-row "
        "value, unlike BRFSS's weighted prevalence which needed DIVIDE(SUM,SUM). "
        "fact_tip and fact_checkin are built in the warehouse but not yet in this model."
    ), "textStyle": {"fontSize": "10px"}}]}]}}]}}
visuals.append((caveat_id, visual_json(caveat_id, 1260, 580, 640, 320, 0, len(visuals), caveat_body)))

for vid, body in visuals:
    write_visual(vid, body)

print(f"Report generator done: {len(visuals)} visuals.")
