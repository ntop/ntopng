# Dashboard Timeseries Component

This document describes how the `timeseries` component type works inside the ntopng dashboard system, covering the full lifecycle from JSON template definition to chart rendering.

---

## Performance optimisations applied

| # | What | Where | Effect |
|---|------|-------|--------|
| 1 | Batch Redis pref reads via `ntop.getManyPrefs()` | `graph_utils.lua` + `LuaEngineNtop.cpp` | 16 individual Redis GETs → 1 C++ call on every historical page load |
| 2 | Permanent `cache_metrics_static` for `include_empty_ts=true` calls | `metrics-manager.js` | `consts.lua` called once per interface per session, not once per refresh |
| 3 | Epoch omitted from `consts.lua` URL when `include_empty_ts=true` | `metrics-manager.js` | Maximises cache hits; epoch-independent metadata never causes cache churn |
| 4 | Redis TTL cache (30 s) for RRD `listSeries` directory scans | `rrd.lua` | Eliminates per-query `readdir` + N×`rrd_lastupdate` syscalls for top-N schemas |
| 5 | Pull shared `http_context` fields outside the `ts_requests` loop | `ts_multi.lua` | Avoids re-evaluating `_POST` lookups and `tostring()` on every iteration |
| 6 | Replace `table.len(statistics)==0` with boolean flag in unify path | `ts_multi.lua` | Removes O(N) table scan per series in the aggregation loop |
| 7 | Simplify aggregation inner loop | `ts_multi.lua` | `(aggregated_serie[i] or 0) + v` removes dead `val_is_nan` check and redundant nil-init branch |
| 8 | `Promise.all` for source resolution | `metrics-manager.js` | All source dimensions resolved in parallel instead of sequentially |

---

## Files involved

| File | Role |
|------|------|
| `scripts/templates/dashboard/*.json` | Dashboard template definitions |
| `http_src/vue/dashboard.vue` | Dashboard host, polling loop, data fetch callback |
| `http_src/vue/dashboard-timeseries.vue` | Timeseries component logic |
| `http_src/utilities/metrics-manager.js` | Source/metric resolution and caching |
| `http_src/utilities/timeseries-utils.js` | Server response → Dygraph options translation |
| `http_src/utilities/graph/dygraph-config.js` | Dygraph axis/legend formatters |
| `http_src/vue/timeseries-chart.vue` | Dygraph wrapper |
| `lua/pro/rest/v2/get/timeseries/ts_multi.lua` | Backend multi-timeseries endpoint |
| `lua/rest/v2/get/timeseries/type/consts.lua` | Backend metric definitions endpoint |

---

## 1. Template definition (`enterprise.json`)

Each timeseries widget in a dashboard JSON has this shape:

```json
{
  "component": "timeseries",
  "id": "traffic_chart",
  "i18n_name": "interfaces_traffic",
  "width": 8,
  "height": 4,
  "params": {
    "url": "/lua/pro/rest/v2/get/timeseries/ts_multi.lua",
    "url_params": {},
    "post_params": {
      "limit": 180,
      "version": 4,
      "ts_requests": {
        "$ANY_IFID$": {
          "ts_query": "ifid:$IFID$",
          "ts_schema": "iface:traffic_rxtx",
          "tskey": "$IFID$"
        }
      }
    },
    "source_type": "interface"
  }
}
```

### `ts_requests` keys — placeholder tokens

The key inside `ts_requests` controls how the request is expanded:

| Key | Meaning |
|-----|---------|
| `$ANY_IFID$` | Expanded to one request **per interface** (fetched from `interfaces.lua`) |
| `$ANY_EXPORTER$` | Expanded to one request **per flow exporter** |
| `$ANY_NETWORK$` | Expanded to one request **per subnet** |
| any other string (e.g. `"$IFID$"`) | Single request, current interface only |

### Value placeholders inside the request object

| Placeholder | Substituted with |
|-------------|-----------------|
| `$IFID$` | Current (or iterated) interface ID |
| `$EXPORTER$` | Flow exporter probe IP |
| `$NETWORK$` | Network/subnet ID |

