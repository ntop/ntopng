import interfaceTopTables from "./interface_top_tables.js";
import hostTopTables from "./host_top_tables.js";
import snmpInterfaceTopTables from "./snmp_interface_top_tables.js";

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
    am_host: (am) => {
	let label = `${am.label} ${am.measurement}`;
	let value = `${am.host},metric:${am.measurement_key}`;
	return {
	    label,
	    value,
	};
    },
};

const sources_types_tables = {
    interface: interfaceTopTables,
    host: hostTopTables,
    snmp_interface: snmpInterfaceTopTables,
    snmp_device: snmpInterfaceTopTables,
    // snmp_interface: [;
};

const sources_types = [
    {
	id: "interface", //unique id
	regex_page_url: "lua\/if_stats", // regex to match url page
	label: i18n("page_stats.source_def.interface"),
	query: "iface",
	source_def_array: [{
	    main_source_def: true, 
	    label: i18n("page_stats.source_def.interface"),
	    regex_type: null,
	    sources_url: "lua/rest/v2/get/ntopng/interfaces.lua", // url to get sources list
	    sources_function: null, // custom function that return sources_list, overwrite sources_url
	    value: "ifid", // used in tsQuery parameter, to get init and set value in url
	    value_url: null, // overwrite value to get and set value in url
	    value_map_sources_res: null,
	    disable_tskey: null,	    
	    f_get_value_url: null, // overwrite value and value_url to get start value from url
	    f_set_value_url: null, // overwrite value and value_url to set start value in url
	    ui_type: ui_types.select,
	}],
    },
    {
	id: "host",
	regex_page_url: "lua\/host_details",
	label: i18n("page_stats.source_def.host"),
	table_value: "host",
	query: "host",
	source_def_array: [{
	    label: i18n("page_stats.source_def.interface"),
	    sources_url: "lua/rest/v2/get/ntopng/interfaces.lua",
	    value: "ifid", 
	    ui_type: ui_types.select,
	}, {
	    main_source_def: true, 
	    label: i18n("page_stats.source_def.host"),
	    regex_type: "ip",	    
	    value: "host",
	    ui_type: ui_types.input,
	}],
    },
    {
	id: "mac",
	regex_page_url: "lua\/mac_details",
	label: i18n("page_stats.source_def.mac"),
	query: "mac",
	source_def_array: [{
	    label: i18n("page_stats.source_def.interface"),
	    sources_url: "lua/rest/v2/get/ntopng/interfaces.lua",
	    value: "ifid", 
	    ui_type: ui_types.select,
	}, {
	    main_source_def: true, 
	    label: i18n("page_stats.source_def.mac"),
	    regex_type: "macAddress",	    
	    value: "mac",
	    value_url: "host",
	    ui_type: ui_types.input,
	}],
    },
    {
	id: "network",
	regex_page_url: "lua\/network_details",
	label: i18n("page_stats.source_def.network"),
	query: "subnet",
	source_def_array: [{
	    label: i18n("page_stats.source_def.interface"),
	    sources_url: "lua/rest/v2/get/ntopng/interfaces.lua",
	    value: "ifid", 
	    ui_type: ui_types.select,
	}, {
	    main_source_def: true, 
	    label: i18n("page_stats.source_def.network"),
	    regex_type: "text",	    
	    value: "subnet",
	    ui_type: ui_types.input,
	}],	
    },
    {
	id: "as",
	regex_page_url: "lua\/as_details",
	label: i18n("page_stats.source_def.as"),
	query: "asn",
	source_def_array: [{
	    label: i18n("page_stats.source_def.interface"),
	    sources_url: "lua/rest/v2/get/ntopng/interfaces.lua",
	    value: "ifid", 
	    ui_type: ui_types.select,
	}, {
	    main_source_def: true,
	    label: i18n("page_stats.source_def.as"),
	    regex_type: "text",
	    value: "asn",
	    ui_type: ui_types.input,
	}],
    },
    {
	id: "country",
	regex_page_url: "lua\/country_details",
	label: i18n("page_stats.source_def.country"),
	query: "country",
	source_def_array: [{
	    label: i18n("page_stats.source_def.interface"),
	    sources_url: "lua/rest/v2/get/ntopng/interfaces.lua",
	    value: "ifid", 
	    ui_type: ui_types.select,
	}, {
	    main_source_def: true,
	    label: i18n("page_stats.source_def.country"),
	    regex_type: "text",
	    value: "country",
	    ui_type: ui_types.input,
	}],
    },
    {
	id: "os",
	regex_page_url: "lua\/os_details",
	label: i18n("page_stats.source_def.os"),
	query: "os",
	source_def_array: [{
	    label: i18n("page_stats.source_def.interface"),
	    sources_url: "lua/rest/v2/get/ntopng/interfaces.lua",
	    value: "ifid", 
	    ui_type: ui_types.select,
	}, {
	    main_source_def: true,
	    label: i18n("page_stats.source_def.os"),
	    regex_type: "text",
	    value: "os",
	    ui_type: ui_types.input,
	}],
    },
    {
	id: "vlan",
	regex_page_url: "lua\/vlan_details",
	label: i18n("page_stats.source_def.vlan"),
	query: "vlan",
	source_def_array: [{
	    label: i18n("page_stats.source_def.interface"),
	    sources_url: "lua/rest/v2/get/ntopng/interfaces.lua",
	    value: "ifid", 
	    ui_type: ui_types.select,
	}, {
	    main_source_def: true,
	    label: i18n("page_stats.source_def.vlan"),
	    regex_type: "text",
	    value: "vlan",
	    ui_type: ui_types.input,
	}],
    },
    {
	id: "pool",
	regex_page_url: "lua\/pool_details",
	label: i18n("page_stats.source_def.pool"),
	query: "host_pool",
	source_def_array: [{
	    label: i18n("page_stats.source_def.interface"),
	    sources_url: "lua/rest/v2/get/ntopng/interfaces.lua",
	    value: "ifid", 
	    ui_type: ui_types.select,
	}, {
	    main_source_def: true,
	    label: i18n("page_stats.source_def.pool"),
	    sources_url: "lua/rest/v2/get/host/pools.lua",
	    value: "pool",
	    ui_type: ui_types.select,
	}],
    },
    {
	id: "system",
	regex_page_url: "lua\/system_stats",
	label: i18n("page_stats.source_def.system"),
	query: "system",
	source_def_array: [{
	    label: i18n("page_stats.source_def.interface"),
	    sources_function: () => { return [{ label: "System", value: -1 }] },
	    value: "ifid", 
	    ui_type: ui_types.hide,
	}],
    },
    {
	id: "profile",	
	regex_page_url: "lua\/profile_details",
	label: i18n("page_stats.source_def.profile"),
	query: "profile",
	source_def_array: [{
	    label: i18n("page_stats.source_def.interface"),
	    sources_url: "lua/rest/v2/get/ntopng/interfaces.lua",
	    value: "ifid", 
	    ui_type: ui_types.select,
	}, {
	    main_source_def: true,
	    label: i18n("page_stats.source_def.profile"),
	    regex_type: "text",
	    value: "profile",
	    ui_type: ui_types.input,
	}],
    },
    {
    	id: "redis",
    	regex_page_url: "lua\/monitor\/redis_monitor.lua",
    	label: i18n("page_stats.source_def.redis"), 
    	query: "redis",
	source_def_array: [{
	    label: i18n("page_stats.source_def.interface"),
	    sources_function: () => { return [{ label: "Redis", value: -1 }] },
	    value: "ifid", 
	    ui_type: ui_types.hide,
	}],
    },
    {
    	id: "influx",
    	regex_page_url: "lua\/monitor\/influxdb_monitor.lua",
    	label: i18n("page_stats.source_def.influx"),
    	query: "influxdb",
	source_def_array: [{
	    label: i18n("page_stats.source_def.interface"),
	    sources_function: () => { return [{ label: "Influx", value: -1 }] },
	    value: "ifid", 
	    ui_type: ui_types.hide,
	}],
    },
    {
	id: "active_monitoring",
	regex_page_url: "lua\/monitor\/active_monitoring_monitor.lua",
	label: i18n("page_stats.source_def.active_monitoring"),
	query: "am",
	source_def_array: [{
	    label: i18n("page_stats.source_def.interface"),
	    sources_function: () => { return [{ label: "", value: -1 }] },
	    value: "ifid", 
	    ui_type: ui_types.hide,
	}, {
	    main_source_def: true,
	    label: i18n("page_stats.source_def.active_monitoring"),
	    sources_url: "lua/rest/v2/get/am_host/list.lua",
	    value: "host",
	    disable_tskey: true,
	    value_map_sources_res: "am_host",
	    ui_type: ui_types.select,
	}],
    },
    {
    	id: "snmp_interface",
	id_group: "snmp",
    	// disable_stats: true,
    	regex_page_url: "lua\/pro\/enterprise\/snmp_interface_details",
    	label: i18n("page_stats.source_def.snmp_interface"),
    	query: "snmp_interface",	
    	source_def_array: [{
    	    label: i18n("page_stats.source_def.interface"),
    	    sources_function: () => { return [{ label: "", value: -1 }] },
    	    value: "ifid", 
    	    ui_type: ui_types.hide,
    	}, {
    	    label: i18n("page_stats.source_def.device"),
    	    regex_type: "ip",
    	    value: "device",
	    value_url: "host",
    	    ui_type: ui_types.input,
    	}, {
	    main_source_def: true,
    	    label: i18n("page_stats.source_def.snmp_interface"),
    	    regex_type: "text",
    	    value: "if_index",
	    value_url: "snmp_port_idx",
    	    ui_type: ui_types.input,
    	}],
    },
    {
    	//todo_test
    	id: "snmp_device",
	id_group: "snmp",
    	// disable_stats: true,
    	regex_page_url: "lua\/pro\/enterprise\/snmp_device_details",
    	label: i18n("page_stats.source_def.snmp_device"),
    	query: "snmp_device",
    	source_def_array: [{
    	    label: i18n("page_stats.source_def.interface"),
    	    sources_function: () => { return [{ label: "", value: -1 }] },
    	    value: "ifid", 
    	    ui_type: ui_types.hide,
    	}, {
	    main_source_def: true,
    	    label: i18n("page_stats.source_def.device"),
    	    regex_type: "ip",
    	    value: "device",
	    value_url: "host",
    	    ui_type: ui_types.input,
    	}],
    },
    {
    	id: "flow_device",
    	regex_page_url: "lua\/pro\/enterprise\/flowdevices_stats",
    	label: i18n("page_stats.source_def.flow_device"),
    	query: "flowdev",
    	source_def_array: [{
	    label: i18n("page_stats.source_def.interface"),
	    sources_url: "lua/rest/v2/get/ntopng/interfaces.lua",
	    value: "ifid", 
	    ui_type: ui_types.select,
    	}, {
	    main_source_def: true,
    	    label: i18n("page_stats.source_def.device"),
    	    regex_type: "ip",
    	    value: "device",
	    value_url: "ip",
    	    ui_type: ui_types.input,
    	}],
    },
    {
    	id: "flow_interface",
    	regex_page_url: "lua\/pro\/enterprise\/flowdevice_interface_details",
    	label: i18n("page_stats.source_def.flow_interface"),
    	query: "flowdev_port",
    	source_def_array: [{
	    label: i18n("page_stats.source_def.interface"),
	    sources_url: "lua/rest/v2/get/ntopng/interfaces.lua",
	    value: "ifid", 
	    ui_type: ui_types.select,
    	}, {
    	    label: i18n("page_stats.source_def.device"),
    	    regex_type: "ip",
    	    value: "device",
	    value_url: "ip",
    	    ui_type: ui_types.input,
    	}, {
	    main_source_def: true,
    	    label: i18n("page_stats.source_def.port"),
    	    regex_type: "port",
    	    value: "port",
	    value_url: "snmp_port_idx",
    	    ui_type: ui_types.input,
    	}],
    },
    {
    	id: "sflow_device",
    	regex_page_url: "lua\/pro\/enterprise\/sflowdevices_stats",
    	label: i18n("page_stats.source_def.sflow_device"),
    	query: "sflowdev",
    	source_def_array: [{
	    label: i18n("page_stats.source_def.interface"),
	    sources_url: "lua/rest/v2/get/ntopng/interfaces.lua",
	    value: "ifid", 
	    ui_type: ui_types.select,
    	}, {
	    main_source_def: true,
    	    label: i18n("page_stats.source_def.device"),
    	    regex_type: "ip",
    	    value: "device",
	    value_url: "ip",
    	    ui_type: ui_types.input,
    	}],
    },
    {
    	id: "sflow_interface",
    	regex_page_url: "lua\/pro\/enterprise\/sflowdevice_interface_details",
    	label: i18n("page_stats.source_def.sflow_interface"),
    	query: "sflowdev_port",
    	source_def_array: [{
	    label: i18n("page_stats.source_def.interface"),
	    sources_url: "lua/rest/v2/get/ntopng/interfaces.lua",
	    value: "ifid", 
	    ui_type: ui_types.select,
    	}, {
    	    label: i18n("page_stats.source_def.device"),
    	    regex_type: "ip",
    	    value: "device",
	    value_url: "ip",
    	    ui_type: ui_types.input,
    	}, {
	    main_source_def: true,
    	    label: i18n("page_stats.source_def.port"),
    	    regex_type: "port",
    	    value: "port",
	    value_url: "snmp_port_idx",
    	    ui_type: ui_types.input,
    	}],
    },
    {
    	id: "observation_point",
    	regex_page_url: "lua\/pro\/enterprise\/observation_points",
    	label: i18n("page_stats.source_def.observation_point"),
    	query: "obs_point",
    	source_def_array: [{
    	    label: i18n("page_stats.source_def.interface"),
    	    sources_url: "lua/rest/v2/get/ntopng/interfaces.lua",
    	    value: "ifid", 
    	    ui_type: ui_types.select,
    	}, {
    	    main_source_def: true,
    	    label: i18n("page_stats.source_def.observation_point"),
    	    regex_type: "text",
    	    value: "obs_point",
    	    value_url: "observation_point",
    	    ui_type: ui_types.input,
    	}],
    },
    {
	//todo_test
	id: "pod",
	regex_page_url: "lua\/pod_details",
	label: i18n("page_stats.source_def.pod"),	
	query: "pod",
	source_def_array: [{
	    label: i18n("page_stats.source_def.interface"),
	    sources_url: "lua/rest/v2/get/ntopng/interfaces.lua",
	    value: "ifid", 
	    ui_type: ui_types.select,
	}, {
	    main_source_def: true,
	    label: i18n("page_stats.source_def.pod"),
	    regex_type: "text",
	    value: "pod",
	    ui_type: ui_types.input,
	}],
    }, {
	//todo_test
	id: "container",
	regex_page_url: "lua\/container_details",
	label: i18n("page_stats.source_def.container"),
	query: "container",
	source_def_array: [{
	    label: i18n("page_stats.source_def.interface"),
	    sources_url: "lua/rest/v2/get/ntopng/interfaces.lua",
	    value: "ifid", 
	    ui_type: ui_types.select,
	}, {
	    main_source_def: true,
	    label: i18n("page_stats.source_def.container"),
	    regex_type: "text",
	    value: "container",
	    ui_type: ui_types.input,
	}],
    },
    // {
    // 	id: "n_edge_interface",
    // 	regex_page_url: "lua\/pro\/nedge\/if_stats.lua",
    // 	label: "Profile nEdge",
    // 	value: "ifid",
    // 	regex_type: "text",
    // 	ui_type: ui_types.select_and_input,
    // 	query: "iface:nedge",
    // },
];

const metricsConsts = function() {
    return {
	ui_types,
	sources_url_el_to_source,
	sources_types,
	sources_types_tables,
    };
}();

export default metricsConsts;
