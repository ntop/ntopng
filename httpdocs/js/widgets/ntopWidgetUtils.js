var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
import NtopWidget from './ntopWidget.js';
class NtopWidgetsUtils {
    static initWidgets() {
        return __awaiter(this, void 0, void 0, function* () {
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
                yield widget.initWidget();
                yield widget.renderWidget();
                widgets.push(widget);
            }
        });
    }
}
NtopWidgetsUtils.initWidgets();