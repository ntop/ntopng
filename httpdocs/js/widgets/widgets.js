/**
 * (C) 2013-21 - ntop.org
 */

const DEFINED_WIDGETS = {};
/* Used to implement the on click events onto the graph */
const DEFINED_EVENTS = {
    /* On click event used by the flow analyze section, redirect to the current url + a single filter */
    "db_analyze" : function (event, chartContext, config) {
        const { dataPointIndex } = config;
        const { filter } = config.w.config;

        const value = config.w.config.filtering_labels[dataPointIndex];

        if(filter.length == 0 || value === undefined)
            return;
        
        let curr_url = new URLSearchParams(window.location.search);
        curr_url.set(filter, value + ';eq');
        window.history.pushState(null, null, "?"+curr_url.toString());
        window.location.reload();
    },

    /* On click event used by the flow analyze section, redirect to the current url + a single filter */
    "db_analyze_multiple_filters" : function (event, chartContext, config) {
        const { dataPointIndex } = config;
        const { filter } = config.w.config;
        const value = config.w.config.true_labels[dataPointIndex];

        if(filter.length == 0 || !value)
            return;

        let curr_url = new URLSearchParams(window.location.search);

        for (let i = filter.length; i >= 0; i--) {
            curr_url.set(filter[0][i], value[i] + ';eq');
        }

        window.history.pushState(null, null, "?"+curr_url.toString());
        window.location.reload();
    },

    "none" : function (event, chartContext, config) {
        return;
    },
    
    /* Standard on click event, redirect to the url */
    "standard" : function (event, chartContext, config) {
        const { seriesIndex, dataPointIndex } = config;
        const { series } = config.config;
        
        if (seriesIndex === -1) return;
        if (series === undefined) return;

        const serie = series[seriesIndex];
        if (serie.base_url !== undefined) {
            const search = serie.data[dataPointIndex].meta.url_query;
            location.href = `${serie.base_url}?${search}`;
        }
    },
}

const DEFINED_TOOLTIP = {
    "none" : function(value, { config, seriesIndex, dataPointIndex }) {
        return "";
    },

    /* Standard on click event, redirect to the url */
    "standard" : function (_, opt) {
        const config = opt.w.config;
        const { series } = config;
        const { dataPointIndex, seriesIndex } = opt;
        const data = series[seriesIndex].data[dataPointIndex];

        if (data.meta !== undefined)
            return data.meta.label || data.x;

        return data;
    },

    /* On click event used by the flow analyze section, redirect to the current url + a single filter */
    "format_bytes" : function(value, { config, seriesIndex, dataPointIndex }) {
        return NtopUtils.bytesToSize(value);
    },

    "format_pkts" : function(value, { config, seriesIndex, dataPointIndex }) {
        return NtopUtils.formatPackets(value);
    },

    /* On click event used by the flow analyze section, redirect to the current url + a single filter */
    "format_value" : function(value, { config, seriesIndex, dataPointIndex }) {
        return NtopUtils.formatValue(value);
    },
}

class WidgetTooltips {
    static showXY({ seriesIndex, dataPointIndex, w }) {

        const defaultFormatter = (x) => x;

        const config = w.config;
        const xLabel = config.xaxis.title.text || "x";
        const yLabel = config.yaxis[0].title.text || "y";
        const serie = config.series[seriesIndex].data[dataPointIndex];
        const { x, y } = serie;
        const title = serie.meta.label || serie.x;

        let xFormatter = defaultFormatter, yFormatter = defaultFormatter;
        if (config.xaxis.labels && config.xaxis.labels.ntop_utils_formatter) {
            xFormatter = NtopUtils[config.xaxis.labels.ntop_utils_formatter];
        }
        if (config.yaxis[0].labels && config.yaxis[0].labels.ntop_utils_formatter) {
            yFormatter = NtopUtils[config.yaxis[0].labels.ntop_utils_formatter];
        }

        return (`
            <div class='apexcharts-theme-light apexcharts-active' id='test'>
                <div class='apexcharts-tooltip-title' style='font-family: Helvetica, Arial, sans-serif; font-size: 12px;'>
                    ${title}
                </div>
                <div class='apexcharts-tooltip-series-group apexcharts-active d-block'>
                    <div class='apexcharts-tooltip-text text-left'>
                        <b>${xLabel}</b>: ${xFormatter(x)}
                    </div>
                    <div class='apexcharts-tooltip-text text-left'>
                        <b>${yLabel}</b>: ${yFormatter(y)}
                    </div>
                </div>
            </div>
        `)
    }
    static unknown() {
        return `<div>Unknown</div>`;
    }
}

