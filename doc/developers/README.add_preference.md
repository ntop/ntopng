# Adding a New Preference

This document describes every file to touch and every field available when adding a new user-configurable preference to the ntopng preferences system.

---

## Files to modify

| File | Purpose |
|------|---------|
| `scripts/lua/modules/prefs_menu_schema.lua` | **Primary**: defines sections and entries served by the REST schema endpoint |
| `scripts/locales/en.lua` (and other locales) | i18n strings for `title`, `description`, section `label` |
| `http_src/vue/pref-field.vue` | Vue renderer — extend only when adding a new `type` |
| `http_src/vue/page-preferences.vue` | Shell/layout — rarely touched |
| `scripts/lua/rest/v2/set/ntopng/preferences.lua` | POST handler — extend only for special validation or side-effects |

The REST schema endpoint is `GET /lua/rest/v2/get/ntopng/prefs_schema.lua`, which calls `prefs_menu_schema.lua` and returns all sections as JSON.  
The save endpoint is `POST /lua/rest/v2/set/ntopng/preferences.lua` with body `pref_section`, `pref_key`, `pref_value`.

---

## Section definition

Sections are pushed onto the `sections` array at the top level:

```lua
sections[#sections + 1] = {
    id          = "my_section",          -- unique string, becomes URL hash
    label       = i18n("prefs.my_label"),
    advanced    = false,                 -- hidden unless Expert View is on
    pro_only    = false,                 -- locked for Community users
    hidden      = false,                 -- boolean, can be a runtime expression
    entries     = { ... }               -- array of entry tables (see below)
}
```

### Section fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | yes | Unique identifier; used as URL hash (`#my_section`) |
| `label` | string | yes | Displayed in the sidebar nav |
| `advanced` | bool | yes | If `true`, section is hidden until Expert View is toggled on |
| `pro_only` | bool | yes | If `true`, section is locked with a crown badge for Community editions |
| `hidden` | bool/expr | yes | Hides the section entirely (not even shown locked); use for feature-flag conditions |
| `entries` | array | yes | One or more entry tables |

---

## Entry definition (common fields)

Every entry inside `entries` shares these fields:

