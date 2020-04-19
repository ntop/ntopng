import NtopWidgetTemplate from '../ntopWidgetTemplate.js';
export class TableTemplate extends NtopWidgetTemplate {
    render(data) {
        const table = document.createElement('table');
        table.setAttribute('class', 'table table-bordered');
        const trHeader = document.createElement('tr');
        for (let header of data.header) {
            const th = document.createElement('th');
            th.insertAdjacentText('afterbegin', header);
            trHeader.appendChild(th);
        }
        table.appendChild(trHeader);
        for (let row of data.rows) {
            const thRow = document.createElement('tr');
            for (let data of row) {
                const td = document.createElement('td');
                td.insertAdjacentText('afterbegin', data);
                thRow.appendChild(td);
            }
            table.appendChild(thRow);
        }
        return super.render(data).appendChild(table);
    }
}
