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

function getSerieName(name, id, tsGroup, extendSeriesName) {
    if (name == null) {
	name = id;
    }
    if (extendSeriesName == false) {
	return name;
    }
    return `${tsGroup.source.name} ${name} (${tsGroup.metric.measure_unit})`;
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

function getSeriesInApexFormat(tsOptions, tsGroup, extendSeriesName) {
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
	// set time at startTime in unix ms
	let time = startTime;
	// find timeseries metadata
	let sMetadata = tsGroup.metric.timeseries[id];
	// extract data and check if we need invert direction
	let scalar = 1;
	if (sMetadata.invert_direction == true) {
	    scalar = -1;
	}
	// extract ts visibility (raw, avg, perc_95)
	let tsVisibility = tsGroup.timeseries?.find((t) => t.id == id);
	// check and add raw serie visibility
	if (tsVisibility == null || tsVisibility.raw == true) {
	    let data = s.data.map((d) => {
		let d2 = { x: time, y: d * scalar };
		time += step;
		return d2;
	    });
	    let sName = getSerieName(sMetadata.label, id, tsGroup, extendSeriesName);
	    // create an apex chart serie
	    let sApex = {
		id,
		color: sMetadata.color,
		type: "area",
		name: sName,
		data,
	    };
	    seriesApex.push(sApex);
	}

	// define a function to build a constant serie
	let fBuildConstantSerie = (prefix, id, name, value) => {
	    if (name == null) { name = id; }
	    name = `${name} (${prefix})`;
	    if (value != null) {
		value *= scalar;
	    } 
	    let sName = getSerieName(name, id, tsGroup, extendSeriesName);
	    let time = startTime;
	    let data = s.data.map((d) => {
		let d2 = { x: time, y: value * scalar };
		time += step;
		return d2;
	    });
	    return {
		id,
		name: sName,
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
	    let sApex = fBuildConstantSerie("Avg", id, sMetadata.label, value);
	    seriesApex.push(sApex);
	}
	// check and add 95thperc serie visibility
	if (tsVisibility?.perc_95 == true) {
	    let value = tsOptions.statistics?.by_serie[i]["95th_percentile"];
	    // create an apex chart serie
	    let sApex = fBuildConstantSerie("95th Perc", id, sMetadata.label, value);
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
    console.log("COLORS");
    console.log(colors);
    colors = colorsInterpolation.transformColors(colors);
    console.log(colors);
    seriesArray.forEach((s, i) => s.color = colors[i]);
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
		    text: metric.measure_unit,
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
  '1_chart': { value: "1_chart", label: "i18n('1_chart')" },
  '1_chart_x_yaxis': { value: "1_chart_x_yaxis", label: "i18n('1_chart_x_yaxis')" },
  '1_chart_x_metric': { value: "1_chart_x_metric", label: "i18n('1_chart_x_metric')" },
}

function getGroupOptionMode(group_id) {
  return groupsOptionsModesEnum[group_id] || null;
};  

function tsArrayToApexOptionsArray(tsOptionsArray, tsGrpupsArray, groupsOptionsMode) {
    if (groupsOptionsMode.value == groupsOptionsModesEnum["1_chart"].value) {	
	let apexOptions = tsArrayToApexOptions(tsOptionsArray, tsGrpupsArray);
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
	    let apexOptions = tsArrayToApexOptions(tsOptionsArray2, tsGrpupsArray2);
	    apexOptionsArray.push(apexOptions);
	}
	setLeftPadding(apexOptionsArray);
	return apexOptionsArray;
    } else if (groupsOptionsMode.value == groupsOptionsModesEnum["1_chart_x_metric"].value) {
	let apexOptionsArray = [];
	tsOptionsArray.forEach((tsOptions, i) => {
	    let apexOptions = tsArrayToApexOptions([tsOptions], [tsGrpupsArray[i]]);
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
		// yaxis.labels.minWidth = 100;
	    });
	}
	if (apexOptions.yaxis.length < 2) {
	    return;
	}    
	apexOptions.yaxis.forEach((yaxis) => {
	    yaxis.labels.offsetX = -20;
	    // yaxis.labels.minWidth = 100;
	});
	apexOptions.grid.padding.left = -8;
    });
}

function tsArrayToApexOptions(tsOptionsArray, tsGrpupsArray) {
    if (tsOptionsArray.length != tsGrpupsArray.length) {
	console.error(`Error in timeseries-utils:tsArrayToApexOptions: tsOptionsArray ${tsOptionsArray} different length from tsGrpupsArray ${tsGrpupsArray}`);
	return;
    }
    
    let seriesArray = [];
    let yaxisArray = [];
    let yaxisDict = {};
    let colors = [];
    let addSeriesNameSource = getAddSeriesNameSource(tsGrpupsArray);
    let addSeriesNameYAxisName = 
    tsOptionsArray.forEach((tsOptions, i) => {
	let tsGroup = tsGrpupsArray[i];

	// get seriesData
	let seriesApex = getSeriesInApexFormat(tsOptions, tsGroup, true);
	seriesArray = seriesArray.concat(seriesApex);

	// get yaxis
	let yaxisApex = getYaxisInApexFormat(seriesApex, tsGroup, yaxisDict);
	yaxisArray = yaxisArray.concat(yaxisApex);
    });

    // set colors in series
    setSeriesColors(seriesArray);

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
	legend: {
	    show: true,
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
  getGroupOptionMode
    };
}();

export default timeseriesUtils;
