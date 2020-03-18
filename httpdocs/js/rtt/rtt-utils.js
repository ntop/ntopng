$(document).ready(function() {

    let rtt_alert_timeout = null;

    $("#rtt-add-form").on('submit', function(event) {

        event.preventDefault();

        const host = $("#input-add-host").val(), measurement = $("#select-add-measurement").val();

        const threshold = $("#input-add-threshold").val();
        perform_request(make_data_to_send('add', host, threshold, measurement, rtt_csrf));

    });

    $("#rtt-edit-form").on('submit', function(event) {

        event.preventDefault();

        const host = $("#input-edit-host").val(), measurement = $("#select-edit-measurement").val();
        const threshold = $("#input-edit-threshold").val();

        perform_request(make_data_to_send('edit', host, threshold, measurement, rtt_csrf));

    });

    $('#rtt-table').on('click', `a[href='#rtt-delete-modal']`, function(e) {

        const row_data = get_rtt_data($rtt_table, $(this));
        $("#delete-host").html(`<b>${row_data.url}</b>`);
        $(`#rtt-delete-modal span.invalid-feedback`).hide();

        $('#rtt-delete-form').off('submit').on('submit', function(e) {

            e.preventDefault();
            perform_request({
                action: 'delete',
                rtt_url: row_data.url,
                csrf: rtt_csrf
            })
        });


    });

    $('#rtt-table').on('click', `a[href='#rtt-edit-modal']`, function(e) {

        const fill_form = (data) => {

            const DEFAULT_THRESHOLD     = 100;
            const DEFAULT_MEASUREMENT   = "icmp";
            const DEFAULT_HOST          = "";

            // fill input boxes
            $('#input-edit-threshold').val(data.threshold || DEFAULT_THRESHOLD);
            $('#select-edit-measurement').val(data.measurement || DEFAULT_MEASUREMENT);
            $('#input-edit-host').val(data.host || DEFAULT_HOST);
        }

        const data = get_rtt_data($rtt_table, $(this));

        // create a closure for reset button
        $('#btn-reset-defaults').off('click').on('click', function() {
            fill_form(data);
        });

        fill_form(data);
        $(`#rtt-edit-modal span.invalid-feedback`).hide();


    });

    const make_data_to_send = (action, rtt_host, rtt_max, rtt_measure, csrf) => {
        return {
            action: action,
            rtt_host: rtt_host,
            rtt_max: rtt_max,
            measurement: rtt_measure,
            csrf: csrf
        }
    }

    const perform_request = (data_to_send) => {

        const {action} = data_to_send;
        if (action != 'add' && action != 'edit' && action != "delete") {
            console.error("The requested action is not valid!");
            return;
        }

        $(`#rtt-${action}-modal span.invalid-feedback`).hide();
        $('#rtt-alert').hide();
        $(`form#rtt-${action}-modal button[type='submit']`).attr("disabled", "disabled");

        $.post(`${http_prefix}/plugins/edit_rtt_host.lua`, data_to_send)
        .then((data, result, xhr) => {

            // always update the token
            rtt_csrf = data.csrf;
            $(`form#rtt-${action}-modal button[type='submit']`).removeAttr("disabled");

            if (data.success) {

                if (!rtt_alert_timeout) clearTimeout(rtt_alert_timeout);
                rtt_alert_timeout = setTimeout(() => {
                    $('#rtt-alert').fadeOut();
                }, 1000)

                $('#rtt-alert .alert-body').text(data.message);
                $('#rtt-alert').fadeIn();
                $(`#rtt-${action}-modal`).modal('hide');
                $rtt_table.ajax.reload();
                return;
            }

            const error_message = data.error;
            $(`#rtt-${action}-modal span.invalid-feedback`).html(error_message).show();

        })
        .fail((status) => {

        });
    }

    const get_rtt_data = ($rtt_table, $button_caller) => {

        const row_data = $rtt_table.row($button_caller.parent()).data();
        return row_data;
    }

    const $rtt_table = $("#rtt-table").DataTable({
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
            setInterval(() => {
                $rtt_table.ajax.reload()
            }, 15000);
        },
        ajax: {
            url: `${http_prefix}/plugins/get_rtt_hosts.lua`,
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
                        $('#input-add-threshold').val(100);
                        $(`#rtt-add-modal span.invalid-feedback`).hide();
                        $('#rtt-add-modal').modal('show');
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
                data: 'url'
            },
            {
                data: 'chart',
                class: 'text-center',
                render: function(href) {
                    if (href == "" || href == undefined) return "";
                    return `<a href='${href}'><i class='fas fa-chart-area'></i></a>`
                }
            },
            {
                data: 'threshold',
                className: 'text-center'
            },
            {
                data: 'last_mesurement_time',
                className: 'dt-body-right dt-head-center'
            },
            {
                data: 'last_ip',
                className: 'dt-body-right dt-head-center'
            },
            {
                data: 'last_rtt',
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
                        <a class="badge badge-info" data-toggle="modal" href="#rtt-edit-modal">Edit</a>
                        <a class="badge badge-danger" data-toggle="modal" href="#rtt-delete-modal">Delete</a>
                    `;
                }
            }
        ]
    });

    importModalHelper({
        load_config_xhr: (json_conf) => {
          return $.post(http_prefix + "/plugins/import_rtt_config.lua", {
            csrf: import_csrf,
            JSON: json_conf,
          });
        }, reset_csrf: (new_csrf) => {
            import_csrf = new_csrf;
        }
    });
});
