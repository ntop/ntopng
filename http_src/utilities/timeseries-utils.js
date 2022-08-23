/**
    (C) 2022 - ntop.org
*/
import formatterUtils from "./formatter-utils";

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
    return serie.label;
}

function getSeriesInApexFormat(tsOptions, tsGroup) {
    // extract start time and step
    let startTime = tsOptions.start * 1000;;
    let step = tsOptions.step * 1000;
    let seriesApex = [];
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
	    // create an apex chart serie
	    let sApex = {
		id,
		type: "area",
		name: sMetadata.label,
		data,
	    };
	    seriesApex.push(sApex);
	}
	// check if we can add statistics series
	if (tsOptions?.statistics?.by_serie == null) {
    	    return;
	}

	// define a function to build a constant serie
	let fBuildConstantSerie = (prefix, id, name, value) => {
	    let time = startTime;
	    let data = s.data.map((d) => {
		let d2 = { x: time, y: value * scalar };
		time += step;
		return d2;
	    });	    
	    return {
		id,
		name: `${prefix} ${name}`,
		type: 'line',
		stacked: false,
		data,
	    };
	};
	// check and add avg serie visibility
	if (tsVisibility == null || tsVisibility.avg == true) {
	    let value = tsOptions.statistics.by_serie[i].average;
	    // create an apex chart serie
	    let sApex = fBuildConstantSerie("Avg", id, sMetadata.label, value);
	    seriesApex.push(sApex);
	}
	// check and add 95thperc serie visibility
	if (tsVisibility == null || tsVisibility.avg == true) {
	    let value = tsOptions.statistics.by_serie[i]["95th_percentile"];
	    // create an apex chart serie
	    let sApex = fBuildConstantSerie("95th Perc", id, sMetadata.label, value);
	    seriesApex.push(sApex);
	}

    });
    return seriesApex;
}

function tsArrayToApexOptions(tsOptionsArray, tsGrpupsArray) {
    if (tsOptionsArray.length != tsGrpupsArray.length) {
	console.error(`Error in timeseries-utils:tsArrayToApexOptions: tsOptionsArray ${tsOptionsArray} different length from tsGrpupsArray ${tsGrpupsArray}`);
	return;
    }
    
    let seriesArray = [];
    let yaxisArray = [];
    let yaxisDict = {};
    let countYaxisId = 0;
    tsOptionsArray.forEach((tsOptions, i) => {
	let tsGroup = tsGrpupsArray[i];
	let metric = tsGroup.metric;
	let yaxisId = `${metric.measure_unit}_${metric.scale}`;

	let seriesApex = getSeriesInApexFormat(tsOptions, tsGroup);
	seriesArray = seriesArray.concat(seriesApex);

	let invertDirection = false;
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
		countYaxisId += 1;
		yaxisDict[yaxisId] = yaxis.seriesName;
		yaxisArray.push(yaxis);
	    } else {
		yaxisArray.push({
		    seriesName: yaxisSeriesName,
		    labels: {
			formatter: formatterUtils.getFormatter(metric.measure_unit, invertDirection),
		    },
		    show: false,
		});
	    }
	});

    });

    return {
	series: seriesArray,
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
