// 2018 - ntop.org

var schema_2_label = {};
var data_2_label = {};
var graph_i18n = {};

function initLabelMaps(_schema_2_label, _data_2_label, _graph_i18n) {
  schema_2_label = _schema_2_label;
  data_2_label = _data_2_label;
  graph_i18n = _graph_i18n;
};

function getSerieLabel(schema, serie) {
  var data_label = serie.label;
  var new_label = data_2_label[data_label];

  if((schema == "top:local_senders") || (schema == "top:local_receivers")) {
    return serie.tags.host
  } else if(schema.startsWith("top:")) { // topk graphs
    if(serie.tags.protocol)
      return serie.tags.protocol;
    else if(serie.tags.category)
      return serie.tags.category
    else if(serie.tags.device && serie.tags.if_index) { // SNMP interface
      if(serie.tags.if_index != serie.ext_label)
        return serie.ext_label + " (" + serie.tags.if_index + ")";
      else
        return serie.ext_label;
    } else if(serie.tags.device && serie.tags.port) // Flow device
      return serie.tags.port;
    else if(serie.tags.profile)
        return serie.tags.profile;
  } else if(data_label != "bytes") { // single series
    if(serie.tags.protocol)
      return serie.tags.protocol + " (" + new_label + ")";
    else if(serie.tags.category)
      return serie.tags.category + " (" + new_label + ")";
    else if(serie.tags.device && serie.tags.if_index) // SNMP interface
      return serie.ext_label + " (" + new_label + ")";
    else if(serie.tags.device && serie.tags.port) // Flow device
      return serie.tags.port + " (" + new_label + ")";
  } else {
      if(serie.tags.protocol)
        return serie.tags.protocol;
      else if(serie.tags.category)
        return serie.tags.category;
      else if(serie.tags.profile)
        return serie.tags.profile;
      else if(data_label == "bytes")
        return graph_i18n.traffic;
  }

  if(schema_2_label[schema])
    return capitaliseFirstLetter(schema_2_label[schema]);

  if(new_label)
    return capitaliseFirstLetter(new_label);

  // default
  return capitaliseFirstLetter(data_label);
}

// Value formatter
function getValueFormatter(schema, series) {
  if(series && series.length && series[0].label) {
    var label = series[0].label;

    if(label.contains("bytes"))
      return [fbits_from_bytes, bytesToSize];
    else if(label.contains("packets"))
      return [fpackets, formatPackets];
    else if(label.contains("flows"))
      return [formatValue, formatFlows, formatFlows];
    else if(label.contains("millis"))
      return [fmillis, fmillis];
  }

  // fallback
  return [fint,fint];
}

function makeFlatLineValues(tstart, tstep, num, data) {
  var t = tstart;
  var values = [];

  for(var i=0; i<num; i++) {
    values[i] = [t, data ];
    t += tstep;
  }

  return values;
}

function checkSeriesConsinstency(schema_name, count, series) {
  var rv = true;

  for(var i=0; i<series.length; i++) {
    var data = series[i].data;

    if(data.length > count) {
        console.error("points mismatch: serie '" + getSerieLabel(schema_name, series[i]) +
          "' has " + data.length + " points, expected " + count);

      rv = false;
    } else if(data.length < count) {
      /* upsample */
      series[i].data = upsampleSerie(data, count);
    }
  }

  return rv;
}

function upsampleSerie(serie, num_points) {
  if(num_points <= serie.length)
    return serie;

  var res = [];
  var intervals = num_points / serie.length;

  function lerp(v0, v1, t) {
    return (1 - t) * v0 + t * v1;
  }

  for(var i=0; i<num_points; i++) {
    var index = i / intervals;
    var prev_i = Math.floor(index);
    var next_i = Math.min(Math.ceil(index), serie.length-1);
    var t = index % 1; // fractional part
    var v = lerp(serie[prev_i], serie[next_i], t);
    //console.log(prev_i, next_i, t, ">>", v);

    res.push(v);
  }

  return res.slice(0, num_points);
}

