# Adding a New Preference in ntopng

This document explains how to add a new preference to ntopng. There are two patterns depending on whether the preference needs to be read by the C++ backend:

- **Lua-only prefs** — stored in Redis, read from Lua. No C++ changes needed. Use this for settings consumed by Lua scripts (REST endpoints, page logic, etc.).
- **C++-backed prefs** — stored in Redis, loaded into `Prefs.cpp`, exposed back to Lua via `ntop.getPrefs()`. Use this for settings that the C++ core needs at runtime.

Both patterns share the same first three steps.

---

## Common Steps (all pref types)

### 1. Add i18n Strings

Add title and description strings to `scripts/locales/en.lua` inside the `["prefs"]` table:

```lua
["my_feature_url_title"] = "API URL",
["my_feature_url_description"] = "Base URL of the remote API endpoint",
["my_feature_token_title"] = "API Token",
["my_feature_token_description"] = "Authentication token for the remote API",
```

### 2. Add the Subpage (or Entry) in `prefs_menu.lua`

`scripts/lua/modules/prefs_menu.lua` drives the tab list and controls access (pro-only, enterprise-only, hidden, etc.).

**Adding a new tab:**

```lua
},{
    id = "my_feature",                  -- must match the tab= GET param and the if-block in prefs.lua
    label = i18n("prefs.my_feature"),
    advanced = false,
    pro_only = true,                    -- set true to restrict to Pro/Enterprise
    hidden = false,
    entries = {
        my_feature_url = {
            title = i18n("prefs.my_feature_url_title"),
            description = i18n("prefs.my_feature_url_description")
        },
        my_feature_token = {
            title = i18n("prefs.my_feature_token_title"),
            description = i18n("prefs.my_feature_token_description")
        }
    }
}}
```

**Adding entries to an existing tab** — just extend the `entries` table of the relevant subpage.

### 3. Implement the Render Function in `prefs.lua`

`scripts/lua/admin/prefs.lua` contains one render function per tab. Use the helpers at the top of the file:

| Helper | Purpose |
|--------|---------|
| `create_table()` | Opens `<form>` + `<table>` |
| `add_section(title)` | Adds a blue `<thead>` section divider |
| `end_table()` | Adds Save button, CSRF token, closes form + table |
| `prefsToggleButton(subpage_active, opts)` | On/off toggle |
| `prefsInputFieldPrefs(label, desc, prekey, key, default, type, ...)` | Text / number / password input |

**Dispatch block** — near the bottom of `prefs.lua`, add:

```lua
if (tab == "my_feature") then
    printMyFeature()
end
```

**Render function skeleton:**

```lua
function printMyFeature()
    create_table()
    add_section(i18n("prefs.my_feature"))

    prefsInputFieldPrefs(
        subpage_active.entries["my_feature_url"].title,
        subpage_active.entries["my_feature_url"].description,
        "ntopng.prefs.my_feature", "url",
        "https://api.example.com",   -- default
        "text",                      -- input type
        true,                        -- show
        true,                        -- disable autocomplete
        true,                        -- allow URLs
        { attributes = { spellcheck = "false", maxlength = 255 } }
    )

    prefsInputFieldPrefs(
        subpage_active.entries["my_feature_token"].title,
        subpage_active.entries["my_feature_token"].description,
        "ntopng.prefs.my_feature", "token",
        "",
        "password",                  -- renders as dots
        true, true, false,
        { attributes = { spellcheck = "false", maxlength = 255 } }
    )

    end_table()
end
```

**Redis key** is assembled as `prekey .. "." .. key`, so the above produces `ntopng.prefs.my_feature.url` and `ntopng.prefs.my_feature.token`. Read them anywhere in Lua with `ntop.getPref("ntopng.prefs.my_feature.url")`.

**Input types:**

| Value | Renders as |
|-------|-----------|
| `"text"` | Plain text box |
| `"number"` | Numeric input (supports `min`, `max`, `step`) |
| `"password"` | Masked dots; also sets `autocomplete="new-password"` |

**Multiple sections on one tab** — call `add_section()` multiple times between field groups:

```lua
add_section(i18n("prefs.section_a"))
-- fields for section A ...

add_section(i18n("prefs.section_b"))
-- fields for section B ...
```

### 4. Register POST Keys in `http_lint.lua`

Every key that can appear in `_POST` must be whitelisted in `scripts/lua/modules/http_lint.lua`. Find the relevant block and add entries:

```lua
-- MY FEATURE
["url"]   = validateUnquoted,
["token"] = {passwordCleanup, validatePassword},
```

Common validators:

| Validator | Use for |
|-----------|---------|
| `validateUnquoted` | Free text, URLs, hostnames |
| `validateSingleWord` | Tokens without spaces |
| `validateNumber` | Numeric values |
| `validatePassword` + `passwordCleanup` | Secret / password fields |
| `validateIpAddress` | IP addresses |

---

## Extra Steps for C++-backed Prefs

Skip this section if the preference is only consumed from Lua.

### 5. Define a Constant

In `include/ntop_defines.h`:

```cpp
#define CONST_PREFS_MY_FEATURE_TOKEN \
    NTOPNG_PREFS_PREFIX ".my_feature.token"
```

### 6. Declare the Variable

In `include/Prefs.h`:

```cpp
#ifdef NTOPNG_PRO
bool my_feature_enabled;
#endif
```

Use `#ifdef NTOPNG_PRO` (or `NTOPNG_ENTERPRISE`) for version-gated features.

### 7. Set the Default

In `Prefs::Prefs()` constructor in `src/Prefs.cpp`:

```cpp
#ifdef NTOPNG_PRO
my_feature_enabled = false;
#endif
```

### 8. Load from Redis

In `Prefs::reloadPrefsFromRedis()`:

```cpp
my_feature_enabled = getDefaultBoolPrefsValue(
    CONST_PREFS_MY_FEATURE_TOKEN, false
);
```

### 9. Expose to Lua

In `Prefs::lua()`:

```cpp
lua_push_bool_table_entry(vm, "my_feature_enabled", my_feature_enabled);
```

The value is then accessible in Lua via `ntop.getPrefs().my_feature_enabled`.

---

## File Checklist

### Lua-only pref

| File | Change |
|------|--------|
| `scripts/locales/en.lua` | Add i18n strings |
| `scripts/lua/modules/prefs_menu.lua` | Add subpage / entries |
| `scripts/lua/admin/prefs.lua` | Add render function + dispatch block |
| `scripts/lua/modules/http_lint.lua` | Whitelist POST keys |

### C++-backed pref (all of the above, plus)

| File | Change |
|------|--------|
| `include/ntop_defines.h` | Add constant |
| `include/Prefs.h` | Declare variable |
| `src/Prefs.cpp` | Initialize, reload, expose to Lua |

---

## Best Practices

- **Namespace Redis keys** — use `ntopng.prefs.<feature>.<key>` to avoid collisions.
- **Use `pro_only = true`** for any feature that should be restricted to Pro/Enterprise builds.
- **Never skip `http_lint.lua`** — unregistered POST keys are silently dropped, which can cause confusing save failures.
- **Password fields** — always use `"password"` as the input type and `{passwordCleanup, validatePassword}` in http_lint; never store tokens in plain `"text"` fields.
- **Defaults** — for URL fields, supply a sensible placeholder default so the user knows the expected format.