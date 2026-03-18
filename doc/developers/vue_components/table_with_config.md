# TableWithConfig

Renders a fully-featured data table driven by a JSON config file in `httpdocs/tables_config/`.
Internally wraps `table.vue` and loads configuration via `TableUtils.build_table`.

Use this component when you need a sortable, paginated, searchable table whose columns are defined externally (so that the user can toggle their visibility). If you need a simple static table without config-file-driven columns, use `table.vue` directly.

## Props

| Prop | Type | Required | Description |
|---|---|---|---|
| `table_config_id` | String | Yes* | Filename (without `.json`) in `httpdocs/tables_config/` |
| `table_id` | String | No | Override for the DOM id and column visibility key. Defaults to `table_config_id` |
| `csrf` | String | No | CSRF token (pass `context.csrf` from Lua) |
| `f_map_config` | Function | No | Post-process the loaded config object |
| `f_map_columns` | Function | No | Transform column definitions after load — use to add `render_func`, `render_v_func`, `f_map_class`, hide columns, etc. |
| `f_sort_rows` | Function | No | Custom row sort function |
| `get_extra_params_obj` | Function | No | Returns extra query params to append to `data_url` |
| `handleLoadedColumns` | Function | No | Called after column visibility is resolved |
| `display_message` | Boolean | No | Show `message_to_display` above the table |
| `message_to_display` | String | No | Message string shown when `display_message` is true |
| `showLoading` | Boolean | No | Overlay the table with a loading spinner |

\* Either `table_config_id` or `table_id` must be provided.

## Slots

| Slot | Description |
|---|---|
| `custom_header` | Content injected above the table toolbar (left-aligned) — ideal for filter btn-groups |
| `custom_buttons` | Extra icon buttons injected in the table toolbar (right-aligned, near refresh/columns) |

## Events

| Event | Payload | Description |
|---|---|---|
| `loaded` | — | Fired after table data is first loaded |
| `rows_loaded` | rows array | Fired every time rows are (re-)fetched. Payload is the full array of row objects as returned by the REST endpoint. Use this to compute counts, totals, or track "all visible rows" for batch operations. |
| `custom_event` | `{ event_id, row, col }` | Fired by button columns and `render_v_func` — `event_id` matches `button_def_array[].event_id` or whatever value is passed by custom render functions |

### Triggering a table refresh from the parent

Call `table_ref.value?.update?.()` after any mutation to reload data from the server.

```js
const table_ref = ref(null);

async function save_and_refresh() {
  await ntopng_utility.http_request(url, { method: "POST", body });
  table_ref.value?.update?.();  // re-fetch rows
}
```

```vue
<TableWithConfig ref="table_ref" table_config_id="my_table" ... />
```

---

## Config file format (`httpdocs/tables_config/<id>.json`)

```json
{
  "id": "my_table",
  "data_url": "lua/rest/v2/get/my/data.lua",
  "use_current_page": false,
  "enable_search": true,
  "paging": false,
  "display_empty_rows": false,
  "default_sort": {
    "column_id": "name",
    "sort": 1
  },
  "columns": [ ... ]
}
```

### Top-level fields

| Field | Type | Default | Description |
|---|---|---|---|
| `id` | string | — | Unique table identifier (matches filename) |
| `data_url` | string | — | REST endpoint returning rows (relative to `http_prefix`) |
| `use_current_page` | bool | `false` | Append current page GET params to `data_url` |
| `enable_search` | bool | `false` | Show search/filter input |
| `paging` | bool | `false` | **Client-side** (`false`): endpoint returns all rows at once; table handles pagination/sort/search in the browser. **Server-side** (`true`): table sends `active_page`, `per_page`, `sort_column` on every change; endpoint must return `recordsTotal` in the response alongside the rows. Use `false` for small-to-medium datasets. |
| `display_empty_rows` | bool | `false` | Show empty row placeholders when no data |
| `default_sort` | Object | — | Initial sort column and direction |
| `default_sort.column_id` | string | — | `id` of the column to sort by (not `data_field`) |
| `default_sort.sort` | 1 or 2 | — | `1` = ascending, `2` = descending |
| `columns` | Array | — | Column definitions (see below) |

### Column definition

```json
{
  "id": "hostname",
  "title_i18n": "name",
  "data_field": "hostname",
  "sortable": true,
  "sticky": false,
  "min-width": "120px",
  "max-width": "200px",
  "class": ["text-nowrap"],
  "render_v_node_type": "button_array",
  "button_def_array": [ ... ]
}
```

