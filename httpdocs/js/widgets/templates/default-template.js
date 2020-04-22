/**
 * Pie Chart, Line Chart, Stacked Chart, Table,
 */

export default class WidgetTemplate {

    constructor(params) {

        if (this.constructor == WidgetTemplate) {
            throw new Error('Cannot instantiate an abstract class!');
        }

        this._defaultOptions = {
            widget: params.widget,
            domId: `ntop-widget-${params.widget.widgetKey}-${params.widget.widgetType}`
        };
        this._data = params.widget.widgetFetchedData || [];
        this._intervalId = 0;
    }

    async _updateData() {
        const response = await this._defaultOptions.widget.getWidgetData();
        return response.data;
    }

    render() {

        const container = document.createElement('div');
        container.setAttribute('class', 'ntop-widget-container');
        container.setAttribute('id', this._defaultOptions.domId);

        if (this._data.length == 0) {
            const emptyContainer = document.createElement('div');
            emptyContainer.classList = "border p-2";
            emptyContainer.innerHTML = `Widget <i>${this._defaultOptions.widget.widgetName}</i>: <b>No data was found.</b>`;
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

    _addGraph() { }

    render() {
        this._checkNVSupport();
        return super.render();
    }
}