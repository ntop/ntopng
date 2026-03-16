# Report Dashboard — Developer Guide

## Overview

The Report page (`/lua/pro/report.lua`) is a Vue SPA that displays historical flow
analysis widgets. It is built on two independent JSON-driven systems that work
together:

| System | Config location | Purpose |
|---|---|---|
| **Template system** | `scripts/templates/report/*.json` | Defines which components appear on the dashboard and in which layout |
| **Widget catalog** | `scripts/templates/widgets.json` | Defines which widgets can be added to a template in edit mode |
| **Analysis queries** | `scripts/historical/analysis/*.json` | Defines the ClickHouse SQL queries powering individual chart endpoints |

---

## System Architecture

```
Browser
  └── dashboard.vue                     ← main SPA, renders all components
        ├── dashboard-pie.vue           ← "pie" component wrapper
        │     └── pie-chart.vue         ← D3 v7 rendering
        ├── TableComponent              ← "table" component
        ├── TimeseriesComponent         ← "timeseries" component
        ├── BadgeComponent              ← "badge" component
        └── ... (bar, lateral-pie, sankey, box-overview, …)

Lua backend
  ├── pro/scripts/lua/report.lua                      ← HTML shell + context
  ├── pro/scripts/lua/rest/v2/get/report/template/    ← template API
  │     ├── list.lua                                  ← list available templates
  │     ├── data.lua                                  ← load components for a template
  │     └── widgets.lua                               ← list addable widgets (edit mode)
  └── pro/scripts/lua/rest/v2/get/db/charts/          ← chart data endpoints
        ├── default_rest.lua                          ← generic endpoint (reads chart_id from GET)
        ├── top_l4_proto.lua
        ├── top_l7_proto.lua
        ├── top_l7_categories.lua
        └── ...
```

---

## Mounting / Loading Process

```
1. Browser loads /lua/pro/report.lua
   └── Lua renders the HTML shell and passes a context JSON to Vue:
         template_endpoint, template_list_endpoint, template_add_endpoint, ...

2. dashboard.vue mounts
   └── calls template_list_endpoint → gets list of available templates
   └── calls template_endpoint?template=<name> → gets components[] for the selected template

3. For each component in the array:
   └── dashboard.vue dynamically renders the matching Vue component
   └── Each component calls its own data endpoint (params.url + url_params)
   └── The endpoint returns data; the component renders it

4. When the user changes the epoch range or applies a filter:
   └── dashboard.vue calls get_component_data() for all components
   └── Components re-render with the new data

5. Template edit mode (Enterprise XL only):
   └── Calls widgets.lua to list addable widgets
   └── Add/remove/reorder components via the REST add/edit/delete endpoints
   └── Changes are persisted to workingdir/templates/report/<template_id>.json
```

---

## Template JSON (`scripts/templates/report/*.json`)

Each file is a named template (tab) shown in the report page.

```json
{
    "name"     : "Default Report",
    "readonly" : true,
    "filters"  : [ ... ],
    "components" : [ ... ]
}
```

### Top-level fields

| Field | Description |
|---|---|
| `name` | Display name of the template |
| `readonly` | When `true`, the template cannot be modified by the user (built-in templates) |
| `filters` | List of filter controls shown above the dashboard (see below) |
| `components` | Ordered array of widgets to display |

### `filters` array

Each entry adds a filter dropdown to the top bar. Optional `show_only_if_selected`
makes a filter visible only when another filter has a value selected.

```json
{ "name": "l7proto" },
{ "name": "output_snmp", "show_only_if_selected": "probe_ip" }
```

### `components` array — common fields

Every component entry shares these fields:

| Field | Required | Description |
|---|---|---|
| `component` | yes | Component type: `pie`, `table`, `timeseries`, `badge`, `bar`, `lateral-pie`, `sankey`, `box-overview`, `empty` |
| `id` | yes | Unique identifier within this template |
| `i18n_name` | no | i18n key for the widget title |
| `width` | no | Bootstrap column width, 1–12 (default 4) |
| `height` | no | Relative height in grid rows (default 4) |
| `params` | yes | Component-specific parameters (see per-type sections below) |

