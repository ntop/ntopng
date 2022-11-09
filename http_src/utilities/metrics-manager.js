/**
    (C) 2022 - ntop.org
*/
import { ntopng_utility, ntopng_url_manager } from "../services/context/ntopng_globals_services.js";
import NtopUtils from "./ntop-utils.js";

const set_timeseries_groups_in_url = (timeseries_groups) => {
    let params_timeseries_groups = [];
    timeseries_groups.forEach((ts_group) => {
	let param = get_ts_group_url_param(ts_group);
	params_timeseries_groups.push(param);
    });
    let url_timeseries_groups = params_timeseries_groups.join(";");
    ntopng_url_manager.set_key_to_url("timeseries_groups", url_timeseries_groups);
};

function get_ts_group_url_param(ts_group) {
    let timeseries = [];
    ts_group.timeseries.forEach((ts) => {
	timeseries.push(`${ts.id}=${ts.raw}:${ts.past}:${ts.avg}:${ts.perc_95}`);
    });
    let metric_schema_query = ts_group.metric.schema;
    if (ts_group.metric.query != null) {
	metric_schema_query = `${metric_schema_query}+${ts_group.metric.query}`;
    }
    let timeseries_param = timeseries.join("|");
    let source_value_query = ts_group.source.value;
    if (ts_group.source.sub_value != null) {
	source_value_query = `${source_value_query}+${ts_group.source.sub_value}`;
    }
    let param = `${ts_group.source_type.id},${source_value_query},${metric_schema_query},${timeseries_param}`;
    return param;
}

const get_timeseries_groups_from_url = async (http_prefix, url_timeseries_groups) => {
    if (url_timeseries_groups == null) {
	url_timeseries_groups = ntopng_url_manager.get_url_entry("timeseries_groups");
    }
    if (url_timeseries_groups == null || url_timeseries_groups == "") {
	return null;
    }
    let groups = url_timeseries_groups.split(";");
    if (!groups?.length > 0) {
	return null;
    }
    let timeseries_groups = Promise.all(groups.map(async (g) => {
	let ts_group = await get_url_param_from_ts_group(g);
	return ts_group;
    }));
    return timeseries_groups;
};

const get_ts_group = (source_type, source, metric) => {
    let id = get_ts_group_id(source_type, source, metric);
    let timeseries = [];
    for (let key in metric.timeseries) {
	let ts = metric.timeseries[key];
	timeseries.push({
	    id: key,
	    label: ts.label,
	    raw: true,
	    past: false,
	    avg: false,
	    perc_95: false,
	});
    }
    return {
	id, source_type, source, metric, timeseries,
    };
};

const get_default_timeseries_groups = async (http_prefix, metric_ts_schema) => {
    let source_type = get_current_page_source_type();
    let source = await get_default_source(http_prefix, source_type);
    let metrics = await get_metrics(http_prefix, source_type, source);
    let metric = get_default_metric(metrics, metric_ts_schema);
    let ts_group = get_ts_group(source_type, source, metric);
    return [ts_group];
};

async function get_url_param_from_ts_group(ts_group_url_param) {
    let g = ts_group_url_param;
    let info = g.split(",");
    let source_type_id = info[0];
    let source_value_query = info[1];
    let source_value_query_array = source_value_query.split("+");
    if (source_value_query_array.lenght < 2) {
	source_value_query_array.push(null);
    }
    let metric_schema_query = info[2];
    let metric_schema_query_array = metric_schema_query.split("+");
    if (metric_schema_query_array.lenght < 2) {
	metric_schema_query_array.push(null);
    }
    let timeseries_url = info[3];

    let source_type = get_source_type_from_id(source_type_id);
    let source = await get_source_from_value(http_prefix, source_type, source_value_query_array[0], source_value_query_array[1]);
    let metric = await get_metrics_from_schema(http_prefix, source_type, source, metric_schema_query_array[0], metric_schema_query_array[1]);
    let timeseries = get_timeseries(timeseries_url, metric);
    return {
	id: get_ts_group_id(source_type, source, metric),
	source_type,
	source,
	metric,
	timeseries,
    };
}

