/**
    (C) 2023 - ntop.org
*/

import Dygraph from 'dygraphs';
import colorsInterpolation from "../colors/colors-interpolation";
import formatterUtils from "../formatter-utils";

/* ***************************************** */

/* This function return the default config for dygraph charts */
function getDefaultConfig() {
    return {
        labelsSeparateLines: true,
        connectSeparatedPoints: false,
        includeZero: true,
        drawPoints: true,
        highlightSeriesBackgroundAlpha: 0.7,
        highlightSeriesOpts: {
            strokeWidth: 2,
            pointSize: 3,
            highlightCircleSize: 6,
        },
        axisLabelFontSize: 12,
        axes: {
            x: {
                axisLabelWidth: 90
            }
        },
    };
}

/* ***************************************** */

/* This function put the correct formatters in the configuration */
function changeFormatters(config, options) {
    if (options?.formatters?.length > 1) {
        /* Multiple formatters */
        /* NOTE: at most 2 formatters can be used */
        config.axes.y1 = getAxisConfiguration(formatterUtils.getFormatter(options.formatters[0]));
        config.axes.y2 = getAxisConfiguration(formatterUtils.getFormatter(options.formatters[1]));
    } else if (options?.formatters?.length == 1) {
        /* Single formatter */
        config.axes.y = getAxisConfiguration(formatterUtils.getFormatter(options.formatters[0]));
    }
}

/* ***************************************** */

/* This function return the color of the serie when highlighted */
function getHighlightColor() {
    const is_dark_mode = document.getElementsByClassName('body dark').length > 0;
    let highlight_color = 'rgb(255, 255, 255)';
    if (is_dark_mode) {
        highlight_color = 'rgb(13, 17, 23)';
    }
    return highlight_color;
}

/* ***************************************** */

/* This function is used to format the value on the legend */
function getAxisConfiguration(formatter) {
    return {
        axisLabelFormatter: formatter,
        valueFormatter: function (num_or_millis, opts, seriesName, dygraph, row, col) {
            const serie_point = dygraph?.rawData_?.[row]?.[col];
            let data = '';
            if (typeof (serie_point) == "object") {
                /* This is the case for the serie with bounds */
                serie_point.forEach((el) => {
                    data = `${data} / ${formatter(el || 0)}`;
                })
                data = data.substring(3); /* Remove the first three characters ' / ' */
            } else {
                /* This is the standard case */
                data = formatter(num_or_millis);
            }
            return (data);
        },
        axisLabelWidth: 80,
    }
}

/* ***************************************** */

/* This function is used to format the value on the legend */
function getDefaultLegendFormatter(options) {
    return function (data) {
        if (!data.x) return ""; // no hover
        const timeBadge = `<h6><span class="badge bg-light mb-1 text-dark">${data.xHTML}</span></h6>`;
        let total = 0
        let setTotal = false
        let totalString = ''

        // Entries
        const seriesHTML = data.series.filter(s => s.isVisible && s.yHTML).map(s => {
            if (!s.isVisible) return "";
            if (!isNaN(s.y) && !s.labelHTML.includes(i18n('details.ago'))) {
                // Skip e.g. 30 min Ago series from the total
                setTotal = true;
                total = total + Math.abs(s.y)
            }
            const colorDot = `<span class="badge rounded-pill me-1" style="background-color:${s.color}"> </span>`;
            return `<div class="mt-1 d-flex"><div class="me-4">${colorDot}${s.labelHTML}</div><div class="ms-auto">${s.yHTML}</div></div>`;
        }).join("");

        if (setTotal) {
            const formatter = formatterUtils.getFormatter(options.formatters[0])
            totalString = `<div class="mt-1 d-flex"><div class="me-4"><strong>Total</strong></div><div class="ms-auto">${formatter(total)}</div></div>`
        }

        return `<div style="font-size:13px; line-height:1.4;">${timeBadge}${totalString}${seriesHTML}</div>`;
    }
}

/* ***************************************** */

/* This function merges the default config with the options requested */
function buildChartOptions(options) {
    const config = getDefaultConfig();
    const legendFormatter = getDefaultLegendFormatter(options);

    config.customBars = options.customBars;
    config.labels = (options.labels) ? options.labels : ["Time"];
    config.series = options.properties;
    config.data = (options.serie) ? options.serie : [];
    config.stackedGraph = options.stacked;
    config.valueRange = options.value_range;
    config.highlightSeriesBackgroundColor = getHighlightColor();
    config.colors = (options.colors) ? colorsInterpolation.transformColors(options.colors || []) : [];
    config.disableTsList = options.disable_ts_list;
    config.yRangePad = options.yRangePad || 1;
    config.legendFormatter = legendFormatter;
    config.blockStacked = options.block_stacked

    /* Change the plotter */
    if (options.plotter) {
        config.plotter = options.plotter;
    }

    changeFormatters(config, options);

    return config;
}

/* ***************************************** */

function formatSerieProperties(type) {
    switch (type) {
        case 'dash':
            return {
                fillGraph: false,
                customBars: false,
                strokePattern: Dygraph.DASHED_LINE
            };
        case 'point':
            return {
                fillGraph: false,
                customBars: false,
                strokeWidth: 0.0,
                pointSize: 2.0,
            };
        case 'bounds':
            return {
                fillGraph: false,
                strokeWidth: 1.0,
                pointSize: 1.5,
                fillAlpha: 0.5
            };
        case 'line':
            return {
                fillGraph: false,
                customBars: false,
                strokeWidth: 1.5,
                pointSize: 1.5,
            };
        default:
            return {
                fillGraph: true,
                customBars: false,
                strokeWidth: 1.0,
                pointSize: 1.5,
                fillAlpha: 0.5
            };
    }
}

/* ***************************************** */

const dygraphConfig = function () {
    return {
        buildChartOptions,
        formatSerieProperties
    };
}();

export default dygraphConfig;