---
name: ntop-vue-scaffold
description: Scaffold new Vue.js components or pages in ntopng. Fires when the user asks to CREATE a new Vue component, chart, or page. Does NOT fire for editing existing components, explanations, or non-Vue work.
user-invocable: true
---

You are scaffolding a new Vue.js component or page for the ntopng application.

## STOP IMMEDIATELY and ask if any of these are missing:
- **No component/page name given** → ask: "What should the component be called?"
- **Type is 'page' but no .lua filename given** → ask: "What should the Lua filename be? (e.g., my_page.lua)"

## STOP IMMEDIATELY and notify user if:
- A `.vue` file with that name already exists in `http_src/vue/` or its subfolders → tell the user the exact path of the conflict and do nothing until they respond.

---

## Step 1 — Classify the request

Determine from the user's request:

| Signal in request | Type | Vue subfolder | ntop_vue.js section |
|---|---|---|---|
| "chart", "graph", "pie", "line", "bar", "d3" | **chart** | `http_src/vue/charts/` | `/* Charts */` imports block + `// graphs` export block |
| "page", "lua page", "community version", "pro version" | **page** | `http_src/vue/` (root, following existing page naming convention) | `// pages` import block + `// pages` export block |
| "modal" | **modal** | `http_src/vue/` (root) | `// modals` import block + export block |
| "dashboard" | **dashboard** | `http_src/vue/` (root) | `// dashboard` import block + export block |
| anything else / "component" | **component** | `http_src/vue/components/` | `// components` import block + export block |

For pages, also determine:
- **community** → `scripts/lua/<filename>.lua`
- **pro** → `pro/scripts/lua/<filename>.lua`

---

## Step 2 — Derive names

From the user's component name (e.g., "TrafficLine", "traffic-line", "traffic line"):

- **kebab-case filename**: `traffic-line.vue`
- **PascalCase export name**: `TrafficLine`
- For pages, prefix with `Page`: filename `page-traffic-line.vue`, export `PageTrafficLine`
- For charts: no prefix needed unless user specifies one
- For modals: prefix `Modal`: filename `modal-traffic-line.vue`, export `ModalTrafficLine`
- For dashboard: prefix `Dashboard`: filename `dashboard-traffic-line.vue`, export `DashboardTrafficLine`

---

## Step 3 — Check for conflicts

Use Glob to search for the target filename in `http_src/vue/**/*.vue`. If found, stop and notify the user with the exact path. Do not create any files.

---

## Step 4 — Create the .vue skeleton

Create the file at the determined path with this minimal skeleton (prevents build errors):

```vue
<!--
  (C) 2024 - ntop.org
-->
<template>
  <div>Hello ntop</div>
</template>

<script setup>
const _i18n = (t) => i18n(t);
</script>
```

Do NOT add implementation code unless the user provided explicit guidelines or described what the component should do.

### i18n usage rules (MANDATORY — enforced across all implementation steps)

- **Always declare** `const _i18n = (t) => i18n(t);` at the top of every `<script setup>` block.
- **Everywhere — template and script**: always call `_i18n(...)`. Example: `{{ _i18n('name') }}` in template, `_i18n('request_failed_message')` in script.
- **Never** call the bare `i18n(...)` global directly in `<script setup>` — TypeScript cannot resolve it and will emit warnings. `_i18n` is the locally-declared alias that TypeScript knows about.
- **Rationale**: `i18n` is a runtime global injected by ntopng and is invisible to the TypeScript checker. `_i18n = (t) => i18n(t)` wraps it in a locally-declared function that TypeScript can see.


### Mandatory comment style
Never use comments with long dashes like  ────────────────────────────────────────────── or like // ── state ──────────────────────── but only provide comments in this format:
// Comment text, brief and explanatory

### Mandatory coding style
Make constants uppercase, variables lowercase with explicative code, not difficult
---

## Step 4b — Check existing reusable components before implementing

