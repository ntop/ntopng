/**
    (C) 2022 - ntop.org
*/

import formatterUtils from "./formatter-utils";
import { ntopng_utility, ntopng_url_manager } from "../services/context/ntopng_globals_services.js";

function tsToApexOptions(tsOptions, metric) {
    let startTime = tsOptions.start;
    let step = tsOptions.step * 1000;
    tsOptions.series.forEach((s) => {
	s.name = s.label;
	delete s.type;
	let time = startTime * 1000;
	s.data = s.data.map((d) => {
	    //let d2 = { x: time, y: d * 8 };
	    let d2 = { x: time, y: d };
	    time += step;
	    return d2;
	});
    });
    tsOptions.xaxis = {
	labels: {
	    show: true,
	},
	axisTicks: {
	    show: true,
	},
    };
    
    tsOptions.yaxis = {
	//reversed: true,
	//seriesName: 
	labels: {
	    formatter: formatterUtils.getFormatter(metric.measure_unit),
	},
	axisBorder: {
            show: true,
	},
	title: {
            text: metric.measure_unit,
	},
    };
    //tsInterface.colors = ["#ff3231", "#ffc007"];
}

function getSerieId(serie) {
    return `${serie.label}`;
}

function getYaxisName(measureUnit, scale) {
    if (measureUnit == "number") {
	return scale;
    }
    return measureUnit;
}

function getSerieName(name, id, tsGroup, extendSeriesName) {
    if (name == null) {
	name = id;
    }
    let name_more_space = "";
    if (name != null) {
	name_more_space = `${name} `;
    }
    if (extendSeriesName == false) {
	return name;
    }
    let source_index = getMainSourceDefIndex(tsGroup);
    let source = tsGroup.source_array[source_index];
    let prefix = `${source.label}`;
    let yaxisName = getYaxisName(tsGroup.metric.measure_unit, tsGroup.metric.scale);
    return `${prefix} ${name_more_space}(${yaxisName})`;
}

function getYaxisId(metric) {
    return `${metric.measure_unit}_${metric.scale}`;
}

function getSeriesInApexFormat(tsOptions, tsGroup, extendSeriesName, forceDrawType, tsCompare) {
    // extract start time and step
    let startTime = tsOptions.start * 1000;
    let step = tsOptions.step * 1000;
    let seriesApex = [];
    let seriesKeys = Object.keys(tsGroup.metric.timeseries);
    if (tsGroup.metric.type != "top" && tsOptions.series?.length != seriesKeys.length) {	
	tsOptions.series = seriesKeys.map((sk, i) => {
	    let serie = tsOptions.series.find((s) => getSerieId(s) == sk);
	    if (serie != null) { return serie; }
	    return {
		label: sk,
		data: [null],
	    };
	});
    }
    tsOptions.series.forEach((s, i) => {
	// extract id
	let id = getSerieId(s);
	// find timeseries metadata
	let sMetadata = tsGroup.metric.timeseries[id];
	if (sMetadata == null) {
	    throw `Impossible find timeserie_id = ${id} in metric metadata (id,schema,query) = (${metric.id},${metric.schema},${metric.id})`;
	}
	// extract data and check if we need invert direction
	let scalar = 1;
	if (sMetadata.invert_direction == true) {
	    scalar = -1;
	}
	let fMapData = (data) => {
	    let time = startTime;
	    let res = data.map((d) => {
		let d2 = { x: time, y: d * scalar };
		if (d == null) {
		    d2.y = null;
		}
		time += step;
		return d2;
	    });
	    return res;
	};
	
	// extract ts visibility (raw, avg, perc_95)
	let tsVisibility = tsGroup.timeseries?.find((t) => t.id == id);
	let name = sMetadata.label;
	if (s.ext_label != null && tsGroup.metric.type == "top") {
	    name = s.ext_label;
	}
	let sName = getSerieName(name, id, tsGroup, extendSeriesName);
	// check and add raw serie visibility
	if (tsVisibility == null || tsVisibility.raw == true) {
	    let data = fMapData(s.data);

	    let drawType = sMetadata.draw_type;
	    if (drawType == null && forceDrawType != null) { drawType = forceDrawType; }
	    else if (drawType == null) { drawType = "area"; }
	    
	    // create an apex chart serie
	    let sApex = {
		id,
		colorPalette: 0,
		color: sMetadata.color,
		// stacked: tsGroup.metric.draw_stacked,
		type: drawType,
		name: sName,		
		data,
		invert_direction: sMetadata.invert_direction,
	    };
	    seriesApex.push(sApex);
	}

	// check and add past serie visibility
	if (tsVisibility?.past == true
	    && ntopng_utility.is_object(tsOptions.additional_series)) {
	    let seriesData = ntopng_utility.object_to_array(tsOptions.additional_series)[0];
	    let sApex = {
		id,
		colorPalette: 1,
		// color: sMetadata.color,
		type: "line",
		// stacked: tsGroup.metric.draw_stacked,
		name: `${sName} ${tsCompare} Ago`,
		data: fMapData(seriesData),
		dashed: true,
		invert_direction: sMetadata.invert_direction,
	    };
	    seriesApex.push(sApex);
	}

	// define a function to build a constant serie
	let fBuildConstantSerie = (prefix, id, value) => {
	    if (value == null) { return null; }
	    let name = `${sName} (${prefix})`;
			value *= scalar;
	    let time = startTime;
	    let data = s.data.map((d) => {
		let d2 = { x: time, y: value };
		time += step;
		return d2;
	    });
	    return {
		id,
		name: name,
		colorPalette: 1,
		// color: sMetadata.color,
		type: 'line',
		// stacked: tsGroup.metric.draw_stacked,
		data,
		invert_direction: sMetadata.invert_direction,
	    };
	};
	// check and add avg serie visibility
	if (tsVisibility?.avg == true) {
	    let value = tsOptions.statistics?.by_serie[i].average;
	    // create an apex chart serie
	    let sApex = fBuildConstantSerie("Avg", id, value);
	    seriesApex.push(sApex);
	}
	// check and add 95thperc serie visibility
	if (tsVisibility?.perc_95 == true) {
	    let value = tsOptions.statistics?.by_serie[i]["95th_percentile"];
	    // create an apex chart serie
	    let sApex = fBuildConstantSerie("95th Perc", id, value);
	    seriesApex.push(sApex);
	}

    });
    return seriesApex;
}

