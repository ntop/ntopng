# Vue Components Reference

This document contains documentation for vuejs components and their usage in ntopng UI.
Components can be used in:
- Other vuejs components with the usual import and instantiation syntax of vuejs components
- In lua pages using the `template.render` function. 
    - **IMPORTANT** Be sure to import newly created components in `http_src/vue/ntop_vue.js` and export it, an example is reported below

```js
// import the new component
import { default as PieChart } from "./charts/pie-chart.vue";

// export it 
let ntopVue = {
    // graphs
    MultiPieChart: MultiPieChart,
    PieChart: PieChart
}
```
---

## PieChart

Single donut chart with legend, tooltip, and auto-refresh. If url is provided in the rest, the pie slice can be clicked and redirected to the page

### Props

| Prop | Type | Required | Description |
|---|---|---|---|
| `chart` | Object | Yes | Chart config object |
| `context` | Object | Alternative | Wrapper with a `chart` key (used from Lua) |

### Chart Object

| Field | Type | Required | Description |
|---|---|---|---|
| `name` | string | Yes | Unique chart ID |
| `update_url` | string | Yes | Endpoint returning `[{ label, value, url? }]` |
| `url_params` | Object | No | Query params appended to `update_url` |
| `refresh` | number | No | Auto-refresh in ms (0 = disabled) |
| `title` | string | No | Title above chart |
| `unit` | string | No | Value formatter — `"bytes"`, `"number"`, etc. |

### Vue
```vue
<PieChart :chart="{
  name:       'myChart',
  title:      'Traffic by Protocol',
  update_url: `${http_prefix}/lua/rest/v2/get/interface/l7/stats.lua`,
  url_params: { ifid: context.ifid },
  refresh:    5000,
  unit:       'bytes',
}" />
```

### Lua
```lua
template.render("pages/vue_page.template", {
   vue_page_name = "PieChart",
   page_context  = json.encode({
      chart = {
         name       = "myChart",
         title      = i18n("my_title"),
         update_url = http_prefix .. "/lua/rest/v2/get/interface/l7/stats.lua",
         url_params = { ifid = ifstats.id },
         refresh    = refresh,
         unit       = "bytes",
      }
   }),
})
```

---

## MultiPieChart

Renders multiple `PieChart` instances in a responsive grid. if `charts_per_row` is specified, it is possible to choose the number of pie charts per row to display, otherwise all charts are disposed on one row with automatic flex and new row creation

### Props

| Prop | Type | Required | Description |
|---|---|---|---|
| `context` | Object | Yes | Object with `charts` array and optional `charts_per_row` |
| `charts_per_row` | number | No | Columns in grid (default: all charts in one row) |

### Context Object

| Field | Type | Required | Description |
|---|---|---|---|
| `charts` | Array | Yes | Array of Chart Objects (same schema as PieChart) |
| `charts_per_row` | number | No | Overrides column count |

### Vue
```vue
<MultiPieChart :context="{
  charts_per_row: 2,
  charts: [
    {
      name:       'clientPorts',
      title:      'Client Ports',
      update_url: `${http_prefix}/lua/iface_ports_list.lua`,
      url_params: { clisrv: 'client', ifid: context.ifid },
      refresh:    5000,
      unit:       'number',
    },
    {
      name:       'serverPorts',
      title:      'Server Ports',
      update_url: `${http_prefix}/lua/iface_ports_list.lua`,
      url_params: { clisrv: 'server', ifid: context.ifid },
      refresh:    5000,
      unit:       'number',
    },
  ],
}" />
```

### Lua
```lua
template.render("pages/vue_page.template", {
   vue_page_name = "MultiPieChart",
   page_context  = json.encode({
      charts_per_row = 2,
      charts = {
         {
            name       = "clientPorts",
            title      = i18n("ports_page.client_ports"),
            update_url = http_prefix .. "/lua/iface_ports_list.lua",
            url_params = table.merge({ clisrv = "client", ifid = ifId }, host_params),
            refresh    = refresh,
            unit       = "number",
         },
         {
            name       = "serverPorts",
            title      = i18n("ports_page.server_ports"),
            update_url = http_prefix .. "/lua/iface_ports_list.lua",
            url_params = table.merge({ clisrv = "server", ifid = ifId }, host_params),
            refresh    = refresh,
            unit       = "number",
         },
      }
   }),
})
```

---

## Data Endpoint Format

All pie chart endpoints must return a JSON array:

```json
[
  { "label": "TCP",  "value": 1024, "url": "/lua/flows_stats.lua?proto=6" },
  { "label": "UDP",  "value": 512 },
  { "label": "Other","value": 128 }
]
```

| Field | Required | Description |
|---|---|---|
| `label` | Yes | Slice label shown in legend |
| `value` | Yes | Numeric value |
| `url` | No | Click-through URL for slice and legend item |

---

## NoData

Simple info banner rendered when there is no data to display. Supports both i18n keys and direct strings.

### Props

| Prop | Type | Required | Description |
|---|---|---|---|
| `show` | Boolean | Yes | Renders the component when `true` |
| `i18nKey` | String | No | i18n translation key (default: `'flows_page.no_data'`) |
| `message` | String | No | Direct string — takes priority over `i18nKey` if provided |

### Vue
```vue
<!-- Default message -->
<NoData :show="no_data" />

<!-- Custom i18n key -->
<NoData :show="no_data" i18nKey="some_page.empty_table" />

<!-- Direct string -->
<NoData :show="no_data" message="No flows available" />

<!-- Compound expression -->
<NoData :show="no_data && !loading" :message="no_data_message" i18nKey="flows_page.no_data" />
```

---

## LoadingOverlay

Full-area loading overlay with spinner and translated label. Positions itself as `fixed` when the parent element exceeds 70% of the viewport height.

### Props

| Prop | Type | Required | Description |
|---|---|---|---|
| `isLoading` | Boolean | Yes | Shows the overlay when `true`, hides when `false` |
| `styles` | String | No | Inline styles applied to the spinner element |

### Notes
- The overlay uses `position: absolute` and fills the parent via `inset: 0` — the parent must have `position: relative`
- Automatically listens to `resize` events to recompute fixed positioning
- Respects `data-theme="light"` / `data-theme="dark"` on `:root`

### Vue
```vue
<div class="position-relative">
  <LoadingOverlay :isLoading="loading" />
</div>

<!-- With custom spinner style -->
<LoadingOverlay :isLoading="loading" styles="width: 60px; height: 60px;" />
```