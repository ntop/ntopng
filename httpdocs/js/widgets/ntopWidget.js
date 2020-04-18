var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
import { ChartTemplate } from './templates/chartTemplate.js';
import { TableTemplate } from './templates/tableTemplate.js';
export default class NtopWidget {
    constructor(params) {
        this.widgetKey = params.widgetKey;
        this.widgetType = params.widgetType;
        this.widgetPostParams = params.widgetPostParams;
        this.widgetElementDom = params.widgetElementDom;
        this.widgetEndPoint = this.buildWidgetEndpoint(params.ntopngEndpointUrl);
    }
    initWidget() {
        return __awaiter(this, void 0, void 0, function* () {
            try {
                const response = yield this.fetchWidgetData();
                const data = yield response.json();
                const widgetEndPointResponse = yield data;
                this.widgetName = widgetEndPointResponse.widgetName;
                this.widgetType = this.widgetType || widgetEndPointResponse.widgetType;
                this.widgetFetchedData = widgetEndPointResponse.data;
                console.log(this.widgetFetchedData);
            }
            catch (e) {
                console.error(e);
                throw new Error(`Something went wrong when fetching widget data.`);
            }
        });
    }
    async renderWidget() {
        if (this.widgetFetchedData == null) throw new Error('The widget has not been initialzed yet!');
        const selectedType = this.widgetType;
        const widgetTemplate = this.getWidgetTemplate(selectedType);
        this.widgetTemplate = widgetTemplate;
        this.widgetElementDom.appendChild(widgetTemplate.render(this.widgetFetchedData))
    }
    getWidgetTemplate(widgetType) {
        switch (widgetType) {
            case 'table':
                return new TableTemplate();
            case 'line':
            case 'bar':
            case 'horizontalBar':
            case 'radar':
            case 'doughnut':
            case 'polarArea':
            case 'bubble':
            case 'pie':
            case 'scatter':
                return new ChartTemplate();
            default:
                throw new Error('The widget type is not valid!');
                break;
        }
    }
    fetchWidgetData() {
        const endpoint = this.widgetEndPoint;
        endpoint.search = new URLSearchParams({
            JSON: JSON.stringify(this.serializeParamaters())
        })
        return fetch(endpoint);
    }
    buildWidgetEndpoint(ntopngEndpointUrl) {
        return new URL(`/lua/widgets/widget.lua`, ntopngEndpointUrl.toString());
    }
    serializeParamaters() {
        return {
            ifid: this.widgetPostParams.ifid,
            keyIP: this.widgetPostParams.keyIP,
            keyMAC: this.widgetPostParams.keyMAC,
            keyASN: this.widgetPostParams.keyASN,
            widgetKey: this.widgetKey
        };
    }
}