const get_ts_group_id = (source_type, source, metric) => {
    let metric_id = metric.schema;
    if (metric.query != null) {
	metric_id = `${metric_id} - ${metric.query}`;
    }
    let source_value = source.value;
    if (source.sub_value != null) {
	source_value = `${source_value}_${source.sub_value}`
    }
    return `${source_type.value} - ${source_value} - ${metric_id}`;
};

function get_timeseries(timeseries_url, metric) {
    let ts_url_array = timeseries_url.split("|");
    let r = /(.+)=(.+):(.+):(.+):(.+)/;
    let timeseries = [];
    ts_url_array.forEach((ts_url) => {
	let values = r.exec(ts_url);
	let id = values[1];
	let label = metric.timeseries[id].label;
	let raw = JSON.parse(values[2]);
	let past = JSON.parse(values[3]);
	let avg = JSON.parse(values[4]);
	let perc_95 = JSON.parse(values[5]);
	timeseries.push({
	    id, label, raw, past, avg, perc_95,
	});
    });
    return timeseries;
}

const ui_types = {
    hide: "hide",
    select: "select",
    select_and_select: "select_and_select",
    select_and_input: "select_and_input",
};

// dictionary of functions to convert an element of source_url rest result to a source ({label, value })
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
	id: "interface",
	regex_page_url: "lua\/if_stats",
	label: "Interface",
	sources_url: "lua/rest/v2/get/ntopng/interfaces.lua",
	value: "ifid",
	ui_type: ui_types.select,
	table_value: "interface",
	query: "iface",
    },
    {
	id: "host",
	regex_page_url: "lua\/host_details",
	label: "Host",
	value: "host",
	regex_type: "ip",
	sources_sub_url: "lua/rest/v2/get/ntopng/interfaces.lua",
	sub_value: "ifid",
	sub_label: "Interface",
	ui_type: ui_types.select_and_input,
	table_value: "host",
	query: "host",
    },
    {
	id: "mac",
	regex_page_url: "lua\/mac_details",
	label: "Mac",
	value_url: "host",
	value: "mac",
	regex_type: "macAddress",
	sources_sub_url: "lua/rest/v2/get/ntopng/interfaces.lua",
	sub_value: "ifid",
	sub_label: "Interface",
	ui_type: ui_types.select_and_input,
	query: "mac",
    },
    {
	id: "network",
	regex_page_url: "lua\/network_details",
	label: "Network",
	// value_url: "subnet",
	value: "subnet",
	regex_type: "text",
	sources_sub_url: "lua/rest/v2/get/ntopng/interfaces.lua",
	sub_value: "ifid",
	sub_label: "Interface",
	ui_type: ui_types.select_and_input,
	query: "subnet",
    },
    {
	id: "as",
	regex_page_url: "lua\/as_details",
	label: "ASN",
	value: "asn",
	regex_type: "text",
	sources_sub_url: "lua/rest/v2/get/ntopng/interfaces.lua",
	sub_value: "ifid",
	sub_label: "Interface",
	ui_type: ui_types.select_and_input,
	query: "asn",
    },
    {
	id: "country",
	regex_page_url: "lua\/country_details",
	label: "Country",
	value: "country",
	regex_type: "text",
	sources_sub_url: "lua/rest/v2/get/ntopng/interfaces.lua",
	sub_value: "ifid",
	sub_label: "Interface",
	ui_type: ui_types.select_and_input,
	query: "country",
    },
    {
	id: "os",
	regex_page_url: "lua\/os_details",
	label: "OS",
	value: "os",
	regex_type: "text",
	sources_sub_url: "lua/rest/v2/get/ntopng/interfaces.lua",
	sub_value: "ifid",
	sub_label: "Interface",
	ui_type: ui_types.select_and_input,
	query: "os",
    },
    {
	id: "vlan",
	regex_page_url: "lua\/vlan_details",
	label: "VLAN",
	value: "vlan",
	regex_type: "text",
	sources_sub_url: "lua/rest/v2/get/ntopng/interfaces.lua",
	sub_value: "ifid",
	sub_label: "Interface",
	ui_type: ui_types.select_and_input,
	query: "vlan",
    },
    {
	id: "pool",
	regex_page_url: "lua\/pool_details",
	label: "Host Pool",
	// get sources_url() { return `lua/rest/v2/get/host/pools.lua?_=${Date.now()}` },
	sources_url: `lua/rest/v2/get/host/pools.lua`,
	value: "pool",
	regex_type: "text",
	sources_sub_url: "lua/rest/v2/get/ntopng/interfaces.lua",
	sub_value: "ifid",
	sub_label: "Interface",
	ui_type: ui_types.select_and_select,
	query: "host_pool",
    },
    {
	id: "observation",
	regex_page_url: "lua\/pro\/enterprise\/observation_points",
	label: "Observation",
	value: "observation_point",
	regex_type: "text",
	sources_sub_url: "lua/rest/v2/get/ntopng/interfaces.lua",
	sub_value: "ifid",
	sub_label: "Interface",
	ui_type: ui_types.select_and_input,
	query: "obs_point",
  ts_query: "obs_point",
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
	query: "process",
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
	ui_type: ui_types.select_and_input,
	query: "am_host",
	ts_query: "host",
    },
];

