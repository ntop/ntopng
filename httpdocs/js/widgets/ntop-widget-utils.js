import NtopWidget from './ntop-widgets.js';

class NtopWidgetUtils {
    static async initAllWidgets() {
        const widgetDomElements = document.querySelectorAll(`[data-ntop-widget-key]`);
        const widgets = [];

        for (let i = 0; i < widgetDomElements.length; i++) {

            const widgetDomElement = widgetDomElements.item(i);

            const key = widgetDomElement.dataset.ntopWidgetKey;
            const type = widgetDomElement.dataset.ntopWidgetType;
            const jsonParams = widgetDomElement.dataset.ntopWidgetParams || "{}";

            const { ifid, keyIP, keyMAC, keyASN, keyMetric } = JSON.parse(jsonParams);

            const widget = new NtopWidget({
                widgetKey: key,
                widgetPostParams: {
                    ifid: ifid,
                    keyIP: keyIP,
                    keyMAC: keyMAC,
                    keyASN: keyASN,
                    keyMetric: keyMetric,
                },
                widgetElementDom: widgetDomElement,
                ntopngEndpointUrl: new URL(`http://localhost:3000`),
                widgetType: type
            });

            await widget.initWidget();
            await widget.renderWidget();
            widgets.push(widget);
        }
    }
}

NtopWidgetUtils.initAllWidgets();