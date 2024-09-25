/**
    (C) 2022 - ntop.org
*/
import { ntopng_utility } from '../services/context/ntopng_globals_services';
import NtopUtils from "../utilities/ntop-utils";
import FormatterUtils from "../utilities/formatter-utils.js";

const ntopChartApex = function () {
  // define default chartOptions for all chart type.
  const _default_BASE_ChartOptions = {
    series: [],
    chart: {
      height: "100%",
      width: "100%",
      toolbar: {
        tools: {
          zoomout: false,
          download: false,
          zoomin: false,
          zoom: " ",
          selection: false,
          pan: false,
          reset: false
        }
      },
      events: {}
    },
    xaxis: {
      tooltip: {
        enabled: false,
      },
    },
    yaxis: {
      labels: {
        show: true,
        style: {
          colors: [],
          fontSize: "11px",
          fontWeight: 400,
          cssClass: ""
        }
      },
      title: {
        rotate: -90,
        offsetY: 0,
        offsetX: 0,
        style: {
          fontSize: "11px",
          fontWeight: 900,
          cssClass: ""
        }
      },
      tooltip: {
        enabled: false,
      },
    },
    grid: {
      show: false,
    },
    legend: {
      show: true
    },
  };

  // define default xaxis formatter for chart with datetime on xaxis.
  const _setXTimeFormatter = function (chartOptions) {
    chartOptions.xaxis.labels.formatter = function (value, { series, seriesIndex, dataPointIndex, w }) {
      return ntopng_utility.from_utc_to_server_date_format(value);
    };
  };

  // define default chartOptions for area chart type.
  const _default_TS_COLUMN_ChartOptions = function () {
    let chartOptions = ntopng_utility.clone(_default_BASE_ChartOptions);
    let TS_COLUMN_ChartOptions = {
      chart: {
        stacked: true,
        type: "bar",
        zoom: {
          enabled: true,
          type: "x",
        },
      },
      tooltip: {
        // shared: true,
        x: {
          format: "dd MMM yyyy HH:mm:ss"
        },
        y: {}
      },
      xaxis: {
        labels: {
          show: true,
          datetimeUTC: false,
          formatter: null,
        },
        axisTicks: {
          show: false,
        },
        type: "datetime",
        axisBorder: {
          show: true,
        },
        convertedCatToNumeric: false
      },
      dataLabels: {
        enabled: false
      },
      stroke: {
        show: false,
        curve: "smooth"
      },
      fill: {
        type: "solid"
      },
    };
    ntopng_utility.copy_object_keys(TS_COLUMN_ChartOptions, chartOptions, true);
    return chartOptions;
  }();

  // define default chartOptions for area chart type.
  const _default_TS_STACKED_ChartOptions = function () {
    let chartOptions = ntopng_utility.clone(_default_BASE_ChartOptions);
    let TS_STACKED_ChartOptions = {
      chart: {
        stacked: true,
        type: "area",
        zoom: {
          enabled: true,
          type: "x",
        },
      },
      tooltip: {
        // shared: true,
        x: {
          format: "dd MMM yyyy HH:mm:ss"
        },
        y: {}
      },
      xaxis: {
        labels: {
          show: true,
          datetimeUTC: false,
          formatter: null,
        },
        axisTicks: {
          show: false,
        },
        type: "datetime",
        axisBorder: {
          show: true,
        },
        convertedCatToNumeric: false
      },
      dataLabels: {
        enabled: false
      },
      stroke: {
        show: false,
        curve: "smooth"
      },
      fill: {
        type: "solid"
      },
    };
    ntopng_utility.copy_object_keys(TS_STACKED_ChartOptions, chartOptions, true);
    return chartOptions;
  }();


  // define default chartOptions for area chart type.
  const _default_TS_POLAR_ChartOptions = function () {
    let chartOptions = ntopng_utility.clone(_default_BASE_ChartOptions);
    let TS_STACKED_ChartOptions = {
      chart: {
        stacked: true,
        type: "polarArea",
        height: 400
      },
      yaxis: {
        show: true,
        labels: {
          formatter: NtopUtils.bytesToSize
        }
      },
      dataLabels: {
        enabled: true,
        formatter: function (val, opts) {
          return (val ? `${val.toFixed(1)}%` : `0%`)
        },
      },
      legend: {
        enabled: true,
        position: 'bottom',
      },
      stroke: {
        show: false,
        curve: "smooth"
      },
      fill: {
        type: "solid"
      },
      tooltip: {
        y: {
          formatter: NtopUtils.bytesToSize
        },
      },
    };
    ntopng_utility.copy_object_keys(TS_STACKED_ChartOptions, chartOptions, true);
    return chartOptions;
  }();

  // define default chartOptions for area chart type.
  const _default_TS_DONUT_ChartOptions = function () {
    let chartOptions = ntopng_utility.clone(_default_BASE_ChartOptions);
    let TS_STACKED_ChartOptions = {
      chart: {
        stacked: true,
        type: "donut",
        height: 300
      },
      yaxis: {
        show: true,
        labels: {
          formatter: NtopUtils.bytesToSize
        }
      },
      dataLabels: {
        enabled: true,
        formatter: function (val, opts) {
          return (val ? `${val.toFixed(1)}%` : `0%`)
        },
      },
      legend: {
        enabled: true,
        position: 'bottom',
      },
      stroke: {
        show: false,
        curve: "smooth"
      },
      fill: {
        type: "solid"
      },
      tooltip: {
        y: {
          formatter: FormatterUtils.getFormatter("number"),
        },
      },
      noData: {
        text: 'No Data',
        style: {
          color: undefined,
          fontSize: '24px',
          fontFamily: undefined
        }
      }
    };
    ntopng_utility.copy_object_keys(TS_STACKED_ChartOptions, chartOptions, true);
    return chartOptions;
  }();

  // define default chartOptions for area chart type.
  const _default_TS_RADIALBAR_ChartOptions = function () {
    let chartOptions = ntopng_utility.clone(_default_BASE_ChartOptions);
    let TS_STACKED_ChartOptions = {
      chart: {
        stacked: true,
        type: "radialBar",
        height: 300
      },
      yaxis: {
        show: true,
      },
      dataLabels: {
        enabled: true,
        formatter: function (val, opts) {
          return val
        },
      },
      stroke: {
        show: false,
        curve: "smooth"
      },
      fill: {
        type: "solid"
      },
      tooltip: {
        y: {
          formatter: NtopUtils.bytesToSize
        },
      },
      noData: {
        text: 'No Data',
        style: {
          color: undefined,
          fontSize: '24px',
          fontFamily: undefined
        }
      },
      plotOptions: {
        radialBar: {
          offsetY: 0,
          startAngle: 0,
          endAngle: 270,
          hollow: {
            margin: 5,
            size: '30%',
            background: 'transparent',
            image: undefined,
          },
          dataLabels: {
            name: {
              show: false,
            },
            value: {
              show: false,
            }
          }
        }
      },
      legend: {
        show: true,
        floating: true,
        fontSize: '16px',
        position: 'left',
        offsetX: 160,
        offsetY: 15,
        labels: {
          useSeriesColors: true,
        },
        markers: {
          size: 0
        },
        formatter: function (seriesName, opts) {
          return seriesName + ":  " + opts.w.globals.series[opts.seriesIndex]
        },
        itemMargin: {
          vertical: 3
        }
      },
      responsive: [{
        breakpoint: 480,
        options: {
          legend: {
            show: false
          }
        }
      }]
    };
    ntopng_utility.copy_object_keys(TS_STACKED_ChartOptions, chartOptions, true);
    return chartOptions;
  }();

  // define default chartOptions for area chart type.
  const _default_TS_PIE_ChartOptions = function () {
    let chartOptions = ntopng_utility.clone(_default_BASE_ChartOptions);
    let TS_STACKED_ChartOptions = {
      chart: {
        stacked: true,
        type: "pie",
        height: 400
      },
      yaxis: {
        show: true,
        labels: {
          formatter: NtopUtils.bytesToSize
        }
      },
      dataLabels: {
        enabled: true,
        formatter: function (val, opts) {
          return (val ? `${val.toFixed(1)}%` : `0%`)
        },
      },
      legend: {
        enabled: true,
        position: 'bottom',
      },
      stroke: {
        show: false,
        curve: "smooth"
      },
      fill: {
        type: "solid"
      },
      tooltip: {
        y: {
          formatter: NtopUtils.bytesToSize
        },
      },
    };
    ntopng_utility.copy_object_keys(TS_STACKED_ChartOptions, chartOptions, true);
    return chartOptions;
  }();

  // define default chartOptions for line chart type.
  const _default_TS_LINE_ChartOptions = function () {
    let chartOptions = ntopng_utility.clone(_default_BASE_ChartOptions);
    let TS_LINE_ChartOptions = {
      chart: {
        type: "line",
        zoom: {
          enabled: true,
          type: "x",
        },
      },
      tooltip: {
        shared: true,
        x: {
          format: "dd MMM yyyy HH:mm:ss"
        },
        y: {}
      },
      xaxis: {
        labels: {
          show: false,
          datetimeUTC: false,
          formatter: null,
        },
        axisTicks: {
          show: true
        },
        type: "datetime",
        axisBorder: {
          show: true
        },
        convertedCatToNumeric: false
      },
      stroke: {
        show: true,
        width: 2,
        curve: "smooth"
      },
      grid: {
        show: true,
      },
      dataLabels: {
        enabled: false
      },
    };
    ntopng_utility.copy_object_keys(TS_LINE_ChartOptions, chartOptions, true);
    return chartOptions;
  }();

  const format_label_from_xname = function ({ series, seriesIndex, dataPointIndex, w }) {
    const serie = w.config.series[seriesIndex]["data"][dataPointIndex];
    const name = serie["name"]
    const y_value = serie["y"];
    const host_name = serie["meta"]["label"];

    const x_axis_title = w.config.xaxis.title.text;
    const y_axis_title = w.config.yaxis[0].title.text;

    return (`
          <div class='apexcharts-theme-light apexcharts-active' id='test'>
              <div class='apexcharts-tooltip-title' style='font-family: Helvetica, Arial, sans-serif; font-size: 12px;'>
                  ${host_name}
              </div>
              <div class='apexcharts-tooltip-series-group apexcharts-active d-block'>
                  <div class='apexcharts-tooltip-text text-left'>
                      <b>${x_axis_title}</b>: ${name}
                  </div>
                  <div class='apexcharts-tooltip-text text-left'>
                      <b>${y_axis_title}</b>: ${y_value}
                  </div>
              </div>
          </div>`)
  };

  // define default chartOptions for line chart type.
  const _default_TS_BUBBLE_ChartOptions = function () {
    let chartOptions = ntopng_utility.clone(_default_BASE_ChartOptions);
    let TS_BUBBLE_ChartOptions = {
      chart: {
        width: '100%',
        height: '100%',
        stacked: true,
        type: "bubble",
        zoom: {
          autoScaleYaxis: true
        },
      },
      legend: {
        enabled: true,
        position: 'bottom',
      },
      stroke: {
        show: false,
        curve: "smooth"
      },
      fill: {
        type: "solid"
      },
      events: {
        dataPointSelection: "standard",
      },
      grid: {
        padding: {
          left: 6
        },
      },
      xaxis: {
        type: 'numeric',
        labels: {}
      },
      yaxis: {
        type: 'numeric',
        forceNiceScale: true,
        labels: {}
      },
      dataLabels: {
        enabled: false
      },
      tooltip: {
        custom: format_label_from_xname,
      }
    };
    ntopng_utility.copy_object_keys(TS_BUBBLE_ChartOptions, chartOptions, true);
    return chartOptions;
  }();

  return {
    typeChart: {
      TS_LINE: "TS_LINE",
      TS_STACKED: "TS_STACKED",
      TS_COLUMN: "TS_COLUMN",
      PIE: "PIE",
      DONUT: "DONUT",
      RADIALBAR: "RADIALBAR",
      RADAR: "RADAR",
      BUBBLE: "BUBBLE",
      BASE: "BASE",
    },
    newChart: function (type) {
      let _chartOptions = {};
      let _chart;
      let _chartHtmlElement;

      if (type == this.typeChart.TS_STACKED) {
        _chartOptions = ntopng_utility.clone(_default_TS_STACKED_ChartOptions);
        _setXTimeFormatter(_chartOptions);
      } else if (type == this.typeChart.TS_LINE) {
        _chartOptions = ntopng_utility.clone(_default_TS_LINE_ChartOptions);
        _setXTimeFormatter(_chartOptions);
      } else if (type == this.typeChart.TS_COLUMN) {
        _chartOptions = ntopng_utility.clone(_default_TS_COLUMN_ChartOptions);
        _setXTimeFormatter(_chartOptions);
      } else if (type == this.typeChart.PIE) {
        _chartOptions = ntopng_utility.clone(_default_TS_PIE_ChartOptions);
      } else if (type == this.typeChart.DONUT) {
        _chartOptions = ntopng_utility.clone(_default_TS_DONUT_ChartOptions);
      } else if (type == this.typeChart.RADIALBAR) {
        _chartOptions = ntopng_utility.clone(_default_TS_RADIALBAR_ChartOptions);
      } else if (type == this.typeChart.POLAR) {
        _chartOptions = ntopng_utility.clone(_default_TS_POLAR_ChartOptions);
      } else if (type == this.typeChart.BUBBLE) {
        _chartOptions = ntopng_utility.clone(_default_TS_BUBBLE_ChartOptions);
      } else if (type == this.typeChart.BASE) {
        _chartOptions = ntopng_utility.clone(_default_BASE_ChartOptions);
      } else {
        throw `ntopChartApex::newChart: chart type = ${type} unsupported`;
      }
      const setYaxisFormatter = (chartOptions) => {
        if (typeof (chartOptions?.yaxis?.labels?.formatter) == "string") {
          const formatter = chartOptions.yaxis.labels.formatter;
          let chartFormatter = FormatterUtils.getFormatter(formatter);
          if (chartFormatter != null) {
            chartOptions.yaxis.labels.formatter = chartFormatter;
          } else {
            if (formatter == "formatValue") {
              chartOptions.yaxis.labels.formatter = FormatterUtils.getFormatter("number");
            }
            else if (formatter == "bytesToSize") {
              chartOptions.yaxis.labels.formatter = FormatterUtils.getFormatter("bytes");
            }
          }
        }
      };
      return {
        drawChart: function (htmlElement, chartOptions) {
          // add/replace chartOptions fields in _chartOptions
          setYaxisFormatter(chartOptions);
          ntopng_utility.copy_object_keys(chartOptions, _chartOptions, true);
          _chart = new ApexCharts(htmlElement, _chartOptions);
          _chartHtmlElement = htmlElement;
          _chart.render();
        },
        to_data_uri: async function (options) {
          if (_chart == null) { return; }
          let res = await _chart.dataURI(options);
          return res.imgURI;
        },
        destroyChart: function () {
          if (_chart == null) { return; }
          _chart.destroy();
        },
        updateChart: function (chartOptions) {
          if (_chart == null) { return; }
          setYaxisFormatter(chartOptions);
          _chart.updateOptions(chartOptions, false, false, false);
        },
        updateSeries: function (series) {
          if (_chart == null) { return; }
          _chart.updateSeries(series);
        },
        registerEvent: function (eventName, callback, updateChart = false) {
          _chartOptions.chart.events[eventName] = callback;
          if (updateChart == true) {
            _chart.updateOptions(_chartOptions);
          }
        },
      };
    },
  };
}();

export { ntopChartApex };
