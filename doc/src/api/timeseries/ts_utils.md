---
title: "ts_utils API"
description: "Data series: All the stats are calculate on the total series. The total series is obtained by taking the sum, point by point, of all the returned"
outline: [2, 3]
lastUpdated: 2020-05-13T16:39:37+02:00
---
# ts_utils API {#ts-utils-api}

`Query options`:
: - *max_num_points*: maximum number of points per data serie.
  - *fill_value*: the value to use for filling empty points. Use 0/0 for `nan`.
  - *min_value*: minimum value.
  - *max_value*: maximum value, use `math.huge` for unlimited.
  - *top*: number of top items to return in a "topk" query.
  - *calculate_stats*: if true, calculate additional stats (like average and 95th percentile).

`Query result` (returned by `ts_utils.query` and `ts_utils.topk`):
: - *start*: result start time epoch (adjusted to UTC).
  - *step*: result time step in seconds between consecutive series points.
  - *count*: number of points for each data series.
  - *series*: a list of data series. See below for details.
  - *statistics*: additional statistics. See below for details. Statistics are optional.
  - *additional_series*: (optional) a list of additional series (e.g. the *total series*).

Data series:
: - *label*: series label.
  - *data*: a unidimensional array of series values.

`Query result statistics`:
: - *total*: traffic integral in the specified time range.
  - *average* average value.
  - *min_val_idx*: index for the minimum series value.
  - *min_val*: minimum series value.
  - *max_val_idx*: index for the maximum series value.
  - *max_val*: maximum series value.
  - *95th_percentile*: the 95th percentile.

::: info
All the stats are calculate on the *total series*.
The *total series* is obtained by taking the sum, point by point, of all the returned
series. On topk queries, it also includes the non top series.
:::

### `ts_utils.newSchema(name, options)` {#ts-utils-newschema}

Define a new timeseries schema.

**Parameters**

- `name`: the schema identifier.

**Returns**: the newly created schema.

### `ts_utils.getSchema(name)` {#ts-utils-getschema}

Find schema by name.

**Parameters**

- `name`: the schema identifier.

**Returns**: a schema object on success, nil on error.

### `ts_utils.listActiveDrivers()` {#ts-utils-listactivedrivers}

Return a list of active timeseries drivers.

**Returns**: list of driver objects.

### `ts_utils.getDriverDisplayName()` {#ts-utils-getdriverdisplayname}

Return the driver name to display

### `ts_utils.append(schema_name, tags_and_metrics, timestamp)` {#ts-utils-append}

Append a new data point to the specified timeseries.

**Parameters**

- `schema_name`: the schema identifier.
- `tags_and_metrics`: a table with tag->value and metric->value mappings.
- `timestamp`: the timestamp associated with the data point.

**Returns**: true on success, false on error.

### `ts_utils.query(schema_name, tags, tstart, tend, options)` {#ts-utils-query}

Perform a query to extract timeseries data.

**Parameters**

- `schema_name`: the schema identifier.
- `tags`: a list of filter tags. All the tags for the given schema must be specified.
- `tstart`: lower time for the query.
- `tend`: upper time for the query.
- `options`: (optional) query options.

**Returns**: query result on success, nil on error.

### `ts_utils.timeseries_query_multi(options, tags_list)` {#ts-utils-timeseries-query-multi}

Same query of ts_utils.timeseries_query for many entities of one schema (e.g. all the SNMP interfaces): one query when the driver supports it, else one per entity. the SNMP interfaces): one query when the driver supports it, else one per entity.

**Parameters**

- `options`: the timeseries_query options; options.tags are the tags common to every entity.
- `tags_list`: list of the tags of each entity, all with the same keys.

**Returns**: the results by tags_list index, nil for an entity not allowed or without data.

### `ts_utils.timeseries_query_top(options)` {#ts-utils-timeseries-query-top}

Perform a top query.

**Parameters**

- `options`: contains all the info available of the timeseries from the schema to the timeframe, options, ecc.
- `from`: the schema to the timeframe, options, ecc.

### `ts_utils.listSeries(schema_name, tags_filter, start_time, end_time, not_print_error)` {#ts-utils-listseries}

List all available timeseries for the specified schema, tags and time.

**Parameters**

- `schema_name`: the schema identifier.
- `tags_filter`: a list of filter tags. Tags which are not specified are considered wildcard.
- `start_time`: time filter. Only timeseries updated after start_time will be returned.
- `end_time`: time filter. Only timeseries updated before end_time will be returned.

**Returns**: a (possibly empty) list of tags values for the matching timeseries on success, nil on error.

### `ts_utils.batchListSeries(schema_name, tags_filter, start_time)` {#ts-utils-batchlistseries}

Add a listSeries request to the current batch.

**Parameters**

- `schema_name`: the schema identifier.
- `tags_filter`: a list of filter tags. Tags which are not specified are considered wildcard.
- `start_time`: time filter. Only timeseries updated after start_time will be returned.

**Returns**: nil on error, otherwise a number is returned, indicating the item id into the batch

::: info
Call ts_utils.getBatchedListSeriesResult() to get the batch responses
:::

### `ts_utils.getBatchedListSeriesResult()` {#ts-utils-getbatchedlistseriesresult}

Completes the current batched requests and returns the results.

**Returns**: nil on error, otherwise a table item_id -> result is returned. See ts_utils.listSeries() for details.

### `ts_utils.exists(schema_name, tags_filter)` {#ts-utils-exists}

Verify timeseries existance.

**Parameters**

- `schema_name`: the schema identifier.
- `tags_filter`: a list of filter tags. Tags which are not specified are considered wildcard.

**Returns**: true if the specified series exist, false otherwise.

### `ts_utils.delete(schema_prefix, tags)` {#ts-utils-delete}

Delete timeseries data.

**Parameters**

- `schema_prefix`: a prefix for the schemas.
- `tags`: a list of filter tags.

**Returns**: true if operation was successful, false otherwise.

::: info
E.g. "iface" schema_prefix matches any schema starting with "iface:". Empty prefix is allowed and matches all the schemas.
:::

### `ts_utils.deleteOldData(ifid)` {#ts-utils-deleteolddata}

Delete old data.

**Parameters**

- `ifid:`: the interface ID to process

**Returns**: true if operation was successful, false otherwise.

### `ts_utils.queryTotalByTag(schema_name, tstart, tend, tags_filter, group_tags, options)` {#ts-utils-querytotalbytag}

Compute the total value of all the series matching the given tags, grouped by one or more tags. grouped by one or more tags.

**Parameters**

- `schema_name`: the schema identifier.
- `tstart`: lower time for the query.
- `tend`: upper time for the query.
- `tags_filter`: a list of filter tags. The grouping tags, if present, are ignored.
- `group_tags`: the schema tag to group by (e.g. "protocol"), or a list of tags.
- `options`: (optional) query options.

**Returns**: a (possibly empty) array of {tags=&lt;full tag set>, value=&lt;total>} sorted by value descending, nil on error. value descending, nil on error.

::: info
This is the cheap replacement for a ts_utils.listSeries() enumeration followed by one ts_utils.queryTotal() per series: drivers implementing topk() answer it with a
:::

::: info
by one ts_utils.queryTotal() per series: drivers implementing topk() answer it with a single grouped query. Series with no data in the time range are never returned.
:::

::: info
single grouped query. Series with no data in the time range are never returned.
:::

### `ts_utils.getPossiblyChangedSchemas()` {#ts-utils-getpossiblychangedschemas}

Get a list of existing schemas which have possibly changed format

**Returns**: a table with a list of possibly changed schemas

::: info
This function should be updated whenever an existng schema is changed
:::
