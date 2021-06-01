/**
 * (C) 2013-21 - ntop.org
 */

const DEFINED_WIDGETS = {};

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
            <div class='apexcharts-theme-light apexcharts-active'>
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
                x: {
                    formatter: function (_, opt) {

                        const config = opt.w.config;
                        const { series } = config;
                        const { dataPointIndex, seriesIndex } = opt;
                        const data = series[seriesIndex].data[dataPointIndex];

                        if (data.meta !== undefined)
                            return data.meta.label || data.x;

                        return data.x;
                    }
                },
                z: {
                    formatter: () => '',
                    title: ''
                }
            },
            chart: {
                type: this._chartType,
                events: {
                    click: function (event, chartContext, config) {
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
                },
                height: '100%',
            },
            xaxis: {
                tooltip: {
                    enabled: false
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
        const additionals = ['series', 'xaxis', 'yaxis', 'colors', 'dataLabels', 'tooltip', 'fill'];
        for (const additional of additionals) {

            if (rsp[additional] === undefined) continue;

            if (config[additional] !== undefined) {
                config[additional] = Object.assign(config[additional], rsp[additional]);
            }
            else {
                config[additional] = rsp[additional];
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
        const { colors, series } = this._fetchedData.rsp;
	    // update the colors list
	    this._chartConfig.colors = colors;
	    this._chartConfig.series = series;
	    this._chart.updateOptions(this._chartConfig, true);
        }
    }

    async destroyAndUpdate(datasource = {}) {
        await super.destroyAndUpdate(datasource);
        this._initializeChart();
    }

}
