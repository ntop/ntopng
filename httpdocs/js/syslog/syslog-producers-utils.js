$(function() {

    let syslog_producers_alert_timeout = null;

    $("#syslog-producers-add-form").on('submit', function(event) {

        event.preventDefault();

        const host = $("#input-add-host").val(), producer = $("#select-add-producer").val();

        perform_request(make_data_to_send('add', host, producer, syslog_producers_csrf));

    });

    $('#syslog-producers-table').on('click', `a[href='#syslog-producers-delete-modal']`, function(e) {

        const row_data = get_syslog_producers_data($syslog_producers_table, $(this));
        $("#delete-host").html(`<b>${row_data.url}</b>`);
        $(`#syslog-producers-delete-modal span.invalid-feedback`).hide();

        $('#syslog-producers-delete-form').off('submit').on('submit', function(e) {

            e.preventDefault();
            perform_request({
                action: 'delete',
                syslog_producer_host: row_data.host,
                syslog_producer: row_data.producer,
                csrf: syslog_producers_csrf
            })
        });


    });

    $('#syslog-producers-table').on('click', `a[href='#syslog-producers-edit-modal']`, function(e) {

        const fill_form = (data) => {

            const DEFAULT_PRODUCER = "";
            const DEFAULT_HOST     = "";

            // fill input boxes
            $('#select-edit-producer').val(data.producer || DEFAULT_PRODUCER);
            $('#input-edit-host').val(data.host || DEFAULT_HOST);
        }

        const data = get_syslog_producers_data($syslog_producers_table, $(this));

        // bind submit to form for edits
        $("#syslog-producers-edit-form").off('submit').on('submit', function(event) {

            event.preventDefault();

            const host = $("#input-edit-host").val(), producer = $("#select-edit-producer").val();
            const data_to_send = {
                action: 'edit',
                syslog_producer_host: host,
                syslog_producer: producer,
                old_syslog_producer_host: data.host,
                old_syslog_producer: data.producer,
                csrf: syslog_producers_csrf
            };

            perform_request(data_to_send);

        });

        // create a closure for reset button
        $('#btn-reset-defaults').off('click').on('click', function() {
            fill_form(data);
        });

        fill_form(data);
        $(`#syslog-producers-edit-modal span.invalid-feedback`).hide();

    });

    const make_data_to_send = (action, syslog_producer_host, syslog_producers_measure, csrf) => {
        return {
            action: action,
            syslog_producer_host: syslog_producer_host,
            syslog_producer: syslog_producers_measure,
            csrf: csrf
        }
    }

    const perform_request = (data_to_send) => {

        const {action} = data_to_send;
        if (action != 'add' && action != 'edit' && action != "delete") {
            console.error("The requested action is not valid!");
            return;
        }

        $(`#syslog-producers-${action}-modal span.invalid-feedback`).hide();
        $('#syslog-producers-alert').hide();
        $(`form#syslog-producers-${action}-modal button[type='submit']`).attr("disabled", "disabled");

        $.post(`${http_prefix}/lua/edit_syslog_producer.lua`, data_to_send)
        .then((data, result, xhr) => {

            $(`form#syslog-producers-${action}-modal button[type='submit']`).removeAttr("disabled");
            $('#syslog-producers-alert').addClass('alert-success').removeClass('alert-danger');

            if (data.success) {

                if (!syslog_producers_alert_timeout) clearTimeout(syslog_producers_alert_timeout);
                syslog_producers_alert_timeout = setTimeout(() => {
                    $('#syslog-producers-alert').fadeOut();
                }, 1000)

                $('#syslog-producers-alert .alert-body').text(data.message);
                $('#syslog-producers-alert').fadeIn();
                $(`#syslog-producers-${action}-modal`).modal('hide');
                $syslog_producers_table.ajax.reload();
                return;
            }

            const error_message = data.error;
            $(`#syslog-producers-${action}-modal span.invalid-feedback`).html(error_message).show();

        })
        .fail((status) => {
            $('#syslog-producers-alert').removeClass('alert-success').addClass('alert-danger');
            $('#syslog-producers-alert .alert-body').text(i18n.expired_csrf);
        });
    }

    const get_syslog_producers_data = ($syslog_producers_table, $button_caller) => {

        const row_data = $syslog_producers_table.row($button_caller.parent()).data();
        return row_data;
    }

    const $syslog_producers_table = $("#syslog-producers-table").DataTable({
        pagingType: 'full_numbers',
        lengthChange: false,
        stateSave: true,
        dom: 'lfBrtip',
        language: {
            info: i18n.showing_x_to_y_rows,
            search: i18n.search,
            infoFiltered: "",
            paginate: {
               previous: '&lt;',
               next: '&gt;',
               first: '«',
               last: '»'
            }
        },
        initComplete: function() {

            if (get_host != "") {
                $syslog_producers_table.search(get_host).draw(true);
                $syslog_producers_table.state.clear();
            }

            setInterval(() => {
                $syslog_producers_table.ajax.reload()
            }, 15000);
        },
        ajax: {
            url: `${http_prefix}/lua/get_syslog_producers.lua`,
            type: 'get',
            dataSrc: ''
        },
        buttons: {
            buttons: [
                {
                    text: '<i class="fas fa-plus"></i>',
                    className: 'btn-link',
                    action: function(e, dt, node, config) {
                        $('#input-add-host').val('');
                        $(`#syslog-producers-add-modal span.invalid-feedback`).hide();
                        $('#syslog-producers-add-modal').modal('show');
                    }
                }
            ],
            dom: {
                button: {
                    className: 'btn btn-link'
                }
            }
        },
        columns: [
            {
                data: 'producer_title'
            },
            {
                data: 'host',
                className: 'dt-body-right dt-head-center'
            },
            {
                targets: -1,
                data: null,
                sortable: false,
                name: 'actions',
                class: 'text-center',
                render: function() {
                    return `
                        <a class="badge bg-info" data-bs-toggle="modal" href="#syslog-producers-edit-modal">${i18n.edit}</a>
                        <a class="badge bg-danger" data-bs-toggle="modal" href="#syslog-producers-delete-modal">${i18n.delete}</a>
                    `;
                }
            }
        ]
    });

});
