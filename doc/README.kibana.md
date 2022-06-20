# Visualize ntopng data in Kibana

ntopng currently has the ability to export both Flows and Alerts to Elasticsearch, in 
this way users can create their own dashboards using Kibana and ELK (Elasticsearch) to have
their personalized data visualization.
In order to do this users have to export Flows to Elasticsearch and add a recipient to
export Alerts instead and have all the information they are interested in available.<br />
**_NOTE:_** Exporting Alerts to ELK needs at least a Pro License.

## Exporting Flows to ELK

In order to export Flows to ELK, users need to add the `-F` option into the configuration file.

Format:
```
  [--dump-flows|-F]=es;<mapping type>;<idx name>;<es URL>;<http auth>
```
Example:
```
  -F=es;ntopng;ntopng-%Y.%m.%d;http://localhost:9200/_bulk;
```

## Exporting Alerts to ELK

To export alerts instead, users need to configure an ELK Endpoint and then an ELK Recipient.
For more info follow the [documentation](https://www.ntop.org/guides/ntopng/alerts/available_recipients.html)<br />
**_NOTE:_**  A Pro License at least is needed to export Alerts to ELK.

## Adding ntopng data from Kibana GUI

Lastly users need to add ntopng data to Kibana GUI; in order to do it users need to add two new
index pattern to Kibana, by jumping from Kibana GUI to `Stack Management -> Index Patterns`.
Here create two new index patterns (one for the alerts, e.g. `alerts-*` and one for the flows, e.g. `ntopng-*`)
and the exported information are going to appear in the `Discover` section.