**Before writing any implementation or running any Glob/Grep search**, read the component documentation files first:

1. Read `doc/developers/vue_components/table_with_config.md` — full TableWithConfig API, config format, render_func/render_v_func patterns, sorting, status-filter pattern, batch operations.
2. Read `doc/developers/vue_components/components_usage.md` — props and usage for PieChart, MultiPieChart, NoData, LoadingOverlay, and other shared components.

Reading the docs first avoids redundant file searches and ensures you use the correct API from the start. Only run Glob/Grep if you need to look up something not covered in the docs.

Key components:

| Component | Import path (from `http_src/vue/`) | When to use |
|---|---|---|
| `Loading` (LoadingOverlay) | `./loading.vue` | Any async data fetch — wrap data area in `<div class="position-relative"><Loading :isLoading="loading" /></div>` |
| `NoData` | `./components/no-data.vue` | Show when fetch returns empty — `<NoData :show="!loading && rows.length === 0" />` |
| `Table` | `./table.vue` | Simple custom table with programmatic column/row control |
| `TableWithConfig` | `./table-with-config.vue` | Sortable/paginated/searchable table driven by a JSON config in `httpdocs/tables_config/`. See `doc/developers/vue_components/table_with_config.md` for full config format. **Use this when you need to hide/show columns from the UI.** |
| `Modal` | `./modal.vue` | Base modal — wrap content inside it |
| `SelectSearch` | `./select-search.vue` | Searchable dropdown |
| `TabList` | `./tab-list.vue` | Tab navigation |
| `DateTimeRangePicker` | `./date-time-range-picker.vue` | Date range picker |

For charts, prefer existing chart components (`PieChart`, `MultiPieChart`, `TimeseriesChart`) over building from scratch with D3 unless the user explicitly requests a custom chart.

Read `doc/developers/vue_components/components_usage.md` if you need props/usage details for `PieChart`, `MultiPieChart`, `NoData`, or `LoadingOverlay`.

### Table component selection rules (MANDATORY)

**Never hand-roll a `<table>` element in a page component.** Always use one of the ntopng table components:

| Situation | Component to use |
|---|---|
| Simple read-only table, no column visibility toggle needed | `Table` (`./table.vue`) |
| Sortable / paginated / searchable table, or columns that can be hidden from the UI | `TableWithConfig` (`./table-with-config.vue`) |

When using `TableWithConfig`:
1. Create a JSON config file at `httpdocs/tables_config/<id>.json` — `id` must match the filename without `.json`.
2. Choose the correct `paging` mode:
   - **`"paging": false`** (client-side) — the endpoint returns all rows at once as a plain array. The table handles pagination, search, and sorting entirely in the browser. **Use this for static/in-memory data or small-to-medium lists.** This is the most common case (see `countries_stats.json` as reference).
   - **`"paging": true`** (server-side) — the table sends `active_page`, `per_page`, and `sort_column` params to the endpoint on every page/sort/search change. The endpoint **must** return `recordsTotal` (total count of all rows across all pages) in the response body alongside the page's rows. **Only use this for very large datasets where fetching everything upfront is too slow.**
3. Set `"enable_search": true` for any list longer than ~10 rows.
4. Each column entry must have `title_i18n` (an i18n key), `data_field` (matching the REST response field), and `sortable`.
5. Pass `table_config_id="<id>"` as the only required prop in the template (add `:get_extra_params_obj` only if the endpoint needs query params like `ifid`).

**Reference config pattern** (from `countries_stats.json`):
```json
{
  "id": "my_table",
  "data_url": "lua/rest/v2/get/my/data.lua",
  "use_current_page": false,
  "enable_search": true,
  "paging": false,
  "display_empty_rows": true,
  "columns": [
    { "id": "name", "title_i18n": "name", "data_field": "name", "sortable": true, "class": ["text-nowrap"] }
  ]
}
```

Minimal `TableWithConfig` usage:
```vue
<TableWithConfig table_config_id="my_table" />
```

