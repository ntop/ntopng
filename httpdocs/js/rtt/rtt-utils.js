$(document).ready(function() {

    $("#rtt-edit-form").areYouSure();

    $("#rtt-edit-form").on('click', function(event) {

        event.preventDefault();
        $.post(``, {

        })
        .then((data, result, xhr) => {

        })
        .fail((status) => {

        });
    });

    $('#rtt-table').on('click', `a[href='#rtt-edit-modal']`, function(e) {

        const fill_form = (data) => {

            const DEFAULT_THRESHOLD = 100;
            const DEFAULT_MEASUREMENT = "icmp";
            const DEFAULT_HOST = "";

            // fill input boxes
            $('#threshold').val(data.threshold || DEFAULT_THRESHOLD);
            $('#select-measurement').val(data.measurement || DEFAULT_MEASUREMENT);
            $('#host-input').val(data.host || DEFAULT_HOST);
        }

        const data = get_rtt_data($rtt_table, $(this));
        // create a closure for reset button
        $('#btn-reset-defaults').off('click').on('click', function() {
            fill_form(data);
        });

        fill_form(data);
        $('##rtt-edit-form').removeClass('dirty');

    });

    const get_rtt_data = ($rtt_table, $button_caller) => {

        const row_data = $rtt_table.row($button_caller.parent()).data();
        return row_data;
    }

    const $rtt_table = $("#rtt-table").DataTable({
        pagingType: 'full_numbers',
        lengthChange: false,
        stateSave: true,
        language: {
            paginate: {
               previous: '&lt;',
               next: '&gt;',
               first: '«',
               last: '»'
            }
        },
        ajax: {
            url: `${http_prefix}/plugins/rtt_get_hosts.lua`,
            type: 'get',
            dataSrc: ''
        },
        columns: [
            {
                data: 'url'
            },
            {
                data: 'chart',
                class: 'text-center',
                render: function(href) {
                    return `<a href='${href}'><i class='fas fa-chart-area'></i></a>`
                }
            },
            {
                data: 'threshold'
            },
            {
                data: 'last_mesurement_time'
            },
            {
                data: 'last_ip'
            },
            {
                data: 'last_rtt'
            },
            {
                targets: -1,
                data: null,
                sortable: false,
                name: 'actions',
                class: 'text-center',
                render: function() {
                    return `
                        <a class="badge badge-info" data-toggle="modal" href="#rtt-edit-modal">Edit</a>
                        <a class="badge badge-danger" data-toggle="modal" href="#rtt-delete-modal">Delete</a>
                    `;
                }
            }
        ]
    });

});