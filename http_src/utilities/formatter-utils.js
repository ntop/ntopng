/**
    (C) 2022 - ntop.org
*/
const types = {
    no_formatting: { id: "no_formatting", um: null, step: null, decimal: null, },
    number: { id: "number", um: ["", "K", "M", "G", "T"], step: 1000, decimal: null },
    bytes: { id: "bytes", um: ["B", "KB", "MB", "GB", "TB"], step: 1024, decimal: 2 },
    bps: { id: "bps", um: ["bit/s", "Kbit/s", "Mbit/s", "Gbit/s"], step: 1000, decimal: 2 },
    pps: { id: "pps", um: ["pps", "Kpps", "Mpps", "Gpps", "Tpps"], step: 1000, decimal: 2 },
};

function getFormatter(type) {
    let typeOptions = types[type];
    let formatter = function(value) {	
	if (type == types.no_formatting.id) {
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

const formatterUtils = function() {
    return {
	types,
	getFormatter,
    };
}();

export default formatterUtils;
