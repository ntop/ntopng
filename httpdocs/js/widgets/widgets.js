/**
 * (C) 2013-21 - ntop.org
 */

const DEFINED_WIDGETS = {};

function getWidgetByName(widgetName) {
    if (widgetName in DEFINED_WIDGETS) {
        return DEFINED_WIDGETS[widgetName];
    }
}

/**
 * Define a simple wrapper class for the widgets.
 */
class Widget {
    
    constructor(name, datasources = [], updateTime = 0, additionalParams = {}) {
    
        // field containing the data fetched from the datasources provided
        this._fetchedData = [];

        this.name = name;
        
        // if 0 then don't update the chart automatically, the time
        // is expressed in milliseconds
        this._updateTime = updateTime;

        this._datasources = datasources;
        this._additionalParams = additionalParams;
    }

    /**
     * Init the widget.
     */
    async init() {

        this._fetchedData = await this._fetchData();
        // register the widget to the DEFINED_WIDGETS object
        DEFINED_WIDGETS[this.name] = this;
    }

    /**
     * Destroy the widget freeing the resources used.
     */
    destroy() {}

    /**
     * Force the widget to reload it's data.
     */
    update() {}

    /**
     * For each datasources provided to the constructor,
     * do a GET request to a REST endpoint.
     */
    async _fetchData() {
        
        const fetchedData = [];

        for (const datasource of this._datasources) {
            const req = await fetch(`${http_prefix}/lua/${datasource.endpoint}`);
            const data = await req.json();
            fetchedData.push(data.rsp);
        }
        
        return fetchedData;
    }

}

class ChartWidget extends Widget {

    constructor(name, type = 'line', datasources = [], updateTime = 0, additionalParams = {}) {
        super(name, datasources, updateTime, additionalParams);
        this._chartType = type;
        this._chart = {};
    }

    get _configToLoad() {
        return this._additionalParams.config || `${this._chartType}.js`;
    }

    async init() {

        await super.init();

        const ctx = document.getElementById(`canvas-widget-${this.name}`);
        const config = await import(`./configs/${this._configToLoad}`);
        const {dataset, options} = config.default;
        
        const optionsToLoad = Object.assign(this._fetchedData[0].options, options);
        const data = {datasets: []};

        this._fetchedData.forEach((rsp) => {
            rsp.data.datasets.forEach(d => {
                d.baseUrl = rsp.redirect_url; 
                data.datasets.push(Object.assign(d, dataset))
            })
        });

        this._chart = new Chart(ctx, { data: data, type: this._chartType, options: optionsToLoad });
    }

}