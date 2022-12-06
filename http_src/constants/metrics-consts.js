import { DataTableUtils } from "../utilities/datatable/sprymedia-datatable-utils";
import formatterUtils from "../utilities/formatter-utils.js";
import { ntopng_utility, ntopng_url_manager } from "../services/context/ntopng_globals_services.js";
import NtopUtils from "../utilities/ntop-utils";

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

const table_column_render_types = {
    metric: "metric",
    text: "text",
    percentage: "percentage",
    button_link: "button_link",
};

const bytesToSizeFormatter = formatterUtils.getFormatter(formatterUtils.types.bytes.id);
const handlerIdAddLinkApplication = "page-stats-action-link-application";
const handlerIdJumpHistorical = "page-stats-action-jump-historical";

const sources_types_tables = {
    interface: [{
	    table_value: "interface",
	    title: i18n('page_stats.top.top_applications'),
	    view: "top_protocols",
	    default_sorting_columns: 2,
	    default: true,
	    
	    columns: [{
		columnName: i18n("application"), name: 'application', data: 'protocol', handlerId: handlerIdAddLinkApplication,
		render: function(data, type, service) {
		    let context = this;
		    let handler = {
			handlerId: handlerIdAddLinkApplication,
			onClick: function() {
			    console.log(data);
			    console.log(service);
			    let schema = `top:${service.ts_schema}`;
			    context.add_metric_from_metric_schema(schema, service.ts_query)
			},
		    };
		    return DataTableUtils.createLinkCallback({ text: data.label, handler });
		},
	    }, {
	    	columnName: i18n("traffic"), name: 'traffic', data: 'traffic', orderable: false,
	    	render: (data) => {
	    	    return bytesToSizeFormatter(data);
	    	    //return NtopUtils.bytesToSize(data)
	    	},
	    }, {
		columnName: i18n("percentage"), name: 'traffic_perc', data: 'percentage',
		render: (data) => {
		    const percentage = data.toFixed(1);
		    return NtopUtils.createProgressBar(percentage)
		}
	    }, {
		columnName: i18n("actions"), width: '5%', name: 'actions', className: 'text-center', orderable: false, responsivePriority: 0, handlerId: handlerIdJumpHistorical,
		render_if: function(context) { return context.is_history_enabled },
		render: function(data, type, service) {
		    let context = this;
		    const jump_to_historical = {
			handlerId: handlerIdJumpHistorical,
			onClick: function() {
			    let status = context.status;
			    let l7_proto = ntopng_url_manager.serialize_param("l7proto", `${service.protocol.id};eq`);
			    let historical_flows_url = `${http_prefix}/lua/pro/db_search.lua?epoch_begin=${context.status.epoch_begin}&epoch_end=${context.status.epoch_end}&${l7_proto}`;
			    let source_type = context.source_type;
			    let source_array = context.source_array;
			    
			    let params = "";
			    let params_array = source_type.source_def_array.map((source_def, i) => {
				let source = source_array[i];
				if (source_def.value == "ifid") {
				    return ntopng_url_manager.serialize_param("ifid", source.value);
				} else if (source_def.value == "host") {
				    return ntopng_url_manager.serialize_param("ip", `${source.value};eq`);
				}
			    });
			    params = params_array.join("&");
			    historical_flows_url = `${historical_flows_url}&${params}`;
			    console.log(historical_flows_url);
			    window.open(historical_flows_url);
			}
		    };
		    return DataTableUtils.createActionButtons([
			{ class: 'dropdown-item', href: '#', title: i18n('db_explorer.historical_data'), handler: jump_to_historical },
		    ]);
		}
	    },],
    }, {
	    table_value: "interface",
	    title: i18n('page_stats.top.top_categories'),
	    view: "top_categories",
	    default_sorting_columns: 2,
	    default: true,
	    
	    columns: [{
		columnName: i18n("page_stats.top.category"), name: 'category', data: 'category', handlerId: handlerIdAddLinkApplication,
		render: function(data, type, service) {
		    let context = this;
		    let handler = {
			handlerId: handlerIdAddLinkApplication,
			onClick: function() {
			    console.log(data);
			    console.log(service);
			    let schema = `top:${service.ts_schema}`;
			    context.add_metric_from_metric_schema(schema, service.ts_query)
			},
		    };
		    return DataTableUtils.createLinkCallback({ text: data.label, handler });
		},
	    }, {
	    	columnName: i18n("traffic"), name: 'traffic', data: 'traffic', orderable: false,
	    	render: (data) => {
	    	    return bytesToSizeFormatter(data);
	    	    //return NtopUtils.bytesToSize(data)
	    	},
	    }, {
		columnName: i18n("percentage"), name: 'traffic_perc', data: 'percentage',
		render: (data) => {
		    const percentage = data.toFixed(1);
		    return NtopUtils.createProgressBar(percentage)
		}
	    }, {
		columnName: i18n("actions"), width: '5%', name: 'actions', className: 'text-center', orderable: false, responsivePriority: 0, handlerId: handlerIdJumpHistorical,
		render_if: function(context) { return context.is_history_enabled },
		render: function(data, type, service) {
		    let context = this;
		    const jump_to_historical = {
			handlerId: handlerIdJumpHistorical,
			onClick: function() {
			    let status = context.status;
			    let category = ntopng_url_manager.serialize_param("l7cat", `${service.category.id};eq`);
			    let historical_flows_url = `${http_prefix}/lua/pro/db_search.lua?epoch_begin=${context.status.epoch_begin}&epoch_end=${context.status.epoch_end}&${category}`;
			    let source_type = context.source_type;
			    let source_array = context.source_array;
			    
			    let params = "";
			    let params_array = source_type.source_def_array.map((source_def, i) => {
				let source = source_array[i];
				if (source_def.value == "ifid") {
				    return ntopng_url_manager.serialize_param("ifid", source.value);
				} else if (source_def.value == "host") {
				    return ntopng_url_manager.serialize_param("ip", `${source.value};eq`);
				}
			    });
			    params = params_array.join("&");
			    historical_flows_url = `${historical_flows_url}&${params}`;
			    console.log(historical_flows_url);
			    window.open(historical_flows_url);
			}
		    };
		    return DataTableUtils.createActionButtons([
			{ class: 'dropdown-item', href: '#', title: i18n('db_explorer.historical_data'), handler: jump_to_historical },
		    ]);
		}
	    },],
    }, {
	    table_value: "interface",
	    title: i18n('page_stats.top.top_senders'),
	    view: "top_senders",
	    default_sorting_columns: 2,
	    
	    columns: [{
		columnName: i18n("page_stats.top.host_name"), name: 'host_name', data: 'host', handlerId: handlerIdAddLinkApplication,
		render: function(data, type, service) {
		    let context = this;
		    let handler = {
			handlerId: handlerIdAddLinkApplication,
			onClick: async function() {
			    console.log(data);
			    console.log(service);
			    let schema = `host:traffic`;
			    context.add_ts_group_from_source_value_dict("host", service.tags, schema);
			},
		    };
		    if (context.sources_types_enabled["host"]) {
			return DataTableUtils.createLinkCallback({ text: data.label, handler });
		    }
		    return data.label;
		},
	    }, {
	    	columnName: i18n("page_stats.top.sent"), name: 'sent', data: 'traffic', orderable: false,
	    	render: (data) => {
	    	    return bytesToSizeFormatter(data);
	    	    //return NtopUtils.bytesToSize(data)
	    	},
	    }, // {
	    // 	columnName: i18n("percentage"), name: 'traffic_perc', data: 'percentage',
	    // 	render: (data) => {
	    // 	    const percentage = data.toFixed(1);
	    // 	    return NtopUtils.createProgressBar(percentage)
	    // 	}
	    // },
		      {
		columnName: i18n("actions"), width: '5%', name: 'actions', className: 'text-center', orderable: false, responsivePriority: 0, handlerId: handlerIdJumpHistorical,
		render_if: function(context) { return context.is_history_enabled },
		render: function(data, type, service) {
		    let context = this;
		    const jump_to_historical = {
			handlerId: handlerIdJumpHistorical,
			onClick: function() {
			    let status = context.status;
			    let historical_flows_url = `${http_prefix}/lua/pro/db_search.lua?epoch_begin=${context.status.epoch_begin}&epoch_end=${context.status.epoch_end}`;
			    let source_type = context.source_type;
			    let source_array = context.source_array;
			    
			    let params = "";			    
			    let params_array = [];
			    for (let key in service.tags) {
				let value = service.tags[key];
				let p_url = "";
				if (key == "ifid") {
				    p_url = ntopng_url_manager.serialize_param(key, value);
				} else if (key == "host") {
				    p_url = ntopng_url_manager.serialize_param("ip", `${value};eq`);
				}
				params_array.push(p_url);
			    }
			    params = params_array.join("&");
			    historical_flows_url = `${historical_flows_url}&${params}`;
			    console.log(historical_flows_url);
			    window.open(historical_flows_url);
			}
		    };
		    return DataTableUtils.createActionButtons([
			{ class: 'dropdown-item', href: '#', title: i18n('db_explorer.historical_data'), handler: jump_to_historical },
		    ]);
		}
	    },],
	}, {
	    table_value: "interface",
	    title: i18n('page_stats.top.top_receivers'),
	    view: "top_receivers",
	    default_sorting_columns: 2,
	    
	    columns: [{
		columnName: i18n("page_stats.top.host_name"), name: 'host_name', data: 'host', handlerId: handlerIdAddLinkApplication,
		render: function(data, type, service) {
		    let context = this;
		    let handler = {
			handlerId: handlerIdAddLinkApplication,
			onClick: async function() {
			    console.log(data);
			    console.log(service);
			    let schema = `host:traffic`;
			    context.add_ts_group_from_source_value_dict("host", service.tags, schema);
			},
		    };
		    if (context.sources_types_enabled["host"]) {
			return DataTableUtils.createLinkCallback({ text: data.label, handler });
		    }
		    return data.label;
		},
	    }, {
	    	columnName: i18n("page_stats.top.received"), name: 'received', data: 'traffic', orderable: false,
	    	render: (data) => {
	    	    return bytesToSizeFormatter(data);
	    	    //return NtopUtils.bytesToSize(data)
	    	},
	    }, // {
	    // 	columnName: i18n("percentage"), name: 'traffic_perc', data: 'percentage',
	    // 	render: (data) => {
	    // 	    const percentage = data.toFixed(1);
	    // 	    return NtopUtils.createProgressBar(percentage)
	    // 	}
	    // },
		      {
		columnName: i18n("actions"), width: '5%', name: 'actions', className: 'text-center', orderable: false, responsivePriority: 0, handlerId: handlerIdJumpHistorical,
		render_if: function(context) { return context.is_history_enabled },
		render: function(data, type, service) {
		    let context = this;
		    const jump_to_historical = {
			handlerId: handlerIdJumpHistorical,
			onClick: function() {
			    let status = context.status;
			    let historical_flows_url = `${http_prefix}/lua/pro/db_search.lua?epoch_begin=${context.status.epoch_begin}&epoch_end=${context.status.epoch_end}`;
			    let source_type = context.source_type;
			    let source_array = context.source_array;
			    
			    let params = "";			    
			    let params_array = [];
			    for (let key in service.tags) {
				let value = service.tags[key];
				let p_url = "";
				if (key == "ifid") {
				    p_url = ntopng_url_manager.serialize_param(key, value);
				} else if (key == "host") {
				    p_url = ntopng_url_manager.serialize_param("ip", `${value};eq`);
				}
				params_array.push(p_url);
			    }
			    params = params_array.join("&");
			    historical_flows_url = `${historical_flows_url}&${params}`;
			    console.log(historical_flows_url);
			    window.open(historical_flows_url);
			}
		    };
		    return DataTableUtils.createActionButtons([
			{ class: 'dropdown-item', href: '#', title: i18n('db_explorer.historical_data'), handler: jump_to_historical },
		    ]);
		}
	    },],
	}],
};

