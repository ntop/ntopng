// 2019 - ntop.org

var schema_2_label = {};
var data_2_label = {};
var graph_i18n = {};

function initLabelMaps(_schema_2_label, _data_2_label, _graph_i18n) {
  schema_2_label = _schema_2_label;
  data_2_label = _data_2_label;
  graph_i18n = _graph_i18n;
};

function getSerieLabel(schema, serie, visualization, serie_index) {
  var data_label = serie.label;
  var new_label = data_2_label[data_label];

  if(visualization && visualization.metrics_labels && visualization.metrics_labels[serie_index])
    return visualization.metrics_labels[serie_index];

    if(serie.ext_label) {
	if(new_label)
	    return serie.ext_label + " (" + new_label + ")";
	else
	    return serie.ext_label;
    }  else if((schema == "top:local_senders") || (schema == "top:local_receivers")) {
    if(serie.ext_label)
      return serie.ext_label;
    else
      return serie.tags.host
  } else if(schema.startsWith("top:")) { // topk graphs
    if(serie.tags.protocol)
      return serie.tags.protocol;
    else if(serie.tags.category)
      return serie.tags.category;
    else if(serie.tags.l4proto)
      return serie.tags.l4proto;
    else if(serie.tags.dscp_class)
      return serie.tags.dscp_class;
    else if(serie.tags.device && serie.tags.if_index) { // SNMP interface
      if(serie.ext_label != "")
          return serie.ext_label;
	else
          return "(" + serie.tags.if_index + ")";
    } else if(serie.tags.device && serie.tags.port) // Flow device
      return serie.tags.port;
    else if(serie.tags.exporter && serie.tags.ifname) // Event exporter
      return serie.tags.ifname;
    else if(serie.tags.profile)
        return serie.tags.profile;
    else if(serie.tags.check)
      return serie.tags.check;
    else if(serie.tags.command)
      return serie.tags.command.substring(4).toUpperCase();
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
      else if(data_label == "bytes") {
        if(schema.contains("volume"))
          return graph_i18n.traffic_volume;
        else
          return graph_i18n.traffic;
      }
  }

  if(schema_2_label[schema])
    return NtopUtils.capitaliseFirstLetter(schema_2_label[schema]);

  if(new_label)
    return NtopUtils.capitaliseFirstLetter(new_label);

  // default
  return NtopUtils.capitaliseFirstLetter(data_label);
}