With extra params:
```vue
<TableWithConfig
  table_config_id="my_table"
  :get_extra_params_obj="() => ({ ifid: props.context.ifid })"
/>
```

### Table sorting rules (MANDATORY)

**Always provide `f_sort_rows`** — the default fallback uses `localeCompare` on rendered HTML strings, which gives wrong order for numbers, bytes, IPs, and timestamps.

#### Step 1 — infer the sort type of every sortable column from its name/content

| Column name pattern | Sort type | Function |
|---|---|---|
| `*name*`, `*label*`, `*title*`, `*category*`, `*protocol*`, `*app*`, `*type*`, `*status*` | string | `sortingFunctions.sortByName` |
| `*ip*`, `*address*`, `*addr*`, `*src*`, `*dst*`, `*host*` | IP address | `sortingFunctions.sortByIP` |
| `*mac*` | MAC address | `sortingFunctions.sortByMacAddress` |
| `*bytes*`, `*traffic*`, `*bps*`, `*throughput*`, `*bandwidth*` | numeric | `sortingFunctions.sortByNumber` |
| `*count*`, `*num*`, `*packets*`, `*flows*`, `*hits*`, `*pps*`, `*fps*`, `*alerts*` | numeric | `sortingFunctions.sortByNumber` |
| `*time*`, `*date*`, `*seen*`, `*epoch*`, `*duration*`, `*ms*`, `*latency*` | numeric | `sortingFunctions.sortByNumber` |
| `*percent*`, `*ratio*`, `*rate*`, `*score*` | numeric | `sortingFunctions.sortByNumber` |
| anything else (unknown) | string (safe default) | `sortingFunctions.sortByName` |

`sortByName` is the safe default — it handles both plain strings and numeric strings correctly.

#### Step 2 — build the `SORT_FIELDS` map and `columns_sorting` function

```js
import { default as sortingFunctions } from "../utilities/sorting-utils.js";

// Map each column id to: { getter, sortFn }
const SORT_FIELDS = {
  name:       { getter: (r) => r.name,       fn: sortingFunctions.sortByName   },
  ip:         { getter: (r) => r.ip,         fn: sortingFunctions.sortByIP     },
  bytes:      { getter: (r) => r.bytes,      fn: sortingFunctions.sortByNumber },
  num_flows:  { getter: (r) => r.num_flows,  fn: sortingFunctions.sortByNumber },
  // ... one entry per sortable column id
};

function columns_sorting(col, r0, r1) {
  if (!col) return 0;
  const def = SORT_FIELDS[col.id];
  if (!def) return 0;
  return def.fn(def.getter(r0), def.getter(r1), col.sort);
}
```

Pass it to the component:
```vue
<TableWithConfig
  table_config_id="my_table"
  :f_sort_rows="columns_sorting"
/>
```

#### Step 3 — set `default_sort` in the JSON config

Always choose the most meaningful default sort column (usually the primary name/label or the highest-value metric):

```json
"default_sort": {
  "column_id": "name",
  "sort": 1
}
```

`sort: 1` = ascending, `sort: 2` = descending.

#### Complete example (name + numeric columns)

JSON config:
```json
{
  "id": "my_table",
  "data_url": "lua/rest/v2/get/my/data.lua",
  "paging": false,
  "enable_search": true,
  "default_sort": { "column_id": "name", "sort": 1 },
  "columns": [
    { "id": "name",      "title_i18n": "name",    "data_field": "name",      "sortable": true  },
    { "id": "bytes",     "title_i18n": "traffic",  "data_field": "bytes",     "sortable": true  },
    { "id": "num_flows", "title_i18n": "flows",    "data_field": "num_flows", "sortable": true  },
    { "id": "actions",   "title_i18n": "actions",  "sortable": false, "render_v_node_type": "button_list", "button_def_array": [] }
  ]
}
```

