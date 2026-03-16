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
| `f_map_columns` | Function | No | Transform column definitions after load |
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
| `custom_header` | Content injected above the table toolbar |
| `custom_buttons` | Extra buttons injected in the table toolbar |

## Events

| Event | Payload | Description |
|---|---|---|
| `loaded` | — | Fired after table data is first loaded |
| `rows_loaded` | rows array | Fired every time rows are refreshed |
| `custom_event` | `{ event_id, row }` | Fired by button columns — `event_id` matches `button_def_array[].event_id` in the config |

---

## Config file format (`httpdocs/tables_config/<id>.json`)

```json
{
  "id": "my_table",
  "data_url": "lua/rest/v2/get/my/data.lua",
  "use_current_page": false,
  "enable_search": true,
  "paging": true,
  "display_empty_rows": true,
  "default_sort": {
    "column_id": "name",
    "sort": 0
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
| `paging` | bool | `false` | Enable pagination |
| `display_empty_rows` | bool | `false` | Show empty row placeholders when no data |
| `default_sort` | Object | — | Initial sort column and direction |
| `default_sort.column_id` | string | — | `data_field` of the column to sort by |
| `default_sort.sort` | 0 or 1 | — | `0` = ascending, `1` = descending |
| `columns` | Array | — | Column definitions (see below) |

### Column definition

```json
{
  "id": "actions",
  "title_i18n": "actions",
  "data_field": "hostname",
  "sortable": true,
  "sticky": false,
  "min-width": "120px",
  "class": ["text-nowrap", "text-center"],
  "render_v_node_type": "button_array",
  "button_def_array": [ ... ]
}
```

| Field | Type | Description |
|---|---|---|
| `id` | string | Column key (required if no `data_field`) |
| `title_i18n` | string | i18n key for column header |
| `data_field` | string | Key in the row object to render as cell value |
| `sortable` | bool | Whether the column can be sorted |
| `sticky` | bool | Pin column to left edge |
| `min-width` | string | CSS min-width (e.g. `"120px"`) |
| `class` | string[] | CSS classes applied to each cell |
| `render_v_node_type` | string | Special renderer — currently supports `"button_array"` |
| `button_def_array` | Array | Button definitions (only used with `render_v_node_type: "button_array"`) |

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
| `class` | Bootstrap button classes (e.g. `btn-info`, `btn-danger`) |
| `event_id` | Emitted as `custom_event` payload when clicked |

---

## Vue usage

```vue
<script setup>
import { default as TableWithConfig } from "../table-with-config.vue";

const props = defineProps({ context: Object });

function get_extra_params() {
  return { ifid: props.context.ifid };
}

function on_custom_event({ event_id, row }) {
  if (event_id === "click_button_view_host") {
    window.location.href = `${http_prefix}/lua/host_details.lua?host=${row.ip_address}`;
  }
}
</script>

<template>
  <TableWithConfig
    table_config_id="hosts_list"
    :csrf="context.csrf"
    :get_extra_params_obj="get_extra_params"
    @custom_event="on_custom_event"
  />
</template>
```

## Import

```js
import { default as TableWithConfig } from "../table-with-config.vue";
```

Path is relative — adjust `../` based on where the importing component lives.
