import TableTemplate from './templates/table-template.js';
import PieChartTemplate from './templates/pie-chart-template.js';
import DonutChartTemplate from './templates/donut-chart-template.js';

export default class NtopWidget {

    constructor(params) {
        this.widgetKey = params.widgetKey;
        this.widgetType = params.widgetType;
        this.widgetPostParams = params.widgetPostParams;
        this.widgetElementDom = params.widgetElementDom;
        this.widgetInitialized = false;
        this.widgetEndPoint = this._buildWidgetEndpoint(params.ntopngEndpointUrl);
    }

    async initWidget() {

        try {
            const response = await this._fetchWidgetData();
            const data = await response.json();
            const widgetEndPointResponse = await data;
            this.widgetName = widgetEndPointResponse.widgetName;
            this.widgetType = this.widgetType || widgetEndPointResponse.widgetType;
            this.widgetFetchedData = widgetEndPointResponse.data;
            this.widgetInitialized = true;
        }
        catch (e) {
            console.error(e);
            throw new Error(`Error! Something went wrong when fetching widget data.`);
        }
    }

    async renderWidget() {

        if (!this.widgetInitialized) throw new Error('The widget has not been initialzed yet!');

        const selectedType = this.widgetType;
        const widgetTemplate = this._getWidgetTemplate(selectedType);
        this.widgetTemplate = widgetTemplate;
        this.widgetElementDom.appendChild(widgetTemplate.render());
    }

    _getWidgetTemplate(widgetType) {

        const params = {
            widgetType: this.widgetType,
            widgetKey: this.widgetKey,
            widgetName: this.widgetName,
            data: this.widgetFetchedData
        };

        switch (widgetType) {
            case 'table':   return new TableTemplate(params);
            case 'pie':     return new PieChartTemplate(params);
            case 'donut':   return new DonutChartTemplate(params);
            default: throw new Error('The widget type is not valid!');
        }
    }

    _fetchWidgetData() {
        const endpoint = this.widgetEndPoint;
        const searchParams = new URLSearchParams({
            JSON: JSON.stringify(this._serializeParamaters())
        });
        endpoint.search = searchParams.toString();
        return fetch(endpoint.toString());
    }

    _buildWidgetEndpoint(ntopngEndpointUrl) {
        return new URL(`/lua/widgets/widget.lua`, ntopngEndpointUrl.toString());
    }

    _serializeParamaters() {
        return {
            ifid: this.widgetPostParams.ifid,
            keyIP: this.widgetPostParams.keyIP,
            keyMAC: this.widgetPostParams.keyMAC,
            keyASN: this.widgetPostParams.keyASN,
            widgetKey: this.widgetKey
        }
    }

}