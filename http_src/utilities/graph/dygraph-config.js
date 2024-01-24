/**
    (C) 2023 - ntop.org
*/

import colorsInterpolation from "../colors/colors-interpolation";
import formatterUtils from "../formatter-utils";

/* ***************************************** */

/* This function return the default config for dygraph charts */
function getDefaultConfig() {
  return {
    labelsSeparateLines: true,
    legend: "follow",
    connectSeparatedPoints: true,
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
  if (options.formatters.length > 1) {
    /* Multiple formatters */
    /* NOTE: at most 2 formatters can be used */
    config.axes.y1 = getAxisConfiguration(formatterUtils.getFormatter(options.formatters[0]));
    config.axes.y2 = getAxisConfiguration(formatterUtils.getFormatter(options.formatters[1]));
  } else if (options.formatters.length == 1) {
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
      const serie_point = dygraph?.rawData_?.[row][col];
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

/* This function merges the default config with the options requested */
function buildChartOptions(options) {
  const interpolated_colors = colorsInterpolation.transformColors(options.colors);
  const highlight_color = getHighlightColor();
  const config = getDefaultConfig();

  config.customBars = options.customBars;
  config.labels = options.labels;
  config.series = options.properties;
  config.data = options.serie;
  config.stackedGraph = options.stacked;
  config.valueRange = options.value_range;
  config.highlightSeriesBackgroundColor = highlight_color;
  config.colors = interpolated_colors;
  config.disableTsList = options.disable_ts_list;
  config.yRangePad = options.yRangePad || 1;

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