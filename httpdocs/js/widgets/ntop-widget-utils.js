import NtopWidget from './ntop-widgets.js';

class NtopWidgetUtils {


    static async initAllWidgets() {

        const buildWidgetEndpointURL = (endpoint) => {
            return (!endpoint) ? new URL(location.origin) : new URL(endpoint);
        }

        const widgetDomElements = document.querySelectorAll(`[data-ntop-widget-key]`);
        const widgets = [];

        for (let i = 0; i < widgetDomElements.length; i++) {

            const widgetDomElement = widgetDomElements.item(i);

            const widgetKey = widgetDomElement.dataset.ntopWidgetKey;
            const widgetType = widgetDomElement.dataset.ntopWidgetType;
            const widgetEndpoint = buildWidgetEndpointURL(widgetDomElement.dataset.ntopWidgetEndpoint);

            const jsonParams = widgetDomElement.dataset.ntopWidgetParams || "{}";
            const { ifid, key, beginTime, endTime } = JSON.parse(jsonParams);

            const widget = new NtopWidget({
                widgetKey: widgetKey,
                widgetElementDom: widgetDomElement,
                ntopngEndpointUrl: widgetEndpoint,
                widgetType: widgetType,
                widgetGetParams: {
                    ifid: ifid,
                    key: key,
                    beginTime: beginTime,
                    endTime: endTime,
                },
            });

            /* do a GET request to fetch data for the widget */
            await widget.initWidget();
            /* render the widget inside the document */
            await widget.renderWidget();

            widgets.push(widget);
        }
    }
}

NtopWidgetUtils.initAllWidgets();