/**
    (C) 2022 - ntop.org
*/
//import { ntopng_utility } from '../services/context/ntopng_globals_services';

function tsInterfaceToApexOptions(tsInterfaceOptions) {
    let startTime = tsInterfaceOptions.start;
    let step = tsInterfaceOptions.step * 1000;
    tsInterfaceOptions.series.forEach((s) => {
	s.name = s.label;
	delete s.type;
	let time = startTime * 1000;;
	s.data = s.data.map((d) => {
	    let d2 = { x: time, y: d };
	    time += step;
	    return d2;
	});
    });
    tsInterfaceOptions.xaxis = {
	labels: {
	    show: true,
	},
	axisTicks: {
	    show: true,
	},
    };
    tsInterfaceOptions.yaxis = {
	labels: {
	    formatter: function(value, index) {
		if (value < 1 << 10) {
		    return `${parseInt(value)} bit/s`;
		}
		value = value >> 10;
		if (value < 1 << 10) {
		    return `${parseInt(value)} Kbit/s`;
		}
		value = value >> 10;
		if (value < 1 << 10) {
		    return `${parseInt(value)} Mbit/s`;
		}
		value = value >> 10;
		return `${parseInt(value)} Gbit/s`;
	    },
	}
    }
    //tsInterface.colors = ["#ff3231", "#ffc007"];
}

const ntopChartOptionsUtility = function() {
    return {
	tsInterfaceToApexOptions: tsInterfaceToApexOptions,
    };
}();

export { ntopChartOptionsUtility };