---

## 2. Component lifecycle (`dashboard-timeseries.vue`)

### 2.1 Initialisation (`onBeforeMount`)

```
onBeforeMount
  └── init()          — computes pixel height from max_height prop
```

### 2.2 First chart render

When the `TimeseriesChart` child requests data it calls `get_chart_options()`:

```
get_chart_options()
  ├── resolve_any_params()      — expand $ANY_* placeholders
  ├── retrieve_basic_info()     — resolve ts_groups (metric metadata)
  ├── get_component_data()      — POST to ts_multi.lua
  └── tsArrayToOptionsArray()   — format response for Dygraph
```

### 2.3 `resolve_any_params()` — placeholder expansion

Reads `params.post_params.ts_requests` from the JSON template.
For each key:

- **`$ANY_IFID$`** → calls `interfaces.lua`, iterates the list, calls `substitute_ifid()` for each.
- **`$ANY_EXPORTER$`** → calls `flowdevices/list.lua`, calls `substitute_exporter()` + `substitute_ifid()` for each.
- **`$ANY_NETWORK$`** → calls `network/networks.lua`, calls `substitute_network()` + `substitute_ifid()` for each.
- **default** → single request, substitutes `$IFID$` with the current interface.

Result is stored in `ts_request` (a `ref` array). Also stored in `source_def` dict (keyed by `ts_schema-ts_query`) to remember which source values (ifid, exporter…) correspond to each request.

This step is **idempotent**: a guard (`ts_request.length > 0`) prevents it from running again on subsequent refreshes.

### 2.4 `retrieve_basic_info()` — metric metadata resolution

For each entry in `ts_request`, calls `get_timeseries_groups_from_metric()` **in parallel** via `Promise.all`.

```
retrieve_basic_info()
  └── Promise.all([
        get_timeseries_groups_from_metric(schema, source_def_values),
        ...
      ])
        └── metricsManager.get_source_array_from_value_array()
        └── metricsManager.get_metric_from_schema()   ← hits consts.lua
        └── metricsManager.get_ts_group()
```

Result is stored in `timeseries_groups` (a `ref`). Also **idempotent**: only runs once per component mount.

### 2.5 Data fetch — `get_component_data()`

POSTs to `ts_multi.lua` with:

```json
{
  "csrf": "...",
  "ifid": 1,
  "epoch_begin": 1700000000,
  "epoch_end":   1700000300,
  "limit": 180,
  "version": 4,
  "ts_requests": [ ... ]   ← expanded array from ts_request
}
```

The callback is provided by `dashboard.vue` and handles:
- Deduplication across components sharing the same datasource
- Backup data (saved reports)
- Infrastructure proxy routing

### 2.6 Stale-request cancellation (generation counter)

`refresh_generation` is a module-level integer. On every `get_chart_options()` call it is pre-incremented and captured as `generation`. After each `await` the captured value is compared to the current counter:

```js
const generation = ++refresh_generation;
await resolve_any_params();
if (generation !== refresh_generation) return null;   // stale, abort
await retrieve_basic_info();
if (generation !== refresh_generation) return null;
// ... fetch ...
if (generation !== refresh_generation) return null;
```

This prevents a slow request from overwriting the chart with outdated data when a newer refresh has already started.

### 2.7 Result formatting — `tsArrayToOptionsArray()`

Translates the raw server response array + timeseries group metadata into Dygraph option objects.

Two layout modes (set at component creation):

| Mode | Behaviour |
|------|-----------|
| `1_chart_x_metric` | One Dygraph instance per metric |
| `1_chart_x_yaxis` | One Dygraph instance per Y-axis unit (groups metrics with the same unit/scale); stacked and non-stacked series are split into separate charts |

Dashboard timeseries always uses `1_chart_x_yaxis`.

---

## 3. Metric metadata — `metrics-manager.js`

### 3.1 Source types

Defined in `metrics-consts.js` as `sources_types`. Each entry has:

- `id` — identifier used in `source_type` field of the JSON template
- `query` — value sent as `?query=` to `consts.lua`
- `regex_page_url` — compiled once at module load (`_regex`) to match the current page URL
- `source_def_array` — array of source dimension definitions (e.g. `ifid`, `exporter`, `network`)

### 3.2 `get_metrics()` — two-tier cache

| Cache | Key | Invalidation |
|-------|-----|-------------|
| `cache_metrics_static` | `source_type_id + source_values` | Never (permanent per session) |
| `cache_metrics` | `source_type_id + source_values` | On epoch interval change |

**When `include_empty_ts = true`** (dashboard timeseries always passes this): the static cache is used and epoch is omitted from the `consts.lua` URL. The response is metric definitions only — static metadata that does not depend on the time window. This means `consts.lua` is called **once per interface per page load**, not once per refresh cycle.

**When `include_empty_ts` is false** (interactive timeseries explorer): the epoch-dependent cache is used. It is cleared as a whole when `epoch_begin_epoch_end` changes.

### 3.3 Source resolution

`get_source_array_from_value_array()` resolves source labels for display using `Promise.all` — all source dimensions are fetched concurrently.

Sources fetched from REST endpoints are cached in `cache_sources`, keyed by `source_type_id + source_def_value [+ selected_values if refresh_on_sources_change]`.

---

## 4. Dashboard refresh loop (`dashboard.vue`)

```
start_dashboard_refresh_loop()
  └── setInterval(REFRESH_INTERVAL_SEC * 1000)
        └── set_components_epoch_interval()
              └── updates epoch_begin/epoch_end on each component
                    └── watch in dashboard-timeseries.vue fires
                          └── refreshChart() → get_chart_options()
```

`REFRESH_INTERVAL_SEC` is defined at the top of `dashboard.vue`.

On each tick, only `epoch_begin`/`epoch_end` change. The component re-uses:
- `ts_request` (already resolved)
- `timeseries_groups` (already resolved)
- `cache_metrics_static` (permanent)
- `cache_sources` (permanent)

So each refresh only makes a **single new network request**: the POST to `ts_multi.lua`.

---

## 5. Dygraph value formatter (`dygraph-config.js`)

`getAxisConfiguration(formatter)` returns Dygraph axis options including `valueFormatter`.

The formatter reads `dygraph.rawData_[row]?.[col]` to detect "band" series (arrays, used for bounds like min/max). Optional chaining on both `[row]` and `[col]` prevents a crash when `clearSelection` fires during a zoom with a stale row index.

---

## 6. Adding a new timeseries widget to a dashboard

1. Add an entry to the JSON template with `"component": "timeseries"`.
2. Set `source_type` to a valid id from `metrics-consts.js` (`interface`, `host`, `network`, …).
3. In `ts_requests`:
   - Use `"$ANY_IFID$"` as key to fan out across all interfaces, or a literal key for a single series.
   - Set `ts_schema` to a schema registered in `consts.lua` for that source type.
   - Set `ts_query` using `dim:value` format (e.g. `ifid:$IFID$`).
   - Set `tskey` to the dimension value that identifies the series in the chart legend.
4. `limit` caps the number of data points returned per series (180 = 3 minutes at 1s resolution or 30 minutes at 10s resolution depending on RRD step).

---

## 7. Data flow diagram

```
JSON template
     │
     ▼
dashboard-timeseries.vue
     │
     ├─ resolve_any_params()
     │       └─ interfaces.lua / flowdevices/list.lua / networks.lua
     │
     ├─ retrieve_basic_info()  [Promise.all, once]
     │       └─ metrics-manager: get_source_array_from_value_array()
     │       └─ metrics-manager: get_metric_from_schema()
     │               └─ consts.lua  [cached in cache_metrics_static]
     │
     ├─ get_component_data()  [every refresh]
     │       └─ POST ts_multi.lua
     │
     └─ tsArrayToOptionsArray()
             └─ timeseries-utils: split stacked / non-stacked
             └─ dygraphFormat: build Dygraph options objects
                     └─ TimeseriesChart.vue: updateChartSeries()
```
