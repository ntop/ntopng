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
    full_number: {
        id: "number",
        um: ["", "K", "M", "G", "T"],
        step: 1000,
        decimal: null,
        scale_values: null,
        thousands_sep: ",", /* Comment this to enable "um" scaled style */
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
    bps_no_scale: {
        id: "bps_no_scale",
        um: ["bps", "Kbps", "Mbps", "Gbps", "Tbps", "Pbps"],
        step: 1000,
        decimal: 2,
        scale_values: null,
        absolute_value: true,
    },
    speed: {
        id: "speed",
        um: ["bit", "Kbit", "Mbit", "Gbit", "Tbit", "Pbit"],
        step: 1000,
        decimal: 0,
        scale_values: null,
        absolute_value: true,
    },
    flows: {
        id: "flows",
        um: ["flows", "Kflows", "Mflows", "Gflows"],
        step: 1000,
        decimal: 2,
        scale_values: null,        
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
    alerts: {
        id: "alerts",
        um: ["alerts", "Kalerts", "Malerts", "Galerts"],
        step: 1000,
        decimal: 2,
        scale_values: null,
        absolute_value: true,
    },
    alertps: {
        id: "alertps",
        um: ["alerts/s", "Kalerts/s", "Malerts/s", "Galerts/s"],
        step: 1000,
        decimal: 2,
        scale_values: null,
        absolute_value: true,
    },
    hits: {
        id: "hits",
        um: ["hits", "Khits", "Mhits", "Ghits"],
        step: 1000,
        decimal: 2,
        scale_values: null,        
        absolute_value: true,
    },
    hitss: {
        id: "hitss",
        um: ["hits/s", "Khits/s", "Mhits/s", "Ghits/s"],
        step: 1000,
        decimal: 2,
        scale_values: null,        
        absolute_value: true,
    },
    packets: {
        id: "packets",
        um: ["packets", "Kpackets", "Mpackets", "Gpackets", "Tpackets"],
        step: 1000,
        decimal: 0,
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
        decimal: 1,
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
    if (typeOptions == null) { return null; }
    
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

        if (typeOptions.max_value != null && value > typeOptions.max_value) {
            value = typeOptions.max_value;
        }

        if (typeOptions.thousands_sep) {
            value = value + '';
            var x = value.split('.');
            var x1 = x[0];
            var x2 = (x.length > 1) ? ('.' + x[1]) : '';
            var rgx = /(\d+)(\d{3})/;
            while (rgx.test(x1)) {
                x1 = x1.replace(rgx, '$1' + ',' + '$2');
            }
            return x1 + x2;
        }
        
        let step = typeOptions.step;
        let decimal = typeOptions.decimal;
        let measures = typeOptions.um;
        let i = 0;

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
            if (i > 0) {
                /* Has a decimal number due to the step */
                value = Number(value.toFixed(1));
            } else {
                /* Has a decimal number */
                value = Math.round(value);
            }
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
