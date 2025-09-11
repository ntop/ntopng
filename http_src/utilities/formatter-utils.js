/**
    (C) 2022-24 - ntop.org
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
        um: ["", "K", "M", "B", "T"],
        step: 1000,
        decimal: null,
        scale_values: null,
    },
    full_number: {
        id: "number",
        um: ["", "K", "M", "B", "T"],
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
    fps_short: {
        id: "fps_short",
        um: ["fps", "Kfps", "Mfps", "Gfps"],
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
        um: ["ms"],
        step: 1000,
        decimal: 2,
        scale_values: null,
        absolute_value: true,
    },
    drops: {
        id: "drops",
        um: ["dps", "Kdps", "Mdps", "Gdps", "Tdps"],
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
    ratio: {
        id: "ratio",
        um: [""],
        step: 101,
        decimal: 2,
        scale_values: null,
        max_value: 100,
        absolute_value: true,
    },
    date: {
        id: "date",
        um: null,
        step: null,
        decimal: null,
        scale_values: null
    }
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

function formatAccounting(amount, decimalCount = 0, decimal = ".", thousands = "'") {
    try {
        decimalCount = Math.abs(decimalCount);
        decimalCount = isNaN(decimalCount) ? 2 : decimalCount;

        const negativeSign = amount < 0 ? "-" : "";

        let i = parseInt(amount = Math.abs(Number(amount) || 0).toFixed(decimalCount)).toString();
        let j = (i.length > 3) ? i.length % 3 : 0;

        return negativeSign +
            (j ? i.substr(0, j) + thousands : '') +
            i.substr(j).replace(/(\d{3})(?=\d)/g, "$1" + thousands) +
            (decimalCount ? decimal + Math.abs(amount - i).toFixed(decimalCount).slice(2) : "");
    } catch (e) {
        console.log(e)
    }
}

function getFormatter(type, absoluteValue, scaleFactorIndex) {
    let typeOptions = types[type];
    if (typeOptions == null) { return null; }

    absoluteValue |= typeOptions.absolute_value;
    let formatter = function (value) {
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

function formatDateTime(date, type = 'datetime') {
    if (!date) {
        return '';
    }

    // localize to server timestamp
    date = utc_s_to_server_date(date);

    // check that date exists
    if (isNaN(date.getTime())) {
        return '';
    }

    const now = new Date();
    
    // create date only
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const inputDate = new Date(date.getFullYear(), date.getMonth(), date.getDate());
    // Calculate difference in days
    const delta_days = Math.floor((today.getTime() - inputDate.getTime()) / (1000 * 60 * 60 * 24));
    
    // Time formatter
    const time_formatter = date.toLocaleTimeString('en-GB', {
        hour: '2-digit',
        minute: '2-digit',
        second: '2-digit',
        hour12: false
    });

    let formatted_date = '';

    if (delta_days === 0) {
        // Today
        formatted_date = 'Today';
        if (type === 'date_only') {
            return formatted_date;
        }
        return `${time_formatter}`;
    } else if (delta_days === 1) {
        // Yesterday
        formatted_date = 'Yesterday';
    } else if (delta_days >= 2 && delta_days <= 6) {
        // Within the last week - show weekday
        formatted_date = date.toLocaleDateString('en-GB', { weekday: 'short' });
    } else if (delta_days >= 7 && delta_days <= 365) {
        // Within the last year - show month and day
        formatted_date = date.toLocaleDateString('en-GB', {
            month: 'short',
            day: 'numeric'
        });
    } else if (delta_days > 365) {
        // More than one year ago - show full date
        formatted_date = date.toLocaleDateString('en-GB', {
            year: 'numeric',
            month: 'short',
            day: 'numeric'
        });
    } else {
        // Future dates (negative delta_days)
        formatted_date = date.toLocaleDateString('en-GB', {
            year: 'numeric',
            month: 'short',
            day: 'numeric'
        });
    }

    // Return based on type
    if (type === 'date_only') {
        return formatted_date;
    }
    
    return `${formatted_date}, ${time_formatter}`;
}

function utc_s_to_server_date(utc_seconds) {
    let utc = utc_seconds * 1000;
    let d_local = new Date(utc);
    let local_offset = d_local.getTimezoneOffset();
    let server_offset = moment.tz(utc, ntop_zoneinfo)._offset;
    let offset_minutes = server_offset + local_offset;
    let offset_ms = offset_minutes * 1000 * 60;
    var d_server = new Date(utc + offset_ms);
    return d_server;
}

function server_date_to_date(date, format) {
    let utc = date.getTime();
    let local_offset = date.getTimezoneOffset();
    let server_offset = moment.tz(utc, ntop_zoneinfo)._offset;
    let offset_minutes = server_offset + local_offset;
    let offset_ms = offset_minutes * 1000 * 60;
    var d_local = new Date(utc - offset_ms);
    return d_local;
}

// formats the as as 
function formatAsn(asn, as_name) {
    if (asn !== 0) {
        return `${asn} (${as_name})`
    }
}

function getMidnightEpoch(utc_seconds) {
  let utc = utc_seconds * 1000;
  const utc_midnight = moment.tz(utc, ntop_zoneinfo).startOf('day');
  return utc_midnight.valueOf()/1000;
}

/* Makes uppercase each first character of a string */
function capitalizeFirstLetters(str) {
    return str
      .split(' ')
      .map(word => {
        if (word.length === 0) return word;
        return word[0].toUpperCase() + word.slice(1);
      })
      .join(' ');
}
  
const formatterUtils = function () {
    return {
        types,
        getUnitMeasureLen,
        getFormatter,
        getScaleFactorIndex,
        formatAccounting,
        formatDateTime,
        utc_s_to_server_date,
        server_date_to_date,
        formatAsn,
        getMidnightEpoch,
        capitalizeFirstLetters
    };
}();

export default formatterUtils;
