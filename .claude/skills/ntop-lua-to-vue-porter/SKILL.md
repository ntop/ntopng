---
name: ntop-lua-to-vue-porter
description: >
  Ports legacy ntopng Lua pages to the modern Vue.js + REST stack. Use this skill
  whenever the user references an existing Lua page path and wants to migrate,
  port, refactor, convert, or modernize it. Triggers on phrases like "port /lua/X.lua
  to Vue", "refactor /lua/X.lua", "modernize /lua/X.lua", "migrate this Lua page",
  or "convert /lua/X.lua to the new stack". Does NOT fire for creating brand-new
  Vue pages with no Lua counterpart (use ntop-vue-scaffold instead), for editing
  already-ported Vue components, or for standalone REST endpoint work with no page.
user-invocable: true
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# ntop Lua → Vue Porter

Ports a legacy ntopng Lua page to the modern Vue.js + REST stack. Produces four
artifacts per run: an archived original file, a new minimal Lua bootstrap, a Vue
component, and refactored REST endpoint(s).

---

## STOP IMMEDIATELY and ask if any of these are missing

- **No Lua file path given** → ask: "What is the path to the Lua page you want to port? (e.g., `/lua/license.lua`)"

---

## Step 0 — Read and archive the original file

1. Read the full Lua file at the given path.
2. **Move it to the attic** — write its content verbatim to `attic/<original_path>`, mirroring the full path from the repo root. For example:
   - `scripts/lua/checks_overview.lua` → `attic/scripts/lua/checks_overview.lua`
   - `scripts/lua/admin/users.lua` → `attic/scripts/lua/admin/users.lua`
   Use the Write tool to create the attic copy, then overwrite the original in Step 3 (the original path is reused for the new bootstrap). **Do not rename or add any suffix** — the filename stays identical, only the directory changes to `attic/`.
3. Check whether an attic copy already exists at that path before writing. If it does, warn the user and ask before overwriting.
4. Scan the file and collect:
   - All REST endpoint paths referenced (patterns: `/lua/rest/`, `/lua/modules/`)
   - All `_GET` and `_POST` parameters consumed
   - All `ntop.getCache(...)` and `ntop.get*()` calls
   - All `interface.getId()` or `interface.select()` calls
   - All conditional rendering guards: `ntop.isPro()`, user role checks, feature flags
   - The active menu entry passed to `print_header_and_set_active_menu_entry`
   - Whether `print_navbar` is called and with what tabs/entries
   - If `print_page_title` is present — note it; it will be replaced by `print_navbar`

---

## Step 1 — Audit REST endpoints

For each REST endpoint path discovered:

1. Read the file at that path.
2. Check whether it already uses `rest_utils.answer(rc, res)` as its final response.
3. Check whether it returns **any HTML** in its response payload (inline tags, class attributes, color strings, translated label strings).
4. If it passes the audit (uses rest_utils, returns clean JSON) → leave it untouched, note it as ✅.
5. If it fails → refactor it:
   - Keep all business logic and data-fetching intact.
   - Replace any HTML construction with plain values.
   - Remove hardcoded color strings — the frontend handles colors via `color-utils.js`.
   - Remove translated label strings — the frontend handles i18n via `i18n()`.
   - URLs are acceptable as values (the frontend uses `http_prefix` as base).
   - Ensure the file ends with `rest_utils.answer(rc, res)`.
   - Overwrite the file in place (the attic copy already preserves the old state).

### REST output rules (strictly enforced)
| ✅ Allowed in REST response | ❌ Never in REST response |
|---|---|
| Numbers, booleans, timestamps | HTML tags or fragments |
| Raw string identifiers / keys | CSS color strings (`#ff0000`, `rgb(...)`) |
| URLs (path strings) | Translated label strings |
| Nested objects and arrays | Inline `style=` or `class=` attributes |

---

## Step 2 — Build the Vue component

Invoke the **ntop-vue-scaffold** skill to create the Vue component. Pass it:

- The component name derived from the Lua filename (e.g., `license.lua` → `PageLicense`)
- The Lua filename for reference
- The full list of props that will arrive in `context` (see Step 3)

If the **frontend-design plugin** is available, invoke it when styling the component
to ensure polished, production-grade UI rather than generic scaffolding. Apply its
directives on top of ntop-vue-scaffold's output — do not skip ntop-vue-scaffold in
favour of frontend-design; both must run.

Follow all directives in the ntop-vue-scaffold skill and any other active UI plugin skills.

### Vue component rules
- All display strings go through `i18n()` — never hardcode labels.
- The JS `i18n()` global is a plain key lookup — it does **not** interpolate `%{key}` placeholders. When a string requires substitution, write a local helper and perform the replacement manually (e.g. `str.replace(/%\{key\}/g, value)`).
- All colors come from `color-utils.js` at `http_src/utilities/color-utils.js`.
  Import as: `import colorUtils from "../utilities/color-utils.js"`
  Use `colorUtils.assignRoundRobinColors(labels)` for charts, `colorUtils.assignColors(names)` for node-based coloring.
- All base URLs are constructed with `http_prefix` (the global ntopng prefix).
- Receive all server-side state through `props.context` — never call `_GET`, `_POST`, or `ntop.*` from Vue.
- If the old Lua page had conditional rendering (e.g., hide a chart column when timeseries are disabled), pass the condition as a boolean prop and handle it in Vue with `v-if` / `:class`.

---

## Step 3 — Write the new Lua bootstrap page

Replace the original Lua file content with a minimal bootstrap. **Always use
`page_utils.print_navbar` — never `print_page_title`.** The title lives inside
the navbar call; do not emit it anywhere else.

### `print_navbar` signature

```lua
page_utils.print_navbar(title, base_url, tabs)
```

| Argument | Type | Description |
|---|---|---|
| `title` | string | Page title — use `i18n("…")` |
| `base_url` | string | Canonical URL for the page, used for tab links — `ntop.getHttpPrefix() .. "/lua/<page>.lua"` |
| `tabs` | array of tab objects | At least one tab required |

**Tab object fields:**

| Field | Type | Description |
|---|---|---|
| `hidden` | bool | Hide this tab (e.g. `not ntop.isPro()`) |
| `active` | bool | Highlight as current tab — typically `page == "tabname" or page == nil` for the default tab |
| `page_name` | string | Value appended as `?page=<page_name>` in the URL |
| `label` | string | Tab label; may contain HTML, e.g. `"<i class=\"fas fa-home\"></i>"` or `i18n("…")` |

**Minimal single-tab example (overview-only page):**

```lua
page_utils.print_navbar(i18n("about.directories"), ntop.getHttpPrefix() .. "/lua/directories.lua", {
  {
    active    = true,
    page_name = "overview",
    label     = i18n("overview"),
  }
})
```

**Multi-tab example:**

```lua
local page = _GET["page"]

page_utils.print_navbar(i18n("license_page.license"), ntop.getHttpPrefix() .. "/lua/license.lua", {
  {
    active    = page == "overview" or page == nil,
    page_name = "overview",
    label     = "<i class=\"fas fa-lg fa-home\"></i>",
  },
  {
    hidden    = not ntop.isPro(),
    active    = page == "details",
    page_name = "details",
    label     = i18n("details"),
  },
})
```

### Full bootstrap template

```lua
--
-- (C) <year> - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "ntop_utils"  -- include only if used

local page_utils     = require "page_utils"
local json           = require "dkjson"
local template_utils = require "template_utils"
local page           = _GET["page"]

sendHTTPContentTypeHeader('text/html')

page_utils.print_header_and_set_active_menu_entry(page_utils.menu_entries.<ENTRY>)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

page_utils.print_navbar(i18n("<title_key>"), ntop.getHttpPrefix() .. "/lua/<page>.lua", {
  {
    active    = page == "overview" or page == nil,
    page_name = "overview",
    label     = "<i class=\"fas fa-lg fa-home\"></i>",
  },
  -- add further tabs here as needed; set hidden = true to suppress pro-only tabs
})

local context = {
  -- _GET / _POST params consumed by the old page
  -- <param> = _GET["<param>"],

  -- feature flags and conditional rendering guards
  -- show_<feature> = <condition_function>(interface.getId()),

  -- cache values needed by the page
  -- <key> = ntop.getCache('<cache.key>'),

  -- pro/enterprise guards
  -- is_pro = ntop.isPro(),
}

local json_context = json.encode(context)

template_utils.render("pages/vue_page.template", {
  vue_page_name = "Page<ComponentName>",
  page_context  = json_context
})

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
```