const get_source_type_from_id = (source_type_id) => {
    return sources_types.find((st) => st.id == source_type_id);
};

async function get_default_sub_source(http_prefix, sub_source_type_id) {
    let sub_source_type = get_source_type_from_id(sub_source_type_id);
    return get_default_source(http_prefix, sub_source_type);    
}

const get_default_source = async (http_prefix, source_type) => {
    let source_value = get_default_source_value(source_type);
    let source_sub_value;
    if (source_type.sub_value) {
	source_sub_value = get_default_source_value({ value: source_type.sub_value })
    }
    let source = await get_source_from_value(http_prefix, source_type, source_value, source_sub_value);
    return source;
};

async function add_source_to_sources(http_prefix, source_type, source) {
    let sources = await get_sources(http_prefix, source_type);
    let is_found = sources.some((s) => s.value == source.value && s.sub_value == source.sub_value);
    if (is_found == false) {
	sources.push(source);
    }
}

const get_source_from_value = async (http_prefix, source_type, source_value, source_sub_value) => {
    if (source_type == null) {
	source_type = get_current_page_source_type();
    }
    if (source_type.sources_url || source_type.sources_function) {
	let sources;
	if (source_type.sources_url) {
	    sources = await get_sources(http_prefix, source_type);
	} else {
	    sources = source_type.sources_function();
	}
	let source = sources.find((s) => s.value == source_value);
	if (source != null && source_sub_value != null) {
	    source.sub_value = source_sub_value;
	}
	return source;
    } else {
	if (source_sub_value == null) {
	    source_sub_value = get_default_source_value({ value: source_type.sub_value });
	}
	if (source_value == null) {
	    source_value = "";
	}
	let source = { label: source_value, value: source_value, sub_value: source_sub_value };
	//add_source_to_sources(http_prefix, source_type, source);
	return source;
    }
};

let cache_sources = {};

async function get_sub_sources(http_prefix, source_type_sub_value) {
    let source_type = sources_types.find((s) => s.value = source_type_sub_value);
    return get_sources(http_prefix, source_type);
}

const get_sources = async (http_prefix, source_type) => {
    if (source_type == null) {
	source_type = get_current_page_source_type();
    }
    let key = source_type.value;    
    if (cache_sources[key] == null) {
	if (source_type.sources_url) {
	    let url = `${http_prefix}/${source_type.sources_url}`;
	    cache_sources[key] = ntopng_utility.http_request(url);
	} else if (source_type.sources_function) {
	    cache_sources[key] = source_type.sources_function();
	} else {
	    return [];
	}
    }
    let sources = await cache_sources[key];
    if (source_type.sources_url) {
	let f_map_source_element = sources_url_el_to_source[source_type.value];
	if (f_map_source_element == null) {
	    throw `:Error: metrics-manager.js, missing sources_url_to_source ${source_type.value} key`;
	}
	sources = sources.map((s) => f_map_source_element(s))
    }
    return sources.sort(NtopUtils.sortAlphabetically)    
};

function get_source_type_key_value_url(source_type) {
    if (source_type.value_url != null) { return source_type.value_url; }
    return source_type.value;
}

function get_source_type_key_sub_value_url(source_type) {
    if (source_type.sub_value_url != null) { return source_type.sub_value_url; }
    return source_type.sub_value;
}

