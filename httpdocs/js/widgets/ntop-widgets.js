import TableTemplate from './templates/table-template.js';
import PieChartTemplate from './templates/pie-chart-template.js';
import DonutChartTemplate from './templates/donut-chart-template.js';
import MultiBarChartTemplate from './templates/multibar-chart-template.js';

export default class NtopWidget {

    constructor(params) {
        this.widgetId = params.widgetId;
        /* the widget type which indicate the template will be chosen */
        this.widgetType = params.widgetType;
        /* this object contains all the paramters that will be sent to datasource assocaited to the widget */
        this.endpointParams = params.endpointParams;
        /* the dom element container of the widget */
        this.widgetElementDom = params.widgetElementDom;
        /* this boolean indicate if the data fetch has been completed successfully */
        this.widgetInitialized = false;
        /* the widget refresh time to fetch new data from ds */
        this.intervalTime = 0;
        /* this variable will contain the url endpoint to make requests */
        this.widgetEndPoint = this._buildWidgetEndpoint(params.ntopngEndpointUrl);
    }

    async initWidget() {

        try {

            // try to get data from the datasource
            const widgetEndPointResponse = await this.getWidgetData();
            // Datasource Retention: this.intervalTime = widgetEndPointResponse.dsRetention;
            this.widgetFetchedData = widgetEndPointResponse;
        
            this.widgetInitialized = true;
        }
        catch (e) {
            throw new Error(`Something went wrong when fetching widget data: ${e}`);
        }
    }

    async getWidgetData() {
        const response = await this._fetchWidgetData();
        const data = await response.json();
        return await data;
    }

    async renderWidget() {

        if (!this.widgetInitialized) {
            throw new Error('The widget has not been initialzed yet!');
        }

        const selectedType = this.widgetType;
        const widgetTemplate = this._getWidgetTemplate(selectedType);

        this.widgetTemplate = widgetTemplate;
        this.widgetElementDom.appendChild(widgetTemplate.render());
    }

    _getWidgetTemplate(widgetType) {

        const params = { widget: this };

        switch (widgetType) {
            case 'pie':         return new PieChartTemplate(params);
            //case 'table':       return new TableTemplate(params);
            // case 'donut':       return new DonutChartTemplate(params);
            // case 'multibar':    return new MultiBarChartTemplate(params);
            default: throw new Error('The widget type is not valid!');
        }
    }

    _fetchWidgetData() {
        const endpoint = this.widgetEndPoint;
        return fetch(endpoint.toString(), {method: 'POST', body: JSON.stringify(this._serializeParamaters())});
    }

    _buildWidgetEndpoint(ntopngEndpointUrl) {
        return new URL(`/lua/rest/v1/get/widget/data.lua`, ntopngEndpointUrl.toString());
    }

    _serializeParamaters() {

        const payload = {
            datasources: this.endpointParams,
            transformation: this.widgetType,
        };

        return payload;
    }

}