Fill in every placeholder from the audit in Step 0. Include `ifid = interface.getId()`
in `context` only if the page uses interface-scoped data. Do not add any params or
flags that were not present in the original file.

---

## Step 3.5 — Register the component in ntop_vue.js

Every new Vue page component **must** be registered in `http_src/vue/ntop_vue.js` before it can be mounted. This file is the single registry — if a component is missing here, the Lua bootstrap's `template_utils.render("pages/vue_page.template", { vue_page_name = "PageFoo" })` call will silently fail to find the component.

Two edits are required:

**1. Import** — add near the other page imports (alphabetical order preferred):
```js
import { default as PageFoo } from "./page-foo.vue"
```

**2. Export** — add to the `ntopVue` object under the `// pages` section:
```js
PageFoo: PageFoo,
```

Always do both edits in the same pass. Never leave a component imported but not exported, or vice versa.

---

## Step 4 — Final checklist

Before finishing, verify:

- [ ] `attic/<original_path>` exists and is byte-for-byte identical to the original
- [ ] New `<original>.lua` renders the Vue component and passes all required context props
- [ ] Every `_GET`/`_POST` param and `ntop.*` value consumed by the old page is in `context`
- [ ] All REST endpoints return clean JSON only (no HTML, no colors, no labels)
- [ ] Vue component uses `i18n()` for all strings
- [ ] Vue component uses `colorUtils` for all color assignment
- [ ] Vue component uses `http_prefix` for all URL construction
- [ ] Bootstrap uses `print_navbar` — never `print_page_title`
- [ ] Component is imported **and** exported in `http_src/vue/ntop_vue.js`

---

## Edge cases

| Situation | Handling |
|---|---|
| REST endpoint already uses `rest_utils` but returns HTML | Refactor output only; preserve all logic |
| REST endpoint does not exist (logic was inline in Lua) | Scaffold a new REST endpoint at an appropriate `/lua/rest/v2/get/...` path and note it to the user |
| Multiple REST endpoints in one page | Audit and refactor each one independently |
| `ntop.isPro()` or role guards gate entire sections | Pass as boolean props (`is_pro`, `is_admin`, etc.) and use `v-if` in Vue |
| Vue component name already exists | Follow ntop-vue-scaffold conflict detection — stop and notify the user |
| Page uses `print_page_title` | Replace it with `print_navbar` — `print_page_title` is outdated and must not appear in ported pages |
| `attic/<original_path>` already exists from a previous run | Warn the user and ask before overwriting |
| Page has internal tab navigation (not Lua navbar) | User may request "do not put navbar" when the Vue component handles tabs itself via Bootstrap nav-tabs inside the component. In that case omit `print_navbar` from the bootstrap and include `activeTab` state inside the Vue component. |

---

## Project-specific knowledge (ntopng codebase)

These findings were collected during actual porting runs. Read them before exploring the codebase — they prevent redundant file reads.

### Component registry (MANDATORY for every new page)

- File: `http_src/vue/ntop_vue.js`
- Add an `import { default as PageFoo } from "./page-foo.vue"` line near the other page imports
- Add `PageFoo: PageFoo,` to the `ntopVue` object under `// pages`
- Both steps are required — missing either causes the Lua bootstrap to silently fail

### Vue page mount

