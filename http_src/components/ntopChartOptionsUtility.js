/**
    (C) 2022 - ntop.org
*/
//import { ntopng_utility } from '../services/context/ntopng_globals_services';

const apexYFormatterTypes = {
    no_formatting: { id: "no_formatting", um: null, step: null, decimal: null, },
    number: { id: "number", um: ["", "K", "M", "G", "T"], step: 1000, decimal: null },
    bytes: { id: "bytes", um: ["B", "KB", "MB", "GB", "TB"], step: 1024, decimal: 2 },
    bps: { id: "bps", um: ["bit/s", "Kbit/s", "Mbit/s", "Gbit/s"], step: 1000, decimal: 2 },
    pps: { id: "pps", um: ["pps", "Kpps", "Mpps", "Gpps", "Tpps"], step: 1000, decimal: 2 },
};

function getApexYFormatter(type) {
    let typeOptions = apexYFormatterTypes[type];
    let formatter = function(value, index) {	
	if (type == apexYFormatterTypes.no_formatting.id) {
	    return value;
	}
	let step = typeOptions.step;
	let decimal = typeOptions.decimal;
	let measures = typeOptions.um;
	let i = 0;
	while (value >= step && i < measures.length) {
	    value = value / step;
	    i += 1;
	}
	if (decimal != null && decimal > 0) {	    
	    value = value * Math.pow(10, decimal);
	    value = Math.round(value);
	    value = value / Math.pow(10, decimal);
	    value = value.toFixed(decimal);
	} else {
	    value = Math.round(value);
	}
	return `${value} ${measures[i]}`;
    }
    return formatter;
}

function tsInterfaceToApexOptions(tsInterfaceOptions) {
    let startTime = tsInterfaceOptions.start;
    let step = tsInterfaceOptions.step * 1000;
    tsInterfaceOptions.series.forEach((s) => {
	s.name = s.label;
	delete s.type;
	let time = startTime * 1000;;
	s.data = s.data.map((d) => {
	    let d2 = { x: time, y: d * 8};
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
	    formatter: getApexYFormatter(apexYFormatterTypes.bps.id),
	}
    }
    //tsInterface.colors = ["#ff3231", "#ffc007"];
}

const ntopChartOptionsUtility = function() {
    return {
	apexYFormatterTypes,
	getApexYFormatter,
	tsInterfaceToApexOptions: tsInterfaceToApexOptions,
    };
}();

export { ntopChartOptionsUtility };
