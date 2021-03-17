/**
 * (C) 2013-21 - ntop.org
 */

const DEFINED_WIDGETS = {};

class WidgetUtils {
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
        DEFINED_WIDGETS[this.name] = this;
        this._fetchedData = await this._fetchData();
    }

    /**
     * Destroy the widget freeing the resources used.
     */
    destroy() {}

    /**
     * Force the widget to reload it's data.
     */
    async destroyAndUpdate(datasource = {}) {
        this.destroy();
        this._datasource = datasource;
        this._fetchedData = await this._fetchData();
    }

    async update(datasourceParams = {}) {
        // build the new endpoint
        const u = new URL(`${location.origin}${this._datasource.endpoint}`);
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
        const data = await req.json();
        return data;
    }

}

class ChartWidget extends Widget {

    constructor(name, type = 'line', datasource = {}, updateTime = 0, additionalParams = {}) {
        super(name, datasource, updateTime, additionalParams);
        
        this._chartType = type;
        this._chart = null;
        // the canvas context
        this._ctx = document.getElementById(`canvas-widget-${this.name}`);
    }

    async _initializeChart() {
        const {data, options} = await this._formatDataAndOptions();
        this._chart = new Chart(this._ctx, { data: data, type: this._chartType, options: options });
    }

    async _formatDataAndOptions() {

        const data = {datasets: [], labels: []};

        // dynamically import the standard configuration for the chart
        const config = await this._loadConfiguration();
        const {dataset, options} = config.default;

        const response = this._fetchedData.rsp;

        let optionsToLoad = options || {};
        if (response.options !== undefined) {
            optionsToLoad = Object.assign(response.options, options);
        }

        response.data.datasets.forEach(d => {
            d.baseUrl = response.redirect_url; 
            data.datasets.push(Object.assign(d, dataset))
        })

        // add labels
        if (response.data.labels !== undefined) {
            data.labels = response.data.labels;
        }

        return {data: data, options: optionsToLoad};
    }

    /**
     * Try to load the default configuration for the chart.
     */
    async _loadConfiguration() {
        try {
            return await import(`./configs/${this._configToLoad}`);
        }
        catch (e) {
            return {default: {dataset: {}, options: {}}};
        }
    }

    get _configToLoad() {
        return this._additionalParams.config || `${this._chartType}.js`;
    }

    async init() {
        await super.init();
        this._initializeChart();
    }

    destroy() {
        this._chart.destroy();
    }

    async update(datasourceParams = {}) {
        await super.update(datasourceParams);

        const response = this._fetchedData.rsp;
        const {data} = await this._formatDataAndOptions();

        this._chart.data.labels = response.data.labels;
        this._chart.data = data;

        this._chart.update();
    }

    async destroyAndUpdate(datasource = {}) {
        await super.destroyAndUpdate(datasource);
        this._initializeChart();
    }

}