- Template: `httpdocs/templates/pages/vue_page.template`
- Mount call: `template_utils.render("pages/vue_page.template", { vue_page_name = "Page<Name>", page_context = json.encode(context) })`
- Component key in ntopVue registry must match `vue_page_name` exactly (PascalCase, e.g. `PageManageData`)

### Vue component conventions

- All components live in `http_src/vue/page-*.vue` (kebab-case filenames)
- `<script setup>` with Composition API (Vue 3) is the standard
- Import global services: `import { ntopng_utility } from "../services/context/ntopng_globals_services"`
- HTTP requests: `ntopng_utility.http_request(url, { method, headers, body })`
- i18n global: `i18n(key)` — does NOT interpolate `%{key}`. Use a local helper:
  ```js
  function _i18n(key, params) {
    let str = i18n(key);
    if (!str) return key;
    if (params) {
      for (const [k, v] of Object.entries(params)) {
        str = str.replace(new RegExp(`%\\{${k}\\}`, "g"), v);
      }
    }
    return str;
  }
  ```
- URL prefix: always use the global `http_prefix` (e.g. `${http_prefix}/lua/rest/...`)
- CSRF: pass `ntop.getRandomCSRFValue()` in context and include it in POST bodies as `csrf`

### Available reusable Vue modal components

| File | Usage |
|---|---|
| `modal-delete-confirm.vue` | Generic delete confirmation. Props: `title`, `body`. Event: `@delete`. Ref method: `.show(body?, title?)` |
| `modal.vue` | Base modal shell used by all modals |
| `loading.vue` | Full-overlay spinner. Prop: `:isLoading` |

### REST endpoint patterns

- All REST endpoints live under `scripts/lua/rest/v2/{get,set,delete,add}/`
- Every endpoint must end with `rest_utils.answer(rc, res)` — never `print()`
- Auth check pattern: `if not isAdministrator() then rest_utils.answer(rest_utils.consts.err.not_granted); return end`
- Read params from `_GET["key"]` (GET) or `_POST["key"]` (POST)
- Error constants: `rest_utils.consts.err.not_granted`, `.invalid_interface`, `.invalid_args`, `.internal_error`
- Success constant: `rest_utils.consts.success.ok`

### Export / file-download endpoints

- `do_export_data.lua` is a direct GET download (sets `Content-Disposition: attachment`). Trigger it from Vue with `window.location.href = url` — do **not** call it via `ntopng_utility.http_request`.
- Build the URL with `new URLSearchParams({ ifid, mode, ... })`.

### Host autocomplete

- Endpoint: `GET /lua/rest/v2/get/host/find.lua?query=<q>&hosts_only=true`
- Response shape: `{ rsp: { results: [ { ip, name, ... }, ... ] } }`
- Suggestions contain `ip` (possibly with `@vlan` suffix) and optional `name`

### Common context props

| Prop | Lua source |
|---|---|
| `ifid` | `interface.getId()` |
| `ifname` | global `ifname` |
| `product` | `ntop.getInfo().product` |
| `csrf` | `ntop.getRandomCSRFValue()` |
| `is_admin` | `isAdministrator()` |
| `is_pro` | `ntop.isPro()` |
| `is_edge` | `ntop.isnEdge()` |
| `has_clickhouse` | `interfaceHasClickHouseSupport()` (from `check_redis_prefs` module) |
| `delete_active_interface_requested` | `delete_data_utils.delete_active_interface_data_requested(ifname)` |

### Module locations

| Module | Path |
|---|---|
| `delete_data_utils` | `scripts/lua/modules/delete_data_utils.lua` |
| `page_utils` | `scripts/lua/modules/page_utils.lua` |
| `template_utils` | `scripts/lua/modules/template_utils.lua` |
| `rest_utils` | `scripts/lua/modules/rest_utils.lua` |
| `json` / `dkjson` | built-in, `require "dkjson"` |

### Tab templates (legacy, do not re-use in new Vue pages)

Legacy tab content lives in `httpdocs/templates/pages/tabs/<page>/`. These are rendered by old `.template` files and should not be referenced from new Vue components.