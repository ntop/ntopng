/**
    (C) 2022 - ntop.org
*/
import formatterUtils from "./formatter-utils";

function tsToApexOptions(tsOptions, formatterId) {
    let startTime = tsOptions.start;
    let step = tsOptions.step * 1000;
    tsOptions.series.forEach((s) => {
	s.name = s.label;
	delete s.type;
	let time = startTime * 1000;;
	s.data = s.data.map((d) => {
	    let d2 = { x: time, y: d * 8};
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
	labels: {
	    formatter: formatterUtils.getFormatter(formatterUtils.types.bps.id),
	}
    }
    //tsInterface.colors = ["#ff3231", "#ffc007"];
}

const timeseriesUtils = function() {
    return {
	tsToApexOptions,
    };
}();

export default timeseriesUtils;