class WidgetUtils {

    static registerWidget(widget) {
        if (widget === null) throw new Error(`The passed widget reference is null!`);
        if (widget.name in DEFINED_WIDGETS) throw new Error(`The widget ${widget.name} is already defined!`);
        DEFINED_WIDGETS[widget.name] = widget;
    }

    static getWidgetByName(widgetName) {
        if (widgetName in DEFINED_WIDGETS) {
            return DEFINED_WIDGETS[widgetName];
        }
        throw new Error(`Widget ${widgetName} not found!`)
    }
}

/**
 * Define a simple wrapper class for the widgets.
 */
class Widget {

    constructor(name, datasource = {}, updateTime = 0, additionalParams = {}) {

        // field containing the data fetched from the datasources provided
        this._fetchedData = [];

        this.name = name;

        // if 0 then don't update the chart automatically, the time
        // is expressed in milliseconds
        this._updateTime = updateTime;

        this._datasource = datasource;
        this._additionalParams = additionalParams;
    }

    /**
     * Init the widget.
     */
    async init() {

        // register the widget to the DEFINED_WIDGETS object
        WidgetUtils.registerWidget(this);
        this._fetchedData = await this._fetchData();

        if (this._updateTime > 0) {
            setInterval(async () => { await this.update(this._datasource.params); }, this._updateTime);
        }
    }

    /**
     * Destroy the widget freeing the resources used.
     */
    async destroy() { }

    /**
     * Force the widget to reload it's data.
     */
    async destroyAndUpdate(datasourceParams = {}) {
        await this.destroy();
        await this.update(datasourceParams);
    }

    async update(datasourceParams = {}) {
	// build the new endpoint
        const u = new URL(`${location.origin}${this._datasource.name}`);
        for (const [key, value] of Object.entries(datasourceParams)) {
            u.searchParams.set(key, value);
        }

        this._datasource.endpoint = u.pathname + u.search;
        this._fetchedData = await this._fetchData();
    }

    /**
     * For each datasources provided to the constructor,
     * do a GET request to a REST endpoint.
     */
    async _fetchData() {
        const req = await fetch(`${http_prefix}${this._datasource.endpoint}`);
        return await req.json();
    }

}

class ChartWidget extends Widget {

    constructor(name, type = 'line', datasource = {}, updateTime = 0, additionalParams = {}) {
        super(name, datasource, updateTime, additionalParams);

        this._chartType = type;
        this._chart = {};
        this._$htmlChart = document.querySelector(`#canvas-widget-${name}`);
    }

    static registerEventCallback(widgetName, eventName, callback) {
        setTimeout(async () => {
            try {
                const widget = WidgetUtils.getWidgetByName(widgetName);
                const updatedOptions = {
                    chart: {
                        events: {
                            [eventName]: callback
                        }
                    }
                };
                await widget._chart.updateOptions(updatedOptions);
            }
            catch (e) {

            }
        }, 1000);
    }

    _generateConfig() {
        const config = {
            series: [],
            tooltip: {
                enabledOnSeries: [0],
                x: {
                    show: true,
                    formatter: DEFINED_TOOLTIP["none"]
                },
                y: {
                    show: true,
                    formatter: DEFINED_TOOLTIP["none"]
                },
                z: {
                    show: true,
                    formatter: DEFINED_TOOLTIP["none"]
                }
            },
            chart: {
                type: this._chartType,
                events: {},
                height: '100%',
                toolbar: {
                    show: false,
                }
            },
            xaxis: {
                labels: {
                    style: {
                        fontSize: '14px',
                    }
                },
                tooltip: {
                    enabled: false,
                    formatter: function(value) {
                        return value;
                    }
                }
            },
            yaxis: {
                labels: {
                    style: {
                        fontSize: '14px',
                    }
                },
                tooltip: {
                    enabled: true,
                    formatter: function(value) {
                        return value;
                    }
                }
            },
            zaxis: {
                labels: {
                    tooltip: {
                        enabled: false,
                    },
                    style: {
                        fontSize: '14px',
                    }
                },
                tooltip: {
                    enabled: true
                }
            },
            dataLabels: {
                enabled: true,
                style: {
                    fontSize: '14px',
                }
            },
            legend: {
                show: true,
                fontSize: '14px',
                position: 'bottom',
                onItemClick: {
                    toggleDataSeries: true,
                },
            },
            plotOptions: {
                bar: {
                    borderRadius: 4,
                    horizontal: true,
                }
            },
        };

        // check if the additionalParams field contains an apex property,
        // then merge the two configurations giving priority to the custom one
        if (this._additionalParams && this._additionalParams.apex) {
            const mergedConfig = Object.assign(config, this._additionalParams.apex);
            return mergedConfig;
        }

        return config;
    }

