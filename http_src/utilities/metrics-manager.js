/**
    (C) 2022 - ntop.org
*/
import { ntopng_utility, ntopng_url_manager } from "../services/context/ntopng_globals_services.js";

const sources_types = [
    {
	name: "Interface",
	sources_url: "lua/rest/v2/get/ntopng/interfaces.lua",
	value: "ifid",
    },
];

let cache_sources = {};
const get_sources = async (http_prefix, source_type) => {
    let url = `${http_prefix}/${source_type.sources_url}`;
    let key = source_type.value;
    if (cache_sources[key] == null) {
	cache_sources[key] = ntopng_utility.http_request(url);
    }
    let res = await cache_sources[key];
    if (source_type.value == "ifid") {
	return res.map((s) => {
	    return {
		name: s.ifname,
		value: s.ifid,
	    };
	});
    }
    throw "source_type not reconized";
};

const get_default_source_value = (source_type) => {
    if (source_type == null) {
	source_type = get_current_page_source_type();
    }
    return ntopng_url_manager.get_url_entry(source_type.value);
}

let cache_metrics = {};
const get_metrics = async (http_prefix, source_type, source_value) => {
    if (source_type == null) {
	source_type = get_current_page_source_type();
    }
    if (source_value == null) {
	source_value = get_default_source_value(source_type);
    }
    let url = `${http_prefix}/lua/pro/rest/v2/get/timeseries/type/consts.lua`;
    let key = `${source_type.value}_${source_value}`;
    if (cache_metrics[key] == null) {
	cache_metrics[key] = ntopng_utility.http_request(url);
    }
    let metrics = await cache_metrics[key];
    return ntopng_utility.clone(metrics);
};

const get_current_page_source_type = () => {
    let pathname = window.location.pathname;
    if (/if_stats/.test(pathname) == true) {
	return sources_types[0];
    } 
    throw `source_type not found for ${pathname}`;
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
	sources_types,
	get_current_page_source_type,
	get_default_source_value,
	get_default_metric,
	get_sources,
	get_metrics,
    };
}();

export default metricsManager;
