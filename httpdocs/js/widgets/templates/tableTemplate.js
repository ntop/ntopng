export class TableTemplate {
    render(data) {

        const contaiter = document.createElement('div');
        contaiter.classList = 'ntop-widget-container';

        const table = document.createElement('table');
        table.classList = 'table table-bordered';

        // build header
        const trHeader = document.createElement('tr');
        for (let header of data.header) {
            const th = document.createElement('th');
            th.innerText = header;
            trHeader.appendChild(th);
        }
        table.appendChild(trHeader);

        // insert data inside table
        for (let row of data.rows) {

            const thRow = document.createElement('tr');
            for (let data of row) {
                const td = document.createElement('td');
                td.innerText = data;
                thRow.appendChild(td);
            }

            table.appendChild(thRow);
        }

        contaiter.appendChild(table);

        return contaiter;
    }
}
