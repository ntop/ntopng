/**
    (C) 2022 - ntop.org
*/
import { ntopng_utility } from '../services/context/ntopng_globals_services';

const ntopChartApex = function() {
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
    const _setXTimeFormatter = function(chartOptions) {
	chartOptions.xaxis.labels.formatter = function(value, { series, seriesIndex, dataPointIndex, w }) {
	    return ntopng_utility.from_utc_to_server_date_format(value);
	};
    };

    // define default chartOptions for area chart type.
    const _default_TS_STACKED_ChartOptions = function() {
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
    const _default_TS_PIE_ChartOptions = function() {
	let chartOptions = ntopng_utility.clone(_default_BASE_ChartOptions);
	let TS_STACKED_ChartOptions = {
    chart: {
      stacked: true,
      type: "polarArea",
      height: 300
    },
    yaxis: {
      labels: {
        formatter: function(value) {
          return value;
        },
      }
    },
    dataLabels: {
      enabled: true,
      formatter: (value) => {
        debugger;
        return NtopUtils.bytesToSize(value);
      },
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

    // define default chartOptions for line chart type.
    const _default_TS_LINE_ChartOptions = function() {
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
    
    return {
	typeChart: {
	    TS_LINE: "TS_LINE",
	    TS_STACKED: "TS_STACKED",
	    PIE: "PIE",
	    BASE: "BASE",
	},
	newChart: function(type) {
	    let _chartOptions;
	    let _chart;
	    let _chartHtmlElement;

	    if (type == this.typeChart.TS_STACKED) {
        _chartOptions = ntopng_utility.clone(_default_TS_STACKED_ChartOptions);
        _setXTimeFormatter(_chartOptions);
	    } else if (type == this.typeChart.TS_LINE) {
        _chartOptions = ntopng_utility.clone(_default_TS_LINE_ChartOptions);
        _setXTimeFormatter(_chartOptions);
	    } else if (type == this.typeChart.PIE) {
        _chartOptions = ntopng_utility.clone(_default_TS_PIE_ChartOptions);
      }  else if (type == this.typeChart.BASE) {
        _chartOptions = ntopng_utility.clone(_default_BASE_ChartOptions);
      } else {
		throw `ntopChartApex::newChart: chart type = ${type} unsupported`;
	    }
	    
	    return {
		drawChart: function(htmlElement, chartOptions) {
		    // add/replace chartOptions fields in _chartOptions
		    if(chartOptions.yaxis && chartOptions.yaxis.labels && chartOptions.yaxis.labels.formatter) {
          const formatter = chartOptions.yaxis.labels.formatter
          if(formatter == "formatValue") {
            chartOptions.yaxis.labels.formatter = NtopUtils.formatValue
          }
          else if(formatter == "bytesToSize") {
            chartOptions.yaxis.labels.formatter = NtopUtils.bytesToSize
          }
        }
        ntopng_utility.copy_object_keys(chartOptions, _chartOptions, true);
        _chart = new ApexCharts(htmlElement, _chartOptions);
		    _chartHtmlElement = htmlElement;
		    _chart.render();
		},
		destroyChart: function() {
		    if (_chart == null) { return; }
		    _chart.destroy();
		},
		updateChart: function(chartOptions) {
		    if (_chart == null) { return; }
		    _chart.updateOptions(chartOptions, true);
		},
		registerEvent: function(eventName, callback, updateChart = false) {
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
