$(document).ready(function() {

    let rtt_alert_timeout = null;

    $("#rtt-add-form").on('submit', function(event) {

        event.preventDefault();

        const host = $("#input-add-host").val(), measurement = $("#select-add-measurement").val();
        const granularity = $("#select-add-granularity").val();
        const threshold = $("#input-add-threshold").val();

        perform_request(make_data_to_send('add', host, threshold, measurement, granularity, rtt_csrf));

    });

    $('#rtt-table').on('click', `a[href='#rtt-delete-modal']`, function(e) {

        const row_data = get_rtt_data($rtt_table, $(this));
        $("#delete-host").html(`<b>${row_data.url}</b>`);
        $(`#rtt-delete-modal span.invalid-feedback`).hide();

        $('#rtt-delete-form').off('submit').on('submit', function(e) {

            e.preventDefault();
            perform_request({
                action: 'delete',
                am_host: row_data.host,
                measurement: row_data.measurement,
                csrf: rtt_csrf
            })
        });


    });

    $('#rtt-table').on('click', `a[href='#rtt-edit-modal']`, function(e) {

        const fill_form = (data) => {

            const DEFAULT_THRESHOLD     = 500;
            const DEFAULT_GRANULARITY   = "min";
            const DEFAULT_MEASUREMENT   = "icmp";
            const DEFAULT_HOST          = "";

            // fill input boxes
            $('#input-edit-threshold').val(data.threshold || DEFAULT_THRESHOLD);
            $('#select-edit-measurement').val(data.measurement || DEFAULT_MEASUREMENT);
            $('#select-edit-granularity').val(data.granularity || DEFAULT_GRANULARITY);
            $('#input-edit-host').val(data.host || DEFAULT_HOST);
            dialogRefreshMeasurement($('#rtt-edit-modal'), data.granularity);
        }

        const data = get_rtt_data($rtt_table, $(this));

        // bind submit to form for edits
        $("#rtt-edit-form").off('submit').on('submit', function(event) {

            event.preventDefault();

            const host = $("#input-edit-host").val(), measurement = $("#select-edit-measurement").val();
            const granularity = $("#select-edit-granularity").val();
            const threshold = $("#input-edit-threshold").val();

            const data_to_send = {
                action: 'edit',
                rtt_max: threshold,
                am_host: host,
                measurement: measurement,
                old_rtt_host: data.host,
                old_measurement: data.measurement,
                granularity: granularity,
                old_granularity: data.granularity,
                csrf: rtt_csrf
            };

            perform_request(data_to_send);

        });

        // create a closure for reset button
        $('#btn-reset-defaults').off('click').on('click', function() {
            fill_form(data);
        });

        fill_form(data);
        $(`#rtt-edit-modal span.invalid-feedback`).hide();

    });

    const dialogRefreshMeasurement = ($dialog, granularity) => {
        const measurement = $dialog.find(".measurement-select").val();

        if(!measurement || !measurements_info[measurement]) return;

        const info = measurements_info[measurement];

        $dialog.find(".measurement-operator").html("&" + (info.operator || "gt") + ";");
        $dialog.find(".measurement-unit").html(info.unit || i18n.msec);

        // Check if host is forced
        const host = $dialog.find(".measurement-host")
        if(info.force_host) {
            host.attr("disabled", "disabled");
            host.val(info.force_host);
        } else {
            host.removeAttr("disabled");
        }

        // Populate the granularities dropdown
        const $granularities = $dialog.find(".measurement-granularity");
        const old_val = $granularities.val();
        let old_val_ok = false;
        $granularities.find('option').remove();

        for(var i=0; i<info.granularities.length; i++) {
            var g_info = info.granularities[i];
            if(g_info.value == old_val)
                old_val_ok = true;

            $granularities.append(`<option value="${g_info.value}">${g_info.title}</option>`);
        }

        if(granularity)
            $granularities.val(granularity);
        else if(old_val_ok)
            $granularities.val(old_val);
    }

    const make_data_to_send = (action, am_host, rtt_max, rtt_measure, granularity, csrf) => {
        return {
            action: action,
            am_host: am_host,
            rtt_max: rtt_max,
            measurement: rtt_measure,
            granularity: granularity,
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

        $.post(`${http_prefix}/plugins/edit_active_monitoring_host.lua`, data_to_send)
        .then((data, result, xhr) => {

            // always update the token
            rtt_csrf = data.csrf;
            $(`form#rtt-${action}-modal button[type='submit']`).removeAttr("disabled");
            $('#rtt-alert').addClass('alert-success').removeClass('alert-danger');

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
            $('#rtt-alert').removeClass('alert-success').addClass('alert-danger');
            $('#rtt-alert .alert-body').text(i18n.expired_csrf);
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

            if (get_host != "") {
                $rtt_table.search(get_host).draw(true);
                $rtt_table.state.clear();
            }

            setInterval(() => {
                $rtt_table.ajax.reload()
            }, 15000);
        },
        ajax: {
            url: `${http_prefix}/plugins/get_active_monitoring_hosts.lua`,
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
                        dialogRefreshMeasurement($('#rtt-add-modal'));
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
                className: 'text-center',
                render: function(data, type, row) {
                    if(row.threshold)
                        return `${row.threshold} ${row.unit}`
                    else
                        return "";
                }
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
                data: 'last_measure',
                className: 'dt-body-right dt-head-center',
                render: function(data, type, row) {
                    if(row.last_measure)
                        return `${row.last_measure} ${row.unit}`
                    else
                        return "";
                }

            },
            {
                targets: -1,
                data: null,
                sortable: false,
                name: 'actions',
                class: 'text-center',
                render: function() {
                    return `
                        <a class="badge badge-info" data-toggle="modal" href="#rtt-edit-modal">${i18n.edit}</a>
                        <a class="badge badge-danger" data-toggle="modal" href="#rtt-delete-modal">${i18n.delete}</a>
                    `;
                }
            }
        ]
    });

    importModalHelper({
        load_config_xhr: (json_conf) => {
          return $.post(http_prefix + "/plugins/import_active_monitoring_config.lua", {
            csrf: import_csrf,
            JSON: json_conf,
          });
        }, reset_csrf: (new_csrf) => {
            import_csrf = new_csrf;
        }
    });

    $("#select-add-measurement").on('change', function(event) {
        dialogRefreshMeasurement($("#rtt-add-modal"));
    });

    $("#select-edit-measurement").on('change', function(event) {
        dialogRefreshMeasurement($("#rtt-edit-modal"));
    });
});
