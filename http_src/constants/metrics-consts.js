const ui_types = {
    hide: "hide",
    select: "select",
    input: "input",
};

const sources_url_el_to_source = {
    ifid: (s) => {
	let label = s.ifname;
	if (s.name != null) {
	    label = s.name;
	}
        return {
	    label,
	    value: s.ifid,
        };
    },
    pool: (p) => {
	let label = p.pool_id;
	if (p.name != null) { label = p.name; }
	return {
	    label,
	    value: p.pool_id,
	};
    },
};

const sources_types = [
    {
	id: "interface", //unique id
	regex_page_url: "lua\/if_stats", // regex to match url page
	label: "Interface",
	table_value: "interface",
	query: "iface",
	source_def_array: [{
	    main_source_def: true, 
	    label: "Interface",
	    regex_type: null,
	    sources_url: "lua/rest/v2/get/ntopng/interfaces.lua", // url to get sources list
	    sources_function: null, // custom function that return sources_list, overwrite sources_url
	    value: "ifid", // used in tsQuery parameter, to get init and set value in url
	    value_url: null, // overwrite value to get and set value in url
	    f_get_value_url: null, // overwrite value and value_url to get start value from url
	    f_set_value_url: null, // overwrite value and value_url to set start value in url
	    ui_type: ui_types.select,
	}],
    },
    {
	id: "host",
	regex_page_url: "lua\/host_details",
	label: "Host",
	table_value: "host",
	query: "host",
	source_def_array: [{
	    label: "Interface",
	    sources_url: "lua/rest/v2/get/ntopng/interfaces.lua",
	    value: "ifid", 
	    ui_type: ui_types.select,
	}, {
	    main_source_def: true, 
	    label: "Host",
	    regex_type: "ip",	    
	    value: "host",
	    ui_type: ui_types.input,
	}],
    },
    {
	id: "mac",
	regex_page_url: "lua\/mac_details",
	label: "Mac",
	query: "mac",
	source_def_array: [{
	    label: "Interface",
	    sources_url: "lua/rest/v2/get/ntopng/interfaces.lua",
	    value: "ifid", 
	    ui_type: ui_types.select,
	}, {
	    main_source_def: true, 
	    label: "Mac",
	    regex_type: "macAddress",	    
	    value: "mac",
	    value_url: "host",
	    ui_type: ui_types.input,
	}],
    },
    {
	id: "network",
	regex_page_url: "lua\/network_details",
	label: "Network",
	query: "subnet",
	source_def_array: [{
	    label: "Interface",
	    sources_url: "lua/rest/v2/get/ntopng/interfaces.lua",
	    value: "ifid", 
	    ui_type: ui_types.select,
	}, {
	    main_source_def: true, 
	    label: "Network",
	    regex_type: "text",	    
	    value: "subnet",
	    ui_type: ui_types.input,
	}],	
    },
    {
	id: "as",
	regex_page_url: "lua\/as_details",
	label: "ASN",
	query: "asn",
	source_def_array: [{
	    label: "Interface",
	    sources_url: "lua/rest/v2/get/ntopng/interfaces.lua",
	    value: "ifid", 
	    ui_type: ui_types.select,
	}, {
	    main_source_def: true,
	    label: "ASN",
	    regex_type: "text",
	    value: "asn",
	    ui_type: ui_types.input,
	}],
    },
    {
	id: "country",
	regex_page_url: "lua\/country_details",
	label: "Country",
	query: "country",
	source_def_array: [{
	    label: "Interface",
	    sources_url: "lua/rest/v2/get/ntopng/interfaces.lua",
	    value: "ifid", 
	    ui_type: ui_types.select,
	}, {
	    main_source_def: true,
	    label: "Country",
	    regex_type: "text",
	    value: "country",
	    ui_type: ui_types.input,
	}],
    },
    {
	id: "os",
	regex_page_url: "lua\/os_details",
	label: "OS",
	query: "os",
	source_def_array: [{
	    label: "Interface",
	    sources_url: "lua/rest/v2/get/ntopng/interfaces.lua",
	    value: "ifid", 
	    ui_type: ui_types.select,
	}, {
	    main_source_def: true,
	    label: "OS",
	    regex_type: "text",
	    value: "os",
	    ui_type: ui_types.input,
	}],
    },
    {
	id: "vlan",
	regex_page_url: "lua\/vlan_details",
	label: "VLAN",
	query: "vlan",
	source_def_array: [{
	    label: "Interface",
	    sources_url: "lua/rest/v2/get/ntopng/interfaces.lua",
	    value: "ifid", 
	    ui_type: ui_types.select,
	}, {
	    main_source_def: true,
	    label: "VLAN",
	    regex_type: "text",
	    value: "vlan",
	    ui_type: ui_types.input,
	}],
    },
    {
	id: "pool",
	regex_page_url: "lua\/pool_details",
	label: "Host Pool",
	query: "host_pool",
	source_def_array: [{
	    label: "Interface",
	    sources_url: "lua/rest/v2/get/ntopng/interfaces.lua",
	    value: "ifid", 
	    ui_type: ui_types.select,
	}, {
	    main_source_def: true,
	    label: "Host Pool",
	    regex_type: null,
	    sources_url: "lua/rest/v2/get/host/pools.lua",
	    value: "pool",
	    ui_type: ui_types.select,
	}],
    },
    {
	id: "observation",
	regex_page_url: "lua\/pro\/enterprise\/observation_points",
	label: "Observation",
	query: "obs_point",
	source_def_array: [{
	    label: "Interface",
	    sources_url: "lua/rest/v2/get/ntopng/interfaces.lua",
	    value: "ifid", 
	    ui_type: ui_types.select,
	}, {
	    main_source_def: true,
	    label: "Observation",
	    regex_type: "text",
	    value: "observation_point",
	    ui_type: ui_types.input,
	}],
    },
    {
	id: "pod",
	regex_page_url: "lua\/pod_details",
	label: "Pod",
	value: "pod",
	regex_type: "text",
	sources_sub_url: "lua/rest/v2/get/ntopng/interfaces.lua",
	sub_value: "ifid",
	sub_label: "Interface",
	ui_type: ui_types.select_and_input,
	query: "pod",
  ts_query: "pod",
    },
    {
	id: "container",
	regex_page_url: "lua\/container_details",
	label: "Container",
	value: "container",
	regex_type: "text",
	sources_sub_url: "lua/rest/v2/get/ntopng/interfaces.lua",
	sub_value: "ifid",
	sub_label: "Interface",
	ui_type: ui_types.select_and_input,
	query: "container",
    },
    {
	id: "hash",
	regex_page_url: "lua\/hash_table_details",
	label: "Hash Table",
	value: "hash_table",
	regex_type: "text",
	sources_sub_url: "lua/rest/v2/get/ntopng/interfaces.lua",
	sub_value: "ifid",
	sub_label: "Interface",
	ui_type: ui_types.select_and_input,
	query: "ht",
    },
    {
	id: "system",
	regex_page_url: "lua\/system_stats",
	label: "System Stats",
	value: "ifid",
	sources_function: () => { return [{ label: "", value: -1 }] },
	regex_type: "text",
	ui_type: ui_types.hide,
	query: "system",
    },
    {
	id: "profile",	
	regex_page_url: "lua\/profile_details",
	label: "Profile",
	value: "profile",
	regex_type: "text",
	sources_sub_url: "lua/rest/v2/get/ntopng/interfaces.lua",
	sub_value: "ifid",
	sub_label: "Interface",
	ui_type: ui_types.select_and_input,
	query: "profile",
    },
    {
	id: "n_edge_interface",
	regex_page_url: "lua\/pro\/nedge\/if_stats.lua",
	label: "Profile",
	value: "ifid",
	regex_type: "text",
	ui_type: ui_types.select_and_input,
	query: "iface:nedge",
    },
    {
	id: "redis",
	regex_page_url: "lua\/monitor\/redis_monitor.lua",
	label: "Redis",
	value: "ifid",
	regex_type: "text",
	ui_type: ui_types.select_and_input,
	query: "redis",
    },
    {
	id: "influx",
	regex_page_url: "lua\/monitor\/influxdb_monitor.lua",
	label: "Influx DB",
	value: "ifid",
	regex_type: "text",
	ui_type: ui_types.select_and_input,
	query: "influxdb",
    },
    {
	id: "active_monitoring",
	regex_page_url: "lua\/monitor\/active_monitoring_monitor.lua",
	label: "Active Monitoring",
	value: "am_host",
	regex_type: "text",
	ui_type: ui_types.select_and_select,
	query: "am_host",
	ts_query: "host",
    },
];

const metricsConsts = function() {
    return {
	ui_types,
	sources_url_el_to_source,
	sources_types,
    };
}();

export default metricsConsts;
