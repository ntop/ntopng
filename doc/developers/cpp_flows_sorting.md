## Architecture Flow

The sorting process follows this path:

```
active_list.lua → getFlowsInfo() → NetworkInterface::getFlows() → NetworkInterface::sortFlows() → flow_search_walker()
```

### Key Components:

1. **Lua Frontend** (`scripts/lua/rest/v2/get/flow/active_list.lua`)
2. **C++ Backend** (`src/NetworkInterface.cpp`)
3. **Type Definitions** (`include/ntop_typedefs.h`)
4. **Flow Class** (`include/Flow.h`)

## Step-by-Step Implementation Guide

### Step 1: Define Sort Column Types

Add new column enums in `include/ntop_typedefs.h`:

```cpp
typedef enum {
  // ... existing columns
  column_score,
  column_score_as_client,
  column_score_as_server,
  
  // NEW COLUMNS - Add here
  column_cli_asn,
  column_srv_asn,
  column_transit_asn,
  
  // ... rest of columns
} sortField;
```

### Step 2: Add Flow Class Methods

If you need new data accessors, add them to `include/Flow.h`:

```cpp
class Flow : public GenericHashEntry {
  // new memers
  u_int32_t srcAS, dstAS;
  u_int32_t transitAS;  // NEW FIELD
  
  // new getters
  u_int32_t getSrcAS()     { return(srcAS);     }
  u_int32_t getDstAS()     { return(dstAS);     }
};
```

### Step 3: Update Lua-to-C++ Column Mapping

In `scripts/lua/rest/v2/get/flow/active_list.lua`, add mappings:

```lua
local mapping_column_lua_c = {
    server = "column_server",
    client = "column_client",
    -- ... existing mappings
    qoe = "column_qoe",
    
    -- NEW MAPPINGS
    cli_asn = "column_cli_asn",
    srv_asn = "column_srv_asn",
    transit_asn = "column_transit_asn"
}
```

### Step 4: Implement Sort Logic in flow_search_walker

In `src/NetworkInterface.cpp`, add cases to the `flow_search_walker` function:

```cpp
static bool flow_search_walker(GenericHashEntry *h, void *user_data, bool *matched) {
  Flow *f = (Flow*)h;
  FlowSearcher *retriever = (FlowSearcher*)user_data;
  
  // ... existing code
  
  switch (retriever->sorter) {
    // ... existing cases
    
    // add new column cases
    case column_cli_asn:
      retriever->elems[retriever->actNumEntries++].numericValue = f->getSrcAS();
      break;
      
    case column_srv_asn:
      retriever->elems[retriever->actNumEntries++].numericValue = f->getDstAS();
      break;
      
    case column_transit_asn:
      retriever->elems[retriever->actNumEntries++].numericValue = f->getTransitAS();
      break;
      
    // ... other cases
  }
}
```

### Step 5: Add Sort Column Recognition

In `NetworkInterface::sortFlows()`, add column string recognition:

```cpp
int NetworkInterface::sortFlows(u_int32_t *begin_slot, bool walk_all,
                                bool a2zSortOrder, sortField field,
                                const char *sortColumn, /* ... */) {
  
  // ... existing code
  
  if (!strcmp(sortColumn, "column_duration"))
    retriever->sorter = column_duration, sorter = numericSorter;
  else if (!strcmp(sortColumn, "column_qoe"))
    retriever->sorter = column_qoe, sorter = numericSorter;
    
  // NEW SORT COLUMNS
  else if (!strcmp(sortColumn, "column_cli_asn"))
    retriever->sorter = column_cli_asn, sorter = numericSorter;
  else if (!strcmp(sortColumn, "column_srv_asn"))
    retriever->sorter = column_srv_asn, sorter = numericSorter;
  else if (!strcmp(sortColumn, "column_transit_asn"))
    retriever->sorter = column_transit_asn, sorter = numericSorter;
    
  // ... rest of the function
}
```

## Key Technical Details

### Sorting Order Control

The sorting order is controlled by `p->a2zSortOrder()`:

```cpp
// In NetworkInterface::getFlows()
if (p->a2zSortOrder()) {
  // Ascending order (A to Z, 0 to 9)
  for (int i = p->toSkip(), num = 0; i < (int)retriever.actNumEntries; i++) {
    // Process sorted elements
  }
} else {
  // Descending order (Z to A, 9 to 0)
  for (int i = (int)retriever.actNumEntries - 1 - p->toSkip(), num = 0; i >= 0; i--) {
    // Process sorted elements in reverse
  }
}
```

### Sort Value Types

Choose the appropriate sorter type:

- **`numericSorter`**: For numeric values (ASN, scores, durations, bytes)
- **`stringSorter`**: For string values (hostnames, protocols)
- **`ipSorter`**: For IP addresses

### Data Storage in Retriever

The `flow_search_walker` populates the `retriever->elems` array:

```cpp
// For numeric values
retriever->elems[retriever->actNumEntries++].numericValue = someNumber;

// For string values  
retriever->elems[retriever->actNumEntries++].stringValue = someString;

// For IP addresses
retriever->elems[retriever->actNumEntries++].ipValue = someIPAddress;
```

## Example: Adding Server ASN Sorting

Following the commit example, here's how the Server ASN sorting was implemented:

1. **Added enum**: `column_srv_asn` in `ntop_typedefs.h`
2. **Added mapping**: `srv_asn = "column_srv_asn"` in Lua
3. **Added walker case**: Extract `f->getDstAS()` as numeric value
4. **Added column recognition**: Map `"column_srv_asn"` string to enum

## Best Practices

1. **Use existing Flow methods** when possible rather than accessing members directly
2. **Choose correct sorter type** based on the data being sorted
3. **Follow naming conventions**: `column_*` for enums, `*_asn`/`*_*` for Lua keys
4. **Handle edge cases**: Consider what happens when data is unavailable (return 0 or appropriate default)
5. **Test both sort orders**: Ensure ascending and descending work correctly

## Related Files

- `include/ntop_typedefs.h` - Column type definitions
- `include/Flow.h` - Flow class and data accessors
- `src/NetworkInterface.cpp` - Core sorting logic
- `scripts/lua/rest/v2/get/flow/active_list.lua` - Frontend API mapping