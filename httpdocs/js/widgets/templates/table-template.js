import WidgetTemplate from "./default-template.js";

export default class TableTemplate extends WidgetTemplate {

    constructor(params) {
        super(params);
    }

    _generateBody() {

        const tbody = document.createElement('tbody');
        for (let row of this._data.rows) {
            const thRow = document.createElement('tr');
            for (let data of row) {
                const td = document.createElement('td');
                td.insertAdjacentText('afterbegin', data);
                thRow.appendChild(td);
            }
            tbody.appendChild(thRow);
        }

        return tbody;
    }

    render() {

        const table = document.createElement('table');
        table.setAttribute('class', 'table table-bordered');

        // build header
        const trHeader = document.createElement('tr');
        for (let header of this._data.header) {
            const th = document.createElement('th');
            th.insertAdjacentText('afterbegin', header);
            trHeader.appendChild(th);
        }

        table.appendChild(trHeader);

        const tbody = this._generateBody();
        table.appendChild(tbody);
        if (this._defaultOptions.widget.intervalTime) {

            const self = this;
            this._intervalId = setInterval(async function() {
                self._data = await self._updateData();
                const newBody = self._generateBody();
                // TODO: implement a native js solution
                $(table).find('tbody').empty();
                $(table).append(newBody);
            }, this._defaultOptions.widget.intervalTime);
        }

        return super.render().appendChild(table);
    }
}