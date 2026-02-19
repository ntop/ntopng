# ntopng UI Architecture

ntopng uses a **hybrid rendering model**: Lua handles server-side page rendering and exposes REST API endpoints, while Vue 3 powers the interactive UI components. The long-term goal is to migrate fully to Vue 3 SPA.

---

## Directory Structure

```
http_src/               # Vue 3 source (compiled → httpdocs/dist/)
├── vue/                # Page-level Vue SFCs (.vue files)
│   └── ntop_vue.js     # Registry: maps component names → Vue SFC exports
├── components/         # Reusable sub-components (charts, widgets, DataTable)
├── services/           # Global services (URL manager, event bus, etc.)
├── utilities/          # Formatters, validators, DataTable helpers
├── constants/          # Shared constants
└── ntopng.js           # Main JS entry point

httpdocs/               # Web root served by ntopng's built-in HTTP server
├── dist/               # Compiled assets (DO NOT edit manually)
│   ├── ntopng.js       # Main Vue bundle (output of build)
│   ├── vendor-*.js     # Split vendor chunks (Vue, DataTables, charts…)
│   └── *.css           # Compiled CSS (dark/white/custom themes)
└── templates/
    ├── pages/
    │   └── vue_page.template   # Generic Lua template that mounts a Vue component
    └── widgets/                # Reusable Lua widget templates
```

---

## How a Page is Rendered

### 1. Lua script runs server-side

A Lua file (e.g. `scripts/lua/alert_stats.lua`) handles the HTTP request. It:
- Authenticates the user and checks permissions
- Gathers any initial data needed by the page
- Encodes a **context object** as JSON

```lua
local context = {
  ifid = interface.getId(),
  -- other initial data…
}
local json_context = json.encode(context)
```

### 2. Lua renders `vue_page.template`

The Lua script delegates HTML rendering to the shared Vue template:

```lua
template_utils.render("pages/vue_page.template", {
  vue_page_name = "PageAlertStats",   -- must match a key in ntop_vue.js
  page_context  = json_context        -- JSON passed verbatim to the browser
})
```

The template emits a thin HTML shell containing the mount point and a bootstrap script:

```html
<div id="PageAlertStats" style="position: relative">
  <page-vue :context="context"></page-vue>
</div>

<script>
  $(function () {
    // ntopVue is the global object built from ntop_vue.js
    start_vue("PageAlertStats", ntopVue["PageAlertStats"], /* JSON context */);
  });
</script>
```

### 3. Browser mounts the Vue component

`start_vue()` (defined inside `vue_page.template`) creates a Vue 3 app and mounts the named component onto the `<div>`. The JSON context is passed as the `context` prop.

`ntopVue` is populated by `http_src/vue/ntop_vue.js`, which explicitly imports and re-exports every page component:

```js
// http_src/vue/ntop_vue.js
import { default as PageAlertStats } from "./page-alert-stats.vue";
// … all other page components …

export { PageAlertStats, /* … */ };
```

### 4. Vue component fetches data via REST

Once mounted, the component calls Lua-backed REST endpoints for live data:

```js
// inside page-alert-stats.vue
const response = await ntop_utils.http_request(
  `/lua/rest/v2/get/alert/top.lua?ifid=${props.context.ifid}`
);
```

REST endpoints live in `scripts/lua/rest/v2/<verb>/<entity>/<resource>.lua` and always return:

```json
{ "rc": 0, "rc_str": "OK", "rsp": { /* payload */ } }
```

---

## Adding a New Vue Page

1. **Create the Vue SFC** at `http_src/vue/page-my-feature.vue`.
2. **Register it** in `http_src/vue/ntop_vue.js`:
   ```js
   import { default as PageMyFeature } from "./page-my-feature.vue";
   export { /* existing… */ PageMyFeature };
   ```
3. **Create the Lua endpoint** at `scripts/lua/my_feature.lua`:
   ```lua
   local context    = { ifid = interface.getId() }
   local json_context = json.encode(context)
   template_utils.render("pages/vue_page.template", {
     vue_page_name = "PageMyFeature",
     page_context  = json_context
   })
   ```
4. **Rebuild the frontend** (see Build section below).
5. **Access the page** via the Lua URL, e.g. `/lua/my_feature.lua`.

### Accessing `context` inside the Vue component

```js
// page-my-feature.vue <script setup>
const props = defineProps({ context: Object });
const ifid = props.context.ifid;
```

---

## Build System

Three bundlers are used (in practice, `build:ntopngjs` is the common daily command):

| Command | What it does |
|---|---|
| `npm run watch` | Vite/Rollup dev watch — rebuilds on save |
| `npm run build:ntopngjs` | Production build of Vue bundle only (fast) |
| `npm run build` | Full build: webpack (CSS/assets) + Rollup/Vite (JS) |

Output always goes to `httpdocs/dist/`. **Commit `httpdocs/dist/` changes** — the compiled assets are tracked in git.

---

## Key Conventions

| Topic | Detail |
|---|---|
| **i18n** | Strings live in `scripts/locales/en.lua`. In Vue use `i18n("key")` in `<script setup>` and `_i18n("key")` in `<template>`. |
| **HTTP requests** | Use `ntop_utils.http_request(url)` — it handles CSRF tokens automatically. |
| **URL state** | Use `ntopng_url_manager` from `http_src/services/context/ntopng_globals_services.js`. |
| **Parameter validation** | All query parameters that reach Lua must be declared in `scripts/lua/modules/http_lint.lua`. |
| **Navbar** | Sections defined in `page_utils.menu_sections`, entries in `page_utils.menu_entries` (`scripts/lua/modules/page_utils.lua`). |
| **REST format** | Responses always wrap payloads: `{ rc, rc_str, rsp }`. Use `rest_utils.answer(rc, payload)`. |

---

## Data Flow Summary

```
Browser
  │  GET /lua/my_feature.lua
  ▼
Lua script
  │  builds context JSON → calls template_utils.render("vue_page.template", …)
  ▼
HTML response
  │  <div id="PageMyFeature"> + ntopng.js (Vue bundle)
  ▼
Browser JS (jQuery ready)
  │  start_vue("PageMyFeature", ntopVue["PageMyFeature"], contextJSON)
  ▼
Vue 3 app mounted
  │  component calls REST APIs for live data
  ▼
Lua REST endpoint (/lua/rest/v2/…)
  │  returns { rc, rc_str, rsp }
  ▼
Vue reactive UI updates
```

---

## Migration Path to Full Vue SPA

The current hybrid model exists because many pages are still pure Lua HTML. The planned migration is:

1. All new pages are Vue SFCs (already the norm).
2. Lua pages are gradually replaced by Vue components served from a single Lua shell.
3. Eventually a Vue Router SPA replaces individual Lua URL endpoints, with Lua reduced purely to REST API server.

In the interim, both styles coexist: older pages are pure Lua HTML, newer ones use `vue_page.template`.

---

## Further Reading

- [Build & install](../README.frontend.md)
- [GUI quickstart](README.GUI.quickstart.md)
- [URL manager utility](README.GUI.ntopng_utility_js.md)
- [Adding preferences](README.add_new_pref.md)
- [Adding startup params](README.Add_startup_param.md)git 