// the stacked total serie
function buildTotalSerie(data_series) {
  var series = [];

  for(var i=0; i<data_series.length; i++)
    series.push(data_series[i].data);

  return d3.transpose(series).map(function(x) {
    return x.map(function(g) {
      return g;
    });
  }).map(function(x) {return d3.sum(x);});
}

function arrayToNvSerie(serie_data, start, step) {
  var values = [];
  var t = start;

  for(var i=0; i<serie_data.length; i++) {
    values[i] = [t, serie_data[i]];
    t += step;
  }

  return values;
}

// computes the difference between visual_total and total_serie
function buildOtherSerie(total_serie, visual_total) {
  if(total_serie.length !== visual_total.length) {
    console.warn("Total/Visual length mismatch: " + total_serie.length + " vs " + visual_total.length);
    return;
  }

  var res = [];
  var max_val = 0;

  for(var i=0; i<total_serie.length; i++) {
    var value = Math.max(0, total_serie[i] - visual_total[i]);
    max_val = Math.max(max_val, value);

    res.push(value);
  }

  if(max_val > 0.1)
    return res;
}

function buildTimeArray(start_time, end_time, step) {
  var arr = [];

  for(var t=start_time; t<end_time; t+=step)
    arr.push(t);

  return arr;
}

function fixTimeRange(chart, params, step) {
  var diff_epoch = (params.epoch_end - params.epoch_begin);
  var frame, align, tick_step, resolution, fmt = "%H:%M:%S";

  // must be sorted by ascending max_diff
  // max_diff / tick_step indicates the number of ticks, which should be <= 15
  // max_diff / resolution indicates the number of actual points, which should be ~60
  var range_params = [
    // max_diff, resolution, x_format, alignment, tick_step
    [15, 1, "%H:%M:%S", 1, 1],                          // <= 15 sec
    [60, 1, "%H:%M:%S", 1, 5],                          // <= 1 min
    [120, 5, "%H:%M:%S", 10, 10],                       // <= 2 min
    [300, 5, "%H:%M:%S", 10, 30],                       // <= 5 min
    [600, 10, "%H:%M:%S", 30, 60],                      // <= 10 min
    [1200, 30, "%H:%M:%S", 60, 120],                    // <= 20 min
    [3600, 60, "%H:%M:%S", 60, 300],                    // <= 1 h
    [5400, 120, "%H:%M", 300, 900],                     // <= 1.5 h
    [10800, 300, "%H:%M", 300, 900],                    // <= 3 h
    [21600, 300, "%H:%M", 3600, 1800],                  // <= 6 h
    [43200, 600, "%H:%M", 3600, 3600],                  // <= 12 h
    [86400, 600, "%H:%M", 3600, 7200],                  // <= 1 d
    [172800, 3600, "%a, %H:%M", 3600, 14400],           // <= 2 d
    [604800, 3600, "%Y-%m-%d", 86400, 86400],           // <= 7 d
    [1209600, 7200, "%Y-%m-%d", 86400, 172800],         // <= 14 d
    [2678400, 21600, "%Y-%m-%d", 86400, 259200],        // <= 1 m
    [15768000, 175200, "%Y-%m-%d", 2678400, 1314000],   // <= 6 m
    [31622400, 175200, "%Y-%m-%d", 2678400, 2678400],   // <= 1 y
  ];

  for(var i=0; i<range_params.length; i++) {
    var range = range_params[i];

    if(diff_epoch <= range[0]) {
      frame = range[0];
      resolution = range[1];
      fmt = range[2];
      align = range[3];
      tick_step = range[4];
      break;
    }
  }

  if(align) {
    align = Math.max(align, step);
    params.epoch_begin -= params.epoch_begin % align;
    params.epoch_end -= params.epoch_end % align;
    diff_epoch = (params.epoch_end - params.epoch_begin);
    params.limit = Math.round(diff_epoch / resolution);

    // align epoch end wrt params.limit
    params.epoch_end += Math.ceil(diff_epoch / params.limit) * params.limit - diff_epoch;

    chart.xAxis.tickValues(buildTimeArray(params.epoch_begin, params.epoch_end, tick_step));
  }

  chart.xAxis.tickFormat(function(d) { return d3.time.format(fmt)(new Date(d*1000)) });
}