const defaultColors = [ 
    "#C6D9FD",
    "#90EE90",
    "#EE8434",
    "#C95D63", 
    "#AE8799", 
    "#717EC3", 
    "#496DDB", 
    "#5A7ADE", 
    "#6986E1", 
    "#7791E4", 
    "#839BE6",
    "#8EA4E8", 
];

function setSeriesColors(seriesArray) {
    let count0 = 0, count1 = 0;
    let colors0 = defaultColors;
    let colors1 = d3v7.schemeCategory10;
    seriesArray.forEach((s) => {
	if (s.colorPalette == 0) {
	    s.color = colors0[count0 % colors0.length];
	    count0 += 1;
	} else if (s.colorPalette == 1) {
	    s.color = colors1[count1 % colors1.length];
	    count1 += 1;
	}
    });
}

function setMinMaxYaxisStacked(yAxisArray, seriesArray) {
    let minMax = { min: 0, max: Number.MIN_SAFE_INTEGER, invert_direction: false };
    let sumSeriesData = [];
    seriesArray.forEach((s) => {
	s.data.forEach((d, i) => {
	    if (sumSeriesData.length <= i) {
		sumSeriesData.push(0);
	    }
	    sumSeriesData[i] += d.y;
	});
    });
    sumSeriesData.forEach((v) => {
	minMax.max = Math.max(minMax.max, v);
	minMax.min = Math.min(minMax.min, v);
    });
    
    yAxisArray.forEach((yAxis) => {
	yAxis.min = minMax.min;
	yAxis.max = minMax.max;
    });
}