const get_default_source_value = (source_type) => {
    if (source_type == null) {
	source_type = get_current_page_source_type();
    }
    let source_type_value_url = source_type.value_url;
    if (source_type_value_url == null) {
	source_type_value_url = source_type.value;
    }
    return ntopng_url_manager.get_url_entry(source_type_value_url);
};

function get_metrics_url(http_prefix, source_type, source_value, source_sub_value) {
    let params = `${source_type.value}=${source_value}`;
    if (source_type.sub_value != null && source_sub_value != null) {
	params = `${params}&${source_type.sub_value}=${source_sub_value}`;
    }
    let url = `${http_prefix}/lua/rest/v2/get/timeseries/type/consts.lua?query=${source_type.query}&${params}`;
    return url;
}

function get_metric_key(source_type, source) {
    let key = `${source_type.value}_${source.value}`;
    if (source.sub_value != null) {
	key = `${key}_${source.sub_value}`;
    }
    return key;
}

let cache_metrics = {};
let last_metrics_time_interval = null;
const get_metrics = async (http_prefix, source_type, source) => {
    let epoch_begin = ntopng_url_manager.get_url_entry("epoch_begin");
    let epoch_end = ntopng_url_manager.get_url_entry("epoch_end");
    let current_last_metrics_time_interval = `${epoch_begin}_${epoch_end}`;
    if (source_type == null) {
	source_type = get_current_page_source_type();
    }
    if (source == null) {
	source = await get_default_source(http_prefix, source_type);
    }
    // let url = `${http_prefix}/lua/rest/v2/get/timeseries/type/consts.lua?query=${source_type.value}`;
    let url = get_metrics_url(http_prefix, source_type, source.value, source.sub_value);
    let key = get_metric_key(source_type, source);
    if (current_last_metrics_time_interval != last_metrics_time_interval) {
	cache_metrics[key] = null;
	last_metrics_time_interval = current_last_metrics_time_interval;
    }
    if (cache_metrics[key] == null) {
	cache_metrics[key] = ntopng_utility.http_request(url);
    }
    let metrics = await cache_metrics[key];
    return ntopng_utility.clone(metrics);
};

const get_current_page_source_type = () => {
    let pathname = window.location.pathname;
    for (let i = 0; i < sources_types.length; i += 1) {
	let regExp = new RegExp(sources_types[i].regex_page_url);
	if (regExp.test(pathname) == true) {
	    return sources_types[i];
	}
    }
    // if (/lua\/if_stats/.test(pathname) == true) {
    // 	return sources_types[0];
    // } else if (/lua\/host_details/.test(pathname) == true) {
    // 	return sources_types[1];
    // } else if (/lua\/mac_details/.test(pathname) == true) {
    // 	return sources_types[2];
    // }
    throw `source_type not found for ${pathname}`;
};

const get_metrics_from_schema = async (http_prefix, source_type, source, metric_schema, metric_query) => {
    let metrics = await get_metrics(http_prefix, source_type, source);
    return metrics.find((m) => m.schema == metric_schema && m.query == metric_query); 
};

const get_default_metric = (metrics, metric_ts_schema) => {
    let default_metric;
    if (metric_ts_schema != null) {
	default_metric = metrics.find((m) => m.schema == metric_ts_schema);
    }
    if (default_metric == null) {
	default_metric = metrics.find((m) => m.default_visible == true);
    }
    if (default_metric != null) {
	return default_metric;
    }
    return metrics[0];
};

const metricsManager = function() {
    return {
	set_timeseries_groups_in_url,
	get_timeseries_groups_from_url,
	get_default_timeseries_groups,
	get_ts_group,
	get_ts_group_id,

	sources_types,
	get_source_type_from_id,
	get_current_page_source_type,

	get_sources,
	get_sub_sources,
	get_default_source,
	get_default_sub_source,
	get_source_from_value,	
	get_default_source_value,
	add_source_to_sources,

	get_metrics,
	get_metrics_from_schema,
	get_default_metric,

	get_source_type_key_value_url,
	get_source_type_key_sub_value_url,

	ui_types,
    };
}();

export default metricsManager;
