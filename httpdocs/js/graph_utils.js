// 2018 - ntop.org

// add a new updateStackedChart function
function attachStackedChartCallback(chart, url, chart_id, params) {
  var pending_request = null;
  var d3_sel = d3.select(chart_id);
  var $chart = $(chart_id);

  //var spinner = $("<img class='chart-loading-spinner' src='" + spinner_url + "'/>");
  var spinner = $('<i class="chart-loading-spinner fa fa-spinner fa-lg fa-spin"></i>');
  $chart.parent().css("position", "relative");

  chart.updateStackedChart = function (tstart, tend) {
    if(pending_request)
      pending_request.abort();
    else
      spinner.appendTo($chart.parent());

    if(tstart) params.epoch_begin = tstart;
    if(tend) params.epoch_end = tend;

    // Load data via ajax
    pending_request = $.get(url, params, function(data) {
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
          key: series[j].label,
          yAxis: 1,
          values: values,
          type: "area",
        });
      }

      // todo stop loading indicator
      d3_sel.datum(res).transition().duration(500).call(chart);
      nv.utils.windowResize(chart.update);
      pending_request = null;
      spinner.remove();
    });
  }
}
