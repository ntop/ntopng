# Historical Class

The `Historical` class provides access to historical information including flows and alerts.

## Constructor

### `__init__(self, ntopng_obj, ifid=None)`

Constructs a new Historical object.

- `ntopng_obj`: The ntopng handle

## Methods

### `get_alert_type_counters(self, epoch_begin, epoch_end)`

Returns statistics about the number of alerts per alert type.

- `epoch_begin`: Start of the time interval (epoch)
- `epoch_end`: End of the time interval (epoch)
- Returns: Statistics (object)

### `get_alert_severity_counters(self, epoch_begin, epoch_end)`

Returns statistics about the number of alerts per alert severity.

- `epoch_begin`: Start of the time interval (epoch)
- `epoch_end`: End of the time interval (epoch)
- Returns: Statistics (object)

### `get_alerts(self, alert_family, epoch_begin, epoch_end, select_clause, where_clause, maxhits, group_by, order_by)`

Runs queries on the alert database.

- `alert_family`: The alert family (flow, host, interface, etc)
- `epoch_begin`: Start of the time interval (epoch)
- `epoch_end`: End of the time interval (epoch)
- `select_clause`: Select clause (SQL syntax)
- `where_clause`: Where clause (SQL syntax)
- `maxhits`: Max number of results (limit)
- `group_by`: Group by condition (SQL syntax)
- `order_by`: Order by condition (SQL syntax)
- Returns: Query result (object)

### `get_alerts_stats(self, epoch_begin, epoch_end, host=None)`

Returns flow alerts stats.

- `epoch_begin`: Start of the time interval (epoch)
- `epoch_end`: End of the time interval (epoch)
- `host` (optional): Host IP address
- Returns: Flow alert stats (object)

### `get_flow_alerts_stats(self, epoch_begin, epoch_end)`

Returns flow alerts statistics.

- `epoch_begin`: Start of the time interval (epoch)
- `epoch_end`: End of the time interval (epoch)
- Returns: Flow alert statistics (object)

### `get_flow_alerts(self, epoch_begin, epoch_end, select_clause, where_clause, maxhits, group_by, order_by)`

Returns flow alerts matching the specified criteria.

- `epoch_begin`: Start of the time interval (epoch)
- `epoch_end`: End of the time interval (epoch)
- `select_clause`: Select clause (SQL syntax)
- `where_clause`: Where clause (SQL syntax)
- `maxhits`: Max number of results (limit)
- `group_by`: Group by condition (SQL syntax)
- `order_by`: Order by condition (SQL syntax)
- Returns: Query result (object)

### `get_active_monitoring_alerts(self, epoch_begin, epoch_end, select_clause, where_clause, maxhits, group_by, order_by)`

Returns alerts matching the specified criteria for active monitoring.

- `epoch_begin`: Start of the time interval (epoch)
- `epoch_end`: End of the time interval (epoch)
- `select_clause`: Select clause (SQL syntax)
- `where_clause`: Where clause (SQL syntax)
- `maxhits`: Max number of results (limit)
- `group_by`: Group by condition (SQL syntax)
- `order_by`: Order by condition (SQL syntax)
- Returns: Query result (object)

### `get_host_alerts(self, epoch_begin, epoch_end, select_clause, where_clause, maxhits, group_by, order_by)`

Returns host alerts matching the specified criteria.

- `epoch_begin`: Start of the time interval (epoch)
- `epoch_end`: End of the time interval (epoch)
- `select_clause`: Select clause (SQL syntax)
- `where_clause`: Where clause (SQL syntax)
- `maxhits`: Max number of results (limit)
- `group_by`: Group by condition (SQL syntax)
- `order_by`: Order by condition (SQL syntax)
- Returns: Query result (object)

### `get_interface_alerts(self, epoch_begin, epoch_end, select_clause, where_clause, maxhits, group_by, order_by)`

Returns interface alerts matching the specified criteria.

- `epoch_begin`: Start of the time interval (epoch)
- `epoch_end`: End of the time interval (epoch)
- `select_clause`: Select clause (SQL syntax)
- `where_clause`: Where clause (SQL syntax)
- `maxhits`: Max number of results (limit)
- `group_by`: Group by condition (SQL syntax)
- `order_by`: Order by condition (SQL syntax)
- Returns: Query result (object)

### `get_mac_alerts(self, epoch_begin, epoch_end, select_clause, where_clause, maxhits, group_by, order_by)`

Returns MAC alerts matching the specified criteria.

- `epoch_begin`: Start of the time interval (epoch)
- `epoch_end`: End of the time interval (epoch)
- `select_clause`: Select clause (SQL syntax)
- `where_clause`: Where clause (SQL syntax)
- `maxhits`: Max number of results (limit)
- `group_by`: Group by condition (SQL syntax)
- `order_by`: Order by condition (SQL syntax)
- Returns: Query result (object)

### `get_network_alerts(self, epoch_begin, epoch_end, select_clause, where_clause, maxhits, group_by, order_by)`

Returns network alerts matching the specified criteria.

- `epoch_begin`: Start of the time interval (epoch)
- `epoch_end`: End of the time interval (epoch)
- `select_clause`: Select clause (SQL syntax)
- `where_clause`: Where clause (SQL syntax)
- `maxhits`: Max number of results (limit)
- `group_by`: Group by condition (SQL syntax)
- `order_by`: Order by condition (SQL syntax)
- Returns: Query result (object)

### `get_snmp_alerts(self, epoch_begin, epoch_end, select_clause, where_clause, maxhits, group_by, order_by)`

Returns SNMP alerts matching the specified criteria.