sources_types_tables["host"] = [ntopng_utility.clone(sources_types_tables["interface"][0])];
sources_types_tables["host"].forEach((table_def) => table_def.table_value = "host");

const sources_types = [
    {
	id: "interface", //unique id
	regex_page_url: "lua\/if_stats", // regex to match url page
	label: "Interface",
	query: "iface",
	source_def_array: [{
	    main_source_def: true, 
	    label: "Interface",
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
	    sources_url: "lua/rest/v2/get/host/pools.lua",
	    value: "pool",
	    ui_type: ui_types.select,
	}],
    },
    {
	id: "system",
	regex_page_url: "lua\/system_stats",
	label: "System Stats",
	query: "system",
	source_def_array: [{
	    label: "Interface",
	    sources_function: () => { return [{ label: "System", value: -1 }] },
	    value: "ifid", 
	    ui_type: ui_types.hide,
	}],
    },
    {
	id: "profile",	
	regex_page_url: "lua\/profile_details",
	label: "Profile",
	query: "profile",
	source_def_array: [{
	    label: "Interface",
	    sources_url: "lua/rest/v2/get/ntopng/interfaces.lua",
	    value: "ifid", 
	    ui_type: ui_types.select,
	}, {
	    main_source_def: true,
	    label: "Profile",
	    regex_type: "text",
	    value: "profile",
	    ui_type: ui_types.input,
	}],
    },
    {
    	id: "redis",
    	regex_page_url: "lua\/monitor\/redis_monitor.lua",
    	label: "Redis Stats", 
    	query: "redis",
	source_def_array: [{
	    label: "Interface",
	    sources_function: () => { return [{ label: "Redis", value: -1 }] },
	    value: "ifid", 
	    ui_type: ui_types.hide,
	}],
    },
    {
    	id: "influx",
    	regex_page_url: "lua\/monitor\/influxdb_monitor.lua",
    	label: "Influx DB Stats",
    	query: "influxdb",
	source_def_array: [{
	    label: "Interface",
	    sources_function: () => { return [{ label: "Influx", value: -1 }] },
	    value: "ifid", 
	    ui_type: ui_types.hide,
	}],
    },
    {
	id: "active_monitoring",
	regex_page_url: "lua\/monitor\/active_monitoring_monitor.lua",
	label: "Active Monitoring",
	query: "am",
	source_def_array: [{
	    label: "Interface",
	    sources_function: () => { return [{ label: "", value: -1 }] },
	    value: "ifid", 
	    ui_type: ui_types.hide,
	}, {
	    main_source_def: true,
	    label: "Active Monitoring",
	    sources_url: "lua/rest/v2/get/am_host/list.lua",
	    value: "host",
	    disable_tskey: true,
	    value_map_sources_res: "am_host",
	    ui_type: ui_types.select,
	}],
    },
    {
    	//todo_test
    	id: "snmp_interface",
    	// disable_stats: true,
    	regex_page_url: "lua\/pro\/enterprise\/snmp_interface_details",
    	label: "SNMP",
    	query: "snmp",	
    	source_def_array: [{
    	    label: "Interface",
    	    sources_function: () => { return [{ label: "", value: -1 }] },
    	    value: "ifid", 
    	    ui_type: ui_types.hide,
    	}, {
    	    label: "Device",
    	    regex_type: "ip",
    	    value: "device",
	    value_url: "host",
    	    ui_type: ui_types.input,
    	}, {
    	    label: "SNMP Interface",
    	    regex_type: "text",
    	    value: "if_index",
	    value_url: "snmp_port_idx",
    	    ui_type: ui_types.input,
    	}],
    },
    {
	//todo_test
	id: "pod",
	regex_page_url: "lua\/pod_details",
	label: "Pod",	
	query: "pod",
	source_def_array: [{
	    label: "Interface",
	    sources_url: "lua/rest/v2/get/ntopng/interfaces.lua",
	    value: "ifid", 
	    ui_type: ui_types.select,
	}, {
	    main_source_def: true,
	    label: "Pod",
	    regex_type: "text",
	    value: "pod",
	    ui_type: ui_types.input,
	}],
    }, {
	//todo_test
	id: "container",
	regex_page_url: "lua\/container_details",
	label: "Container",
	query: "container",
	source_def_array: [{
	    label: "Interface",
	    sources_url: "lua/rest/v2/get/ntopng/interfaces.lua",
	    value: "ifid", 
	    ui_type: ui_types.select,
	}, {
	    main_source_def: true,
	    label: "Container",
	    regex_type: "text",
	    value: "container",
	    ui_type: ui_types.input,
	}],
    },
    // {
    // 	//todo_test
    // 	id: "snmp",
    // 	serie_id_field: "ext_label",
    // 	disable_stats: true,
    // 	regex_page_url: "lua\/pro\/enterprise\/snmp_device_details",
    // 	label: "SNMP",
    // 	query: "snmp",	
    // 	source_def_array: [{
    // 	    label: "Interface",
    // 	    sources_function: () => { return [{ label: "", value: -1 }] },
    // 	    value: "ifid", 
    // 	    ui_type: ui_types.hide,
    // 	}, {
    // 	    main_source_def: true,
    // 	    label: "Device",
    // 	    regex_type: "ip",
    // 	    value: "device",
    // 	    value_url: "host",
    // 	    ui_type: ui_types.input,
    // 	}],
    // },
    // {
    // 	//todo_test
    // 	id: "observation",
    // 	regex_page_url: "lua\/pro\/enterprise\/observation_points",
    // 	label: "Observation",
    // 	query: "obs_point",
    // 	source_def_array: [{
    // 	    label: "Interface",
    // 	    sources_url: "lua/rest/v2/get/ntopng/interfaces.lua",
    // 	    value: "ifid", 
    // 	    ui_type: ui_types.select,
    // 	}, {
    // 	    main_source_def: true,
    // 	    label: "Observation",
    // 	    regex_type: "text",
    // 	    value: "observation_point",
    // 	    ui_type: ui_types.input,
    // 	}],
    // },
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
