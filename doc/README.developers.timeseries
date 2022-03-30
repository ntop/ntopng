Add Timeseries in ntopng
------------------------

In ntopng it's possible to extend the timeseries. To do it users need to change very few files. 

Check for example asn:traffic_anomalies timeseries (Pro timeseries used to understand if any anomaly is found in an ASN):

- scripts/lua/as_details.lua:                          {schema="asn:traffic_anomalies",     label=i18n("graphs.iface_traffic_anomalies")}
- scripts/lua/modules/timeseries/schemas/ts_5min.lua:  schema = ts_utils.newSchema("asn:traffic_anomalies", {step=300, metrics_type=ts_utils.metrics.gauge})
- scripts/lua/modules/ts_5min_dump_utils.lua:          ts_utils.append("asn:traffic_anomalies",{ifid=ifstats.id, asn=asn, anomaly=anomaly}, when)

Modify the scripts/lua/modules/timeseries/schemas/ts_{FREQUENCY}.lua file, by adding a new timeseries schema (like shown above), replacing {FREQUENCY} with the update frequency of the timeseries:
- second;
- 5sec;
- minute;
- 5min;
- hour;

To the ts_utils.newSchema, 3 parameters are needed:
- name of the schema;
- list containing step (number, update frequency), metric_type (ts_utils.metrics.gauge or ts_utils.metrics.counter) and is_system_schema (boolean, optional);
after the ts_utils.newSchema function call, users need to add the parameters of the schema:

schema:addTag("ifid")
schema:addTag("asn")
schema:addMetric("anomaly")

schema:addTag(), add a new tag to the schema
schema:addMetric(), add a metric to the schema

Then modify scripts/lua/modules/ts_{FREQUENCY}_dump_utils.lua by adding a new call to the ts_utils.append("asn:traffic_anomalies",{ifid=ifstats.id, asn=asn, anomaly=anomaly}, when).
ts_utils.append needs:
- name of the schema (the one add above in the ts_utils.newSchema function);
- list of the tags and metrics (Note: the name of the parameters have to be the same of the ones added by using the addTag and addMetric functions);
- timestamp of current update;

Then to show the schema in the GUI modify the file that shows the timeseries charts (in the example above, 'scripts/lua/as_details.lua').
To do it add, add a new entry to the object 'LIST_OF_TIMESERIES' of the graph_utils.drawGraphs(ifId, schema, tags, zoom, asn_url, selected_epoch, {timeseries = LIST_OF_TIMESERIES}) function, having at least 2 parameters (like asn:traffic_anomalies): 
- schema: string, having the timeseries schema name;
- label:  string, name of the schema, shown in the GUI;
- split_directions (optional): boolean, if the serie has 2 or more values then split them in when shown in the chart; 
- first_timeseries_only (optional): boolean, show only the first timeseries;
- time_elapsed: number, update frequency of the GUI (usually the same of the timeseries); 
- value_formatter: array of functions, an array of functions used to format the value in the GUI;
- metrics_labels: array of strings, representing the list of timeseries name, shown in the GUI;

NOTE:
if a timeseries is changed during the time, the old rrd timeseries needs to be deleted and instead for influxdb the name of the schema needs to be added to the return of the
function ts_utils.getPossiblyChangedSchemas() in the 'scripts/lua/modules/timeseries/ts_utils_core.lua' file, 
