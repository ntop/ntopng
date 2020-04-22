import WidgetTemplate from "./default-template.js";

export default class TableTemplate extends WidgetTemplate {

    constructor(params) {
        super(params);
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

        // insert data inside table
        for (let row of this._data.rows) {

            const thRow = document.createElement('tr');
            for (let data of row) {
                const td = document.createElement('td');
                td.insertAdjacentText('afterbegin', data);
                thRow.appendChild(td);
            }
            table.appendChild(thRow);
        }

        return super.render().appendChild(table);
    }
}