function setMinMaxYaxis(yAxisArray, seriesArray, stacked) {
    if (stacked == true) {
	setMinMaxYaxisStacked(yAxisArray, seriesArray);
	return;
    }
    let yAxisArrayDict = {};
    let minMaxDict = {};
    for (let i = 0; i < seriesArray.length; i+= 1) {
	let s = seriesArray[i];
	let y = yAxisArray[i];
	let id = y.seriesName;
	if (yAxisArrayDict[id] == null) {
	    yAxisArrayDict[id] = [];
	    minMaxDict[id] = { min: 0, max: Number.MIN_SAFE_INTEGER, invert_direction: false };
	    // minMaxDict[id] = { min: 0, max: 0, invert_direction: false };
	}
	yAxisArrayDict[id].push(y);
	let minMax = minMaxDict[id];
	s.data.forEach((d) => {
	    minMax.max = Math.max(minMax.max, d.y);
	    minMax.min = Math.min(minMax.min, d.y);
	});
	minMax.invert_direction |= s.invert_direction;
    }

    let fAddOrSubtrac3Perc = (x, isAdd) => {
	if (x == 0 || x == null || x == Number.MAX_SAFE_INTEGER || x == Number.MIN_SAFE_INTEGER) {
	    return 0;
	}
	let onePerc = x / 100 * 3;
	if ((isAdd && x > 0) || (!isAdd && x < 0)) {
	    return x + onePerc;
	} else {
	    return x - onePerc;
	}
    };
    for (let sName in yAxisArrayDict) {
	let yArray = yAxisArrayDict[sName];
	let minMax = minMaxDict[sName];
	minMax.min = fAddOrSubtrac3Perc(minMax.min, false);
	minMax.max = fAddOrSubtrac3Perc(minMax.max, true);
	
	yArray.forEach((y) => {
	    let min_abs = Math.abs(minMax.min);
	    let max_abs = Math.abs(minMax.max);
	    if (min_abs > max_abs) {
	    	y.min = minMax.min;
	    	y.max = min_abs;
	    } else if (min_abs < max_abs && minMax.invert_direction == true) {
	    	y.min = -1 * max_abs;
	    	y.max = minMax.max;
	    } else {
		y.min = minMax.min;
		y.max = minMax.max;
	    }
	});
    }
}

function getYaxisInApexFormat(seriesApex, tsGroup, yaxisDict, formatterDict) {
    let metric = tsGroup.metric;
    let yaxisId = getYaxisId(metric);
    let invertDirection = false;
    let countYaxisId = Object.keys(yaxisDict).length;

    let yaxisApex = [];    

    for (let mdKey in tsGroup.metric.timeseries) {
	invertDirection |= tsGroup.metric.timeseries[mdKey].invert_direction;
    }

    seriesApex.forEach((s) => {
	let yaxisSeriesName = yaxisDict[yaxisId];
	let max = 0;
	let scaleFactorIndex = null;
	if (s.data != null) {
	    // calculate scaleFactor of measureUnit
	     let values = s.data.map((o) => {
		if (o.y == null) { return 0; }
		return Math.abs(o.y);
	     });
	    max = Math.max.apply(Math, values);
	    scaleFactorIndex = formatterUtils.getScaleFactorIndex(metric.measure_unit, max);
	}
	if (yaxisSeriesName == null) {
	    formatterDict[yaxisId] = scaleFactorIndex;
	    let yaxis = {
		seriesName: s.name,
		show: true,
		//forceNiceScale: true,
		labels: {
		    // formatter: formatterDict[yaxisId],
		    // minWidth: 60,
		     // maxWidth: 75,
		    // offsetX: -20,
		},
		axisTicks: {
		    show: true
		},
		axisBorder: {
		    // offsetX: 60,
		    show: true,
		},
		title: {
		    text: getYaxisName(tsGroup.metric.measure_unit, tsGroup.metric.scale),
		},
		opposite: (countYaxisId % 2) == 1,
	    };
	    yaxisDict[yaxisId] = yaxis.seriesName;
	    yaxisApex.push(yaxis);
	} else {
	    yaxisApex.push({
		seriesName: yaxisSeriesName,
		labels: {
		    // formatter: formatterDict[yaxisId],
		},
		show: false,
	    });
	}
	formatterDict[yaxisId] = Math.max(formatterDict[yaxisId], scaleFactorIndex);
    });
    yaxisApex.forEach((y) => y.labels.formatter = formatterUtils.getFormatter(metric.measure_unit, invertDirection, formatterDict[yaxisId]));
    return yaxisApex;
}

const groupsOptionsModesEnum = {
  '1_chart_x_metric': { value: "1_chart_x_metric", label: i18n('page_stats.layout_1_per_1') },
  '1_chart_x_yaxis': { value: "1_chart_x_yaxis", label: i18n('page_stats.layout_1_per_y') },
  '1_chart': { value: "1_chart", label: i18n('page_stats.layout_1_per_all') },
}