Vue component:
```js
import { default as sortingFunctions } from "../utilities/sorting-utils.js";

const SORT_FIELDS = {
  name:      { getter: (r) => r.name,      fn: sortingFunctions.sortByName   },
  bytes:     { getter: (r) => r.bytes,     fn: sortingFunctions.sortByNumber },
  num_flows: { getter: (r) => r.num_flows, fn: sortingFunctions.sortByNumber },
};

function columns_sorting(col, r0, r1) {
  if (!col) return 0;
  const def = SORT_FIELDS[col.id];
  if (!def) return 0;
  return def.fn(def.getter(r0), def.getter(r1), col.sort);
}
```

Import syntax is always:
```js
import { default as Loading } from "../loading.vue"; // adjust relative path
```

---

## Step 4c — Data fetching rules (MANDATORY — always follow these)

All HTTP requests in Vue components **must** use `ntopng_utility.http_request` or `ntopng_utility.http_post_request`. **Never** use `$.get`, `$.post`, `$.ajax`, or raw `fetch()`.

### Import
```js
import { ntopng_utility } from "../services/context/ntopng_globals_services.js";
```
(Adjust the relative path based on the component's location.)

### GET requests
```js
// Returns response.rsp (unwrapped). Returns null on error.
const data = await ntopng_utility.http_request(url);
```

### POST requests
```js
// params MUST include csrf. Returns response.rsp (unwrapped).
const result = await ntopng_utility.http_post_request(url, { csrf: props.context.csrf, ...other_params });
```

### Parallel requests — ALWAYS prefer this pattern

When a component needs data from **multiple endpoints**, fetch them all at once with `Promise.all`. Never chain sequential `await` calls when the requests are independent.

```js
// ✅ Correct — parallel, fast
const [users, groups, stats] = await Promise.all([
  ntopng_utility.http_request(`${http_prefix}/lua/rest/v2/get/users.lua`),
  ntopng_utility.http_request(`${http_prefix}/lua/rest/v2/get/groups.lua`),
  ntopng_utility.http_request(`${http_prefix}/lua/rest/v2/get/stats.lua`),
]);

// ❌ Wrong — sequential, slow
const users  = await ntopng_utility.http_request(url1);
const groups = await ntopng_utility.http_request(url2);
const stats  = await ntopng_utility.http_request(url3);
```

### Loading state pattern (MANDATORY for any async fetch)

Every component that fetches data must use a loading state and the `<Loading>` component so the page never appears stuck:

```vue
<template>
  <div class="position-relative">
    <Loading :isLoading="isLoading" />
    <div v-if="!isLoading">
      <!-- content -->
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from "vue";
import { ntopng_utility } from "../services/context/ntopng_globals_services.js";
import { default as Loading } from "./loading.vue";

const isLoading = ref(false);
const data = ref(null);

onMounted(async () => {
  isLoading.value = true;
  try {
    data.value = await ntopng_utility.http_request(`${http_prefix}/lua/rest/v2/get/my/data.lua`);
  } finally {
    isLoading.value = false;  // always reset, even on error
  }
});
</script>
```

### Fire-and-forget for secondary data

When a component has **primary** data (needed before anything can render) and **secondary** data (enrichments, optional sections), show the primary content immediately and load secondary data independently without blocking:

```js
onMounted(async () => {
  isLoading.value = true;
  try {
    // Primary — block render until this arrives
    primaryData.value = await ntopng_utility.http_request(primaryUrl);
  } finally {
    isLoading.value = false;
  }
  // Secondary — fire-and-forget; don't block render
  loadSecondaryData();
});

async function loadSecondaryData() {
  secondaryLoading.value = true;
  try {
    secondaryData.value = await ntopng_utility.http_request(secondaryUrl);
  } finally {
    secondaryLoading.value = false;
  }
}
```

### Summary table

| Need | Use |
|---|---|
| GET request | `ntopng_utility.http_request(url)` |
| POST request | `ntopng_utility.http_post_request(url, { csrf, ...params })` |
| Multiple independent requests | `Promise.all([...])` — always parallel |
| Block render on data | `isLoading` ref + `<Loading :isLoading="isLoading" />` |
| Optional/secondary data | fire-and-forget async function, own loading state |
| Never use | `$.get`, `$.post`, `$.ajax`, raw `fetch()` |

---

## Step 4e — Enhance UI with frontend-design plugin (if available)

If the **frontend-design plugin** is available, invoke it now to enhance the component's
visual design and layout quality. This step runs **after** reusable components have been
identified (Step 4b) and **before** the build (Step 8), so the plugin works on a
component that already has correct ntopng structure.

### Hard constraints the plugin MUST respect (non-negotiable)
These override any frontend-design plugin suggestions:

1. **No hardcoded colors** — all colors must use Bootstrap 5 semantic classes or
   ntopng CSS variables (see Step 9 variable table). The plugin must not introduce
   raw hex, RGB, or RGBA values anywhere.

2. **CSS variables must come from the scss files** — before using or adding any
   CSS variable, read both theme files:
   - `http_src/views/private/clients/white-mode.scss`
   - `http_src/views/private/clients/dark-mode.scss`

   **If the variable already exists** → use it as-is. Do not redefine it.
   **If a new variable is needed** → add it to **both** files with appropriate
   light and dark values before referencing it in the component.

3. **No custom fonts** - always use default fonts, do not overwrite fonts
3. **No custom fonts** - always use default fonts, do not overwrite fonts

4. **Always `<style scoped>`** — the plugin must not produce unscoped styles or
   global class definitions.

5. **Bootstrap 5 first** — the plugin must use Bootstrap 5 utility classes for
   layout, spacing, and typography before reaching for custom CSS.

6. **Dark/light theme awareness is automatic** — components using Bootstrap classes
   and ntopng CSS variables need no extra theme logic. The plugin must not add
   manual theme-switching JavaScript or duplicate style blocks unless a genuine
   per-theme override is required (use the `:root[data-theme]` selector pattern
   from Step 9 in that case).

7. **ntopng reusable components take priority** — the plugin must not replace
   `<Loading>`, `<NoData>`, `<TableWithConfig>`, etc. with custom re-implementations.

8. **Always use and import i18n** - components must always import and use i18n in html sections or js sections, here is how to import and use i18n in components

   **ALWAYS IMPORT i18n for text localization**
   ```js
   <script setup>

   const _i18n = (t) => i18n(t);
   </script>
   ```

   and use i18n **everywhere** as `_i18n(...)`:
   - in html/template: `{{ _i18n('loading') }}`
   - in js/script: `_i18n('request_failed_message')` — **never** call bare `i18n()` in script; TypeScript cannot resolve the runtime global and will emit warnings
   - grep available strings in `scripts/locales/en.lua` search it as "text_to_search", if not present add an entry

9. **Always format values with ntopng formatter**
   ```javascript
   import formatterUtils from "../../utilities/formatter-utils.js";
   let formatted_val = formatterUtils.getFormatter(<FORMATTER_UNIT>)(value)
   ```
   where available **FORMATTER_UNIT** is: ["no_formatting", "number","bytes", "bps", "bps_no_scale","speed","flows","fps","fps_short","alerts","alertps","hits","hitss","packets","pps","ms","drops","percentage","percentage_no_limit","ratio","date"]

10. **Always document newly created components or graphs.chart** you must always document created reusable components in `doc/developers/vue_components`

11. **Never repeat the page title inside the Vue component** — the page title is already rendered by `page_utils.print_navbar` in the Lua bootstrap. Do not add a card header, `<h1>`, `<h2>`, or any other element that duplicates the page name (e.g., "Timeseries Schema Definitions"). The Vue component starts directly with its content (table, chart, form, etc.).

### What the plugin should improve
Within the constraints above, the plugin is free to enhance:
- Layout composition and visual hierarchy
- Spacing rhythm and responsive behaviour
- Card/panel structure and shadow usage
- Icon placement and badge styling
- Empty state and loading state presentation
- Table and list aesthetics beyond the default Bootstrap baseline

---

## Step 5 — Edit ntop_vue.js

File: `http_src/vue/ntop_vue.js`

**Add import** in the correct section (match the section comment). Follow the exact style of neighboring imports:
```js
import { default as MyComponent } from "./charts/my-component.vue";
```

**Add export** in the correct `let ntopVue` block section. Follow exact style:
```js
MyComponent: MyComponent,
```

Insert at the END of the relevant section, just before the next section comment or closing brace.

---

## Step 6 — Create Lua page (only if type is 'page')

### Community version (`scripts/lua/<filename>.lua`):
```lua
--
-- (C) 2024 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local page_utils = require("page_utils")
local template_utils = require("template_utils")
local json = require("dkjson")

sendHTTPContentTypeHeader('text/html')

page_utils.print_header_and_set_active_menu_entry(page_utils.menu_entries.home)
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

local context = {
    ifid = interface.getId()
}

local json_context = json.encode(context)

template_utils.render("pages/vue_page.template", {
    vue_page_name = "PAGE_EXPORT_NAME",
    page_context  = json_context
})

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
```

### Pro version (`pro/scripts/lua/<filename>.lua`):
```lua
--
-- (C) 2024 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local page_utils = require("page_utils")
local template_utils = require("template_utils")
local json = require("dkjson")

sendHTTPContentTypeHeader('text/html')

-- Pro-only guard
if not ntop.isEnterpriseL() and not ntop.isnEdgeEnterprise() then
    return
end

page_utils.print_header_and_set_active_menu_entry(page_utils.menu_entries.home)
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

local context = {
    ifid = interface.getId(),
    csrf = ntop.getRandomCSRFValue()
}

local json_context = json.encode(context)

template_utils.render("pages/vue_page.template", {
    vue_page_name = "PAGE_EXPORT_NAME",
    page_context  = json_context
})

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
```

Replace `PAGE_EXPORT_NAME` with the actual PascalCase export name.

---

## Step 7 — Handle embedding modes (non-page types)

If the user mentioned embedding in an **existing Lua page** (mode 3.2), print this snippet for them to paste into the relevant Lua file's HTML section — do NOT modify the Lua file automatically since the insertion point is unknown:

```lua
template_utils.render("pages/vue_page.template", {
    vue_page_name = "EXPORT_NAME",
    page_context  = json.encode({
        -- add your context here
    }),
})
```

If the user mentioned embedding inside **another Vue component** (mode 3.1), add this import to the top of the target `.vue` file's `<script setup>` block:

```js
import { default as MyComponent } from "../path/to/my-component.vue";
```

(Adjust relative path based on actual file locations.)

**If the user requests BOTH a Lua page AND a Vue parent import simultaneously**, stop and tell them:
> "These are two different embedding strategies — a component can either be rendered as a standalone Lua page OR imported inside another Vue component, not both at the same time. Which do you want?"

---

## Step 8 — Validate the build

Run:
```bash
cd /home/gabriele/develop/ntopng && npm run watch &
sleep 8
kill %1 2>/dev/null
```

Check the output for errors. If there are build errors, fix them before reporting success. Common issues:
- Malformed template → fix the `<template>` block
- Bad import path → verify the file was created at the expected path
- Duplicate export name → alert the user

---

## Step 9 — Styling rules (always enforce these)

Every generated component must follow these rules. For skeletons, the `<style>` block (if present) must comply. For implementation, enforce all of them.

### Bootstrap 5 first (MANDATORY — never use Bootstrap 3/4 patterns)
- Use Bootstrap 5 utility classes for all layout, spacing, typography, and UI primitives.
- Never write custom CSS for things Bootstrap already covers (`p-*`, `m-*`, `d-flex`, `gap-*`, `text-*`, `border`, `rounded`, `shadow`, etc.).
- Prefer existing ntopng Vue components over raw Bootstrap HTML (e.g. use `<Loading>` not a hand-rolled spinner div).
- **Use `btn-group` for filter/tab selectors** — never replicate nav-tabs in a Vue component; those belong in the Lua bootstrap.
- **Use `form-switch` for boolean toggles** — `<div class="form-check form-switch"><input class="form-check-input" type="checkbox"></div>`.
- **Use `badge` for counts** — `<span class="badge bg-secondary">42</span>`.
- **Do not use jQuery** — no `$()`, `$.ajax()`, `.modal()`, `.tab()`, etc. All interactions must be Vue-native.
- **`data-toggle` / `data-dismiss` are Bootstrap 3/4** — always use `data-bs-toggle` / `data-bs-dismiss` (Bootstrap 5).

### No hardcoded colors — ever
Never use raw hex (`#FF8F00`), RGB, or RGBA values in `<style>` or inline styles. Always use one of:

1. **Bootstrap semantic classes**: `text-primary`, `text-secondary`, `bg-light`, `bg-dark`, `border-primary`, `btn-primary`, `btn-secondary`, etc. These are already overridden per-theme in ntopng's CSS.
2. **ntopng CSS variables** — always read `http_src/views/private/clients/white-mode.scss`
   and `dark-mode.scss` first to check if a variable already exists before adding a new one.
   If a new variable is genuinely needed, add it to **both** files before using it.

| Variable | Purpose |
|---|---|
| `var(--ntop-orange)` | Primary brand — buttons, active states, highlights |
| `var(--ntop-orange-light)` | Hover / lighter accent |
| `var(--ntop-orange-dark)` | Pressed / darker accent |
| `var(--ntop-blue)` | Secondary brand |
| `var(--ntop-blue-light)` | Secondary hover |
| `var(--ntop-blue-dark)` | Secondary pressed |
| `var(--ntop-text-color)` | Main body text (auto theme-aware) |
| `var(--icon-color)` | Icon fill/stroke |
| `var(--timeseries-legend-bg-color)` | Chart legend background |
| `var(--timeseries-legend-border-color)` | Chart legend border |
| `var(--loading-bg)` | Loading overlay background |
| `var(--loading-text-color)` | Loading overlay text |

### If a new color variable is needed
1. Read `http_src/views/private/clients/white-mode.scss` — check if the variable already exists.
2. Read `http_src/views/private/clients/dark-mode.scss` — check if the variable already exists.
3. Only if absent from both: add it under `:root[data-theme = 'light']` in white-mode.scss
   and the matching selector in dark-mode.scss with appropriate values.
4. Then reference it in the component.

### Dark/light theme awareness
Components using Bootstrap classes and the ntopng variables above are automatically theme-aware — no extra work needed. If you need a theme-specific CSS override in `<style scoped>`:
```css
:root[data-theme='light'] .my-element { color: var(--ntop-text-color); }
:root[data-theme='dark']  .my-element { color: var(--ntop-text-color); }
```

### D3 / SVG charts specifically
- Axis labels and tick text: `fill: var(--ntop-text-color)`
- Primary data series: `var(--ntop-orange)`
- Secondary data series: `var(--ntop-blue)`
- Tooltips: apply class `.d3-tooltip` (already defined in `dark-mode.scss`) — do not create a new tooltip style.

### `<style>` block rules
- Always use `<style scoped>`.
- Keep it minimal — prefer Bootstrap utility classes in the template.
- Do not import or define color palettes inline.

---

## Step 10 — Report to the user

Summarize:
- File(s) created (with paths)
- `ntop_vue.js` updated (import + export in which section)
- Lua page created (if applicable) and URL to access it (`/lua/my_page.lua` or `/lua/pro/my_page.lua`)
- Reusable components used (if any)
- frontend-design plugin invoked (yes / not available)
- Any new CSS variables added to white-mode.scss and dark-mode.scss
- Build status (clean or errors found and fixed)