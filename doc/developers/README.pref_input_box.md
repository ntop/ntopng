# prefsInputFieldPrefs Component Documentation

## Overview

`prefsInputFieldPrefs` is a Lua function that creates input field components for ntopng preferences. It handles form rendering, validation, Redis persistence, and runtime notification for preference changes.

## Function Signature

```lua
function prefsInputFieldPrefs(label, comment, prekey, key, default_value, _input_type, showEnabled, disableAutocomplete, allowURLs, extra)
```

## Parameters

### Required Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `label` | string | Display label for the input field |
| `comment` | string | Help text shown below the label |
| `prekey` | string | Redis key prefix for the preference |
| `key` | string | Unique identifier for the input field |
| `default_value` | string/number | Default value when preference is not set |

### Optional Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `_input_type` | string | "text" | HTML input type (text, number, password, etc.) |
| `showEnabled` | boolean | true | Whether to display the field |
| `disableAutocomplete` | boolean | false | Disable browser autocomplete |
| `allowURLs` | boolean | false | Enable URL pattern validation |
| `extra` | table | {} | Additional configuration options |

### Extra Configuration Options

The `extra` parameter accepts a table with the following optional fields:

#### Validation Options
- `min` - Minimum value (for number inputs)
- `max` - Maximum value (for number inputs)
- `minlength` - Minimum string length
- `maxlength` - Maximum string length
- `step` - Step value for number inputs
- `pattern` - Regex pattern for validation
- `required` - Mark field as required

#### UI Options
- `width` - Custom width for the input
- `inputBoxWidth` - Specific input box width (e.g., "20em")
- `style` - Additional CSS styles (table)
- `attributes` - Additional HTML attributes (table)
- `append` - HTML to append after the input
- `disabled` - Disable the input field

#### Special Options
- `skip_redis` - Skip Redis operations (for testing)
- `tformat` - Time format for resolution buttons
- `format_spec` - Format specification for time inputs

## Usage Examples

### Basic Text Input

```lua
prefsInputFieldPrefs(
    "Server Name",           -- label
    "Enter the server name", -- comment
    "myapp.server",         -- prekey
    "name",                 -- key
    "localhost",            -- default_value
    "text"                  -- input_type
)
```

### Number Input with Validation

```lua
prefsInputFieldPrefs(
    "Port Number",
    "TCP port for the service (1-65535)",
    "myapp.network",
    "port",
    "8080",
    "number",
    true,  -- showEnabled
    false, -- disableAutocomplete
    false, -- allowURLs
    {
        min = 1,
        max = 65535,
        required = true,
        inputBoxWidth = "8em"
    }
)
```

### Password Input

```lua
prefsInputFieldPrefs(
    "Database Password",
    "Password for database connection",
    "myapp.db",
    "password",
    "",
    "password",
    true,
    true, -- disable autocomplete for passwords
    false,
    {
        required = true,
        minlength = 8,
        maxlength = 64
    }
)
```

### URL Input with Pattern Validation

```lua
prefsInputFieldPrefs(
    "API Endpoint",
    "REST API base URL",
    "myapp.api",
    "endpoint",
    "https://api.example.com",
    "url",
    true,
    false,
    true, -- allow URLs
    {
        pattern = "https?://.*",
        required = true,
        inputBoxWidth = "25em"
    }
)
```

### Conditional Display

```lua
local showAdvanced = ntop.getPref("myapp.show_advanced") == "1"

prefsInputFieldPrefs(
    "Advanced Setting",
    "This setting is only for advanced users",
    "myapp.advanced",
    "setting",
    "default",
    "text",
    showAdvanced, -- only show if advanced mode is enabled
    false,
    false,
    {
        style = { ["font-family"] = "monospace" }
    }
)
```

## Data Flow

### 1. Form Submission
When a form is submitted via POST:
- Function checks `_POST[key]` for the submitted value
- Validates the input based on type and constraints
- Stores the value in Redis using `ntop.setPref()`
- Notifies the runtime ntopng instance via `notifyNtopng()`

### 2. Initial Load
When rendering the form:
- Retrieves current value from Redis using `ntop.getPref()`
- Falls back to `default_value` if no stored value exists
- Sets the default value in Redis if not present

### 3. URL Processing
When `allowURLs` is true, the function automatically fixes common URL formatting issues:
- `ldaps:__` → `ldaps://`
- `http:__` → `http://`
- `smtp:__` → `smtp://`
- etc.

## Client-Side Validation

The component includes JavaScript validation that:
- Validates numeric ranges on focus out
- Shows error indicators for invalid values
- Removes error styling on focus in
- Prevents form submission with invalid data

## Redis Key Construction

The Redis key is constructed as:
- If `prekey` ends with ".", then key = `prekey + key`
- Otherwise, key = `prekey + "." + key`

Example:
```lua
prekey = "myapp.database"
key = "port"
-- Result: "myapp.database.port"
```

## Best Practices

### 1. Consistent Naming
Use hierarchical naming for related preferences:
```lua
-- Good
"myapp.database.host"
"myapp.database.port"
"myapp.database.timeout"

-- Avoid
"db_host"
"port_db"
"timeout"
```

### 2. Meaningful Defaults
Choose sensible default values:
```lua
-- Good
default_value = "localhost"  -- for hostname
default_value = "443"        -- for HTTPS port

-- Avoid
default_value = ""           -- for required fields
default_value = "0"          -- when 0 is invalid
```

### 3. Proper Validation
Always validate user input:
```lua
{
    min = 1,
    max = 65535,
    required = true,
    pattern = "^[0-9]+$"  -- only digits
}
```

### 4. User-Friendly Labels
Use clear, descriptive labels:
```lua
-- Good
label = "Maximum Connection Timeout (seconds)"
comment = "How long to wait before timing out connections"

-- Avoid
label = "Timeout"
comment = "Timeout value"
```

## Error Handling

The component handles several error conditions:
- Invalid numeric ranges (shows visual error indicator)
- Missing required values (HTML5 validation)
- Pattern mismatches (browser validation)
- Redis connection issues (graceful fallback to defaults)

## Integration with ntopng

This component integrates with ntopng's preference system by:
- Storing values in Redis for persistence
- Notifying the runtime instance of changes
- Supporting enterprise/pro feature flags
- Following ntopng's UI conventions and styling