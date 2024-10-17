/**
    (C) 2023 - ntop.org
*/

import dygraphPlotters from "./dygraph-plotters.js";
import dygraphConfig from "./dygraph-config.js";


/* ***************************************** */

const defaultColors = [
  "#C6D9FD",
  "#90EE90",
  "#EE8434",
  "#C95D63",
  "#AE8799",
  "#717EC3",
  "#496DDB",
  "#5A7ADE",
  "#6986E1",
  "#7791E4",
  "#839BE6",
  "#8EA4E8",
];

/* ***************************************** */

const constant_serie_colors = {
  "default_color": "#C6D9FD",
  "95_perc": "#8EA4E8",
  "avg": "#839BE6",
}

/* ***************************************** */

function getSerieId(serie) {
  return `${serie.id}`;
}

/* ***************************************** */

function formatSerieColors(palette_list) {
  let colors_list = palette_list;
  let count0 = 0, count1 = 0;
  let colors0 = defaultColors;
  let colors1 = d3v7.schemeCategory10;
  colors_list.forEach((s, index) => {
    if (s.palette == 0) {
      if (palette_list.find((element, j) => (element.color === s.color && j !== index))) {
        palette_list[index] = colors0[count0 % colors0.length];
      } else {
        palette_list[index] = s.color;
      }
      count0 += 1;
    } else if (s.palette == 1) {
      palette_list[index] = colors1[count1 % colors1.length];
      count1 += 1;
    }
  });
}

/* *********************************************** */

/* Return the formatted serie name */
function getSerieName(name, id, tsGroup, useFullName) {
  if (name == null) {
    name = id;
  }
  let name_more_space = "";
  if (name != null) {
    name_more_space = `${name}`;
  }
  if (useFullName == false) {
    return name;
  }
  let source_index = 0;
  let source_def_array = tsGroup.source_type.source_def_array;
  for (let i = 0; i < source_def_array.length; i += 1) {
    let source_def = source_def_array[i];
    if (source_def.main_source_def == true) {
      source_index = i;
      break;
    }
  }

  let source = tsGroup.source_array[source_index];
  let prefix = `${source.label}`;
  return `${prefix} - ${name_more_space}`;
}

/* *********************************************** */

/* Given all the info about a timeserie, return the correct name to be displayed */
function getName(ts_info, metadata) {
  let name = (metadata.use_serie_name == true) ? ts_info.name : metadata.label;

  if (ts_info.ext_label) {
    name = ts_info.ext_label
  }
  return name
}

/* *********************************************** */

/* This function return the plotting function */
function getPlotter(chart_type) {
  switch (chart_type) {
    case 'bar':
      return dygraphPlotters.barChartPlotter;
  }
}

/* *********************************************** */

function addNewSerie(serie_name, chart_type, color, config) {
  config.labels.push(serie_name);
  if(config.properties == null) 
    config.properties = {}
  config.properties[serie_name] = {}
  config.properties[serie_name] = dygraphConfig.formatSerieProperties(chart_type);
  config.colors.push(color);
}

/* *********************************************** */

/* This function given a serie, format the array needed */
function compactSerie(config, ts_info, extra_timeseries, serie, past_serie, scalar, step, epoch_begin, names) {
  const avg_value = ts_info.statistics["average"];
  const perc_value = ts_info.statistics["95th_percentile"];
  let time = epoch_begin;

  /* Now format the timeserie */
  for (let point = 0; point < serie.length; point++) {
    const serie_point = serie[point];
    /* If the point is inserted for the first time, add the time before everything else */
    if (!config.serie[time]) {
      config.serie[time] = [{ value: new Date(time * 1000), name: "Time" }];
    }
    /* Add the point to the array or NaN if it's null */
    (serie_point !== null) ?
      config.serie[time].push({ value: serie_point * scalar, name: names.serie_name }) :
      config.serie[time].push({ value: NaN, name: names.serie_name });

    /* Add extra series, avg, 95th and past timeseries */
    if (extra_timeseries?.avg == true) {
      config.serie[time].push({ value: avg_value * scalar, name: names.avg_name });
    }
    if (extra_timeseries?.perc_95 == true) {
      config.serie[time].push({ value: perc_value * scalar, name: names.perc_name });
    }
    if (extra_timeseries?.past == true) {
      const past_value = (past_serie) ? past_serie[point] : null;
      (past_value) ?
        config.serie[time].push({ value: past_value * scalar, name: names.past_name }) :
        config.serie[time].push({ value: NaN, name: names.past_label });
    }

    /* Increase the time using the step */
    time = time + step;
  }
}

/* *********************************************** */

