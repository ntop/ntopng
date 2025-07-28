# Adding a New Preference in ntopng

This document provides a comprehensive guide for adding a new preference to ntopng. The process involves modifying several files across Lua and backend (C++) components.

## Overview

Adding a new preference requires modifications to:
- Internationalization files (i18n)
- Lua preference menu configuration
- Frontend component rendering
- C++ preference handling (header, implementation, and constants)

## Step-by-Step Implementation

### 1. Add Internationalization Strings

First, define the title and description for your preference in the i18n configuration:

```lua
["prefs"] = {
    ["toggle_export_flows_to_archive_description"] = "Save data to the specified archive folder before it's automatically deleted by the retention policy",
    ["toggle_export_flows_to_archive_title"] = "Archive Flows Before TTL Deletion",
}
```

### 2. Configure Preference Menu

Add the i18n mapping to `ntopng/scripts/lua/modules/prefs_menu.lua` under the appropriate section:

```lua
{
    id = "clickhouse",
    label = i18n("prefs.clickhouse"),
    advanced = true,
    pro_only = true,
    hidden = not ((ntop.isEnterpriseM() or ntop.isnEdgeEnterprise())),
    entries = {
        -- ... existing entries ...
        toggle_data_archive_before_ttl_delete = {
            title = i18n("prefs.toggle_export_flows_to_archive_title"),
            description = i18n("prefs.toggle_export_flows_to_archive_description")
        }
    }
}
```

### 3. Add Frontend Component

Specify the UI component for the preference. For a toggle button:

- field is the entries element to display
- pref is the

```lua
prefsToggleButton(subpage_active, {
    field = "toggle_data_archive_before_ttl_delete",
    default = "0",
    pref = "toggle_data_archive_before_ttl_delete",
    hidden = not showAggregateFlowsPrefs
})
```

**Note:** The `pref` parameter is used in C++ via `ntop->getPrefs()`.

### 4. Define Constants

In `ntop_defines.h`, add the preference constant:

```cpp
#define CONST_PREFS_ENABLE_ARCHIVE_BEFORE_TTL_DELETE \
    NTOPNG_PREFS_PREFIX ".archive_before_ttl_delete"
```

### 5. Update Header File

In `Prefs.h`, declare the preference variable:

```cpp
#ifdef NTOPNG_PRO
bool data_archive_before_ttl_delete;
#endif
```

**Important:** Use appropriate version guards (e.g., `#ifdef NTOPNG_PRO`) when the feature is version-specific.

### 6. Initialize Default Value

In `Prefs::Prefs(Ntop *_ntop)` constructor in `Prefs.cpp`, set the default value:

```cpp
#ifdef NTOPNG_PRO
data_archive_before_ttl_delete = false;
#endif
```

Consider version compatibility when setting defaults.

### 7. Implement Preference Reloading

In `Prefs.cpp`, add the preference loading logic in `void Prefs::reloadPrefsFromRedis()`:

```cpp
data_archive_before_ttl_delete = getDefaultBoolPrefsValue(
    CONST_PREFS_ENABLE_ARCHIVE_BEFORE_TTL_DELETE, 
    false
);
```

### 8. Expose to Lua Interface

In `Prefs.cpp`, add the preference to the Lua interface in `void Prefs::lua(lua_State *vm)`:

```cpp
lua_push_bool_table_entry(vm, "data_archive_before_ttl_delete", data_archive_before_ttl_delete);
```

This makes the preference accessible from Lua scripts.

## File Summary

The following files need to be modified:

| File | Purpose |
|------|---------|
| i18n files | Internationalization strings |
| `prefs_menu.lua` | Menu configuration |
| Frontend templates | UI component rendering |
| `ntop_defines.h` | Constant definitions |
| `Prefs.h` | Variable declarations |
| `Prefs.cpp` | Implementation and Lua interface |

## Best Practices

1. **Naming Convention**: Use consistent naming across all components (Lua field names, C++ variables, constants)

2. **Version Guards**: Apply appropriate `#ifdef` guards for enterprise or pro features

3. **Default Values**: Choose sensible defaults and document the rationale

4. **Documentation**: Update relevant documentation and comments

5. **Testing**: Verify the preference works correctly in both UI and backend

## Example Use Case

The example demonstrates adding an archive preference for flows before TTL deletion, showing how data flows from the UI toggle through the Lua interface to the C++ backend where the actual functionality is implemented.

This pattern can be adapted for various preference types including toggles, dropdowns, text inputs, and numeric values by adjusting the frontend component and C++ data types accordingly.