// Value formatter
function getValueFormatter(schema, metric_type, series, custom_formatter, stats) {
  if(series && series.length && series[0].label) {
    if(custom_formatter) {
      var formatters = [];

      if(typeof(custom_formatter) != "object")
        custom_formatter = [custom_formatter];

      for(var i=0; i<custom_formatter.length; i++) {
        // translate function name to actual function
        const functionName = custom_formatter[i].replace("NtopUtils.", "")
        const formatterFunction = NtopUtils[functionName];

        if(typeof formatterFunction !== "function")
          console.error("Cannot find custom value formatter \"" + custom_formatter + "\"");

        formatters[i] = formatterFunction;
      }

      return(formatters);
    }

    var label = series[0].label;

    if(label.contains("bytes")) {
      if(schema.contains("volume") || schema.contains("memory") || schema.contains("size"))
        return [NtopUtils.bytesToSize, NtopUtils.bytesToSize];
      else
        return [NtopUtils.fbits_from_bytes, NtopUtils.bytesToSize];
    } else if(label.contains("packets"))
      return [NtopUtils.fpackets, NtopUtils.formatPackets];
      else if(label.contains("points"))
      return [NtopUtils.fpoints, formatPoints];
    else if(label.contains("flows")) {
      var as_counter = ((metric_type === "counter") && (schema !== "custom:memory_vs_flows_hosts"));
      return [as_counter ? NtopUtils.fflows : NtopUtils.formatValue, NtopUtils.formatFlows, as_counter ? NtopUtils.fflows : NtopUtils.formatFlows];
    } else if(label.contains("millis") || label.contains("_ms")) {
      return [NtopUtils.fmillis, NtopUtils.fmillis];
    } else if(label.contains("alerts") && (metric_type === "counter")) {
      return [NtopUtils.falerts, NtopUtils.falerts];
    } else if(label.contains("percent")) {
      return [NtopUtils.fpercent, NtopUtils.fpercent];
    }
  }

  // fallback
  if(stats && (stats.max_val < 1)) {
    /* Use the float formatter to avoid having the same 0 value repeated into the scale */
    return [NtopUtils.ffloat, NtopUtils.ffloat];
  }

  return [NtopUtils.fint,NtopUtils.fint];
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

function fixTimeRange(chart, params, align_step, actual_step) {
  var diff_epoch = (params.epoch_end - params.epoch_begin);
  var frame, align, tick_step, resolution, fmt = "%H:%M:%S";

  // must be sorted by ascending max_diff
  // max_diff / tick_step indicates the number of ticks, which should be <= 15
  // max_diff / resolution indicates the number of actual points, which should be ~300
  var range_params = [
    // max_diff, resolution, x_format, alignment, tick_step
    [15, 1, "%H:%M:%S", 1, 1],                          // <= 15 sec
    [60, 1, "%H:%M:%S", 1, 5],                          // <= 1 min
    [120, 1, "%H:%M:%S", 10, 10],                       // <= 2 min
    [300, 1, "%H:%M:%S", 10, 30],                       // <= 5 min
    [600, 5, "%H:%M:%S", 30, 60],                       // <= 10 min
    [1200, 5, "%H:%M:%S", 60, 120],                     // <= 20 min
    [3600, 10, "%H:%M:%S", 60, 300],                    // <= 1 h
    [5400, 15, "%H:%M", 300, 900],                      // <= 1.5 h
    [10800, 30, "%H:%M", 300, 900],                     // <= 3 h
    [21600, 60, "%H:%M", 3600, 1800],                   // <= 6 h
    [43200, 120, "%H:%M", 3600, 3600],                  // <= 12 h
    [86400, 240, "%H:%M", 3600, 7200],                  // <= 1 d
    [172800, 480, "%a, %H:%M", 3600, 14400],            // <= 2 d
    [604800, 1800, "%Y-%m-%d", 86400, 86400],           // <= 7 d
    [1209600, 3600, "%Y-%m-%d", 86400, 172800],         // <= 14 d
    [2678400, 7200, "%Y-%m-%d", 86400, 259200],         // <= 1 m
    [15768000, 43200, "%Y-%m-%d", 2678400, 1314000],    // <= 6 m
    [31622400, 86400, "%Y-%m-%d", 2678400, 2678400],    // <= 1 y
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

  resolution = Math.max(actual_step, resolution);

  if(align) {
    align = (align_step && (frame != 86400) /* do not align daily traffic to avoid jumping to other RRA */) ? Math.max(align, align_step) : 1;
    params.epoch_begin -= params.epoch_begin % align;
    params.epoch_end -= params.epoch_end % align;
    diff_epoch = (params.epoch_end - params.epoch_begin);
    params.limit = Math.ceil(diff_epoch / resolution);

    // align epoch end wrt params.limit
    params.epoch_end += Math.ceil(diff_epoch / params.limit) * params.limit - diff_epoch;
    chart.align = align;
    chart.tick_step = tick_step;
  } else
    chart.tick_step = null;

  chart.x_fmt = fmt;
}

function findActualStep(raw_step, tstart) {
  if(typeof supported_steps === "object") {
    if(supported_steps[raw_step]) {
      var retention = supported_steps[raw_step].retention;

      if(retention) {
        var now_ts = Date.now() / 1000;
        var delta = now_ts - tstart;

        for(var i=0; i<retention.length; i++) {
          var partial = raw_step * retention[i].aggregation_dp;
          var tframe = partial * retention[i].retention_dp;
          delta -= tframe;

          if(delta <= 0)
            return partial;
        }
      }
    }
  }
  return raw_step;
}

function has_initial_zoom() {
  return typeof NtopUtils.parseQuery(window.location.search).epoch_begin !== "undefined";
}

var current_zoom_level = (history.state) ? (history.state.zoom_level) : 0;

function canCompareBackwards(epoch_begin, epoch_end) {
  var jump_duration = $("#btn-jump-time-ahead").data("duration");
  var current_duration = epoch_end - epoch_begin;
  return(jump_duration == current_duration);
}

function fixJumpButtons(epoch_begin, epoch_end) {
  var duration = $("#btn-jump-time-ahead").data("duration");
  if((epoch_end + duration)*1000 > $.now())
    $("#btn-jump-time-ahead").addClass("disabled");
  else
    $("#btn-jump-time-ahead").removeClass("disabled");
}

function showQuerySlow() {
  $("#query-slow-alert").show();
}

function hideQuerySlow() {
  $("#query-slow-alert").hide();
}

function chart_data_sum(series) {
  return(series.reduce(function(acc, x) {
    return(acc + x.values.reduce(
      function(acc, pt) {
        return(acc + pt[1] || 0);
      }, 0)
    )
  }, 0));
}

function redrawExtraLines(chart, chart_id, extra_lines) {
  /* Remove the previous extra lines */
  d3.selectAll(chart_id + " line.extra-line").remove();

  if(extra_lines.length > 0) {
    var xValueScale = chart.xAxis.scale();
    var yValueScale = chart.yAxis1.scale();
    var g = d3.select(chart_id + " .stack1Wrap");

    for(var i=0; i<extra_lines.length; i++) {
      var d = extra_lines[i];

      g.append("line")
        .style("stroke", "#FF5B56")
        .style("stroke-width", "2.5px")
        .attr("x1", xValueScale(d[0]))
        .attr("y1", yValueScale(d[2]))
        .attr("x2", xValueScale(d[1]))
        .attr("y2", yValueScale(d[3]))
        .attr("class", "extra-line")
    }
  }
}

// add a new updateStackedChart function
function attachStackedChartCallback(chart, schema_name, chart_id, zoom_reset_id, params, step,
          metric_type, align_step, show_all_smooth, initial_range, ts_table_shown) {
  var pending_chart_request = null;
  var pending_table_request = null;
  var d3_sel = d3.select(chart_id);
  var $chart = $(chart_id);
  var $zoom_reset = $(zoom_reset_id);
  var $graph_zoom = $("#graph_zoom");
  var max_interval = findActualStep(step, params.epoch_begin) * 8;
  var initial_interval = (params.epoch_end - params.epoch_begin);
  var is_max_zoom = (initial_interval <= max_interval);
  var url = http_prefix + "/lua/rest/v2/get/timeseries/ts.lua";
  var first_load = true;
  var first_time_loaded = true;
  var manual_trigger_extra_series = {}; // keeps track of series manually shown/hidden by the user
  var datetime_format = "dd/MM/yyyy hh:mm:ss";
  var max_cmp_over_total_ratio = 3;     // if the comparison serie max value is too big compared to the actual chart series, hide it
  var max_line_over_total_ratio = 10;   // if the extra line series max value is too big compared to the actual chart series, hide them
  var query_timer = null;
  var seconds_before_query_slow = 6;
  var query_completed = 0;
  var query_was_aborted = false;
  let last_known_t = null; // only set if show_unreachable is set
  const visualization = chart.visualization_options || {};
  chart.is_zoomed = ((current_zoom_level > 0) || has_initial_zoom());

  /* Extra lines to draw into the chart. Each item is in the format [x_start, x_end, y_start, y_end] */
  let extra_lines = [];
  let unreachable_timestamps = {};

  //var spinner = $("<img class='chart-loading-spinner' src='" + spinner_url + "'/>");
  var spinner = $('<i class="chart-loading-spinner fas fa-spinner fa-lg fa-spin"></i>');
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
  var split_directions_colors = ["#69B87F", "#FF7C00", "#FF4700"];

  /* This is used to show the "unreachable" label when the chart "show_unreachable"
   * options is set. See the extra_lines computation below. */
  function format_unreachable(formatter) {
    return function(y, d) {
      if(d && unreachable_timestamps[d[0]])
        return(i18n.unreachable_host);

      // Not unreachable, use the provided formatter
      return(formatter(y));
    }
  }

  /* The default number of y points */
  var num_ticks_y1 = null;
  var num_ticks_y2 = null;
  var domain_y1 = null;
  var domain_y2 = null;
  var first_run = true;

  var update_chart_data = function(new_data) {
    /* reset chart data so that the next transition animation will be gracefull */
    d3_sel.datum([]).call(chart);
    d3_sel.datum(new_data);

    /* This additional refresh is needed to determine the yticks
     * and domain, needed below.
     * NOTE: calling transition().duration(500) is important to properly refresh
     * the tooltip position. */
    d3_sel.transition().duration(500).call(chart);

    if(first_run) {
      num_ticks_y1 = chart.yAxis1.ticks();
      num_ticks_y2 = chart.yAxis2.ticks();
      domain_y1 = chart.yDomain1();
      domain_y2 = chart.yDomain2();
      first_run = false;
    }

    if(metric_type === "gauge") {
      var cur_domain_y1 = chart.yAxis1.scale().domain();
      var cur_domain_y2 = chart.yAxis2.scale().domain();

      cur_domain_y1 = cur_domain_y1[1] - cur_domain_y1[0];
      cur_domain_y2 = cur_domain_y2[1] - cur_domain_y2[0];

      /* If there are not enough points available, reduce the number of
       * ticks to avoid repeated ticks with same integer value.
       * Other solutions (documented in https://stackoverflow.com/questions/21075245/nvd3-prevent-repeated-values-on-y-axis)
       * are not easily applicable in this case.
       *
       * NOTE: the problem should not occur when using NtopUtils.ffloat
       */
      if(chart.yAxis1.tickFormat() != NtopUtils.ffloat)
        chart.yAxis1.ticks(Math.min(cur_domain_y1, num_ticks_y1));
      if(chart.yAxis2.tickFormat() != NtopUtils.ffloat)
        chart.yAxis2.ticks(Math.min(cur_domain_y2, num_ticks_y2));
    }

    var y1_sum = chart_data_sum(new_data.filter(function(x) { return(x.yAxis == 1); }))
    var y2_sum = chart_data_sum(new_data.filter(function(x) { return(x.yAxis == 2); }))

    /* Fix negative ydomain values appearing when dataset is empty */
    if(y1_sum == 0)
      chart.yDomain1([0, 1]);
    else
      chart.yDomain1(domain_y1);

    if(y2_sum == 0)
      chart.yDomain2([0, 1]);
    else
      chart.yDomain2(domain_y2);

    /* Refresh the chart */
    d3_sel.call(chart);
    nv.utils.windowResize(function() {
      chart.update();
      redrawExtraLines(chart, chart_id, extra_lines);
    })
    redrawExtraLines(chart, chart_id, extra_lines);

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
    manual_trigger_extra_series[d.legend_key] = true;

    if(typeof localStorage !== "undefined")
      localStorage.setItem("chart_series.disabled." + d.legend_key, (!d.disabled) ? true : false);
  });

  chart.dispatch.on("zoom", function(e) {
    var cur_zoom = [params.epoch_begin, params.epoch_end];
    var t_start = Math.floor(e.xDomain[0]);
    var t_end = Math.ceil(e.xDomain[1]);
    var old_zoomed = chart.is_zoomed;
    var is_user_zoom = (typeof e.is_user_zoom !== "undefined") ? e.is_user_zoom : true;
    chart.is_zoomed = true;

    if(chart.updateStackedChart(t_start, t_end, false, is_user_zoom)) {
      if(is_user_zoom || e.push_state) {
        //console.log("zoom IN!");
        current_zoom_level += 1;
        var url = NtopUtils.getHistoryParameters({epoch_begin: t_start, epoch_end: t_end});
        history.pushState({zoom_level: current_zoom_level, range: [t_start, t_end]}, "", url);
      }

      chart.fixChartButtons();
    } else
      chart.is_zoomed = old_zoomed;
  });

  function updateZoom(zoom, is_user_zoom, force) {
    var t_start = zoom[0];
    var t_end = zoom[1];

    chart.updateStackedChart(t_start, t_end, false, is_user_zoom, null, force);
    chart.fixChartButtons();
  }

  chart.zoom_in = function() {
    var cur_interval = params.epoch_end - params.epoch_begin;

    if(cur_interval > 60) {
      var delta = cur_interval/4;
      $("#period_begin").datetimepicker("date", new Date((params.epoch_begin + delta) * 1000));
      $("#period_end").datetimepicker("date", new Date((params.epoch_end - delta) * 1000));
      updateChartFromPickers();
    }
  }

  chart.zoom_out = function() {
    var cur_interval = params.epoch_end - params.epoch_begin;

    //if(current_zoom_level) {
      // Zoom out from history
      //console.log("zoom OUT");
      //history.back();
    //} else {
    // Zoom out with fixed interval
    //var delta = zoom_out_value;
    var delta = cur_interval/2;
    //if((params.epoch_end + delta)*1000 <= $.now())
      //delta /= 2;

    $("#period_begin").datetimepicker("date", new Date((params.epoch_begin - delta) * 1000));
    $("#period_end").datetimepicker("date", new Date((params.epoch_end + delta) * 1000));
    updateChartFromPickers();
    //}
  }

  $chart.on('dblclick', function(event) {
    if($(event.target).hasClass("nv-legend-text"))
      // legend was double-clicked, keep the original behavior
      return;

    chart.zoom_out();
  });

  $zoom_reset.on("click", function() {
    if(current_zoom_level) {
      //console.log("zoom RESET");
      history.go(-current_zoom_level);
    }
  });

  window.addEventListener('popstate', function(e) {
    var zoom = initial_range;
    //console.log("popstate: ", e.state);

    if(e.state) {
      zoom = e.state.range;
      current_zoom_level = e.state.zoom_level;
    } else
      current_zoom_level = 0;

    updateZoom(zoom, true, true /* force */);
  });

  chart.fixChartButtons = function() {
    if((current_zoom_level > 0) || has_initial_zoom()) {
      $graph_zoom.find(".btn-warning:not(.custom-zoom-btn)")
        .addClass("initial-zoom-sel")
        .removeClass("btn-warning");
      $graph_zoom.find(".custom-zoom-btn").css("visibility", "visible");

      var zoom_link = $graph_zoom.find(".custom-zoom-btn");
      var link = zoom_link.val().replace(/&epoch_begin=.*/, "");
      link += "&epoch_begin=" + params.epoch_begin + "&epoch_end=" + params.epoch_end;
      zoom_link.val(link);
    } else {
      $graph_zoom.find(".initial-zoom-sel")
        .addClass("btn-warning");
      $graph_zoom.find(".custom-zoom-btn").css("visibility", "hidden");
      chart.is_zoomed = false;
    }

    fixJumpButtons(params.epoch_begin, params.epoch_end);

    if(current_zoom_level > 0)
      $zoom_reset.show();
    else
      $zoom_reset.hide();
  }

  function checkQueryCompleted() {
    var flows_dt = $("#chart1-flows");
    var wait_num_queries = (ts_table_shown && ($("#chart1-flows").css("display") !== "none")) ? 2 : 1;

    query_completed += 1;

    if(query_completed >= wait_num_queries) {
      if(query_timer) {
        clearInterval(query_timer);
        query_timer = null;
      }

      hideQuerySlow();
    }
  }

  chart.queryWasAborted = function() {
    return query_was_aborted;
  }

  chart.abortQuery = function() {
    query_was_aborted = true;

    if(pending_chart_request) {
      pending_chart_request.abort();
      chart.noData(i18n.query_was_aborted);
      update_chart_data([]);
    }

    if(pending_table_request)
      pending_table_request.abort();

    if(query_timer) {
      clearInterval(query_timer);
      query_timer = null;
    }

    hideQuerySlow();
  }

  chart.tableRequestCompleted = function() {
    checkQueryCompleted();
    pending_table_request = null;
  }

  chart.getDataUrl = function() {
    var data_params = jQuery.extend({}, params);
    delete data_params.zoom;
    delete data_params.ts_compare;
    data_params.extended = 1; /* with extended timestamps */
    return url + "?" + $.param(data_params, true);
  }

  var old_start, old_end, old_interval;

  /* Returns false if zoom update is rejected. */
  chart.updateStackedChart = function (tstart, tend, no_spinner, is_user_zoom, on_load_callback, force_update) {
    if(tstart) params.epoch_begin = tstart;
    if(tend) params.epoch_end = tend;
    const series_formatted_labels = {};

    const now = Date.now() / 1000;

    var cur_interval = (params.epoch_end - params.epoch_begin);
    var actual_step = findActualStep(step, params.epoch_begin);
    max_interval = actual_step * 6; /* host traffic 30 min */

    if(cur_interval < max_interval) {
      if((is_max_zoom && (cur_interval < old_interval)) && !force_update) {
        old_interval = cur_interval;
        return false;
      }

      if(!force_update) {
        /* Ensure that a minimal number of points is available */
        var epoch = params.epoch_begin + (params.epoch_end - params.epoch_begin) / 2;
        var new_end = Math.floor(epoch + max_interval / 2);

        if(new_end >= now) {
          /* Only expand on the left side of the interval */
          params.epoch_begin = params.epoch_end - max_interval;
        } else {
          params.epoch_begin = Math.floor(epoch - max_interval / 2);
          params.epoch_end = Math.floor(epoch + max_interval / 2);
        }

        is_max_zoom = true;
        chart.zoomType(null); // disable zoom
      }
    } else if (cur_interval > max_interval) {
      is_max_zoom = false;
      chart.zoomType('x'); // enable zoom
    }

    old_interval = cur_interval;

    if(!first_load || has_initial_zoom() || force_update)
      align_step = null;
    fixTimeRange(chart, params, align_step, actual_step);

    if(first_load)
      initial_range = [params.epoch_begin, params.epoch_end];

    if((old_start == params.epoch_begin) && (old_end == params.epoch_end) && (!force_update))
      return false;

    old_start = params.epoch_begin;
    old_end = params.epoch_end;

    if(pending_table_request)
      pending_table_request.abort();

    if(pending_chart_request)
      pending_chart_request.abort();
    else if(!no_spinner)
      spinner.appendTo($chart.parent());

    // Update datetime selection
    $("#period_begin").datetimepicker("date", new Date(params.epoch_begin * 1000));
    $("#period_end").datetimepicker("date", new Date(Math.min(params.epoch_end * 1000, $.now())));

    if(query_timer)
      clearInterval(query_timer);

    query_timer = setInterval(showQuerySlow, seconds_before_query_slow * 1000);
    query_completed = 0;
    query_was_aborted = false;
    chart.noData(i18n.no_data_available);
    hideQuerySlow();

    var req_params = $.extend({}, params);
    // skip past period comparison if a custom interval is selected
    if(!canCompareBackwards(req_params.epoch_begin, req_params.epoch_end))
      delete req_params.ts_compare;

    /* Disable the null data filling only for the charts which support the
     * "unreachable" status (unreachable reported as a 0 value instead of null). */
    if(visualization.show_unreachable)
      req_params.no_fill = 1;

    // Load data via ajax
    pending_chart_request = $.get(url, req_params, function(data) {
        data = data.rsp; /* Adapts the response to the new REST API v1 */

	if(data && data.error)
        chart.noData(data.error);

      if(!data || !data.series || !data.series.length || !checkSeriesConsinstency(schema_name, data.count, data.series)) {
        update_chart_data([]);
        return;
      }

      // Fix x axis
      var tick_step = Math.ceil(chart.tick_step / data.step) * data.step;
      chart.xAxis.tickValues(buildTimeArray(data.start, data.start + data.count * data.step, tick_step));
      chart.xAxis.tickFormat(function(d) { return d3.time.format(chart.x_fmt)(new Date(d*1000)) });

      // Adapt data
      var res = [];
      var series = data.series;
      var total_serie;
      var color_i = 0;
      let time_elapsed = 1;

      if(visualization.time_elapsed)
        time_elapsed = visualization.time_elapsed;

      var chart_colors = (series.length <= chart_colors_min.length) ? chart_colors_min : chart_colors_full;

      for(var j=0; j<series.length; j++) {
        var values = [];
        var serie_data = series[j].data;

        var t = data.start;
        for(var i=0; i<serie_data.length; i++) {
          values[i] = [t, serie_data[i] / time_elapsed ];
          t += data.step;
        }

        var label = getSerieLabel(schema_name, series[j], visualization, j);
        var legend_key = schema_name + ":" + label;
        chart.current_step = data.step;
        let serie_type = series[j].type;
        let serie_color = chart_colors[color_i++]

        if(!serie_type) {
          if(visualization.split_directions) {
            /* RX and TX directions are splitted, drow the second serie
             * (TX) as a line */
            serie_type = (j == 0) ? "area" : "line";
            serie_color = split_directions_colors[j] || serie_color;
          } else
            serie_type = "area";
        }

        series_formatted_labels[j] = label;

        res.push({
          key: label,
          yAxis: series[j].axis || 1,
          values: values,
          type: serie_type,
          color: serie_color,
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

      var past_serie = null;

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
          past_serie = serie_data; // TODO: more reliable way to determine past serie

          /* Hide comparison serie at first load if it's too high */
          if((first_time_loaded || !manual_trigger_extra_series[key]) && (ratio_over_total > max_cmp_over_total_ratio))
            is_disabled = true;

          res.push({
            key: NtopUtils.capitaliseFirstLetter(key),
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

      /* Extra horizontal series */
      if(visualization && visualization.extra_series) {
        for(var i=0; i<visualization.extra_series.length; i++) {
          var serie = visualization.extra_series[i];

          if(!serie.label) {
            console.warn("Missing extra_series label");
            continue;
          }

          if(!serie.value) {
            console.warn("Missing extra_series value");
            continue;
          }

          var ratio_over_total = serie.value / d3.max(visual_total);
          var is_disabled = isLegendDisabled(serie.label, false);

          /* Hide the line serie at first load if it's too high */
          if((first_time_loaded || !manual_trigger_extra_series[serie.label]) && (ratio_over_total > max_line_over_total_ratio))
            is_disabled = true;

          res.push({
            key: serie.label,
            yAxis: serie.axis || 1,
            values: arrayToNvSerie(upsampleSerie([serie.value], data.count), data.start, data.step),
            type: serie.type || "line",
            color: serie.color || "red",
            classed: serie.class,
            legend_key: serie.label,
            disabled: is_disabled,
          });
        }
      }

      if(!data.no_trend && has_full_data && (total_serie.length >= 3)) {
        // Smoothed serie
        /* num_smoothed_points determines the window size to use while computing rolling functions */
        var num_smoothed_points = Math.min(Math.max(Math.floor(total_serie.length / 5), 3), 12);

        var smooth_functions = {
          //trend: [graph_i18n.trend, "#62ADF6", smooth, num_smoothed_points],
          //ema: ["EMA", "#F96BFF", exponentialMovingAverageArray, {periods: num_smoothed_points}],
          //sma: ["SMA", "#A900FF", simpleMovingAverageArray, {periods: num_smoothed_points}],
          //rsi: ["RSI cur vs past", "#00FF5D", relativeStrengthIndexArray, {periods: num_smoothed_points}],
        }

        function add_smoothed_serie(fn_to_use) {
          var options = smooth_functions[fn_to_use];
          var smoothed;

          if(fn_to_use == "rsi") {
            if(!past_serie)
              return;

            var delta_serie = [];
            for(var i=0; i<total_serie.length; i++) {
              delta_serie[i] = total_serie[i] - past_serie[i];
            }
            smoothed = options[2](delta_serie, options[3]);
          } else
            smoothed = options[2](total_serie, options[3]);

          // remove the first point as it's used as the base window in the rolling functions
          if(smoothed[0])
            delete smoothed[0];

          var max_val = d3.max(smoothed);
          if(max_val > 0) {
            var aligned;

            if((fn_to_use != "ema") && (fn_to_use != "sma") && (fn_to_use != "rsi")) {
              var scale = d3.max(total_serie) / max_val;
              var scaled = $.map(smoothed, function(x) { return x * scale; });
              aligned = upsampleSerie(scaled, data.count);
            } else {
              var remaining = (data.count - smoothed.length);
              var to_fill = remaining < num_smoothed_points ? remaining : num_smoothed_points;

              /* Fill the initial buffering space */
              for(var i=0; i<to_fill; i++)
                smoothed.splice(0, 0, smoothed[0]);

              aligned = upsampleSerie(smoothed, data.count);
            }

            if(fn_to_use == "rsi")
              chart.yDomainRatioY2(1.0);

            res.push({
              key: options[0],
              yAxis: (fn_to_use != "rsi") ? 1 : 2,
              values: arrayToNvSerie(aligned, data.start, data.step),
              type: "line",
              classed: "line-animated",
              color: options[1],
              legend_key: fn_to_use,
              disabled: isLegendDisabled(fn_to_use, false),
            });
          }
        }

        if(show_all_smooth) {
          for(fn_to_use in smooth_functions)
            add_smoothed_serie(fn_to_use);
        }
      }

      /* Add extra lines. These are different from the extra series as
       * they are simple lines, so they are not bound to an axis. */
      extra_lines = [];

      if((visualization.show_unreachable) && (res.length > 0)) {
        var ref_serie = res[0].values;
        let tok = ref_serie[0][0];
        let was_unreachable = false;
        unreachable_timestamps = {};

        for(var i=0; i<ref_serie.length; i++) {
          const is_unreachable = (ref_serie[i][1] === 0);
          const tval = ref_serie[i][0];

          if((ref_serie[i][1] == ref_serie[i][1]))
            /* The most recent time for non NaN values */
            last_known_t = tval;

          if(!is_unreachable) {
            if(was_unreachable)
              extra_lines.push([tok, tval, 0, 0]);

            tok = tval;
            was_unreachable = false;
          } else {
            /* Change the reference serie point to null to fix interpolation issues */
            ref_serie[i][1] = null;
            unreachable_timestamps[tval] = true;

            was_unreachable = true;
          }
        }

        if(was_unreachable) {
          const tlast = ref_serie[ref_serie.length - 1][0];

          if(tlast != tok)
            extra_lines.push([tok, tlast, 0, 0]);
        }
      }

      // get the value formatter
      var formatter1 = getValueFormatter(schema_name, metric_type, series.filter(function(d) { return(d.axis != 2); }), visualization.value_formatter, data.statistics);
      var value_formatter = formatter1[0];
      var tot_formatter = formatter1[1] || value_formatter;
      var stats_formatter = formatter1[2] || value_formatter;
      chart.yAxis1.tickFormat(value_formatter);
      chart.yAxis1_formatter = visualization.show_unreachable ? format_unreachable(value_formatter) : value_formatter;

      var second_axis_series = series.filter(function(d) { return(d.axis == 2); });
      var formatter2 = getValueFormatter(schema_name, metric_type, second_axis_series, visualization.value_formatter2 || visualization.value_formatter, data.statistics);
      var value_formatter2 = formatter2[0];
      chart.yAxis2.tickFormat(value_formatter2);
      chart.yAxis2_formatter = value_formatter2;

      var stats_table = $("#ts-chart-stats");
      var stats = data.statistics;

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

        /* 
          Function used to split charts info, otherwise graphs with multiple
          timeseries are going to have incorrect values
        */
        function splitSeriesInfo(stats_name, cell, show_date, formatter, total) {
          let val = "";
          let time_elapsed = 1;
          const val_formatter = (formatter ? formatter : stats_formatter)

          if(visualization.time_elapsed)
            time_elapsed = visualization.time_elapsed
          
          if(visualization.first_timeseries_only) {
            val = val_formatter(stats.by_serie[0][stats_name] / time_elapsed) + (show_date ? (" (" + (new Date(res[0].values[stats[stats_name + "_idx"]][0] * 1000)).format(datetime_format) + ")") : "");
          } else if(visualization.split_directions && stats.by_serie && !total) {
            const values = [];

            /* Format each splitted info */
            for(var i=0; i<series.length; i++) {
              if(stats.by_serie[i])
                values.push(val_formatter(stats.by_serie[i][stats_name] / time_elapsed) +
                  " [" + series_formatted_labels[i] + "]" +
                  /* Add the date */
                  (show_date ? (" (" + (new Date(res[i].values[stats.by_serie[i][stats_name + "_idx"] + 1][0] * 1000)).format(datetime_format) + ")") : ""));
            }

            /* Join them using a new line */
            val = values.join("<br />");
          } else
            val = val_formatter(stats[stats_name] / time_elapsed) + (show_date ? (" (" + (new Date(res[0].values[stats[stats_name + "_idx"]][0] * 1000)).format(datetime_format) + ")") : "");

          /* Add the string to the span */
          if(val)
            cell.show().find("span").html(val);

          return values;
        }

        var total_cell = stats_table.find(".graph-val-total");
        var average_cell = stats_table.find(".graph-val-average");
        var min_cell = stats_table.find(".graph-val-min");
        var max_cell = stats_table.find(".graph-val-max");
        var perc_cell = stats_table.find(".graph-val-95percentile");
        
        // fill the stats
        if(stats.total || total_cell.is(':visible'))
          splitSeriesInfo("total", total_cell, false, tot_formatter, true);
        if(stats.average || average_cell.is(':visible'))
          splitSeriesInfo("average", average_cell, false, stats_formatter);
        if((stats.min_val || min_cell.is(':visible')) && res[0].values[stats.min_val_idx])
          splitSeriesInfo("min_val", min_cell, true, stats_formatter);
        if((stats.max_val || max_cell.is(':visible')) && res[0].values[stats.max_val_idx])
          splitSeriesInfo("max_val", max_cell, true, stats_formatter);
        if(stats["95th_percentile"] || perc_cell.is(':visible')) {
          splitSeriesInfo("95th_percentile", perc_cell, false, stats_formatter);

          if(!visualization.split_directions) {
            /* When directions are split, hide the total stat */
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
        }

        // check if there are visible elements
        //if(stats_table.find("td").filter(function(){ return $(this).css("display") != "none"; }).length > 0)
      }
      stats_table.show();

      if(visualization.show_unreachable && last_known_t &&
          (last_known_t + data.step > now) && (now < last_known_t + 2*data.step)) {
        /* For the active monitoring chart, we show an additional point with the
         * last value and the now timestamp as requested for
         * https://github.com/ntop/ntopng/issues/3822 */
        for(var j=0; j<res.length; j++) {
          const serie = res[j].values;

          if(serie.length > 0)
            serie[serie.length] = [now, serie[serie.length - 1][1]];
        }
      }

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

      if(data.source_aggregation)
        $("#data-aggr-dropdown > button > span:first").html(data.source_aggregation);
    }).fail(function(xhr, status, error) {
      if (xhr.statusText =='abort') {
        return;
      }

      console.error("Error while retrieving the timeseries data [" + status + "]: " + error);
      chart.noData(error);
      update_chart_data([]);
    }).always(function(data, status, xhr) {
      checkQueryCompleted();
      pending_chart_request = null;
    });

    if(first_load) {
      first_load = false;

      /* Wait for page load because datatable is not instantiated yet right now */
      $(function() {
        var flows_dt = $("#chart1-flows").data("datatable");
        if(flows_dt)
          pending_table_request = flows_dt.pendingRequest;
      });
    } else {
      var flows_dt = $("#chart1-flows");

      /* Reload datatable */
      if(ts_table_shown) {
        /* note: flows_dt.data("datatable") will change after this call */
        updateGraphsTableView(null, params);

        if($("#chart1-flows").css("display") !== "none")
          pending_table_request = flows_dt.data("datatable").pendingRequest;
      }
    }

    if(typeof on_load_callback === "function")
      on_load_callback(chart);

    return true;
  }
}

var graph_old_view = null;
var graph_old_has_nindex = null;
var graph_old_nindex_query = null;

function tsQueryToTags(ts_query) {
  return ts_query.split(",").
    reduce(function(params, value) {
      var pos = value.indexOf(":");

      if(pos != -1) {
        var k = value.slice(0, pos);
        var v = value.slice(pos+1);
        params[k] = v;
      }

      return params;
  }, {});
}

/* Hide or show the timeseries table items based on the current time range */
function recheckGraphTableEntries() {
  var table_view = graph_table_views;
  var tdiff = (graph_params.epoch_end - graph_params.epoch_begin);
  var reset_selection = false;
  $("#chart1-flows").show();
  $("#graphs-table-selector").show();

  for(view_id in table_view) {
    var view = table_view[view_id];
    var elem = $("#" + view.html_id);

    if(tdiff <= view.min_step) {
      if(graph_old_view.id === view_id)
        reset_selection = true;

      elem.hide();
    } else
      elem.show();
  }

  /* Hide/show the headers */
  var items_ul = $("#graphs-table-active-view").closest(".btn-group").find("ul:first");

  items_ul.find("li.dropdown-header").each(function(idx,e) {
    var next_item = $(e).nextAll("li").filter(function(idx,e) {
      return(($(e).css("display") !== "none") || (!$(e).attr("data-view-id")));
    }).first();
    var divider = $(e).nextAll(".divider").first();

    if(!next_item.attr("data-view-id")) {
      $(e).hide();
      divider.hide();
    } else {
      $(e).show();
      divider.show();
    }
  });

  if(reset_selection) {
    /* Select the first available view */
    var first_view = items_ul.find("li[data-view-id]").filter(function(idx,e) {
        return($(e).css("display") !== "none");
      }).first();

    if(first_view.length)
      setActiveGraphsTableView(first_view.attr("data-view-id"));
    else {
      $("#chart1-flows").hide();
      $("#graphs-table-selector").hide();
    }

    return false;
  }

  return true;
}

function updateGraphsTableView(view, graph_params, has_nindex, nindex_query, per_page) {
  if(view)
    graph_old_view = view;

  if(!recheckGraphTableEntries(graph_params)) {
    /* handled by setActiveGraphsTableView */
    return;
  }

  if(view) {
    graph_old_has_nindex = has_nindex;
    graph_old_nindex_query = nindex_query;
  } else {
    view = graph_old_view;
    has_nindex = graph_old_has_nindex;
    nindex_query = graph_old_nindex_query;
  }

  var graph_table = $("#chart1-flows");
  nindex_query = nindex_query + "&begin_time_clause=" + graph_params.epoch_begin + "&end_time_clause=" + graph_params.epoch_end;
  var nindex_buttons = "";
  var params_obj = tsQueryToTags(graph_params.ts_query);

  // TODO localize

  /* Hide IP version selector when a host is selected */
  if(!params_obj.host) {
    nindex_buttons += '<div class="btn-group"><button class="btn btn-link dropdown-toggle" data-bs-toggle="dropdown">';
    nindex_buttons += "IP Version";
    nindex_buttons += '<span class="caret"></span></button><ul class="dropdown-menu" role="menu">';
    nindex_buttons += '<li><a class="dropdown-item" href="#" onclick="return onGraphMenuClick(null, 4)">4</a></li>';
    nindex_buttons += '<li><a class="dropdown-item" href="#" onclick="return onGraphMenuClick(null, 6)">6</a></li>';
    nindex_buttons += '</span></div>';
  }
  
  if(view.columns) {
    var url = http_prefix + (view.nindex_view ? "/lua/pro/get_nindex_flows.lua" : "/lua/pro/get_ts_table.lua");

    var columns = view.columns.map(function(col) {
      return {
        title: col[1],
        field: col[0],
          css: {
	      textAlign: col[2], width: col[3],//
	  },
        hidden: col[4] ? true : false,
      };
    });

    columns.push({
      title: i18n.actions,
      field: "drilldown",
      css: {width: "1%", "text-align": "center"},
    });

    var old_dt = graph_table.data("datatable");
    if(old_dt && old_dt.pendingRequest)
      old_dt.pendingRequest.abort();

    /* Force reinstantiation */
    graph_table.removeData('datatable');
    graph_table.html("");

    graph_table.datatable({
      title: "",
      url: url,
      perPage: per_page,
      noResultsMessage: function() {
        if(ts_chart.queryWasAborted())
          return i18n.query_was_aborted;
        else
          return i18n.no_results_found;
      },
      post: function() {
        var params = $.extend({}, graph_params);
        delete params.ts_compare;
        delete params.initial_point;
        params.limit = 1; // TODO make specific query
        // TODO change topk
        // TODO disable statistics
        params.detail_view = view.id;

        return params;
      },
      loadingYOffset: 40,
      columns: columns,
      buttons: view.nindex_view ? [nindex_buttons, ] : [],
      tableCallback: function() {
        var data = this.resultset;
        ts_chart.tableRequestCompleted();

        if(!data) {
          // error
          return;
        }

        /* The user changed page */
        if(data.currentPage > 1)
          graph_table.data("has_interaction", true);

        var stats_div = $("#chart1-flows-stats");
        var has_drilldown = (data && data.data.some(function(row) { return row.drilldown; }));

        /* Remove the drilldown column if no drilldown is available */
        if(!has_drilldown)
          $("table td:last-child, th:last-child", graph_table).remove();

        if(data && data.stats && data.stats.query_duration_msec) {
           let time_elapsed = data.stats.query_duration_msec/1000.0;
           if(time_elapsed < 0.1)
            time_elapsed = "< 0.1"
           $("#flows-query-time").html(time_elapsed);
           $("#flows-processed-records").html(data.stats.num_records_processed);
           stats_div.show();
        } else
          stats_div.hide();
      }, rowCallback: function(row, row_data) {
        if((typeof row_data.tags === "object") && (
          (params_obj.category && (row_data.tags.category === params_obj.category)) ||
          (params_obj.protocol && (row_data.tags.protocol === params_obj.protocol))
        )) {
          /* Highlight the row */
          row.addClass("info");
        }

        return row;
      }
    });
  }
}