/* This function format the Bound type serie in the correct format */
function splitBoundSerie(series, timeserie_info) {
  let serie = [];
  let color = {};
  let formatter = null;
  let serie_name = null;
  let properties = {};
  let full_serie = [];

  /* A bound timeserie should be composed by 3 timeseries:
   *    - metric (main)
   *    - lower_bound (the lower bound)
   *    - upper_bound (the upper bound)
   */
  series.forEach((ts_info, j) => {
    const ts_id = getSerieId(ts_info);
    const serie = ts_info.data || []; /* Safety check */
    const metadata = timeserie_info.metric.timeseries[ts_id];
    const scalar = (metadata?.invert_direction === true) ? -1 : 1;

    /* Just add the name, properties, colors, ecc, for the 
     * "main" timeserie and not for the bounds ones 
     */
    if (metadata.type == "metric") {
      serie_name = getSerieName(metadata.label, ts_id, timeserie_info, true);
      properties = dygraphConfig.formatSerieProperties('bounds');
      color = { color: metadata.color, palette: 0 };
      formatter = timeserie_info.metric.measure_unit;
    }
    for (let point = 0; point < serie.length; point++) {
      let serie_point = (serie[point] === null) ? NaN : serie[point];
      if (full_serie[point] == null) {
        full_serie[point] = [0, NaN, 0];
      }

      if (metadata.type == "lower_bound") {
        full_serie[point][0] = serie_point * scalar;
      } else if (metadata.type == "metric") {
        full_serie[point][1] = serie_point * scalar;
      } else if (metadata.type == "upper_bound") {
        full_serie[point][2] = serie_point * scalar;
      }
    }
  })

  return { serie: full_serie, color: color, formatter: formatter, serie_name: serie_name, properties: properties };
}

/* *********************************************** */

/* This function, given a serie format the bounds serie */
function formatBoundsSerie(timeserie_info, timeserie_options, config) {
  /* By default the chart type is line */
  const chart_type = timeserie_info.metric.chart_type || "filled";
  const series = timeserie_options.series || [];
  const epoch_begin = timeserie_options.metadata.epoch_begin;
  const step = timeserie_options.metadata.epoch_step;
  const { serie, color, formatter, serie_name, properties } = splitBoundSerie(series, timeserie_info);
  let time = epoch_begin;
  /* TODO: add avg, past, ecc. timeseries to the bounds one */

  /* Update the config */
  const formatted_name = `${serie_name} ${i18n('lower_value_upper')}`
  const formatter_found = config.formatters.find(el => el == formatter);
  if (!formatter_found)
    config.formatters.push(formatter);
  config.plotter = getPlotter(chart_type);
  config.customBars = true;
  config.colors.push(color);
  config.labels.push(formatted_name);
  config.properties[formatted_name] = properties;

  /* Update the serie */
  Object.keys(serie).forEach((key) => {
    if (!config.serie[time]) {
      config.serie[time] = [
        { value: new Date(time * 1000), name: "Time" },
        { value: serie[key], name: formatted_name }
      ];
    }

    time = time + step;
  });
}

/* *********************************************** */

function formatStandardSerie(timeserie_info, timeserie_options, config, tsCompare) {
  /* Iterate all the timeseries currently contained inside the single ts:
   * e.g. in the Traffic timeseries we have the Bytes sent and Bytes rcvd
   */
  const series = timeserie_options.series || [];
  const chart_type = timeserie_info.metric.chart_type || "filled";
  const epoch_begin = timeserie_options.metadata.epoch_begin;
  const step = timeserie_options.metadata.epoch_step;
  const formatter = timeserie_info.metric.measure_unit;
  const max_value = timeserie_info.metric.max_value || null;
  const min_value = timeserie_info.metric.min_value || null;
  const past_serie = timeserie_options.additional_series;
  let disable_past_ts = false;

  config.value_range = [min_value, max_value];
  config.plotter = getPlotter(chart_type);
  if (!config.stacked) {
    config.stacked = timeserie_info.metric.draw_stacked || false;
  }
  if (timeserie_info.metric.disable_default_ago_ts) {
    disable_past_ts = timeserie_info.metric.disable_default_ago_ts || true
  }

  series.forEach((ts_info, j) => {
    const serie = ts_info.data || []; /* Safety check */
    const extra_timeseries = timeserie_info.timeseries[0]; /* e.g. the Average */
    const ts_id = getSerieId(ts_info);
    const metadata = timeserie_info.metric.timeseries[ts_id];
    const scalar = (metadata.invert_direction === true) ? -1 : 1;
    const timeserie_name = getName(ts_info, metadata)
    const serie_name = getSerieName(timeserie_name, ts_id, timeserie_info, config.use_full_name)
    const avg_name = getSerieName(timeserie_name + " Avg", ts_id, timeserie_info, config.use_full_name)
    const perc_name = getSerieName(timeserie_name + " 95th Perc", ts_id, timeserie_info, config.use_full_name);
    const past_name = getSerieName(timeserie_name + " " + tsCompare + " Ago", ts_id, timeserie_info, config.use_full_name);
    const past_value = (past_serie) ? past_serie[`${tsCompare}_ago`]?.series[j]?.data : null;
    /* An option used to not display a timeserie */
    if (metadata.hidden) {
      return;
    }

    /* Search for the formatter in the array, if not found, add it. */
    const formatter_found = config.formatters.find(el => el == formatter);
    if (!formatter_found)
      config.formatters.push(formatter);

    /* Add the serie */
    addNewSerie(serie_name, chart_type, { color: metadata.color, palette: 0 }, config)

    /* Adding the extra timeseries, 30m ago, avg and 95th */
    if (extra_timeseries?.avg == true) {
      addNewSerie(avg_name, "point", { color: constant_serie_colors["avg"], palette: 1 }, config)
    }
    if (extra_timeseries?.perc_95 == true) {
      addNewSerie(perc_name, "point", { color: constant_serie_colors["perc_95"], palette: 1 }, config)
    }
    if (extra_timeseries?.past == true && !disable_past_ts) {
      addNewSerie(past_name, "dash", { color: constant_serie_colors["past"], palette: 1 }, config)
    }

    /* ************************************** */

    compactSerie(config, ts_info, extra_timeseries, serie, past_value, scalar, step, epoch_begin, {
      serie_name: serie_name,
      avg_name: avg_name,
      perc_name: perc_name,
      past_name: past_name
    });
  })
}

