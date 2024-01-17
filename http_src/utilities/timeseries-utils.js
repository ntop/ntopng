/**
		(C) 2022 - ntop.org
*/

import './graph/dygraph-extension.js';
import dygraphFormat from "./graph/dygraph-format.js";
import { ntopng_utility, ntopng_url_manager } from "../services/context/ntopng_globals_services.js";

function getSerieId(serie) {
	return dygraphFormat.getSerieId(serie);
}

function getSerieName(name, id, tsGroup, useFullName) {
	return dygraphFormat.getSerieName(name, id, tsGroup, useFullName);
}

function getYaxisId(metric) {
	return `${metric.measure_unit}_${metric.scale}`;
}

const groupsOptionsModesEnum = {
	'1_chart_x_metric': { value: "1_chart_x_metric", label: i18n('page_stats.layout_1_per_1') },
	'1_chart_x_yaxis': { value: "1_chart_x_yaxis", label: i18n('page_stats.layout_1_per_y') },
}

function getGroupOptionMode(group_id) {
	return groupsOptionsModesEnum[group_id] || null;
};

/* This function is going to translate the response sent from the server to the formatted data needed from the chart library */
function tsArrayToOptionsArray(tsOptionsArray, tsGroupsArray, groupsOptionsMode, tsCompare) {
	/* One chart per metric requested */
	if (groupsOptionsMode.value == groupsOptionsModesEnum["1_chart_x_metric"].value) {
		return tsArrayToOptionsArrayRaw(tsOptionsArray, tsGroupsArray, groupsOptionsMode, tsCompare);
	}
	let splittedTsArray = splitTsArrayStacked(tsOptionsArray, tsGroupsArray);
	let DygraphOptionsStacked = tsArrayToOptionsArrayRaw(splittedTsArray.stacked.tsOptionsArray, splittedTsArray.stacked.tsGroupsArray, groupsOptionsMode, tsCompare);
	let DygraphOptionsNotStacked = tsArrayToOptionsArrayRaw(splittedTsArray.not_stacked.tsOptionsArray, splittedTsArray.not_stacked.tsGroupsArray, groupsOptionsMode, tsCompare);
	//console.log([...DygraphOptionsStacked, ...DygraphOptionsNotStacked])
	return [...DygraphOptionsStacked, ...DygraphOptionsNotStacked];
}

function splitTsArrayStacked(tsOptionsArray, tsGroupsArray) {
	let tsOptionsArrayStacked = [];
	let tsGroupsArrayStacked = [];
	let tsOptionsArrayNotStacked = [];
	let tsGroupsArrayNotStacked = [];
	tsGroupsArray.forEach((tsGroup, i) => {
		if (tsGroup.metric.draw_stacked == true) {
			tsOptionsArrayStacked.push(tsOptionsArray[i]);
			tsGroupsArrayStacked.push(tsGroup);
		} else {
			tsOptionsArrayNotStacked.push(tsOptionsArray[i]);
			tsGroupsArrayNotStacked.push(tsGroup);
		}
	});
	return {
		stacked: {
			tsOptionsArray: tsOptionsArrayStacked,
			tsGroupsArray: tsGroupsArrayStacked,
		},
		not_stacked: {
			tsOptionsArray: tsOptionsArrayNotStacked,
			tsGroupsArray: tsGroupsArrayNotStacked,
		},
	};
}

function tsArrayToOptionsArrayRaw(tsOptionsArray, tsGroupsArray, groupsOptionsMode, tsCompare) {
	let useFullName = false;
	if (groupsOptionsMode.value == groupsOptionsModesEnum["1_chart_x_yaxis"].value) {
		let tsDict = {};
		tsGroupsArray.forEach((tsGroup, i) => {
			let yaxisId = getYaxisId(tsGroup.metric);
			let tsEl = { tsGroup, tsOptions: tsOptionsArray[i] };
			if (tsDict[yaxisId] == null) {
				tsDict[yaxisId] = [tsEl];
			} else {
				tsDict[yaxisId].push(tsEl);
			}
		});
		useFullName = tsGroupsArray.length > 1 || (tsGroupsArray.length > 0
			&& tsGroupsArray[0].source_type.display_full_name === true);
		let DygraphOptionsArray = [];
		for (let key in tsDict) {
			let tsArray = tsDict[key];
			let tsOptionsArray2 = tsArray.map((ts) => ts.tsOptions);
			let tsGroupsArray2 = tsArray.map((ts) => ts.tsGroup);
			let DygraphOptions = tsArrayToOptions(tsOptionsArray2, tsGroupsArray2, tsCompare, useFullName);
			DygraphOptionsArray.push(DygraphOptions);
		}
		return DygraphOptionsArray;
	} else if (groupsOptionsMode.value == groupsOptionsModesEnum["1_chart_x_metric"].value) {
		useFullName = tsOptionsArray.length > 1 || (tsGroupsArray.length > 0
			&& tsGroupsArray[0].source_type.display_full_name === true);
		let optionsArray = [];
		tsOptionsArray.forEach((tsOptions, i) => {
			let options = tsArrayToOptions([tsOptions], [tsGroupsArray[i]], tsCompare, useFullName);
			optionsArray.push(options);
		});
		return optionsArray;
	}
	return [];
}