// add a new updateStackedChart function
function attachStackedChartCallback(chart, schema_name, chart_id, zoom_reset_id, flows_dt, params, step) {
  var pending_request = null;
  var d3_sel = d3.select(chart_id);
  var $chart = $(chart_id);
  var $zoom_reset = $(zoom_reset_id);
  var $graph_zoom = $("#graph_zoom");
  var max_interval = step * 8;
  var is_max_zoom = false;
  var zoom_stack = [];
  var url = http_prefix + "/lua/get_ts.lua";
  var first_load = true;
  var first_time_loaded = true;
  var datetime_format = "dd/MM/yyyy hh:mm:ss";
  var max_over_total_ratio = 3;

  //var spinner = $("<img class='chart-loading-spinner' src='" + spinner_url + "'/>");
  var spinner = $('<i class="chart-loading-spinner fa fa-spinner fa-lg fa-spin"></i>');
  $chart.parent().css("position", "relative");

  var chart_colors_full = [
    "#69B87F",
    "#94CFA4",
    "#B3DEB6",
    "#E5F1A6",
    "#FFFCC6",
    "#FEDEA5",
    "#FFB97B",
    "#FF8D6D",
    "#E27B85"
  ];

  var chart_colors_min = ["#7CC28F", "#FCD384", "#FD977B"];

  var update_chart_data = function(new_data) {
    /* reset chart data so that the next transition animation will be gracefull */
    d3_sel.datum([]).call(chart);

    d3_sel.datum(new_data).transition().call(chart);
    nv.utils.windowResize(chart.update);
    pending_request = null;
    spinner.remove();
  }

  function isLegendDisabled(key, default_val) {
    if(typeof localStorage !== "undefined") {
      var val = localStorage.getItem("chart_series.disabled." + key);

      if(val != null)
        return(val === "true");
    }

    return default_val;
  }

  chart.legend.dispatch.on('legendClick', function(d,i) {
    if(typeof localStorage !== "undefined")
      localStorage.setItem("chart_series.disabled." + d.legend_key, (!d.disabled) ? true : false);
  });

  chart.dispatch.on("zoom", function(e) {
    var cur_zoom = [params.epoch_begin, params.epoch_end];
    var t_start = Math.floor(e.xDomain[0]);
    var t_end = Math.ceil(e.xDomain[1]);

    if(chart.updateStackedChart(t_start, t_end)) {
      chart.is_zoomed = true;
      zoom_stack.push(cur_zoom);
      $zoom_reset.show();
      $graph_zoom.find(".btn-warning:not(.custom-zoom-btn)")
        .addClass("initial-zoom-sel")
        .removeClass("btn-warning");
      $graph_zoom.find(".custom-zoom-btn").show();

      var zoom_link = $graph_zoom.find(".custom-zoom-btn input");
      var link = zoom_link.val().replace(/&epoch_begin=.*/, "");
      link += "&epoch_begin=" + params.epoch_begin + "&epoch_end=" + params.epoch_end;
      zoom_link.val(link);
    }
  });

  function updateZoom(zoom) {
    var t_start = zoom[0];
    var t_end = zoom[1];

    chart.updateStackedChart(t_start, t_end);

    if(!zoom_stack.length) {
      $zoom_reset.hide();

      $graph_zoom.find(".initial-zoom-sel")
        .addClass("btn-warning");
      $graph_zoom.find(".custom-zoom-btn").hide();
    }
  }

  $chart.on('dblclick', function() {
    if(zoom_stack.length) {
      var zoom = zoom_stack.pop();
      updateZoom(zoom);
    }
  });

  $zoom_reset.on("click", function() {
    if(zoom_stack.length) {
      var zoom = zoom_stack[0];
      zoom_stack = [];
      updateZoom(zoom);
    }
  });

  var old_start, old_end;

  /* Returns false if zoom update is rejected. */
  chart.updateStackedChart = function (tstart, tend, no_spinner) {
    if(tstart) params.epoch_begin = tstart;
    if(tend) params.epoch_end = tend;

    var cur_interval = (params.epoch_end - params.epoch_begin);

    if(cur_interval < max_interval) {
      if(is_max_zoom)
        return false;

      if(!first_load) {
        var epoch = params.epoch_begin + (params.epoch_end - params.epoch_begin) / 2;
        params.epoch_begin = Math.floor(epoch - max_interval / 2);
        params.epoch_end = Math.ceil(epoch + max_interval / 2);
      }

      is_max_zoom = true;
      chart.zoomType(null); // disable zoom
    } else {
      is_max_zoom = false;
      chart.zoomType('x'); // enable zoom
    }

    fixTimeRange(chart, params, step);

    if((old_start == params.epoch_begin) && (old_end == params.epoch_end))
      return false;

    old_start = params.epoch_begin;
    old_end = params.epoch_end;

    if(pending_request)
      pending_request.abort();
    else if(!no_spinner)
      spinner.appendTo($chart.parent());

    // Load data via ajax
    pending_request = $.get(url, params, function(data) {
      if(!data || !data.series || !data.series.length || !checkSeriesConsinstency(schema_name, data.count, data.series)) {
        update_chart_data([]);
        return;
      }

      // Adapt data
      var res = [];
      var series = data.series;
      var total_serie;
      var color_i = 0;

      var chart_colors = (series.length <= chart_colors_min.length) ? chart_colors_min : chart_colors_full;

      for(var j=0; j<series.length; j++) {
        var values = [];
        var serie_data = series[j].data;

        var t = data.start;
        for(var i=0; i<serie_data.length; i++) {
          values[i] = [t, serie_data[i] ];
          t += data.step;
        }

        var label = getSerieLabel(schema_name, series[j]);
        var legend_key = schema_name + ":" + label;

        res.push({
          key: label,
          yAxis: series[j].axis || 1,
          values: values,
          type: series[j].type || "area",
          color: chart_colors[color_i++],
          legend_key: legend_key,
          disabled: isLegendDisabled(legend_key, false),
        });
      }

      var visual_total = buildTotalSerie(series);
      var has_full_data = false;

      if(data.additional_series && data.additional_series.total) {
        total_serie = data.additional_series.total;

        /* Total -> Other */
        var other_serie = buildOtherSerie(total_serie, visual_total);

        if(other_serie) {
          res.push({
            key: graph_i18n.other,
            yAxis: 1,
            values: arrayToNvSerie(other_serie, data.start, data.step),
            type: "area",
            color: chart_colors[color_i++],
            legend_key: "other",
            disabled: isLegendDisabled("other", false),
          });

          has_full_data = true;
        }
      } else {
        total_serie = visual_total;
        has_full_data = !schema_name.startsWith("top:");
      }

      if(data.additional_series) {
        for(var key in data.additional_series) {
          if(key == "total") {
            // handle manually as "other" above
            continue;
          }

          var serie_data = upsampleSerie(data.additional_series[key], data.count);
          var ratio_over_total = d3.max(serie_data) / d3.max(visual_total);
          var values = arrayToNvSerie(serie_data, data.start, data.step);
          var is_disabled = isLegendDisabled(key, false);

          /* Hide comparison serie at first load if it's too high */
          if(first_time_loaded && (ratio_over_total > max_over_total_ratio))
            is_disabled = true;

          res.push({
            key: capitaliseFirstLetter(key),
            yAxis: 1,
            values: values,
            type: "line",
            classed: "line-dashed line-animated",
            color: "#7E91A0",
            legend_key: key,
            disabled: is_disabled,
          });
        }
      }

      if(!data.no_trend && has_full_data && total_serie.length) {
        // Smoothed serie
        var num_smoothed_points = Math.max(Math.floor(total_serie.length / 5), 3);

        var smoothed = smooth(total_serie, num_smoothed_points);
        var max_val = d3.max(smoothed);
        if(max_val > 0) {
          var scale = d3.max(total_serie) / max_val;
          var scaled = $.map(smoothed, function(x) { return x * scale; });
          var aligned = upsampleSerie(scaled, data.count);

          res.push({
            key: graph_i18n.trend,
            yAxis: 1,
            values: arrayToNvSerie(aligned, data.start, data.step),
            type: "line",
            classed: "line-animated",
            color: "#62ADF6",
            legend_key: "trend",
            disabled: isLegendDisabled("trend", false),
          });
        }
      }

      // get the value formatter
      var formatter1 = getValueFormatter(schema_name, series.filter(function(d) { return(d.axis != 2); }));
      var value_formatter = formatter1[0];
      var tot_formatter = formatter1[1];
      var stats_formatter = formatter1[2] || value_formatter;
      chart.yAxis1.tickFormat(value_formatter);
      chart.yAxis1_formatter = value_formatter;

      var second_axis_series = series.filter(function(d) { return(d.axis == 2); });
      var formatter2 = getValueFormatter(schema_name, second_axis_series);
      var value_formatter2 = formatter2[0];
      chart.yAxis2.tickFormat(value_formatter2);
      chart.yAxis2_formatter = value_formatter2;

      var stats_table = $chart.closest("table").find(".graph-statistics");
      var stats = data.statistics;

      stats_table.find(".graph-val-begin").show().find("span").html(new Date(data.start * 1000).format(datetime_format));
      stats_table.find(".graph-val-end").show().find("span").html(new Date((data.start + data.step * (data.count-1)) * 1000).format(datetime_format));

      if(stats) {
        if(stats.average) {
          var values = makeFlatLineValues(data.start, data.step, data.count, stats.average);

          res.push({
            key: graph_i18n.avg,
            yAxis: 1,
            values: values,
            type: "line",
            classed: "line-dashed line-animated",
            color: "#AC9DDF",
            legend_key: "avg",
            disabled: isLegendDisabled("avg", true),
          });
        }

        // fill the stats
        if(stats.total)
          stats_table.find(".graph-val-total").show().find("span").html(tot_formatter(stats.total));
        if(stats.average)
          stats_table.find(".graph-val-average").show().find("span").html(stats_formatter(stats.average));
        if(stats.min_val)
          stats_table.find(".graph-val-min").show().find("span").html(stats_formatter(stats.min_val) + " @ " + (new Date(res[0].values[stats.min_val_idx][0] * 1000)).format(datetime_format));
        if(stats.max_val)
          stats_table.find(".graph-val-max").show().find("span").html(stats_formatter(stats.max_val) + " @ " + (new Date(res[0].values[stats.max_val_idx][0] * 1000)).format(datetime_format));
        if(stats["95th_percentile"]) {
          stats_table.find(".graph-val-95percentile").show().find("span").html(stats_formatter(stats["95th_percentile"]));

          var values = makeFlatLineValues(data.start, data.step, data.count, stats["95th_percentile"]);

          res.push({
            key: graph_i18n["95_perc"],
            yAxis: 1,
            values: values,
            type: "line",
            classed: "line-dashed line-animated",
            color: "#476DFF",
            legend_key: "95perc",
            disabled: isLegendDisabled("95perc", true),
          });
        }

        // check if there are visible elements
        //if(stats_table.find("td").filter(function(){ return $(this).css("display") != "none"; }).length > 0)
      }
      stats_table.show();

      var enabled_series = res.filter(function(d) { return(d.disabled !== true); });

      if(second_axis_series.length > 0 || enabled_series.length == 0) {
        // Enable all the series
        for(var i=0; i<res.length; i++)
          res[i].disabled = false;
      }

      if(second_axis_series.length > 0) {
        // Don't allow series toggle by disabling legend clicks
        chart.legend.updateState(false);
      }

      update_chart_data(res);
      first_time_loaded = false;
    }).fail(function(xhr, status, error) {
      if (xhr.statusText =='abort') {
        return;
      }

      console.error("Error while retrieving the timeseries data [" + status + "]: " + error);
      update_chart_data([]);
    });

    if(first_load) {
      first_load = false;
    } else {
      /* Reload datatable */
      if(flows_dt)
        flows_dt.render();
    }

    return true;
  }
}
