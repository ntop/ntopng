import NtopWidget from './ntopWidget.js';
class NtopWidgetsUtils {
    static async initWidgets() {
        const widgetDomElements = document.querySelectorAll(`[data-ntop-widget-key]`);
        const widgets = [];
        for (let i = 0; i < widgetDomElements.length; i++) {
            const widgetDomElement = widgetDomElements.item(i);
            const key = widgetDomElement.dataset.ntopWidgetKey;
            const type = widgetDomElement.dataset.ntopWidgetType;
            const jsonParams = widgetDomElement.dataset.ntopWidgetParams || "{}";
            const { ifid, keyIP, keyMAC, keyASN } = JSON.parse(jsonParams);
            let widget = new NtopWidget({
                widgetKey: key,
                widgetPostParams: {
                    ifid: ifid,
                    keyIP: keyIP,
                    keyMAC: keyMAC,
                    keyASN: keyASN
                },
                widgetElementDom: widgetDomElement,
                ntopngEndpointUrl: new URL(`http://localhost:3000`),
                widgetType: type
            });
            widgets.push(widget);
            await widget.initWidget();
            await widget.renderWidget();
        }
    }
}

NtopWidgetsUtils.initWidgets();