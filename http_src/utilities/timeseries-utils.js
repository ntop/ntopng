/**
    (C) 2022 - ntop.org
*/

import formatterUtils from "./formatter-utils";
import colorsInterpolation from "./colors-interpolation.js";
import { ntopng_utility } from "../services/context/ntopng_globals_services.js";

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
	let yAxis = {
	};
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
    if (extendSeriesName == false) {
	return name;
    }
    let yaxisName = getYaxisName(tsGroup.metric.measure_unit, tsGroup.metric.scale);
    return `${tsGroup.source.label} ${name} (${yaxisName})`;
}

function getAddSeriesNameSource(tsGrpupsArray) {
    return tsGrpupsArray[0]?.source?.name != null;
}

function getYaxisId(metric) {
    return `${metric.measure_unit}_${metric.scale}`;
}

function getAddSeriesNameYAxisName(tsOptionsArray) {
    tsOptionsArray.forEach((tsOptions) => {
	let sourceId = `${tsOptions.source_type.value}_${tsOptions.source.value}`;
	sourceDict[sourceId] = true;
    });
    
}

function getSeriesInApexFormat(tsOptions, tsGroup, extendSeriesName, forceDrawType, tsCompare) {
    // extract start time and step
    let startTime = tsOptions.start * 1000;;
    let step = tsOptions.step * 1000;
    let seriesApex = [];

    let seriesKeys = Object.keys(tsGroup.metric.timeseries);
    if (tsOptions.series?.length != seriesKeys.length) {
	tsOptions.series = seriesKeys.map((sk) => {
	    return {
		label: sk,
		data: [null],
	    }
	})	
    }
    tsOptions.series.forEach((s, i) => {
	// extract id
	let id = getSerieId(s);
	// find timeseries metadata
	let sMetadata = tsGroup.metric.timeseries[id];
	// extract data and check if we need invert direction
	let scalar = 1;
	if (sMetadata.invert_direction == true) {
	    scalar = -1;
	}
	let fMapData = (data) => {
	    let time = startTime;
	    let res = data.map((d) => {
		let d2 = { x: time, y: d * scalar };
		time += step;
		return d2;
	    });
	    return res;
	};
	
	// extract ts visibility (raw, avg, perc_95)
	let tsVisibility = tsGroup.timeseries?.find((t) => t.id == id);
	let sName = getSerieName(sMetadata.label, id, tsGroup, extendSeriesName);
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
		type: drawType,
		name: sName,
		data,
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
		color: sMetadata.color,
		type: "line",
		name: `${sName} ${tsCompare} Ago`,
		data: fMapData(seriesData),
	    };
	    seriesApex.push(sApex);
	}

	// define a function to build a constant serie
	let fBuildConstantSerie = (prefix, id, value) => {
	    if (value == null) { return null; }
	    let name = `${sName} (${prefix})`;
	    if (value != null) {
		value *= scalar;
	    }
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
		color: sMetadata.color,
		type: 'line',
		stacked: false,
		data,
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
    let colors = seriesArray.map((s) => {
	if (s.color != null) {
	    return s.color;
	}
	let hash = ntopng_utility.string_hash_code(s.name);
	if (hash < 0) { hash *= -1; }
	let colorIndex = hash % defaultColors.length;
	return defaultColors[colorIndex];
    });
    colors = colorsInterpolation.transformColors(colors);
    console.log(colors);
    seriesArray.forEach((s, i) => s.color = colors[i]);
}

function setSeriesColors2(seriesArray) {
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

function setMinMaxYaxis(yAxisArray, seriesArray) {
    let yAxisArrayDict = {};
    let minMaxDict = {};
    for (let i = 0; i < seriesArray.length; i+= 1) {
	let s = seriesArray[i];
	let y = yAxisArray[i];
	let id = y.seriesName;
	if (yAxisArrayDict[id] == null) {
	    yAxisArrayDict[id] = [];
	    minMaxDict[id] = { min: Number.MAX_SAFE_INTEGER, max: Number.MIN_SAFE_INTEGER };
	}
	yAxisArrayDict[id].push(y);
	let minMax = minMaxDict[id];
	s.data.forEach((d) => {
	    minMax.max = Math.max(minMax.max, d.y);
	    minMax.min = Math.min(minMax.min, d.y);
	});	
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
    }
    for (let sName in yAxisArrayDict) {
	let yArray = yAxisArrayDict[sName];
	let minMax = minMaxDict[sName];
	minMax.min = fAddOrSubtrac3Perc(minMax.min, false);
	minMax.max = fAddOrSubtrac3Perc(minMax.max, true);
	
	yArray.forEach((y) => {
	    y.min = minMax.min;
	    y.max = minMax.max;
	});
    }
}

function getYaxisInApexFormat(seriesApex, tsGroup, yaxisDict) {
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
	if (yaxisSeriesName == null) {
	    let yaxis = {
		seriesName: s.name,
		show: true,
		//forceNiceScale: true,
		labels: {
		    formatter: formatterUtils.getFormatter(metric.measure_unit, invertDirection),
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
		    formatter: formatterUtils.getFormatter(metric.measure_unit, invertDirection),
		},
		show: false,
	    });
	}
    });
    return yaxisApex;
}

const groupsOptionsModesEnum = {
  '1_chart': { value: "1_chart", label: i18n('page_stats.layout_1_per_all') },
  '1_chart_x_yaxis': { value: "1_chart_x_yaxis", label: i18n('page_stats.layout_1_per_y') },
  '1_chart_x_metric': { value: "1_chart_x_metric", label: i18n('page_stats.layout_1_per_1') },
}

function getGroupOptionMode(group_id) {
  return groupsOptionsModesEnum[group_id] || null;
};  

function tsArrayToApexOptionsArray(tsOptionsArray, tsGrpupsArray, groupsOptionsMode, tsCompare) {
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
    let addSeriesNameSource = getAddSeriesNameSource(tsGrpupsArray);
    let forceDrawType = null;
    tsOptionsArray.forEach((tsOptions, i) => {
	let tsGroup = tsGrpupsArray[i];

	if (i > 0) {
	    forceDrawType = "line"
	}
	// get seriesData
	let seriesApex = getSeriesInApexFormat(tsOptions, tsGroup, true, forceDrawType, tsCompare);
	seriesArray = seriesArray.concat(seriesApex);

	// get yaxis
	let yaxisApex = getYaxisInApexFormat(seriesApex, tsGroup, yaxisDict);
	yaxisArray = yaxisArray.concat(yaxisApex);
    });

    // set colors in series
    setSeriesColors2(seriesArray);
    setMinMaxYaxis(yaxisArray, seriesArray);
    
    let chartOptions = buildChartOptions(seriesArray, yaxisArray);    
    return chartOptions;
}

function buildChartOptions(seriesArray, yaxisArray) {
    return {
	chart: {
	    id: ntopng_utility.get_random_string(),
	    group: "timeseries",
	    // height: 300,
	},
	grid: {
	    padding: {
	    	// left: -8,
	    },
	},
	fill: {
	    opacity: 0.5,
	    type: 'solid',
	    pattern: {
		strokeWidth: 10,
	    },
	},
	// fill: {
	    
	// }
	stroke: {
	    show: true,
	    lineCap: 'butt',
	    width: 3,
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

const timeseriesUtils = function() {
    return {
	groupsOptionsModesEnum,
	tsToApexOptions,
	tsArrayToApexOptions,
	tsArrayToApexOptionsArray,
	getGroupOptionMode,
	getSerieId,
	getSerieName,
    };
}();

export default timeseriesUtils;
