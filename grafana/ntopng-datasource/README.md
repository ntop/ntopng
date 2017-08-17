## ntopng Datasource

The official ntopng Grafana datasource plugin lets you quickly
navigate ntopng data from inside the beautiful Grafana dashboards.

### Setting Up the Datasource

To set up the datasource visit Grafana Datasources page and select the
green button `Add a datasource`. Select `ntopng` as the datasource
`Type` in the page that opens.

The HTTP url must point to a running ntopng instance, to the endpoint
`/lua/modules/grafana`. The `Access` method must be set to
`Direct`. An example of a full HTTP url that assumes there is an
ntopng instance running on `localhost` port `3001` is the following:

`http://localhost:3001/lua/modules/grafana` 

Tick `Basic Auth` if your ntopng instance has authentication enabled
and specify a username-password pair in fields `User` and
`Password`. The pair must identify an ntopng user. Leave the `Basic
Auth` checkbock unticked if ntopng has no authentication
(`--disable-login`).

Finally, hit the button `Save and Test` to verify the datasource is
working properly. A green message `Success: Data souce is working`
appears to confirm the datasource is properly set up.

### Supported metrics

Once the datasource is set up, ntopng metrics can be charted in any
Grafana dashboard.

Supported metrics are:
- Interface metrics
- Host metrics

Metrics that identify an interface are prefixed with a `interface_`
that precedes the actual interface name. Similarly,  metrics that
identify an host are prefixed with a `host_` followed by the actual
host ip address.

Interface and host metrics have a suffix that contain the type of
metric (i.e., `traffic` for traffic rates and traffic totals  or
`allprotocols` for layer-7 application protocol rates).
The type of metric is followed by the unit of measure (i.e., `bps`
for bits per second, `pps` for packets per second, and `bytes`).

#### Interface Metrics

Supported interface metrics are:
- Traffic rates, in bits and packets per second
- Traffic totals, both in Bytes and packets
- Application protocol rates, in bits per second

#### Host Metrics

Supported host metrics are:
- Traffic rate in bits per second
- Traffic total in Bytes
- Application protocol rates in bits per second.