| Field | Type | Description |
|---|---|---|
| `id` | string | Column key — used as the sort key and visibility key |
| `title_i18n` | string | i18n key for column header |
| `data_field` | string | Key in the row object used as cell value (passed to `render_func` / `render_v_func`) |
| `sortable` | bool | Whether the column can be sorted |
| `sticky` | bool | Pin column to left edge |
| `min-width` | string | CSS min-width (e.g. `"120px"`) |
| `max-width` | string | CSS max-width |
| `class` | string[] | CSS classes applied to each cell |
| `render_v_node_type` | string | Built-in Vue-node renderer. Currently supports `"button_array"` (inline buttons) and `"button_list"` (dropdown). Mutually exclusive with `render_v_func`. |
| `button_def_array` | Array | Button definitions (used with `render_v_node_type`) |

### Button definition (`button_def_array[]`)

```json
{
  "id": "view_host",
  "icon": "fas fa-eye",
  "title_i18n": "view",
  "class": ["btn-info"],
  "event_id": "click_button_view_host"
}
```

| Field | Description |
|---|---|
| `id` | Unique button id |
| `icon` | FontAwesome icon class |
| `title_i18n` | i18n key for tooltip |
| `class` | Extra Bootstrap button classes (e.g. `btn-info`, `btn-danger`) — appended to the default `btn btn-sm btn-secondary` |
| `event_id` | String emitted as `custom_event.event_id` when clicked |
| `f_map_class` | `(classArray, row) => classArray` — dynamic class override based on row data (set via `f_map_columns`) |

---

## Advanced column customisation via `f_map_columns`

`f_map_columns` is an `async function(columns) => columns` callback. It receives the column array after the JSON is loaded and must return the (mutated) array. Use it to:

### 1 — Add a `render_func` (HTML string renderer)

Called with `(data_field_value, row)`. Return an HTML string.

```js
async function mapColumns(columns) {
  columns.forEach((c) => {
    if (c.id === "category") {
      c.render_func = (_data, row) => {
        const icon  = row.category_icon ? `<i class="${row.category_icon}"></i> ` : "";
        const label = row.category_key  ? _i18n(row.category_key) : "";
        return `${icon}${label}`;
      };
    }
  });
  return columns;
}
```

### 2 — Add a `render_v_func` (Vue vnode renderer — for interactive cells)

Called with `(_col, row, vue_obj)`. Return a vnode created with `vue_obj.h(...)`.
`vue_obj.emit("custom_event", payload)` routes the event back to the parent page via the `@custom_event` handler.

**Use this for toggle switches, checkboxes, or any cell that must fire events.**

```js
if (c.id === "enabled") {
  c.render_v_func = (_col, row, vue_obj) => {
    return vue_obj.h(
      "div",
      { class: "form-check form-switch d-flex justify-content-center mb-0" },
      [
        vue_obj.h("input", {
          type:    "checkbox",
          class:   "form-check-input",
          checked: row.is_enabled,
          style:   "cursor:pointer;",
          onChange: (e) => {
            e.stopPropagation();
            vue_obj.emit("custom_event", {
              event_id: "toggle_enabled",
              row,
              enabled: e.target.checked,
            });
          },
        }),
      ]
    );
  };
}
```

> **Important**: name the first parameter `_col` (underscore prefix) to suppress the "declared but never read" TypeScript hint.

### 3 — Hide a column programmatically

Set `col.visible = false`. The table respects this flag and hides both header and cells. The column still appears in the "visible columns" dropdown so the user can re-enable it.

```js
if (c.id === "subdir" && props.context.check_subdir !== "all") {
  c.visible = false;
}
```

### 4 — Add `f_map_class` to a button (dynamic per-row styling)

```js
const toggle_btn = c.button_def_array.find((b) => b.id === "toggle");
if (toggle_btn) {
  toggle_btn.f_map_class = (classArray, row) =>
    row.is_enabled
      ? [...classArray, "btn-success"]
      : [...classArray, "btn-secondary"];
}
```

---

## Sorting with `f_sort_rows`

**Always provide `f_sort_rows`** — the default fallback uses `localeCompare` on rendered HTML strings, which breaks for numbers, IPs, bytes, and timestamps.

```js
import { default as sortingFunctions } from "../utilities/sorting-utils.js";

const SORT_FIELDS = {
  name:      { getter: (r) => r.name,      fn: sortingFunctions.sortByName   },
  ip:        { getter: (r) => r.ip,        fn: sortingFunctions.sortByIP     },
  bytes:     { getter: (r) => r.bytes,     fn: sortingFunctions.sortByNumber },
  enabled:   { getter: (r) => r.is_enabled ? 1 : 0, fn: sortingFunctions.sortByNumber },
};

function columns_sorting(col, r0, r1) {
  if (!col) return 0;
  const def = SORT_FIELDS[col.id];
  if (!def) return 0;
  return def.fn(def.getter(r0), def.getter(r1), col.sort);
}
```

Available sort functions: `sortByName`, `sortByNumber`, `sortByIP`, `sortByMacAddress`.

---

## Status-filter pattern (All / Enabled / Disabled tabs)

