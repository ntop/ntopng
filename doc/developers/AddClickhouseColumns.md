# Adding New Queryable Columns

This guide explains how to add a new column to ntopng so that it can be queried from the frontend **Historical Flows** page.

## Overview

To expose a new column in the historical flow search:

1. Update the database schema to include the new column.
2. Synchronize all ClickHouse/C++ schema definitions.
3. Update tag utils to support filtering.
4. Modify flow column definitions to link tags and database fields.
5. Ensure the REST API returns and formats the new column.

## Steps

### 1. Modify the ClickHouse Schema

Edit the schema file:

`httpdocs/misc/db_schema_clickhouse.sql`

- Add the new column to the appropriate flow table (e.g., `flows`, `aggregated_flows_hourly`, etc.).
- At the top of the SQL file, you'll find a list of **4 scripts** that must be kept in sync when updating the schema.
  Update those C++ and Lua files accordingly to ensure consistency.

### 2. Update Tag Utilities

Edit the tag definition in:

`scripts/lua/modules/tag_utils.lua`

Add an entry for your new column (example: `dst_peer_as`):

```lua
dst_peer_as = {
    value_type = 'asn',
    i18n_label = i18n('db_search.tags.dst_peer_as'),
    operators = { 'eq', 'neq' },
    hourly_available = false,
},
```

- The `hourly_available` field should be set to `true` if you want the field usable in hourly aggregations.
- i18n label is the entry in the i18n file (scripts/locales/en.lua) that renders the label for the newly created tag.

### 3. Update Historical Flow Utils

Edit:

`scripts/lua/modules/historical_flow_utils.lua`

Add the new column to the `flow_columns` table:

```lua
['DST_PEER_ASN'] = { tag = "dst_peer_asn" },
```

- The key (`DST_PEER_ASN`) should match the column name in ClickHouse (uppercase).
- The `tag` must correspond to the tag defined in `tag_utils.lua`.

### 4. Handle Aggregates (Optional)

If aggregations (e.g., hourly) are enabled, ensure the new column is also available in:

- Aggregated flow tables in `db_schema_clickhouse.sql`
- Add the new columns definition to `scripts/lua/modules/historical_flow_utils.lua` `aggregated_flow_columns`.

### 5. Update REST API Formatting

Edit:

`pro/scripts/lua/rest/v2/get/flow/historical/flow_details.lua`

Find and update the `historical_flow_details_formatter.formatHistoricalFlowDetails(flow)` function to include your new column:

```lua
formatted_flow.dst_peer_asn = flow.dst_peer_asn
```

This ensures the new field is visible in the frontend when rendering historical flow details.

## Summary

To add a new column for querying and displaying in the historical flow UI, update the following files:

- **Schema:** `httpdocs/misc/db_schema_clickhouse.sql`
- **C++/Lua schema sync:** Top 4 files listed in the schema file
- **Tags:** `scripts/lua/modules/tag_utils.lua`
- **Flow Utils:** `scripts/lua/modules/historical_flow_utils.lua`
- **REST API:** `pro/scripts/lua/rest/v2/get/flow/historical/flow_details.lua`

Ensure that all parts are in sync to allow querying, filtering, and rendering of the new column.