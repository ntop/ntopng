---
title: "Driver Implementation"
description: "Topk result: Topk item: A timeseries driver must implement the API described below."
outline: [2, 3]
lastUpdated: 2019-02-28T09:35:47+01:00
---
# Driver Implementation {#driver-implementation}

Topk result:
: - *topk*: a sorted list of a topk item
  - *statistics*: (optional) query result statistics.
  - *additional_series*: (optional) a list of additional series (e.g. the *total series*).

Topk item:
: - *tags*: a map tag_name -> tag_value
  - *value*: the integral value for the topk item on the specified time range

A timeseries driver must implement the API described below.

### `driver:new(options)` {#driver-new}

Driver constructor.

**Parameters**

- `options`: global options.

**Returns**: the newly created driver.

### `driver:append(schema, timestamp, tags, metrics)` {#driver-append}

Append a new data point to the timeseries.

**Parameters**

- `schema`: the schema object.
- `timestamp`: the data point timestamp.
- `tags`: map tag_name->tag_value. It contains exactly the tags defined in the schema.
- `metrics`: map metric_name->metric_value. It contains exactly the metrics defined in the schema.

**Returns**: the true on success, false otherwise.

### `driver:query(schema, tstart, tend, tags, options)` {#driver-query}

Query timeseries data.

**Parameters**

- `schema`: the schema object.
- `tstart`: lower time bound for the query.
- `tend`: upper time bound for the query.
- `tags`: a list of filter tags. It contains exactly the tags defined in the schema.
- `options`: query options.

**Returns**: a (possibly empty) query result on success, nil on failure.

### `driver:queryTotal(schema_name, tstart, tend, tags, options)` {#driver-querytotal}

Calculate a sum on the timeseries metrics.

**Parameters**

- `schema`: the schema object.
- `tstart`: lower time bound for the query.
- `tend`: upper time bound for the query.
- `tags`: a list of filter tags. It contains exactly the tags defined in the schema.
- `options`: query options.

**Returns**: a table containing metric->metric_total mappings on success, nil on failure.

### `driver:listSeries(schema, tags_filter, wildcard_tags, start_time, end_time)` {#driver-listseries}

List all available timeseries for the specified schema, tags and time.

**Parameters**

- `schema`: the schema object.
- `tags_filter`: a list of filter tags.
- `wildcard_tags`: the remaining tags of the schema which are considered wildcard.
- `start_time`: time filter. Only timeseries updated after start_time will be returned.
- `end_time`: time filter. Only timeseries updated before end_time will be returned.

**Returns**: a (possibly empty) list of tags values for the matching timeseries on success, nil for non-existing series.

### `driver:timeseries_top(options, top_tags)` {#driver-timeseries-top}

Get top k items information.

**Parameters**

- `options`: query options: schema, schema_info, tags (filter tags), epoch_begin, epoch_end, top. options.unlimited_top returns every item with data; options.totals_only returns only
- `options.unlimited_top`: returns every item with data; options.totals_only returns only tags, name and value of each item (no per item data query).
- `tags,`: name and value of each item (no per item data query).
- `top_tags`: the remaining tags of the schema, on which top k calculation is taking place.

**Returns**: {metadata, series} with the items sorted by value (total) descending, nil on error or no data.

### `driver:export()` {#driver-export}

Informs the driver that it's time to export data.

::: info
This is called periodically by ntopng and should not be called manually.
:::

### `driver:getLatestTimestamp(ifid)` {#driver-getlatesttimestamp}

Get the most recent timestamp available for queries.

**Parameters**

- `ifid`: can be used to possibly provide a more accurate answer.

**Returns**: most recent timestamp available.

::: info
a conservative way to implement this is to return the current time.
:::

### `driver:delete(schema_prefix, tags)` {#driver-delete}

Delete timeseries data

**Parameters**

- `schema_prefix`: a prefix for the schemas.
- `tags`: a list of filter tags. When a given scheam tag is not specified, it will be considered wildcard.

**Returns**: true if operation was successful, false otherwise.

::: info
E.g. "iface" schema_prefix matches any schema starting with "iface:". Empty prefix is allowed and matches all the schemas.
:::

### `driver:deleteOldData(ifid)` {#driver-deleteolddata}

Delete old data.

**Parameters**

- `ifid:`: the interface ID to process

**Returns**: true if operation was successful, false otherwise.

### `driver:setup(ts_utils)` {#driver-setup}

This is called when some driver configuration changes.

**Parameters**

- `ts_utils:`: a reference to the ts_utils module

**Returns**: true if operation was successful, false otherwise.