/* *********************************************** */

/* This function is used to format a simple timeseries given an array 
 */
function formatSimpleSerie(data, serie_name, chart_type, formatters, value_range) {
	return dygraphFormat.formatSimpleSerie(data, serie_name, chart_type, formatters, value_range);
}

/* *********************************************** */

/* Given an array of timeseries, it compacts them into a single array 
 * and return the configuration for the timeserie with the data 
 */
function tsArrayToOptions(tsOptionsArray, tsGroupsArray, tsCompare, useFullName) {
	return dygraphFormat.formatSerie(tsOptionsArray, tsGroupsArray, tsCompare, useFullName);
}

/* *********************************************** */

function getTsQuery(tsGroup, not_metric_query, enable_source_def_value_dict) {
	let tsQuery = tsGroup.source_type.source_def_array.map((source_def, i) => {
		if (enable_source_def_value_dict != null && !enable_source_def_value_dict[source_def.value]) { return null; }
		let source_value = tsGroup.source_array[i].value;
		return `${source_def.value}:${source_value}`;
	}).filter((s) => s != null).join(",");

	if (!not_metric_query && tsGroup.metric.query != null) {
		tsQuery = `${tsQuery},${tsGroup.metric.query}`
	}
	return tsQuery;
}

function getMainSourceDefIndex(tsGroup) {
	let source_def_array = tsGroup.source_type.source_def_array;
	for (let i = 0; i < source_def_array.length; i += 1) {
		let source_def = source_def_array[i];
		if (source_def.main_source_def == true) { return i; }
	}
	return 0;

}

async function getTsChartsOptions(httpPrefix, epochStatus, tsCompare, timeseriesGroups, isPro) {
	let paramsEpochObj = { epoch_begin: epochStatus.epoch_begin, epoch_end: epochStatus.epoch_end };

	let tsChartsOptions;
	if (!isPro) {
		let tsDataUrl = `${httpPrefix}/lua/rest/v2/get/timeseries/ts.lua`;
		let paramsUrlRequest = `ts_compare=${tsCompare}&version=4&zoom=${tsCompare}&limit=180`;
		let tsGroup = timeseriesGroups[0];
		let main_source_index = getMainSourceDefIndex(tsGroup);
		let tsQuery = getTsQuery(tsGroup);
		let pObj = {
			...paramsEpochObj,
			ts_query: tsQuery,
			ts_schema: `${tsGroup.metric.schema}`,
		};
		if (!tsGroup.source_type.source_def_array[main_source_index].disable_tskey) {
			pObj.tskey = tsGroup.source_array[main_source_index].value;
		}
		let pUrlRequest = ntopng_url_manager.add_obj_to_url(pObj, paramsUrlRequest);
		let url = `${tsDataUrl}?${pUrlRequest}`;
		let tsChartOption = await ntopng_utility.http_request(url);
		tsChartsOptions = [tsChartOption];
	} else {
		let paramsChart = {
			zoom: tsCompare,
			limit: 180,
			version: 4,
			ts_compare: tsCompare,
		};

		let tsRequests = timeseriesGroups.map((tsGroup) => {
			let main_source_index = getMainSourceDefIndex(tsGroup);
			let tsQuery = getTsQuery(tsGroup);
			let pObj = {
				ts_query: tsQuery,
				ts_schema: `${tsGroup.metric.schema}`,
			};
			if (!tsGroup.source_type.source_def_array[main_source_index].disable_tskey) {
				pObj.tskey = tsGroup.source_array[main_source_index].value;
			}
			return pObj;
		});
		let tsDataUrlMulti = `${httpPrefix}/lua/pro/rest/v2/get/timeseries/ts_multi.lua`;
		let req = { ts_requests: tsRequests, ...paramsEpochObj, ...paramsChart };
		let headers = {
			'Content-Type': 'application/json'
		};
		tsChartsOptions = await ntopng_utility.http_request(tsDataUrlMulti, { method: 'post', headers, body: JSON.stringify(req) });
	}
	return tsChartsOptions;
}

const timeseriesUtils = function () {
	return {
		groupsOptionsModesEnum,
		tsArrayToOptions,
		formatSimpleSerie,
		tsArrayToOptionsArray,
		getGroupOptionMode,
		getSerieId,
		getSerieName,
		getTsChartsOptions,
		getTsQuery,
		getMainSourceDefIndex,
	};
}();

export default timeseriesUtils;
