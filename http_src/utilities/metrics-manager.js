/**
    (C) 2022 - ntop.org
*/
import { ntopng_utility, ntopng_url_manager } from "../services/context/ntopng_globals_services.js";
import metricsConsts from "../constants/metrics-consts.js"
import NtopUtils from "./ntop-utils.js";

const set_timeseries_groups_in_url = (timeseries_groups) => {
    let params_timeseries_groups = [];
    timeseries_groups.forEach((ts_group) => {
	let param = get_ts_group_url_param(ts_group);
	params_timeseries_groups.push(param);
    });
    let url_timeseries_groups = params_timeseries_groups.join(";;");
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
    let source_value_array_query = ts_group.source_array.map((source) => source.value).join("+");
    let param = `${ts_group.source_type.id};${source_value_array_query};${metric_schema_query};${timeseries_param}`;
    return param;
}

const get_timeseries_groups_from_url = async (http_prefix, url_timeseries_groups) => {
    if (url_timeseries_groups == null) {
	url_timeseries_groups = ntopng_url_manager.get_url_entry("timeseries_groups");
    }
    if (url_timeseries_groups == null || url_timeseries_groups == "") {
	return null;
    }
    let groups = url_timeseries_groups.split(";;");
    if (!groups?.length > 0) {
	return null;
    }
    let timeseries_groups = Promise.all(groups.map(async (g) => {
	let ts_group = await get_url_param_from_ts_group(g);
	return ts_group;
    }));
    return timeseries_groups;
};

const get_ts_group = (source_type, source_array, metric) => {
    let id = get_ts_group_id(source_type, source_array, metric);
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
	id, source_type, source_array, metric, timeseries,
    };
};

const get_default_timeseries_groups = async (http_prefix, metric_ts_schema) => {
    let source_type = get_current_page_source_type();
    let source_array = await get_default_source_array(http_prefix, source_type);
    let metrics = await get_metrics(http_prefix, source_type, source_array);
    let metric = get_default_metric(metrics, metric_ts_schema);
    let ts_group = get_ts_group(source_type, source_array, metric);
    return [ts_group];
};

async function get_url_param_from_ts_group(ts_group_url_param) {
    let g = ts_group_url_param;
    let info = g.split(";");
    let source_type_id = info[0];
    let source_value_query = info[1];
    let source_value_array = source_value_query.split("+");

    let metric_schema_query = info[2];
    let metric_schema_query_array = metric_schema_query.split("+");
    if (metric_schema_query_array.length < 2) {
	metric_schema_query_array.push(null);
    }

    let timeseries_url = info[3];

    let source_type = get_source_type_from_id(source_type_id);
    let source_array = await get_source_array_from_value_array(http_prefix, source_type, source_value_array);
    let metric = await get_metric_from_schema(http_prefix, source_type, source_array, metric_schema_query_array[0], metric_schema_query_array[1]);
    let timeseries = get_timeseries(timeseries_url, metric);
    return {
	id: get_ts_group_id(source_type, source_array, metric),
	source_type,
	source_array,
	metric,
	timeseries,
    };
}

