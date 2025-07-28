# Adding New Startup Parameters in ntopng

This guide explains how to add a new command-line startup parameter to ntopng, using the `--db-archive-dir` parameter implementation as a reference example.

## Overview

Adding a new startup parameter in ntopng requires modifications to three main files:
- `include/Prefs.h` - Header file containing the Prefs class declaration
- `src/Prefs.cpp` - Implementation of preferences handling and command-line parsing
- `src/LuaEngineNtop.cpp` - Lua engine integration (if the parameter needs to be accessible from Lua scripts)

## Step 1: Modify the Header File (`include/Prefs.h`)

### 1.1 Add the Member Variable

Add a new member variable to store the parameter value in the private section of the `Prefs` class:

```cpp
char *data_dir, *install_dir, *docs_dir, *scripts_dir, *callbacks_dir,
    *pcap_dir, *clickhouse_archive_dir  // Add your new parameter here
```

### 1.2 Add the Getter Method

Add a public getter method to access the parameter value:

```cpp
inline const char* get_clickhouse_archive_dir() { return (clickhouse_archive_dir); };
```

**Note**: Use `inline const char*` for string parameters that return directory paths or simple string values.

## Step 2: Modify the Implementation File (`src/Prefs.cpp`)

### 2.1 Initialize the Member Variable

In the `Prefs::Prefs(Ntop *_ntop)` constructor, initialize your new member variable to `NULL`:

```cpp
pcap_dir = NULL;
clickhouse_archive_dir = NULL;  // Add initialization here
```

### 2.2 Add Memory Cleanup

In the `Prefs::~Prefs()` destructor, add memory cleanup for your parameter:

```cpp
if(pcap_dir) free(pcap_dir);
if(clickhouse_archive_dir) free(clickhouse_archive_dir);  // Add cleanup here
```

### 2.3 Update the Usage Function

Add your parameter's documentation to the `usage()` function:

```cpp
"[--db-archive-dir|-6] <path>        | Directory used for archiving historical flows\n"
"                                    | recorded on ClickHouse when data retention is over.\n"
"                                    | Default: %s\n"
```

Make sure to add the corresponding format argument in the printf-style call:

```cpp
CONST_DEFAULT_DOCS_DIR, CONST_DEFAULT_SCRIPTS_DIR,
CONST_DEFAULT_CALLBACKS_DIR, CONST_DEFAULT_DATA_DIR,
CONST_DEFAULT_DATA_DIR,  // Add default value here
```

### 2.4 Add Long Option Definition

Add your parameter to the `long_options` array:

```cpp
{"pcap-dir",                required_argument, NULL, '5'},
{"db-archive-dir",          required_argument, NULL, '6'},  // Add your option here
```

**Important**: 
- Use a unique single character (like '6') for the option identifier
- Set `required_argument` if the parameter requires a value
- Set `no_argument` if it's a boolean flag

### 2.5 Update the Option String

Add your option character to the option string in `loadFromCLI()`:

```cpp
"k:eg:hi:w:r:sg:m:n:p:qd:t:x:y:1:2:3:4:5:6:l:L:uv:zA:B:c:CD:E:F:MN:G:I:O:Q:"
//                                        ^ Add your character here
```

**Note**: Add `:` after the character if the parameter requires an argument.

### 2.6 Implement Option Handling

Add a case in the `setOption()` function to handle your parameter:

```cpp
case '6':
  if(clickhouse_archive_dir) free(clickhouse_archive_dir);
  clickhouse_archive_dir = strdup(optarg);
  break;
```

### 2.7 Add Default Value Assignment

In the `checkOptions()` function, set a default value if none was provided:

```cpp
if(!pcap_dir) pcap_dir = strdup(ntop->get_working_dir());
if(!clickhouse_archive_dir) clickhouse_archive_dir = strdup(ntop->get_working_dir());
```

### 2.8 Add Path Validation

Add path validation for directory parameters:

```cpp
docs_dir = ntop->getValidPath(docs_dir);
scripts_dir = ntop->getValidPath(scripts_dir);
callbacks_dir = ntop->getValidPath(callbacks_dir);
pcap_dir = ntop->getValidPath(pcap_dir);
clickhouse_archive_dir = ntop->getValidPath(clickhouse_archive_dir);
```

### 2.9 Add Directory Existence Check

Add validation to ensure the directory exists:

```cpp
if(!pcap_dir[0]) {
  ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to locate pcap dir");
  return (-1);
}
if(!clickhouse_archive_dir[0]) {
  ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to locate ClickHouse archive dir");
  return (-1);
}
```

### 2.10 Add Trailing Slash Removal

Remove trailing slashes from directory paths:

```cpp
ntop->removeTrailingSlash(docs_dir);
ntop->removeTrailingSlash(scripts_dir);
ntop->removeTrailingSlash(callbacks_dir);
ntop->removeTrailingSlash(pcap_dir);
ntop->removeTrailingSlash(clickhouse_archive_dir);
```

## Step 3: Add Lua Integration (Optional)

If your parameter needs to be accessible from Lua scripts, modify `src/LuaEngineNtop.cpp`:

### 3.1 Update the `ntop_get_dirs()` Function

Add your parameter to the Lua table in the `ntop_get_dirs()` function:

```cpp
lua_push_str_table_entry(vm, "callbacksdir",
                         ntop->getPrefs()->get_callbacks_dir());
lua_push_str_table_entry(vm, "pcapdir", ntop->getPrefs()->get_pcap_dir());
lua_push_str_table_entry(vm, "dbarchivedir", ntop->getPrefs()->get_clickhouse_archive_dir());
```

**Note**: Use a descriptive key name (like "dbarchivedir") that will be used in Lua scripts.

## Best Practices

### Parameter Naming
- Use descriptive, kebab-case names for long options (e.g., `--db-archive-dir`)
- Choose meaningful single characters for short options
- Avoid conflicts with existing parameters

### Memory Management
- Always initialize pointers to `NULL` in the constructor
- Always free allocated memory in the destructor
- Use `strdup()` to copy string arguments
- Check for existing values before reassigning (free first)

### Validation
- Validate directory paths using `ntop->getValidPath()`
- Check directory existence and accessibility
- Provide meaningful error messages
- Set sensible default values

### Documentation
- Add comprehensive usage text explaining the parameter's purpose
- Include default values in the usage text
- Use consistent formatting with existing parameters

## Testing

After implementing your new parameter:

1. **Compile ntopng** to ensure no syntax errors
2. **Test the help output**: `./ntopng --help` should show your new parameter
3. **Test with the parameter**: `./ntopng --db-archive-dir /path/to/archive`
4. **Test without the parameter** to ensure defaults work
5. **Test invalid paths** to ensure error handling works
6. **Test Lua integration** (if applicable) by accessing the parameter from Lua scripts

## Example Usage

Once implemented, the parameter can be used as:

```bash
# Long form
./ntopng --db-archive-dir /var/lib/ntopng/archive

# Short form  
./ntopng -6 /var/lib/ntopng/archive
```

And accessed from Lua scripts as:

```lua
local dirs = ntop.getDirs()
local archive_dir = dirs["dbarchivedir"]
```