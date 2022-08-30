/**
    (C) 2022 - ntop.org
*/

import formatterUtils from "./formatter-utils";
import colorsInterpolation from "./colors-interpolation.js";

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

function getSerieName(name, tsGroup, extendSeriesName) {
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
	    let sName = getSerieName(sMetadata.label, tsGroup, extendSeriesName);
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
	    name = `${name} (${prefix})`;
	    if (value != null) {
		value *= scalar;
	    } 
	    let sName = getSerieName(name, tsGroup, extendSeriesName);
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
    let colors = seriesArray.map((s) => s.color);
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
		labels: {
		    formatter: formatterUtils.getFormatter(metric.measure_unit, invertDirection),
		},
		axisTicks: {
		    show: true
		},
		axisBorder: {
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
    
    return {
	chart: {
	    group: "test",
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
    }
}

const timeseriesUtils = function() {
    return {
	tsToApexOptions,
	tsArrayToApexOptions,
    };
}();

export default timeseriesUtils;