Use a Bootstrap 5 `btn-group` injected via the `custom_header` slot. Changing the active filter updates the URL params returned by `get_extra_params_obj`, then calls `table_ref.value?.update?.()` to re-fetch.

```vue
<template v-slot:custom_header>
  <div class="btn-group btn-group-sm" role="group">
    <button
      v-for="tab in status_tabs" :key="tab.id"
      type="button" class="btn"
      :class="active_status === tab.id ? 'btn-primary' : 'btn-outline-secondary'"
      @click="set_status(tab.id)"
    >
      {{ _i18n(tab.label_key) }}
      <span class="badge ms-1"
        :class="active_status === tab.id ? 'bg-light text-dark' : 'bg-secondary'"
      >{{ counts[tab.id] ?? '…' }}</span>
    </button>
  </div>
</template>
```

```js
const active_status = ref("all");
const counts = reactive({});

function set_status(id) {
  active_status.value = id;
  table_ref.value?.update?.();
}

// Populate counts from the "all" fetch
function on_rows_loaded(rows) {
  if (active_status.value === "all") {
    counts.all      = rows.length;
    counts.enabled  = rows.filter((r) => r.is_enabled).length;
    counts.disabled = rows.length - counts.enabled;
  } else {
    counts[active_status.value] = rows.length;
  }
}
```

The REST endpoint must accept and honour the `status` param (`"all"` | `"enabled"` | `"disabled"`).

---

## Batch operations pattern

Use `@rows_loaded` to cache the current row set, then operate on it from action buttons in `custom_buttons`:

```vue
<template v-slot:custom_buttons>
  <button class="btn btn-sm btn-outline-danger"
    :disabled="all_rows.length === 0"
    @click="show_confirm = true"
  >
    <i class="fas fa-toggle-off"></i>
  </button>
</template>
```

```js
const all_rows = ref([]);

function on_rows_loaded(rows) {
  all_rows.value = rows || [];
}

async function disable_all() {
  const keys = all_rows.value.filter((r) => r.is_enabled).map((r) => r.key);
  // group by subdir if needed, then call batch endpoint
}
```

---

## Full example

```vue
<template>
  <TableWithConfig
    ref="table_ref"
    table_config_id="my_configset"
    :get_extra_params_obj="getExtraParams"
    :f_map_columns="mapColumns"
    :f_sort_rows="columns_sorting"
    @custom_event="on_table_event"
    @rows_loaded="on_rows_loaded"
  >
    <template v-slot:custom_header>
      <!-- filter btn-group here -->
    </template>
    <template v-slot:custom_buttons>
      <!-- batch action buttons here -->
    </template>
  </TableWithConfig>
</template>

<script setup>
import { ref, reactive } from "vue";
import { default as TableWithConfig } from "./table-with-config.vue";
import { default as sortingFunctions } from "../utilities/sorting-utils.js";
import { ntopng_utility } from "../services/context/ntopng_globals_services.js";

const _i18n = (t) => i18n(t);
const props = defineProps({ context: Object });

const table_ref   = ref(null);
const all_rows    = ref([]);
const active_status = ref("all");

function getExtraParams() {
  return { ifid: props.context.ifid, status: active_status.value };
}

async function mapColumns(columns) {
  columns.forEach((c) => {
    if (c.id === "enabled") {
      c.render_v_func = (_col, row, vue_obj) =>
        vue_obj.h("div", { class: "form-check form-switch d-flex justify-content-center mb-0" }, [
          vue_obj.h("input", {
            type: "checkbox", class: "form-check-input",
            checked: row.is_enabled, style: "cursor:pointer;",
            onChange: (e) => {
              e.stopPropagation();
              vue_obj.emit("custom_event", { event_id: "toggle", row, enabled: e.target.checked });
            },
          }),
        ]);
    }
  });
  return columns;
}

const SORT_FIELDS = {
  name:    { getter: (r) => r.name,       fn: sortingFunctions.sortByName   },
  enabled: { getter: (r) => r.is_enabled ? 1 : 0, fn: sortingFunctions.sortByNumber },
};

function columns_sorting(col, r0, r1) {
  const def = col && SORT_FIELDS[col.id];
  return def ? def.fn(def.getter(r0), def.getter(r1), col.sort) : 0;
}

function on_rows_loaded(rows) { all_rows.value = rows || []; }

async function on_table_event({ event_id, row, enabled }) {
  if (event_id === "toggle") {
    await ntopng_utility.http_request(toggle_url, { method: "POST",
      body: new URLSearchParams({ key: row.key, enabled: String(enabled), csrf: props.context.csrf }) });
    table_ref.value?.update?.();
  }
}
</script>
```

## Import

```js
import { default as TableWithConfig } from "./table-with-config.vue";
```

Path is relative — adjust `../` or `./` based on where the importing component lives.