- `epoch_begin`: Start of the time interval (epoch)
- `epoch_end`: End of the time interval (epoch)
- `select_clause`: Select clause (SQL syntax)
- `where_clause`: Where clause (SQL syntax)
- `maxhits`: Max number of results (limit)
- `group_by`: Group by condition (SQL syntax)
- `order_by`: Order by condition (SQL syntax)
- Returns: Query result (object)

### `get_system_alerts(self, epoch_begin, epoch_end, select_clause, where_clause, maxhits, group_by, order_by)`

Returns system alerts matching the specified criteria.

- `epoch_begin`: Start of the time interval (epoch)
- `epoch_end`: End of the time interval (epoch)
- `select_clause`: Select clause (SQL syntax)
- `where_clause`: Where clause (SQL syntax)
- `maxhits`: Max number of results (limit)
- `group_by`: Group by condition (SQL syntax)
- `order_by`: Order by condition (SQL syntax)
- Returns: Query result (object)

### `get_user_alerts(self, epoch_begin, epoch_end, select_clause, where_clause, maxhits, group_by, order_by)`

Returns user alerts matching the specified criteria.

- `epoch_begin`: Start of the time interval (epoch)
- `epoch_end`: End of the time interval (epoch)
- `select_clause`: Select clause (SQL syntax)
- `where_clause`: Where clause (SQL syntax)
- `maxhits`: Max number of results (limit)
- `group_by`: Group by condition (SQL syntax)
- `order_by`: Order by condition (SQL syntax)
- Returns: Query result (object)

### `timeseries_to_pandas(self, rsp)`

Converts timeseries response to a pandas DataFrame.

- `rsp`: Timeseries response data
- Returns: Pandas DataFrame (object)

### `get_timeseries(self, ts_schema, ts_query, epoch_begin, epoch_end)`

Returns timeseries data in a pandas DataFrame for a specified schema and query.

- `ts_schema`: The timeseries schema (e.g., 'host:traffic')
- `ts_query`: The timeseries query (e.g., 'ifid:0,host:10.0.0.1')
- `epoch_begin`: Start of the time interval (epoch)
- `epoch_end`: End of the time interval (epoch)
- Returns: Timeseries data (object, pandas DataFrame)

### `get_timeseries_stats(self, ts_schema, ts_query, epoch_begin, epoch_end)`

Returns statistics from timeseries.

- `ts_schema`: The timeseries schema (e.g., 'host:traffic')
- `ts_query`: The timeseries query (e.g., 'ifid:0,host:10.0.0.1')
- `epoch_begin`: Start of the time interval (epoch)
- `epoch_end`: End of the time interval (epoch)
- Returns: Timeseries statistics (object)

### `get_timeseries_metadata(self)`

Returns timeseries metadata (lists all available timeseries).

- Returns: Timeseries metadata (object)

### `get_host_timeseries(self, host_ip, ts_schema, epoch_begin, epoch_end)`

Returns timeseries data in a pandas DataFrame for a specified interface and host.

- `host_ip`: The host IP
- `ts_schema`: The timeseries schema
- `epoch_begin`: Start of the time interval (epoch)
- `epoch_end`: End of the time interval (epoch)
- Returns: Timeseries data (object, pandas DataFrame)

### `get_host_timeseries_stats(self, host_ip, ts_schema, epoch_begin, epoch_end)`

Returns timeseries statistics for a specified interface and host.

- `host_ip`: The host IP
- `ts_schema`: The timeseries schema
- `epoch_begin`: Start of the time interval (epoch)
- `epoch_end`: End of the time interval (epoch)
- Returns: Timeseries statistics (object)

### `get_interface_timeseries(self, ts_schema, epoch_begin, epoch_end)`

Returns timeseries data in a pandas DataFrame for a specified interface.

- `ts_schema`: The timeseries schema
- `epoch_begin`: Start of the time interval (epoch)
- `epoch_end`: End of the time interval (epoch)
- Returns: Timeseries data (object, pandas DataFrame)

### `get_interface_timeseries_stats(self, ts_schema, epoch_begin, epoch_end)`

Returns timeseries statistics for a specified interface.

- `ts_schema`: The timeseries schema
- `epoch_begin`: Start of the time interval (epoch)
- `epoch_end`: End of the time interval (epoch)
- Returns: Timeseries statistics (object)

### `get_flows(self, epoch_begin, epoch_end, select_clause, where_clause, maxhits, group_by, order_by)`

Runs queries on the historical flows database (ClickHouse).

- `epoch_begin`: Start of the time interval (epoch)
- `epoch_end`: End of the time interval (epoch)
- `select_clause`: Select clause (SQL syntax)
- `where_clause`: Where clause (SQL syntax)
- `maxhits`: Max number of results (limit)
- `group_by`: Group by condition (SQL syntax)
- `order_by`: Order by condition (SQL syntax)
- Returns: Query result (object)

### `get_topk_flows(self, epoch_begin, epoch_end, max_hits, where_clause)`

Retrieves Top-K results from the historical flows database.

- `epoch_begin`: Start of the time interval (epoch)
- `epoch_end`: End of the time interval (epoch)
- `max_hits`: Max number of results (limit)
- `where_clause`: Where clause (SQL syntax)
- Returns: Query result (object)

### `get_top_conversations(self, epoch_begin, epoch_end, host=None)`

Returns Top Conversations.

- `epoch_begin`: Start of the time interval (epoch)
- `epoch_end`: End of the time interval (epoch)
- `host` (optional): Host IP address
- Returns: Top conversations (object)

### `get_host_top_protocols(self, host, epoch_begin, epoch_end)`

Returns Top protocols for a specified host.

- `host`: Host IP address
- `epoch_begin`: Start of the time interval (epoch)
- `epoch_end`: End of the time interval (epoch)
- Returns: Top protocols (object)

