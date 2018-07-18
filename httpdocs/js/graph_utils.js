// 2018 - ntop.org

var schema_2_label = {};
var data_2_label = {};

function initLabelMaps(_schema_2_label, _data_2_label) {
  schema_2_label = _schema_2_label;
  data_2_label = _data_2_label;
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
      return [formatFlows, formatFlows];
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

// add a new updateStackedChart function
function attachStackedChartCallback(chart, schema_name, url, chart_id, params) {
  var pending_request = null;
  var d3_sel = d3.select(chart_id);
  var $chart = $(chart_id);

  //var spinner = $("<img class='chart-loading-spinner' src='" + spinner_url + "'/>");
  var spinner = $('<i class="chart-loading-spinner fa fa-spinner fa-lg fa-spin"></i>');
  $chart.parent().css("position", "relative");

  var update_chart_data = function(new_data) {
    d3_sel.datum(new_data).transition().duration(500).call(chart);
    nv.utils.windowResize(chart.update);
    pending_request = null;
    spinner.remove();
  }

  chart.updateStackedChart = function (tstart, tend) {
    if(pending_request)
      pending_request.abort();
    else
      spinner.appendTo($chart.parent());

    if(tstart) params.epoch_begin = tstart;
    if(tend) params.epoch_end = tend;

    // Load data via ajax
    pending_request = $.get(url, params, function(data) {
      if(!data || !data.series) {
        update_chart_data([]);
        return;
      }

      // Adapt data
      var res = [];
      var series = data.series;

      for(var j=0; j<series.length; j++) {
        var values = [];
        var serie_data = series[j].data;

        var t = data.start;
        for(var i=0; i<serie_data.length; i++) {
          values[i] = [t, serie_data[i] ];
          t += data.step;
        }

        res.push({
          key: getSerieLabel(schema_name, series[j]),
          yAxis: 1,
          values: values,
          type: "area",
        });
      }

      if(data.additional_series) {
        for(var key in data.additional_series) {
          var values = [];
          var serie_data = data.additional_series[key];

          var t = data.start;
          for(var i=0; i<serie_data.length; i++) {
            values[i] = [t, serie_data[i] ];
            t += data.step;
          }

          res.push({
            key: capitaliseFirstLetter(key),
            yAxis: 1,
            values: values,
            type: "line",
            classed: "line-dashed",
            color: "#ff0000",
            disabled: true, /* hide additional series by default */
          });
        }
      }

      // get the value formatter
      var formatter = getValueFormatter(schema_name, series);
      var value_formatter = formatter[0];
      var tot_formatter = formatter[1];
      chart.yAxis1.tickFormat(value_formatter);
      chart.interactiveLayer.tooltip.valueFormatter(value_formatter);

      var stats_table = $chart.closest("table").find(".graph-statistics");
      var stats = data.statistics;

      if(stats) {
        if(stats.average) {
          var values = makeFlatLineValues(data.start, data.step, data.count, stats.average);

          res.push({
            key: "Avg", // TODO localize
            yAxis: 1,
            values: values,
            type: "line",
            classed: "line-dashed",
            color: "#00ff00",
          });
        }

        // fill the stats
        if(stats.total)
          stats_table.find(".graph-val-total").show().find("span").html(tot_formatter(stats.total));
        if(stats.average)
          stats_table.find(".graph-val-average").show().find("span").html(value_formatter(stats.average));
        if(stats.min_val)
          stats_table.find(".graph-val-min").show().find("span").html(value_formatter(stats.min_val) + "@" + (new Date(res[0].values[stats.min_val_idx][0] * 1000)).format("dd/MM/yyyy hh:mm:ss"));
        if(stats.max_val)
          stats_table.find(".graph-val-max").show().find("span").html(value_formatter(stats.max_val) + "@" + (new Date(res[0].values[stats.max_val_idx][0] * 1000)).format("dd/MM/yyyy hh:mm:ss"));
        if(stats["95th_percentile"]) {
          stats_table.find(".graph-val-95percentile").show().find("span").html(value_formatter(stats["95th_percentile"]));

          var values = makeFlatLineValues(data.start, data.step, data.count, stats["95th_percentile"]);

          res.push({
            key: "95th Perc", // TODO localize
            yAxis: 1,
            values: values,
            type: "line",
            classed: "line-dashed",
            color: "#0000ff",
          });
        }

        // only show if there are visible elements
        if(stats_table.find("td").filter(function(){ return $(this).css("display") != "none"; }).length > 0)
          stats_table.show();
        else
          stats_table.hide();
      } else {
        stats_table.hide();
      }

      update_chart_data(res);
    }).fail(function(xhr, status, error) {
      console.error("Error while retrieving the timeseries data [" + status + "]: " + error);
      update_chart_data([]);
    });
  }
}