const get_ts_group_id = (source_type, source_array, metric) => {
    let metric_id = metric.schema;
    if (metric.query != null) {
	metric_id = `${metric_id} - ${metric.query}`;
    }
    let source_value_array = source_array.map((source) => source.value).join("_");
    return `${source_type.id} - ${source_value_array} - ${metric_id}`;
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

const ui_types = metricsConsts.ui_types;

// dictionary of functions to convert an element of source_url rest result to a source ({label, value })
const sources_url_el_to_source = metricsConsts.sources_url_el_to_source;

const sources_types = metricsConsts.sources_types;

const get_source_type_from_id = (source_type_id) => {
    return sources_types.find((st) => st.id == source_type_id);
};

const get_default_source_array = async (http_prefix, source_type) => {
    let source_value_array = get_default_source_value_array(source_type);
    let source_array = await get_source_array_from_value_array(http_prefix, source_type, source_value_array);
    return source_array;
};

const get_source_array_from_value_array = async (http_prefix, source_type, source_value_array) => {
    if (source_type == null) {
	source_type = get_current_page_source_type();
    }
    let source_array = [];
    let source;
    for (let i = 0; i < source_value_array.length; i += 1) {
	let source_value = source_value_array[i];
	let source_def = source_type.source_def_array[i];
	if (source_def.sources_url || source_def.sources_function) {
	    let sources = [];
	    if (source_def.sources_url) {
		sources = await get_sources(http_prefix, source_type.id, source_def);
	    } else {
		sources = source_def.sources_function();
	    }
	    source = sources.find((s) => s.value == source_value);
	} else {
	    source = { label: source_value, value: source_value };	    
	}
	source_array.push(source);
    }
    return source_array;
};

let cache_sources = {};

const get_sources = async (http_prefix, id, source_def) => {
    let key = `${id}_${source_def.value}`;
    if (cache_sources[key] == null) {
	if (source_def.sources_url) {
	    let url = `${http_prefix}/${source_def.sources_url}`;
	    cache_sources[key] = ntopng_utility.http_request(url);
	} else if (source_def.sources_function) {
	    cache_sources[key] = source_def.sources_function();
	} else {
	    return [];
	}
    }
    let sources = await cache_sources[key];
    if (source_def.sources_url) {
	let f_map_source_element = sources_url_el_to_source[source_def.value];
	if (f_map_source_element == null) {
	    throw `:Error: metrics-manager.js, missing sources_url_to_source ${source_def.value} key`;
	}
	sources = sources.map((s) => f_map_source_element(s))
    }
    return sources.sort(NtopUtils.sortAlphabetically)    
};

function set_source_value_object_in_url(source_type, source_value_object) {
    source_type.source_def_array.forEach((source_def) => {		
	let source_value = source_value_object[source_def.value];
	if (source_value == null) { return; }
	if (source_def.f_set_value_url != null) {
	    source_def.f_set_value_url();
	} else if (source_def.value_url != null) {
	    ntopng_url_manager.set_key_to_url(source_def.value_url, source_value);
	} else {
	    ntopng_url_manager.set_key_to_url(source_def.value, source_value);
	}
    });
}

const get_default_source_value_array = (source_type) => {
    if (source_type == null) {
	source_type = get_current_page_source_type();
    }
    let source_value_array = source_type.source_def_array.map((source_def) => {
	if (source_def.f_get_value_url != null) {
	    return source_def.f_get_value_url();
	}
	let source_def_value = source_def.value_url;
	if (source_def_value == null) {
	    source_def_value = source_def.value;
	}
	return ntopng_url_manager.get_url_entry(source_def_value);
    });
    return source_value_array;
};

function get_metrics_url(http_prefix, source_type, source_array) {
    let params = source_type.source_def_array.map((source_def, i) => {
	return `${source_def.value}=${source_array[i].value};`
    }).join("&");
    let url = `${http_prefix}/lua/rest/v2/get/timeseries/type/consts.lua?query=${source_type.query}&${params}`;
    return url;
}

function get_metric_key(source_type, source_array) {
    let source_array_key = source_array.map((source) => source.value).join("_");
    let key = `${source_type.id}_${source_array_key}`;
    return key;
}

let cache_metrics = {};
let last_metrics_time_interval = null;
const get_metrics = async (http_prefix, source_type, source_array) => {
    let epoch_begin = ntopng_url_manager.get_url_entry("epoch_begin");
    let epoch_end = ntopng_url_manager.get_url_entry("epoch_end");
    let current_last_metrics_time_interval = `${epoch_begin}_${epoch_end}`;
    if (source_type == null) {
	source_type = get_current_page_source_type();
    }
    if (source_array == null) {
	source_array = await get_default_source_array(http_prefix, source_type);
    }
    // let url = `${http_prefix}/lua/rest/v2/get/timeseries/type/consts.lua?query=${source_type.value}`;
    let url = get_metrics_url(http_prefix, source_type, source_array);
    let key = get_metric_key(source_type, source_array);
    if (current_last_metrics_time_interval != last_metrics_time_interval) {
	cache_metrics[key] = null;
	last_metrics_time_interval = current_last_metrics_time_interval;
    }
    if (cache_metrics[key] == null) {
	cache_metrics[key] = ntopng_utility.http_request(url);
    }
    let metrics = await cache_metrics[key];
    if (metrics.some((m) => m.default_visible == true) == false) {
	metrics[0].default_visible = true;
    }
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
    throw `source_type not found for ${pathname}`;
};

const get_metric_from_schema = async (http_prefix, source_type, source_array, metric_schema, metric_query) => {
    let metrics = await get_metrics(http_prefix, source_type, source_array);
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
	get_default_source_array,
	get_source_array_from_value_array,
	get_default_source_value_array,

	get_metrics,
	get_metric_from_schema,
	get_default_metric,

	set_source_value_object_in_url,

	ui_types,
    };
}();

export default metricsManager;
