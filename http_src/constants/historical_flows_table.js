const historical_flows_table = {
    columns: [
	{
	    "name": "first_seen",
	    "data": "first_seen",
	},
	{
	    "name": "last_seen",
	    "data": "last_seen",
	},
	{
	    "name": "l4proto",
	    "data": "l4proto",
	},
	{
	    "name": "l7proto",
	    "data": "l7proto",
	},
	{
	    "name": "score",
	    "data": "score",
	},
	{
	    "name": "flow",
	    "data": "flow",
	    "orderable": false,
	},
	{
	    "name": "packets",
	    "data": "packets",
	},
	{
	    "name": "bytes",
	    "data": "bytes",
	},
	{
	    "name": "throughput",
	    "data": "throughput",
	},
	{
	    "name": "cli_asn",
	    "data": "cli_asn",
	},
	{
	    "name": "srv_asn",
	    "data": "srv_asn",
	},
	{
	    "name": "l7cat",
	    "data": "l7cat",
	},
	{
	    "name": "alert_id",
	    "data": "alert_id",
	},
	{
	    "name": "flow_risk",
	    "data": "flow_risk",
	},
	{
	    "name": "src2dst_tcp_flags",
	    "data": "src2dst_tcp_flags",
	},
	{
	    "name": "dst2src_tcp_flags",
	    "data": "dst2src_tcp_flags",
	},
	{
	    "name": "cli_nw_latency",
	    "data": "cli_nw_latency",
	},
	{
	    "name": "srv_nw_latency",
	    "data": "srv_nw_latency",
	},
	{
	    "name": "info",
	    "data": "info",
	},
	{
	    "name": "observation_point_id",
	    "data": "observation_point_id",
	    "className": "no-wrap"
	},
	{
	    "name": "probe_ip",
	    "data": "probe_ip",
	},
	{
	    "name": "cli_network",
	    "data": "cli_network",
	},
	{
	    "name": "srv_network",
	    "data": "srv_network",
	},
	{
	    "name": "cli_host_pool_id",
	    "data": "cli_host_pool_id",
	},
	{
	    "name": "srv_host_pool_id",
	    "data": "srv_host_pool_id",
	},
	{
	    "name": "input_snmp",
	    "data": "input_snmp",
	},
	{
	    "name": "output_snmp",
	    "data": "output_snmp",
	},
	{
	    "name": "cli_country",
	    "data": "cli_country",
	},
	{
	    "name": "srv_country",
	    "data": "srv_country",
	},
	{
	    "name": "community_id",
	    "data": "community_id",
	},
    ]
};

export default historical_flows_table;
