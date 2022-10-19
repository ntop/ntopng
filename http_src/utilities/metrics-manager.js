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
    let param = `${ts_group.source_type.value},${source_value_query},${metric_schema_query},${timeseries_param}`;
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

const get_default_timeseries_groups = async (http_prefix) => {
    let source_type = get_current_page_source_type();
    let source = await get_default_source(http_prefix, source_type);
    let metrics = await get_metrics(http_prefix, source_type, source);
    let metric = get_default_metric(metrics);
    let ts_group = get_ts_group(source_type, source, metric);
    return [ts_group];
};

async function get_url_param_from_ts_group(ts_group_url_param) {
    let g = ts_group_url_param;
    let info = g.split(",");
    let source_type_value = info[0];
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

    let source_type = get_source_type_from_value(source_type_value);
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
    return `${source_type.value} - ${source.value} - ${metric_id}`;
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
    select: "select",
    select_and_input: "select_and_input",
};

const sources_types = [
    {
	label: "Interface",
	sources_url: "lua/rest/v2/get/ntopng/interfaces.lua",
	value: "ifid",
	ui_type: ui_types.select,
    },
    {
	label: "Host",
	disable_url: true,
	//sources_url: "lua/rest/v2/get/ntopng/interfaces.lua",
	value: "host",
	sources_sub_url: "lua/rest/v2/get/ntopng/interfaces.lua",
	sub_value: "ifid",
	sub_label: "Interface",
	ui_type: ui_types.select_and_input,
    },
];

const get_source_type_from_value = (source_type_value) => {
    return sources_types.find((st) => st.value == source_type_value);
};

async function get_default_sub_source(http_prefix, sub_source_type_value) {
    let sub_source_type = get_source_type_from_value(sub_source_type_value);
    return get_default_source(http_prefix, sub_source_type);    
}

const get_default_source = async (http_prefix, source_type) => {
    let source_value = get_default_source_value(source_type);
    let source = await get_source_from_value(http_prefix, source_type, source_value);
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
    if (!source_type.disable_url) {
	let sources = await get_sources(http_prefix, source_type);
	return sources.find((s) => s.value == source_value);
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
	if (!source_type.disable_url) {
	    let url = `${http_prefix}/${source_type.sources_url}`;
	    cache_sources[key] = ntopng_utility.http_request(url);
	}
	else {
	    cache_sources[key] = [];
	}
    }
    let res = await cache_sources[key];
    const sources = res.map((s) => {
	let label = s.ifname;
	if (s.name != null) {
	    label = s.name;
	}
        return {
	    label,
	    value: s.ifid,
        };
    });	
    return sources.sort(NtopUtils.sortAlphabetically)    
};

const get_default_source_value = (source_type) => {
    if (source_type == null) {
	source_type = get_current_page_source_type();
    }
    return ntopng_url_manager.get_url_entry(source_type.value);
};

function get_metrics_url(http_prefix, source_type, source_value, source_sub_value) {
    let params;
    if (source_type.value == "ifid") {
	params = `ifid=${source_value}`;
    } else if (source_type.value == "host") {
	params = `ifid=${source_sub_value}&host=${source_value}`;	
    }
    let url = `${http_prefix}/lua/rest/v2/get/timeseries/type/consts.lua?query=${source_type.value}&${params}`;
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
    if (/lua\/if_stats/.test(pathname) == true) {
	return sources_types[0];
    } else if (/lua\/host_details/.test(pathname) == true) {
	return sources_types[1];
    }
    throw `source_type not found for ${pathname}`;
};

const get_metrics_from_schema = async (http_prefix, source_type, source, metric_schema, metric_query) => {
    let metrics = await get_metrics(http_prefix, source_type, source);
    return metrics.find((m) => m.schema == metric_schema && m.query == metric_query); 
};

const get_default_metric = (metrics) => {
    let default_metric = metrics.find((m) => m.default_visible == true);
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
	get_source_type_from_value,
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

	ui_types,
    };
}();

export default metricsManager;