/* ************************************** */

/* This function finally format the timeseries and compact it togheter */
function formatFullSerie(config) {
  const full_serie = [];
  const serie_keys = Object.keys(config.serie);

  /* Iterate the serie and for each label, get the value and set to null in case it does not exists */
  serie_keys.forEach((key, index) => {
    full_serie[index] = [];
    config.labels.forEach((label) => {
      let found = false;
      for (let j = 0; j < config.serie[key].length; j++) {
        if (config.serie[key][j].name == label) {
          full_serie[index].push(config.serie[key][j].value);
          found = true;
          break;
        }
      }

      /* Push null if no value is found */
      if (found == false) {
        full_serie[index].push(null);
      }
    })
  });
  config.serie = full_serie;
}

/* ************************************** */

function formatSingleSerie(timeserie_info, timeserie_options, tsCompare, config) {
  if (timeserie_info.source_type.f_map_ts_options != null) {
    const f_map_ts_options = timeserie_info.source_type.f_map_ts_options;
    timeserie_options = f_map_ts_options(timeserie_options, timeserie_info);
  }

  /* Format the data */

  /* the data in Dygraphs should be formatted as follow:
   * { [ time_1, serie1_1, serie2_1 ], [ time_2, serie1_2, serie2_2 ] } 
   */
  const bounds = timeserie_info.metric.bounds || false;

  /* The serie can possibly have multiple timeseries, like for the 
   * bytes, we have sent and rcvd, so compact them 
   */
  if (bounds == true) {
    formatBoundsSerie(timeserie_info, timeserie_options, config);
  } else {
    formatStandardSerie(timeserie_info, timeserie_options, config, tsCompare);
  }
}

/* *********************************************** */

function formatSimpleSerie(data, serie_name, chart_type, formatters, value_range) {
  let counter = 1;
  const tmp_serie = [];
  data.serie.forEach((value) => {
    tmp_serie.push([counter, value]);
    counter++;
  });

  /* To not have an error, just add a null value */
  if(tmp_serie.length == 0) {
    tmp_serie.push([1, null]);
  }

  const config = {
    serie: tmp_serie,
    formatters: formatters,
    labels: ["index"],
    colors: [],
    stacked: false,
    customBars: false,
    use_full_name: false,
    plotter: getPlotter(chart_type),
    value_range: value_range,
    disable_ts_list: true,
  };

  if (typeof(serie_name) === "string") {
    addNewSerie(serie_name, chart_type, { color: constant_serie_colors["default_color"], palette: 0 }, config)
  } else {
    serie_name.forEach((el) => {
      addNewSerie(el, chart_type, { color: constant_serie_colors["default_color"], palette: 0 }, config)
    })
  }
  formatSerieColors(config.colors);  
  return dygraphConfig.buildChartOptions(config);
}

/* *********************************************** */

function formatSerie(tsOptionsArray, tsGroupsArray, tsCompare, useFullName) {
  const config = {
    serie: [],
    formatters: [],
    labels: ["Time"],
    colors: [],
    properties: [],
    stacked: false,
    customBars: false,
    use_full_name: (useFullName != null) ? useFullName : false
  };

  /* Go throught each serie */
  tsOptionsArray.forEach((tsOptions, i) => {
    formatSingleSerie(tsGroupsArray[i], tsOptions, tsCompare, config);
  });

  /* Need to finally format the serie as requested by Dygraph, with
     NULL as value in case the serie has NOT THAT POINT (e.g. with a 5 minutes frequency, the user
      is confronting a chart with 1 minute frequency, there are 4 minutes with no existing points)
   */
  formatFullSerie(config);
  formatSerieColors(config.colors);
  return dygraphConfig.buildChartOptions(config);
}

/* *********************************************** */

const dygraphFormat = function () {
  return {
    formatSerie,
    formatSimpleSerie,
    getSerieId,
    getSerieName,
  };
}();

export default dygraphFormat;