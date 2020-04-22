/**
 * Pie Chart, Line Chart, Stacked Chart, Table,
 */

export default class WidgetTemplate {

    constructor(params) {

        if (this.constructor == WidgetTemplate) {
            throw new Error('Cannot instantiate an abstract class!');
        }

        const intervalTime = params.intervalTime || 0;

        this._defaultOptions = {
            intervalTime: intervalTime,
            widgetKey: params.widgetKey,
            widgetName: params.widgetName,
            widgetType: params.widgetType
        };
        this._data = params.data || [];
    }

    render() {
        const container = document.createElement('div');
        container.setAttribute('class', 'ntop-widget-container');
        container.setAttribute('id', `ntop-widget-${this._defaultOptions.widgetKey}-${this._defaultOptions.widgetType}`);

        if (this._data.length == 0) {
            const emptyContainer = document.createElement('div');
            emptyContainer.classList = "border p-2";
            emptyContainer.innerHTML = `Widget <i>${this._defaultOptions.widgetName}</i>: <b>No data was found.</b>`;
            container.appendChild(emptyContainer);
        }

        return container;
    }
}

export class ChartTemplate extends WidgetTemplate {

    constructor(params) {
        super(params);
        this._chart = {};
        this._width = params.width || 400;
        this._height = params.height || 400;
    }

    _checkNVSupport() {
        if (!nv) throw new Error("NVD3 not found! Do you have included in your page?");
    }

    _addGraph() {}
    _updateData() {}

    render() {
        this._checkNVSupport();
        return super.render();
    }
}