import NtopWidget from './ntop-widgets.js';


let widgetId = 0;
class NtopWidgetUtils {

    // Right now only 'single-datasources' are implemented
    static async initAllWidgets() {

        /**
         * Build the URL to fetch datasources data
         * @param {string} endpoint 
         */
        const buildWidgetEndpointURL = (endpoint) => {
            return (!endpoint) ? new URL(location.origin) : new URL(endpoint);
        }

        const widgetDomElements = document.querySelectorAll(`.ntop-widget`);

        for (let i = 0; i < widgetDomElements.length; i++) {

            const widgetDomElement = widgetDomElements.item(i);

            const widgetType = widgetDomElement.dataset.ntopWidgetType;
            const widgetParams = widgetDomElement.dataset.ntopWidgetParams;
            const datasourceType = widgetDomElement.dataset.ntopWidgetDatasource;

            const widgetEndpoint = buildWidgetEndpointURL(widgetDomElement.dataset.ntopWidgetEndpoint);
            const { ifid } = JSON.parse(widgetParams);

            const widget = new NtopWidget({
                widgetId: widgetId++,
                widgetElementDom: widgetDomElement,
                ntopngEndpointUrl: widgetEndpoint,
                widgetType: widgetType,
                endpointParams: [
                    {
                        ds_type: datasourceType,
                        params: {ifid: ifid}
                    }
                ]
            });

            /* do a GET request to fetch data for the widget */
            await widget.initWidget();
            /* render the widget inside the document */
            await widget.renderWidget();
        }
    }
}

NtopWidgetUtils.initAllWidgets();