```lua
{
    key         = "my_pref_key",                      -- unique within the section
    title       = i18n("prefs.my_pref_title"),
    description = i18n("prefs.my_pref_description"),  -- optional but recommended
    type        = "toggle",                            -- see Types below
    redis_key   = "ntopng.prefs.my_pref",             -- Redis key where value is stored
    default     = "0",                                 -- string, always
    hidden      = false,                               -- hide this entry (not the section)
    section     = i18n("prefs.group_label"),           -- optional: renders a group header above this entry
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `key` | string | yes | Unique within the section; used as the POST `pref_key` |
| `title` | string | yes | Bold label shown to the user |
| `description` | string | no | Muted subtitle below the title; supports HTML |
| `type` | string | yes | Control type — see **Types** below |
| `redis_key` | string | yes | Full Redis key path (e.g. `ntopng.prefs.foo`) |
| `default` | string | yes | Always a string, even for numbers/booleans |
| `hidden` | bool/expr | no | Hides this individual entry |
| `section` | string | no | Inserts a group-label divider above this entry in the UI |

---

## Types

### `toggle` — Boolean switch

```lua
type        = "toggle",
default     = "0",
on_value    = "1",    -- optional, default "1"
off_value   = "0",    -- optional, default "0"
```

Use `on_value`/`off_value` to invert logic (e.g. a "disable" toggle stores `"0"` when ON):

```lua
on_value    = "0",
off_value   = "1",
```

**Visibility gating** — when a toggle controls whether sibling entries are shown:

```lua
to_switch       = {"key_a", "key_b"},   -- keys to show when this toggle is ON
reverse_switch  = true,                 -- optional: show them when toggle is OFF instead
```

---

### `input` — Text / Number / Password

```lua
type        = "input",
input_type  = "text",     -- "text" | "number" | "password"
default     = "",
attrs       = {           -- any HTML input attributes
    min       = "0",
    max       = "9999",
    maxlength = "128",
    pattern   = "[a-z]+",
    spellcheck = "false",
},
```

#### Unit label (static suffix)

Appends a plain text badge after the input box:

```lua
unit = "MB",    -- any string, e.g. "GB", "files", "%"
```

#### Formatted unit selector (tformat)

Replaces the static unit with a set of toggle buttons that convert to/from the raw stored value.  
The stored value is always the base unit (seconds for time, bytes for size).

```lua
tformat = "mhd",   -- any combination of the characters below
```

**Time characters** (stored as seconds):

| Char | Label | Factor |
|------|-------|--------|
| `s`  | Sec   | 1 |
| `m`  | Min   | 60 |
| `h`  | Hours | 3600 |
| `d`  | Days  | 86400 |

**Byte characters** (stored as bytes):

| Char | Label | Factor |
|------|-------|--------|
| `m`  | MB    | 1 048 576 |
| `g`  | GB    | 1 073 741 824 |

Examples:

```lua
tformat = "hd"    -- Hours / Days selector (value in seconds)
tformat = "mhd"   -- Min / Hours / Days selector (value in seconds)
tformat = "mg"    -- MB / GB selector (value in bytes)
```

The UI picks the largest unit that divides the stored value evenly.  
`attrs.min` is always the raw base-unit value (bytes or seconds); the UI converts it to the display unit automatically.

#### Connectivity test button

Adds a "Test" button that GETs the endpoint and shows success/failure inline:

```lua
test_endpoint = "/lua/rest/v2/get/ntopng/test_url_connectivity.lua",
-- optional: extra sibling field values to pass as query params
test_params   = { username = "my_user_key", password = "my_password_key" },
```

The current field value is always sent as `url`. `test_params` maps query-param names to sibling `key` names in the same section.

#### Client-side validator

```lua
validator = "ipAddress",   -- "ipAddress" | "ipv4" | "mac" | "network"
```

---

### `select` — Dropdown

```lua
type    = "select",
default = "rrd",
options = {{
    value = "rrd",
    label = "RRD"
}, {
    value = "influxdb",
    label = "InfluxDB"
}},
```

Can also use `to_switch` to show/hide sibling entries based on the selected value (shows entries whose keys are listed when the value equals the option's `value` — handled server-side in schema conditionals or client-side via toggle logic).

---

### `button_group` / `resolution` — Segmented control

Mutually exclusive buttons, same semantic as `select` but rendered inline:

```lua
type    = "button_group",   -- or "resolution" (alias)
default = "normal",
options = {{
    value = "low",    label = "Low"
}, {
    value = "normal", label = "Normal"
}, {
    value = "high",   label = "High"
}},
```

---

### `info` — Read-only display

Renders the value as monospace text, no editing:

```lua
type    = "info",
default = "",
```

---

### `download_link` — File download button

Renders a download button. No value is saved to Redis.

```lua
type              = "download_link",
download_url      = ntop.getHttpPrefix() .. "/misc/grafana/dashboard.json",
download_filename = "dashboard.json",   -- suggested filename for the browser
```

---

## Complete example

```lua
sections[#sections + 1] = {
    id       = "my_feature",
    label    = i18n("prefs.my_feature_label"),
    advanced = false,
    pro_only = false,
    hidden   = not ntop.isMyFeatureEnabled(),
    entries  = {

        -- Boolean toggle that controls visibility of the URL field
        {
            key         = "my_feature_enabled",
            title       = i18n("prefs.my_feature_enabled_title"),
            description = i18n("prefs.my_feature_enabled_description"),
            type        = "toggle",
            redis_key   = "ntopng.prefs.my_feature_enabled",
            default     = "0",
            to_switch   = {"my_feature_url"},
        },

        -- URL input with connectivity test
        {
            key           = "my_feature_url",
            title         = i18n("prefs.my_feature_url_title"),
            description   = i18n("prefs.my_feature_url_description"),
            type          = "input",
            input_type    = "text",
            redis_key     = "ntopng.prefs.my_feature_url",
            default       = "http://localhost:9000",
            test_endpoint = "/lua/rest/v2/get/ntopng/test_url_connectivity.lua",
            attrs         = { maxlength = "256", spellcheck = "false" },
        },

        -- Retention in days (stored as seconds, displayed as h/d)
        {
            key       = "my_feature_retention",
            title     = i18n("prefs.my_feature_retention_title"),
            type      = "input",
            input_type = "number",
            tformat   = "hd",
            redis_key = "ntopng.prefs.my_feature_retention_secs",
            default   = tostring(7 * 86400),
            attrs     = { min = tostring(3600) },  -- minimum 1 hour (in seconds)
        },

        -- Max file size in bytes, displayed with MB/GB selector
        {
            key        = "my_feature_max_bytes",
            title      = i18n("prefs.my_feature_max_bytes_title"),
            type       = "input",
            input_type = "number",
            tformat    = "mg",
            redis_key  = "ntopng.prefs.my_feature_max_bytes",
            default    = tostring(500 * 1024 * 1024),  -- 500 MB in bytes
            attrs      = { min = tostring(10 * 1024 * 1024) },  -- 10 MB minimum
        },

        -- Segmented choice, group header above
        {
            key     = "my_feature_mode",
            title   = i18n("prefs.my_feature_mode_title"),
            type    = "button_group",
            redis_key = "ntopng.prefs.my_feature_mode",
            default = "auto",
            section = i18n("prefs.my_feature_advanced_group"),
            options = {{
                value = "auto",   label = i18n("auto")
            }, {
                value = "manual", label = i18n("manual")
            }},
        },

        -- Grafana dashboard download
        {
            key               = "my_feature_dashboard",
            title             = i18n("prefs.my_feature_dashboard_title"),
            description       = i18n("prefs.my_feature_dashboard_description"),
            type              = "download_link",
            download_url      = ntop.getHttpPrefix() .. "/misc/grafana/my-dashboard.json",
            download_filename = "my-dashboard.json",
        },
    }
}
```

---

## Adding i18n strings

Add entries under the `prefs` namespace in `scripts/locales/en.lua` (and other locale files):

```lua
["my_feature_label"]              = "My Feature",
["my_feature_enabled_title"]      = "Enable My Feature",
["my_feature_enabled_description"]= "Activates the my feature integration.",
["my_feature_url_title"]          = "Server URL",
["my_feature_url_description"]    = "URL of the my feature server.",
["my_feature_retention_title"]    = "Data Retention",
["my_feature_max_bytes_title"]    = "Max File Size",
["my_feature_mode_title"]         = "Operating Mode",
["my_feature_advanced_group"]     = "Advanced",
["my_feature_dashboard_title"]    = "Grafana Dashboard",
["my_feature_dashboard_description"] = "Download the pre-built Grafana dashboard.",
```

---

## Adding a new `type` (rare)

If none of the built-in types fit, add a new branch in `http_src/vue/pref-field.vue`:

1. Add a `v-else-if="entry.type === 'my_type'"` block in the `<template>` inside `.pref-ctrl-col`.
2. Emit `update:modelValue` with a string when the value changes.
3. Document the new type here.

The Vue component receives the full entry object as `entry`, so any extra fields added to the Lua schema are available as `entry.my_field`.
