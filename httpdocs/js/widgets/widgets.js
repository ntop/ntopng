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
        let value, value_label, label;

        if(config.w.config.filtering_labels)
            value = config.w.config.filtering_labels[dataPointIndex];

        if(config.w.config.labels)
            value_label = config.w.config.labels[dataPointIndex];

        if(filter.length == 0 || value === undefined)
            return;

        if(DEFINED_TAGS[filter[0]])
            label = DEFINED_TAGS[filter[0]].i18n_label;
        
        addFilterTag({ value: (value_label || value), realValue: value, selectedOperator: "eq", key: filter[0], title: value, label: label });
    },

    /* On click event used by the flow analyze section, redirect to the current url + a single filter */
    "db_analyze_multiple_filters" : function (event, chartContext, config) {
        const { dataPointIndex } = config;
        const { filter } = config.w.config;
        let value, value_label, label;

        if(config.w.config.filtering_labels)
            value = config.w.config.filtering_labels[dataPointIndex];

        if(config.w.config.labels)
            value_label = config.w.config.labels[dataPointIndex];

        if(filter.length == 0 || !value)
            return;
        
        for (let i = filter.length; i >= 0; i--) {
            if(DEFINED_TAGS[filter[0][i]])
                label = DEFINED_TAGS[filter[0][i]].i18n_label;

            addFilterTag({ value: (value_label || value[i]), realValue: value[i], selectedOperator: "eq", key: filter[0][i], title: value[i], label: label });
        }
    },

    "none" : function (event, chartContext, config) {
        return;
    },
    
    /* Standard on click event, redirect to the url */
    "standard" : function (event, chartContext, config) {
        const { seriesIndex, dataPointIndex } = config;
        const { series } = config.w.config;
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

    "format_multiple_date" : function(value, { config, seriesIndex, dataPointIndex }) {
        return new Date(value[0]) + " - " + new Date(value[1])
    },

    /*
     *  This formatter is used by the bubble host map, from the y axis,
     *  used to show the Hosts, with their respective values 
     */
    "format_label_from_xy" : function({series, seriesIndex, dataPointIndex, w}) {
        const serie = w.config.series[seriesIndex]["data"][dataPointIndex];
        
        const x_value = serie["x"];
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
                        <b>${x_axis_title}</b>: ${x_value}
                    </div>
                    <div class='apexcharts-tooltip-text text-left'>
                        <b>${y_axis_title}</b>: ${y_value}
                    </div>
                </div>
            </div>`)
    },
}

/* Standard Formatter */
const DEFAULT_FORMATTER = DEFINED_TOOLTIP["format_value"];

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
                    format: 'dd/MM/yyyy HH:mm:ss',
                },
                y: {
                    formatter: function(value, { series, seriesIndex, dataPointIndex, w }) {
                        return value;
                    },
                },
                z: {
                    show: false,
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
                    enabled: true,
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
	    labels: [],
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
            noData: {
                text: 'No Data',
                align: 'center',
                verticalAlign: 'middle',
                style: {
                    fontSize: '24px'
                }
            }
        };

        // check if the additionalParams field contains an apex property,
        // then merge the two configurations giving priority to the custom one
        if (this._additionalParams && this._additionalParams.apex) {
            const mergedConfig = Object.assign(config, this._additionalParams.apex);
            return mergedConfig;
        }

        return config;
    }

    _buildTooltip(config, rsp) {
        /* By default the areaChart tooltip[y] is overwritten */
        config["tooltip"]["y"] = {
            formatter: function(value, { series, seriesIndex, dataPointIndex, w }) {
                return value;
            }
        };

        /* Changing events if given */
        if (rsp['tooltip']) {
            for (const axis in rsp['tooltip']) {
                if (axis === "x" || axis === "y" || axis === "z") {
                    const formatter = rsp['tooltip'][axis]['formatter'];
                    if(!config['tooltip'][axis])
                        config['tooltip'][axis] = {}

                    config['tooltip'][axis]['formatter'] = DEFINED_TOOLTIP[formatter] || NtopUtils[formatter]
                }
            }

            /* Customizable tooltip requested */
            if(rsp['tooltip']['custom'])
                config['tooltip']['custom'] = DEFINED_TOOLTIP[rsp['tooltip']['custom']] || NtopUtils[rsp['tooltip']['custom']]
        }
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

    _buildDataLabels(config, rsp) {
        if (rsp["dataLabels"]) {
            for (const [dataLabelsOpts, data] of Object.entries(rsp["dataLabels"])) {
                config["dataLabels"][dataLabelsOpts] = data;
            }
        }   

        let formatter = config["dataLabels"]["formatter"];
        
        if(formatter && DEFINED_TOOLTIP[formatter]) {
            config["dataLabels"]["formatter"] = DEFINED_TOOLTIP[formatter];
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
        if (rsp['events']) {
            /* Just pass a table of events. e.g. { events = { click = "db_analyze", updated = "standard" } }*/
            for (const event in rsp['events']) {
                config['chart']['events'][event] = DEFINED_EVENTS[rsp['events'][event]]
            }
        }

        if (rsp['horizontal_chart'] !== undefined) {
            config['plotOptions']['bar']['horizontal'] = rsp['horizontal_chart'];
        }

        this._buildTooltip(config, rsp)
        this._buildAxisFormatter(config, 'xaxis');
        this._buildAxisFormatter(config, 'yaxis');
        this._buildDataLabels(config, rsp);

        return config;
    }

    _initializeChart() {
        const config = this._buildConfig();
        this._chartConfig = config;
        this._chart = new ApexCharts(this._$htmlChart, this._chartConfig);
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
        if(this._chartConfig !== undefined) {
            await super.update(datasourceParams);
            if (this._chart != null) {
                // expecting that rsp contains an object called series
                const { colors, series, dataLabels, labels, xaxis, filtering_labels } = this._fetchedData.rsp;
                // update the colors list
                this._chartConfig.colors = colors;
                this._chartConfig.series = series;
                
                if(xaxis && xaxis.categories)
                    this._chartConfig.xaxis.categories = xaxis.categories;
                
                if(filtering_labels)
                    this._chartConfig.filtering_labels = filtering_labels;

                if(dataLabels) {
                    let formatter = this._chartConfig.dataLabels.formatter;
                    if(formatter && DEFINED_TOOLTIP[formatter])
                        this._chartConfig.dataLabels.formatter = DEFINED_TOOLTIP[formatter];
                    else
                        this._chartConfig.dataLabels.formatter = DEFAULT_FORMATTER;
                }
                    
                if(labels) 
                    this._chartConfig.labels = labels;

                this._chart.updateOptions(this._chartConfig, true);
            }
        }
    }

    async destroyAndUpdate(datasource = {}) {
        await super.destroyAndUpdate(datasource);
        this._initializeChart();
    }

}
