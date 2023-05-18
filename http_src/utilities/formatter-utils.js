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
	um: ["B", "KB", "MB", "GB", "TB", "PB", "EB"],
	step: 1024,
	decimal: 2,
	scale_values: null,
	absolute_value: true,
    },
    bps: {
	id: "bps",
	um: ["bps", "Kbps", "Mbps", "Gbps", "Tbps", "Pbps"],
	step: 1000,
	decimal: 2,
	scale_values: 8,	
	absolute_value: true,
    },
    fps: {
	id: "fps",
	um: ["flows/s", "Kflows/s", "Mflows/s", "Gflows/s"],
	step: 1000,
	decimal: 2,
	scale_values: null,	
	absolute_value: true,
    },
    pps: {
	id: "pps",
	um: ["pps", "Kpps", "Mpps", "Gpps", "Tpps"],
	step: 1000,
	decimal: 2,
	scale_values: null,	
	absolute_value: true,
    },
    ms: {
	id: "ms",
	um: ["ms", "s"],
	step: 1000,
	decimal: 2,
	scale_values: null,	
	absolute_value: true,
    },
    percentage: {
	id: "percentage",
	um: ["%"],
	step: 101,
	decimal: 0,
	scale_values: null,	
	max_value: 100,
	absolute_value: true,
    },
};

function getUnitMeasureLen(type) {
    // 000.00
    let t = types[type];
    let spaceValue = 3;
    if (t.decimal != null && t.decimal > 0) {	
	spaceValue = 6;
    }
    let spaceUm = 0;
    if (t.um != null) {
	spaceUm = Math.max(...t.um.map((um) => um.length));
    }
    return (spaceValue + 1 + spaceUm);
}

function getScaleFactorIndex(type, value) {
   let typeOptions = types[type];
    if (type == types.no_formatting.id || value == null) {
	return null;
    }
    if (typeOptions.scale_values != null) {
	value *= typeOptions.scale_values;
    }
    let step = typeOptions.step;
    let negativeValue = value < 0;
    if (negativeValue) { value *= -1; }
    let i = 0;
    let measures = typeOptions.um;
    while (value >= step && i < measures.length) {
	value = value / step;
	i += 1;
    }
    return i;
}

function getFormatter(type, absoluteValue, scaleFactorIndex) {
    let typeOptions = types[type];
    absoluteValue |= typeOptions.absolute_value; 
    let formatter = function(value) {
	if (value == null) {
	    return '';
	}
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
  if (typeOptions.max_value != null && value > typeOptions.max_value) {
    value = typeOptions.max_value;
  }

	while ((value >= step && i < measures.length && !scaleFactorIndex) || (scaleFactorIndex != null && i < scaleFactorIndex)) {
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
	let valString = `${value}`;
	// if (valString.length < maxLenValue) {
	//     valString = valString.padEnd(maxLenValue - valString.length, " ");
	// }
	let mString = `${measures[i]}`;
	// if (mString.length < maxLenUm) {
	//     mString = mString.padStart(maxLenUm - mString.length, "_");
	// }
	let text = `${valString} ${mString}`;
	return text;
    }
    return formatter;
}

const formatterUtils = function() {
    return {
	types,
	getUnitMeasureLen,
	getFormatter,
	getScaleFactorIndex,
    };
}();

export default formatterUtils;