function getGroupOptionMode(group_id) {
  return groupsOptionsModesEnum[group_id] || null;
};

function tsArrayToApexOptionsArray(tsOptionsArray, tsGrpupsArray, groupsOptionsMode, tsCompare) {
    if (groupsOptionsMode.value == groupsOptionsModesEnum["1_chart_x_metric"].value) {
	return tsArrayToApexOptionsArrayRaw(tsOptionsArray, tsGrpupsArray, groupsOptionsMode, tsCompare);	
    }
    let splittedTsArray = splitTsArrayStacked(tsOptionsArray, tsGrpupsArray);
    let apexOptionsStacked = tsArrayToApexOptionsArrayRaw(splittedTsArray.stacked.tsOptionsArray, splittedTsArray.stacked.tsGroupsArray, groupsOptionsModesEnum["1_chart_x_metric"], tsCompare);
    let apexOptionsNotStacked = tsArrayToApexOptionsArrayRaw(splittedTsArray.not_stacked.tsOptionsArray, splittedTsArray.not_stacked.tsGroupsArray, groupsOptionsMode, tsCompare);
    return [...apexOptionsStacked, ...apexOptionsNotStacked];
}

function splitTsArrayStacked(tsOptionsArray, tsGrpupsArray) {
    let tsOptionsArrayStacked = [];
    let tsGroupsArrayStacked = [];
    let tsOptionsArrayNotStacked = [];
    let tsGroupsArrayNotStacked = [];
    tsGrpupsArray.forEach((tsGroup, i) => {
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

function tsArrayToApexOptionsArrayRaw(tsOptionsArray, tsGrpupsArray, groupsOptionsMode, tsCompare) {    
    if (groupsOptionsMode.value == groupsOptionsModesEnum["1_chart"].value) {
	let apexOptions = tsArrayToApexOptions(tsOptionsArray, tsGrpupsArray, tsCompare);
	let apexOptionsArray = [apexOptions];
	setLeftPadding(apexOptionsArray);
	return apexOptionsArray;
    } else if (groupsOptionsMode.value == groupsOptionsModesEnum["1_chart_x_yaxis"].value) {
	let tsDict = {};
	tsGrpupsArray.forEach((tsGroup, i) => {
	    let yaxisId = getYaxisId(tsGroup.metric);
	    let tsEl = {tsGroup, tsOptions: tsOptionsArray[i]};
	    if (tsDict[yaxisId] == null) {
		tsDict[yaxisId] = [tsEl];
	    } else {
		tsDict[yaxisId].push(tsEl);
	    }
	});	
	let apexOptionsArray = [];
	for (let key in tsDict) {
	    let tsArray = tsDict[key];
	    let tsOptionsArray2 = tsArray.map((ts) => ts.tsOptions);
	    let tsGrpupsArray2 = tsArray.map((ts) => ts.tsGroup);
	    let apexOptions = tsArrayToApexOptions(tsOptionsArray2, tsGrpupsArray2, tsCompare);
	    apexOptionsArray.push(apexOptions);
	}
	setLeftPadding(apexOptionsArray);
	return apexOptionsArray;
    } else if (groupsOptionsMode.value == groupsOptionsModesEnum["1_chart_x_metric"].value) {
	let apexOptionsArray = [];
	tsOptionsArray.forEach((tsOptions, i) => {
	    let apexOptions = tsArrayToApexOptions([tsOptions], [tsGrpupsArray[i]], tsCompare);
	    apexOptionsArray.push(apexOptions);	    
	});
	setLeftPadding(apexOptionsArray);
	return apexOptionsArray;
    }
    return [];
}

function setLeftPadding(apexOptionsArray) {
    // apexOptions.yaxis.filter((yaxis) => yaxis.show).forEach((yaxis) => yaxis
    let oneChart = apexOptionsArray.length == 1;
    apexOptionsArray.forEach((apexOptions) => {
	if (!oneChart) {
	    apexOptions.yaxis.filter((yaxis) => yaxis.show).forEach((yaxis) => {
		yaxis.labels.minWidth = 60;
	    });
	}
	if (apexOptions.yaxis.length < 2) {
	    return;
	}    
	apexOptions.yaxis.forEach((yaxis) => {
	    yaxis.labels.offsetX = -20;
	});
	apexOptions.grid.padding.left = -7;
    });
}

function tsArrayToApexOptions(tsOptionsArray, tsGrpupsArray, tsCompare) {
    if (tsOptionsArray.length != tsGrpupsArray.length) {
	console.error(`Error in timeseries-utils:tsArrayToApexOptions: tsOptionsArray ${tsOptionsArray} different length from tsGrpupsArray ${tsGrpupsArray}`);
	return;
    }
    let seriesArray = [];
    let yaxisArray = [];
    let yaxisDict = {};
    let formatterDict = {};
    let forceDrawType = null;
    let stacked = false;
    tsOptionsArray.forEach((tsOptions, i) => {
	let tsGroup = tsGrpupsArray[i];

	if (i > 0) {
	    forceDrawType = "line";
	}
	stacked |= tsGroup.metric.draw_stacked;
	// get seriesData
	let seriesApex = getSeriesInApexFormat(tsOptions, tsGroup, true, forceDrawType, tsCompare);

	seriesArray = seriesArray.concat(seriesApex);

	// get yaxis
	let yaxisApex = getYaxisInApexFormat(seriesApex, tsGroup, yaxisDict, formatterDict);
	yaxisArray = yaxisArray.concat(yaxisApex);
    });

    // set colors in series
    setSeriesColors(seriesArray);
    setMinMaxYaxis(yaxisArray, seriesArray, stacked);
    
    let chartOptions = buildChartOptions(seriesArray, yaxisArray, stacked);
    return chartOptions;
}


function buildChartOptions(seriesArray, yaxisArray, stacked) {
    return {
	chart: {
	    id: ntopng_utility.get_random_string(),
	    stacked,
	    group: "timeseries",
	    // height: 300,
	},
	grid: {
	    padding: {
	    	// left: -8,
	    },
	    row: {
		// opacity: 1,
	    }
	},
	fill: {
	    opacity: 0.9,
	    type: 'solid',
	    pattern: {
		strokeWidth: 10,
	    },
	},
	// fill: {
	    
	// }
	markers: {
            size: 2.5,
	    strokeWidth: 1,
	    // fillOpacity: 0,
	    // strokeColors: '#000',
	    // colors: '#000',
	    strokeColors: seriesArray.map((s) => s.color),
	    // colors: null,
	    // strokeOpacity: 1,
	},
	stroke: {
	    show: true,
            // curve: 'straight',
	    lineCap: 'butt',
	    width: 3,
	    dashArray: seriesArray.map((s) => { if (s.dashed) { return 4; } return 0; }),
	},
	legend: {
	    show: true,
	    showForSingleSeries: true,
	    position: "top",
	    horizontalAlign: "right",
	    onItemClick: {
		toggleDataSeries: false,
	    },
	},
	series: seriesArray,
	// colors: colorsInterpolation.transformColors(colors),
	yaxis: yaxisArray,
	xaxis: {
	    labels: {
		show: true,
	    },
	    axisTicks: {
		show: true,
	    },
	},
    };
}

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
	let paramsUrlRequest = `ts_compare=${tsCompare}&version=4&zoom=${tsCompare}&initial_point=true&limit=180`;
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
	let pUrlRequest =  ntopng_url_manager.add_obj_to_url(pObj, paramsUrlRequest);
	let url = `${tsDataUrl}?${pUrlRequest}`;
	let tsChartOption = await ntopng_utility.http_request(url);
	tsChartsOptions = [tsChartOption];
    } else {
	let paramsChart = {
		zoom: tsCompare,
		initial_point: true,
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
	tsChartsOptions = await ntopng_utility.http_request(tsDataUrlMulti, { method: 'post', headers, body: JSON.stringify(req)});
    }
    return tsChartsOptions;
}

const timeseriesUtils = function() {
    return {
	groupsOptionsModesEnum,
	tsToApexOptions,
	tsArrayToApexOptions,
	tsArrayToApexOptionsArray,
	getGroupOptionMode,
	getSerieId,
	getSerieName,
	getTsChartsOptions,
	getTsQuery,
	getMainSourceDefIndex,
    };
}();

export default timeseriesUtils;