---

## Component Types and Their `params`

### `pie` — Pie / Donut chart

Renders a donut chart using `dashboard-pie.vue` → `pie-chart.vue`.

```json
{
    "component" : "pie",
    "id"        : "top_l4_proto",
    "i18n_name" : "top_l4_proto",
    "width"     : 3,
    "height"    : 4,
    "params"    : {
        "url"        : "/lua/pro/rest/v2/get/db/charts/top_l4_proto.lua",
        "url_params" : { "length": 10 },
        "unit"       : "bytes",
        "label"      : "traffic_labels.total_bytes"
    }
}
```

| `params` field | Description |
|---|---|
| `url` | REST endpoint; must return `[{ label, value }]` |
| `url_params` | Extra query parameters appended to the URL |
| `unit` | Optional value formatter passed to `pie-chart.vue` (`"bytes"`, `"value"`, …) |
| `label` | Optional i18n key for the unit label shown in tooltips |

**Endpoint response format** (returned by `format_pie_array_data`):
```json
[ { "label": "TCP", "value": 29126273 }, { "label": "Other", "value": 45400 } ]
```

### `table` — Data table

```json
{
    "component"  : "table",
    "id"         : "top_clients",
    "i18n_name"  : "db_search.top_clients",
    "width"      : 6,
    "height"     : 4,
    "params"     : {
        "url"        : "/lua/pro/rest/v2/get/db/historical_db_search.lua",
        "url_params" : { "query_preset": "clients", "aggregated": true, "start": 0, "length": 20 },
        "table_type" : "db_search",
        "columns"    : [
            { "id": "cli_ip",      "data_type": "host",  "i18n_name": "host_details.host" },
            { "id": "total_bytes", "data_type": "bytes", "i18n_name": "volume" }
        ]
    }
}
```

| `params` field | Description |
|---|---|
| `url` | REST endpoint |
| `url_params` | Query parameters |
| `table_type` | `"db_search"` for ClickHouse query preset tables |
| `columns` | Array of column definitions: `id` (field name), `data_type` (formatter), `i18n_name` |

### `timeseries` — Time-series area chart

```json
{
    "component" : "timeseries",
    "id"        : "traffic_chart",
    "width"     : 12,
    "height"    : 6,
    "params"    : {
        "url"         : "/lua/pro/rest/v2/get/timeseries/ts_multi.lua",
        "url_params"  : {},
        "post_params" : {
            "limit": 180, "version": 4,
            "ts_requests": {
                "ifid": { "ts_query": "ifid:$IFID$", "ts_schema": "iface:traffic_rxtx", "tskey": "$IFID$" }
            }
        },
        "source_type" : "interface"
    }
}
```

### `badge` — Single-value counter

```json
{
    "component" : "badge",
    "id"        : "total_bytes",
    "color"     : "info",
    "width"     : 4,
    "height"    : 2,
    "params"    : {
        "url"               : "/lua/pro/rest/v2/get/db/stats.lua",
        "url_params"        : { "type": "summary" },
        "icon"              : "fas fa-scale-balanced",
        "i18n_name"         : "total_bytes",
        "counter_path"      : "total_bytes",
        "counter_formatter" : "bytes"
    }
}
```

---

## Widget Catalog (`scripts/templates/widgets.json`)

Used only in **edit mode** to list widgets that can be added to a template. Each
entry mirrors a component definition but adds `i18n_descr` and an optional
`requires` block:

```json
{
    "id"         : "top_l4_proto",
    "component"  : "pie",
    "i18n_name"  : "top_l4_proto",
    "i18n_descr" : "top_l4_proto",
    "width"      : 4,
    "height"     : 4,
    "requires"   : { "modules": [ "historical_flows" ] },
    "params"     : { ... }
}
```

The `requires.modules` array lists capability strings that must be enabled for the
widget to be offered. Widgets that fail the check are hidden from the add-widget UI.

---

## Analysis Query Presets (`scripts/historical/analysis/*.json`)

These power the chart-specific Lua endpoints (e.g. `top_l4_proto.lua`). They are
loaded by `db_search_manager.get_charts_query(chart_id, query_preset)`.

