# ntopng Porting Knowledge Base

Auto-maintained by ntop-lua-to-vue-porter and ntop-rest-endpoint-scaffolder skills.
Do not edit the structure of section headers — skills grep by exact header name.
Free to add entries manually following the existing format.
To see documented components see: `doc/developers/vue_components`
Last updated: <!-- skills update this line -->

---

## Module Functions

> Format: `module_name.function_name(params) → return_type` — one-line description
> Source: `scripts/lua/modules/<module>.lua` or `pro/scripts/lua/modules/<module>.lua`

<!-- MODULES:START -->
<!-- MODULES:END -->

---

## Module Functions

> Format: `module_name.function_name(params) → return_type` — one-line description
> Source: `scripts/lua/modules/<module>.lua` or `pro/scripts/lua/modules/<module>.lua`

<!-- MODULES:START -->

### checks module (`scripts/lua/modules/checks.lua`)
- `checks.getConfigset() → table` — returns the active configset (all script configs)
- `checks.getFactoryConfig() → table` — returns factory-default configset
- `checks.listSubdirs() → [{id, label}]` — all valid check subdirs (host, flow, interface, network, snmp_device, system, active_monitoring, syslog, as)
- `checks.getScriptType(subdir) → script_type | nil` — maps subdir string to internal type; returns nil for invalid subdirs
- `checks.load(ifid, script_type, subdir, opts) → {modules={}}` — loads all scripts for a subdir; opts: `{return_all=true}` includes disabled scripts too
- `checks.loadModule(ifid, script_type, subdir, script_key) → script | nil` — loads a single script module
- `checks.getScriptConfig(config_set, script, subdir) → {[hook]={enabled, script_conf}}` — per-hook config for a script
- `checks.toggleScript(script_key, subdir, enable) → ok, err` — enable/disable a single check
- `checks.updateScriptConfig(script_key, subdir, data) → ok, err` — save new hook config for a script
- `checks.getScriptEditorUrl(script) → url_path` — path to the check's source editor page
- `checks.check_categories → {[key]={i18n_title, i18n_descr, icon}}` — category metadata table
- `getSystemInterfaceId() → number` — returns the system interface id (lua_utils global)

### checks_utils module (`scripts/lua/modules/checks_utils.lua`)
- `checks_utils.load_configset_titles() → {[subdir]=title}` — localized hook titles keyed by subdir

### alert_consts module (`scripts/lua/modules/alert_consts.lua`)
- `alert_consts.alerts_granularities → {[hook]={i18n_title, ...}}` — maps hook keys (min, 5mins, hour, day) to granularity info
- `alert_consts.alertSeverityById(severity_id) → {i18n_title, icon} | nil` — severity metadata from numeric id

### auth module (`scripts/lua/modules/auth.lua`)
- `auth.has_capability(auth.capabilities.checks) → bool` — checks user has checks capability
- `auth.capabilities` — table of capability keys: `checks`, `alerts`, ...

<!-- MODULES:END -->

---

## Ported Page Patterns

> Format: entries record what worked well during a port — reusable patterns,
> prop structures, TableWithConfig column shapes, REST shapes that paired well
> with a Vue component. Grep by Lua filename or Vue component name.

<!-- PATTERNS:START -->

### edit_configset.lua → PageEditConfigset (2026-03-18)

**Lua**: `scripts/lua/admin/edit_configset.lua`
**Vue**: `http_src/vue/page-edit-configset.vue`
**REST (GET)**: `scripts/lua/rest/v2/get/checks/list.lua` — accepts `check_subdir` (all | host | flow | …), `ifid`, `status` (all | enabled | disabled)
**REST (POST toggle)**: `scripts/lua/rest/v2/toggle/checks/batch.lua` — accepts `check_subdir`, `script_keys` (JSON array), `enabled`
**Table config**: `httpdocs/tables_config/edit_configset.json`

**Context props passed from Lua**:
```lua
{
  check_subdir = subdir,   -- "all" | "host" | "flow" | ...
  ifid         = interface.getId(),
  page_csrf    = ntop.getRandomCSRFValue(),
}
```

**Column rendering patterns**:
- Category column: `render_func` in `f_map_columns` — renders `<i class="icon"></i> translated_label` HTML from `row.category_icon` + `i18n(row.category_key)`
- Severity column: same pattern as category using `row.severity_icon` + `i18n(row.severity_key)`
- Enabled toggle: `render_v_func` in `f_map_columns` — renders Bootstrap 5 `form-check form-switch` via `vue_obj.h(...)`, emits `custom_event` with `event_id: "toggle_check"`
- Subdir column: hidden (`.visible = false`) when `check_subdir !== 'all'`

**Filter pattern (status tabs)**:
- Vue: Bootstrap 5 `btn-group` (not `nav-tabs`) with All/Enabled/Disabled buttons + count badges
- Changing the status tab calls `table_ref.value.update()` to re-fetch with new `status` URL param
- `@rows_loaded` event updates counts for badge display

**Batch operations**:
- "Disable all visible" button calls batch toggle endpoint with all keys from `@rows_loaded`
- Factory reset only shown when `check_subdir === 'all'`; calls `set/checks/config.lua` POST then re-fetches

**i18n rule** (enforced in this port):
- `_i18n('key')` in `<template>` HTML
- `i18n('key')` in `<script setup>` JS code
- `const _i18n = (t) => i18n(t)` declared at top of every `<script setup>`

<!-- PATTERNS:END -->

---

## REST Endpoint Conventions

> Format: entries record discovered conventions, path decisions, param names,
> and any non-obvious behaviour found in existing v2 endpoints.

<!-- REST:START -->

### checks/* endpoints
- `GET /lua/rest/v2/get/checks/list.lua` — list of checks for a subdir; `check_subdir=all` aggregates all subdirs. Returns array of `{key, subdir, title, description, category_key, category_icon, severity_key, severity_icon, is_enabled, edit_url}`.
- `GET /lua/rest/v2/get/checks/subdirs.lua` — returns `{checks_subdirs: [id, ...]}`.
- `GET /lua/rest/v2/get/ntopng/checks.lua` — different endpoint: returns runtime stats (hooks, filters, exec_time_ms) for the checks overview table. Not the same as list.lua.
- `POST /lua/rest/v2/toggle/checks/batch.lua` — batch enable/disable; POST body: `check_subdir`, `script_keys` (JSON array), `enabled` ("true"/"false"), `csrf`. Returns `{results: [{key, success, error?}]}`.
- `POST /lua/rest/v2/enable/check.lua` and `disable/check.lua` — single-check toggle (legacy single endpoints); POST: `check_subdir`, `script_key`.

### Legacy (non-v2) check endpoints still in use
- `GET /lua/get_checks.lua` — legacy, uses `print(json.encode(...))` not `rest_utils.answer`. Do not call from Vue.
- `GET /lua/get_check_config.lua` — per-script config detail for the edit modal. Not yet ported.
- `POST /lua/edit_check_config.lua` — save per-script config. Not yet ported.
- `POST /lua/set/checks/config.lua` — import/factory-reset of full config. Uses `_POST["JSON"]`.

### v2 endpoint output rules (summary)
- Always end with `rest_utils.answer(rc, result)`.
- Translated strings (i18n) are allowed **only** when the key is dynamic and unknown to the frontend (e.g., check title/description come from module GUI config — key varies per module). Pass translated value in that case.
- Static i18n keys (severity, category labels whose keys are passed as `*_key` fields) must NOT be pre-translated: pass the key and let `i18n(key)` run in the Vue component.

<!-- REST:END -->