    _buildAxisFormatter(config, axisName) {

        const axis = config[axisName];
        if (axis === undefined || axis.labels === undefined) return;

        // enable formatters
        if (axis.labels.ntop_utils_formatter !== undefined && axis.labels.ntop_utils_formatter !== 'none') {

            const selectedFormatter = axis.labels.ntop_utils_formatter;

            if (NtopUtils[selectedFormatter] === undefined) {
                console.error(`xaxis: Formatting function '${selectedFormatter}' didn't found inside NtopUtils.`);
            }
            else {
                axis.labels.formatter = NtopUtils[selectedFormatter];
            }
        }
    }

    _buildTooltipFormatter(config) {
	// do we need a custom tooltip?
        if (config.tooltip && config.tooltip.widget_tooltips_formatter) {
            const formatterName = config.tooltip.widget_tooltips_formatter;
            config.tooltip.custom = WidgetTooltips[formatterName] || WidgetTooltips.unknown;
        }
    }

    _buildConfig() {

        const config = this._generateConfig();
        const rsp = this._fetchedData.rsp;
        
        // add additional params fetched from the datasource
        const additionals = ['series', 'xaxis', 'yaxis', 'colors', 'labels', 'fill', 'filter', 'filtering_labels'];
        for (const additional of additionals) {

            if (rsp[additional] === undefined) continue;

            if (config[additional] !== undefined) {
                config[additional] = Object.assign(config[additional], rsp[additional]);
            }
            else {
                config[additional] = rsp[additional];
            }
        }

        /* Changing events if given */
        if (rsp['tooltip']) {
            for (const axis in rsp['tooltip']) {
                if (axis === "x" || axis === "y" || axis === "z") {
                    config['tooltip'][axis]['formatter'] = DEFINED_TOOLTIP[rsp['tooltip'][axis]['formatter']]
                }
            }
        }

        /* Changing events if given */
        if (rsp['events']) {
            /* Just pass a table of events. e.g. { events = { click = "db_analyze", updated = "standard" } }*/
            for (const event in rsp['events']) {
                config['chart']['events'][event] = DEFINED_EVENTS[rsp['events'][event]]
            }
        }

        this._buildTooltipFormatter(config);
        this._buildAxisFormatter(config, 'xaxis');
        this._buildAxisFormatter(config, 'yaxis');

        return config;
    }

    _initializeChart() {
        const config = this._buildConfig();
        this._chartConfig = config;
        this._chart = new ApexCharts(this._$htmlChart, config);
        this._chart.render();
    }

    async init() {
        await super.init();
        this._initializeChart();
    }

    async destroy() {
        await super.destroy();
        this._chart.destroy();
        this._chart = null;
    }

    async update(datasourceParams = {}) {
        await super.update(datasourceParams);
        if (this._chart != null) {
	    // expecting that rsp contains an object called series
        const { colors, series, dataLabels, labels } = this._fetchedData.rsp;
	    // update the colors list
	    this._chartConfig.colors = colors;
	    this._chartConfig.series = series;
        this._chartConfig.dataLabels = dataLabels;
        this._chartConfig.labels = labels;
	    this._chart.updateOptions(this._chartConfig, true);
        }
    }

    async destroyAndUpdate(datasource = {}) {
        await super.destroyAndUpdate(datasource);
        this._initializeChart();
    }

}