Each file groups related charts into a **preset** (e.g. `protos`, `score`):

```json
{
    "name"        : "Applications",
    "i18n_name"   : "top_protos",
    "data_source" : "flows",
    "hourly"      : true,
    "chart"       : [ ... ],
    "show_in_page": "analysis"
}
```

### Chart entry fields

| Field | Required | Description |
|---|---|---|
| `chart_id` | yes | Unique ID; must match what the endpoint passes to `get_charts_query` |
| `chart_i18n_name` | yes | i18n key for the chart title |
| `chart_endpoint` | yes | REST URL called by the Analysis page (not the dashboard template) |
| `chart_sql_query` | yes | ClickHouse SQL; use `$WHERE$` as the filter placeholder |
| `chart_type` | yes | Determines the formatter (see table below) |
| `chart_record_value` | yes | SQL column used as the numeric value |
| `chart_record_label` | yes | SQL column used as the display label |
| `chart_width` | no | 1–12, defaults to 4 |
| `chart_css_styles` | no | CSS applied to the chart container (`max-height`, `min-height`, …) |
| `chart_y_formatter` | no | JS formatter for tooltip values (`format_bytes`, `format_value`, …) |
| `chart_aggregate_low_data` | no | When `true`, entries ≤ 2% of total are collapsed into an "Other" bucket |
| `chart_events` | no | JS click events, e.g. `{ "dataPointSelection": "db_analyze" }` |
| `chart_gui_filter` | no | Filter key applied when the user clicks a slice/bar |
| `chart_i18n_extra_x_tooltip_label` | no | i18n key for the extra tooltip label |

### Chart types and their formatters

| `chart_type` | Lua formatter | Frontend component | Output format |
|---|---|---|---|
| `pie_apex_chart` | `format_apexchart_piechart` | `pie-chart.vue` | `[{label, value}]` |
| `donut_apex_chart` | `format_apexchart_donutchart` | `pie-chart.vue` | `[{label, value}]` |
| `polararea_apex_chart` | `format_apexchart_polarareachart` | `pie-chart.vue` | `[{label, value}]` |
| `radialbar_apex_chart` | `format_apexchart_radialbarchart` | `pie-chart.vue` | `[{label, value}]` |
| `bar_apex_chart` | `format_apexchart_barchart` | ApexCharts bar | `{series, xaxis, …}` |
| `heatmap_apex_chart` | `format_apexchart_heatmap` | ApexCharts heatmap | `{series, xaxis, …}` |
| `treemap_apex_chart` | `format_apexchart_treemap` | ApexCharts treemap | `{series, …}` |
| `timeline_apex_chart` | `format_apexchart_timelinechart` | ApexCharts timeline | `{series, xaxis, …}` |
| `area_apex_chart` | `format_apexchart_list_res` | ApexCharts area | `{series, xaxis, …}` |
| `radar_apex_chart` | `format_apexchart_radarchart` | ApexCharts radar | `{series, xaxis, …}` |
| `geomap` | `format_geomap` | Leaflet map | `[{ip, lat, lng, …}]` |

---

## Adding a New Pie Chart to the Dashboard

### Step 1 — Create the Lua endpoint

Create `pro/scripts/lua/rest/v2/get/db/charts/my_chart.lua` (or reuse
`default_rest.lua` with a `chart_id` GET param):

```lua
local chart_id     = "my_chart"
local query_preset = "protos"   -- name of the .json file in scripts/historical/analysis/

local res, preset = db_search_manager.get_charts_query(chart_id, query_preset, any_interface)
res = historical_chart_formatter.format_default_preset_chart(res, preset)
rest_utils.answer(rc, res)
```

### Step 2 — Add the SQL query preset

Add a chart entry to the appropriate `scripts/historical/analysis/<preset>.json`:

```json
{
    "chart_id"               : "my_chart",
    "chart_i18n_name"        : "my_chart_title",
    "chart_endpoint"         : "/lua/pro/rest/v2/get/db/charts/my_chart.lua",
    "chart_events"           : { "dataPointSelection": "db_analyze" },
    "chart_gui_filter"       : "l7proto",
    "chart_sql_query"        : "SELECT L7_PROTO, SUM(TOTAL_BYTES) AS bytes FROM flows WHERE ($WHERE$) GROUP BY L7_PROTO ORDER BY bytes DESC LIMIT 10",
    "chart_type"             : "donut_apex_chart",
    "chart_record_value"     : "bytes",
    "chart_record_label"     : "L7_PROTO",
    "chart_width"            : 4,
    "chart_y_formatter"      : "format_bytes",
    "chart_aggregate_low_data": true
}
```

### Step 3 — Add it to a template

In `scripts/templates/report/<template>.json`, add a component entry:

```json
{
    "component" : "pie",
    "id"        : "my_chart",
    "i18n_name" : "my_chart_title",
    "width"     : 4,
    "height"    : 4,
    "params"    : {
        "url"        : "/lua/pro/rest/v2/get/db/charts/my_chart.lua",
        "url_params" : { "length": 10 },
        "unit"       : "bytes"
    }
}
```

### Step 4 — (Optional) Expose it in the widget catalog

To make it addable via the edit-mode UI, add an entry to
`scripts/templates/widgets.json`:

```json
{
    "id"         : "my_chart",
    "component"  : "pie",
    "i18n_name"  : "my_chart_title",
    "i18n_descr" : "my_chart_descr",
    "width"      : 4,
    "height"     : 4,
    "requires"   : { "modules": [ "historical_flows" ] },
    "params"     : {
        "url"        : "/lua/pro/rest/v2/get/db/charts/my_chart.lua",
        "url_params" : { "length": 10 },
        "unit"       : "bytes"
    }
}
```

### Step 5 — Add the i18n key

Add the title string to `scripts/locales/en.lua`:
```lua
["my_chart_title"] = "My Chart Title",
```

---

## Custom Label Formatting

If the raw DB label needs transformation before display (e.g. appending extra info),
add a custom formatter in `historical_chart_formatter.lua` and call it from the
endpoint instead of `format_default_preset_chart`:

```lua
function historical_chart_formatter.format_my_chart(records, preset)
    for _, record in pairs(records["results"]) do
        record["label"] = record["L7_PROTO_NAME"] .. " (" .. record["SRC_ASN"] .. ")"
    end
    -- delegate to the standard pie formatter
    return format_pie_array_data(
        preset["chart_record_value"],
        preset["chart_record_label"],
        records, preset
    )
end
```

Then in the endpoint:
```lua
res = historical_chart_formatter.format_my_chart(res, preset)
```

---

## Key Files Reference

| File | Role |
|---|---|
| `pro/scripts/lua/report.lua` | Entry point — renders HTML shell, passes API endpoints to Vue |
| `scripts/templates/report/*.json` | Built-in dashboard template definitions |
| `scripts/templates/widgets.json` | Widget catalog for edit mode |
| `scripts/historical/analysis/*.json` | ClickHouse query presets for chart endpoints |
| `pro/scripts/lua/rest/v2/get/report/template/data.lua` | Returns components[] for a template |
| `pro/scripts/lua/rest/v2/get/report/template/list.lua` | Returns available template names |
| `pro/scripts/lua/rest/v2/get/report/template/widgets.lua` | Returns addable widgets |
| `pro/scripts/lua/modules/analysis_db/historical_chart_formatter.lua` | Formats DB results into frontend-ready data |
| `pro/scripts/lua/modules/analysis_db/gui_charts_utils.lua` | Maps `chart_type` string → formatter function |
| `pro/scripts/lua/modules/flow_db/db_search_manager.lua` | Executes SQL against ClickHouse |
| `pro/scripts/lua/rest/v2/get/db/charts/default_rest.lua` | Generic chart endpoint (uses `chart_id` GET param) |
| `http_src/vue/dashboard.vue` | Main SPA component — orchestrates all widgets |
| `http_src/vue/dashboard-pie.vue` | Dashboard wrapper for pie/donut widgets |
| `http_src/vue/charts/pie-chart.vue` | D3 v7 pie/donut rendering component |
