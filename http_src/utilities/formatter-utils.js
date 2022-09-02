/**
    (C) 2022 - ntop.org
*/
const types = {
    no_formatting: {
	id: "no_formatting",
	um: null,
	step: null,
	decimal: null,
	scale_values: null,
    },
    number: {
	id: "number",
	um: ["", "K", "M", "G", "T"],
	step: 1000,
	decimal: null,
	scale_values: null,
    },
    bytes: {
	id: "bytes",
	um: ["B", "KB", "MB", "GB", "TB"],
	step: 1024,
	decimal: 2,
	scale_values: null,
    },
    bps: {
	id: "bps",
	um: ["bit/s", "Kbit/s", "Mbit/s", "Gbit/s"],
	step: 1000,
	decimal: 2,
	scale_values: 8,	
    },
    fps: {
	id: "fps",
	um: ["flows/s", "Kflows/s", "Mflows/s", "Gflows/s"],
	step: 1000,
	decimal: 2,
	scale_values: null,	
    },
    pps: {
	id: "pps",
	um: ["pps", "Kpps", "Mpps", "Gpps", "Tpps"],
	step: 1000,
	decimal: 2,
	scale_values: null,	
    },
};

function getFormatter(type, absoluteValue) {
    let typeOptions = types[type];
    let formatter = function(value) {	
	if (type == types.no_formatting.id) {
	    return value;
	}
	if (typeOptions.scale_values != null) {
	    value *= typeOptions.scale_values;
	}
	let negativeValue = value < 0;
	if (negativeValue) { value *= -1; }
	
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
	
	if (negativeValue && !absoluteValue) { value *= -1; }
	let text = `${value}    ${measures[i]}`;
	return text;
	// console.log(text);
	// return text.padStart(40 - text.length, "&nbsp;()");
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
