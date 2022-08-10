/**
    (C) 2022 - ntop.org
*/
import formatterUtils from "./formatter-utils";

function tsToApexOptions(tsOptions, metric) {
    let startTime = tsOptions.start;
    let step = tsOptions.step * 1000;
    tsOptions.yAxis = [];
    tsOptions.series.forEach((s) => {
	s.name = s.label;
	delete s.type;
	let time = startTime * 1000;
	s.data = s.data.map((d) => {
	    let d2 = { x: time, y: d * 8};
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

function mergeApexOptions(apexOptionsArray, timeseries_groups) {
    if (apexOptionsArray.length == 0) { return; }

    let yAxisGroups = {};
    let yAxis = [];
    apexOptionsArray.forEach((options) => {
	
    });
}

const timeseriesUtils = function() {
    return {
	tsToApexOptions,
	mergeApexOptions,
    };
}();

export default timeseriesUtils;
