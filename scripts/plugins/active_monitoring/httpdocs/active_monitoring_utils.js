$(document).ready(function() {

    let am_alert_timeout = null;

    $("#am-add-form").on('submit', function(event) {

        event.preventDefault();

        const host = $("#input-add-host").val(), measurement = $("#select-add-measurement").val();
        const granularity = $("#select-add-granularity").val();
        const threshold = $("#input-add-threshold").val();

        perform_request(make_data_to_send('add', host, threshold, measurement, granularity, am_csrf));

    });

    $('#am-table').on('click', `a[href='#am-delete-modal']`, function(e) {

        const row_data = get_am_data($am_table, $(this));
        $("#delete-host").html(`<b>${row_data.url}</b>`);
        $(`#am-delete-modal span.invalid-feedback`).hide();

        $('#am-delete-form').off('submit').on('submit', function(e) {

            e.preventDefault();
            perform_request({
                action: 'delete',
                am_host: row_data.host,
                measurement: row_data.measurement,
                csrf: am_csrf
            })
        });


    });

    $('#am-table').on('click', `a[href='#am-edit-modal']`, function(e) {

        const fill_form = (data) => {

            const DEFAULT_THRESHOLD     = 500;
            const DEFAULT_GRANULARITY   = "min";
            const DEFAULT_MEASUREMENT   = "icmp";
            const DEFAULT_HOST          = "";

            const cur_measurement = data.measurement || DEFAULT_MEASUREMENT;
            const $dialog = $('#am-edit-modal');
            dialogDisableUniqueMeasurements($dialog, cur_measurement);
            // fill input boxes
            $('#input-edit-threshold').val(data.threshold || DEFAULT_THRESHOLD);
            $('#select-edit-measurement').val(cur_measurement);
            $('#select-edit-granularity').val(data.granularity || DEFAULT_GRANULARITY);
            $('#input-edit-host').val(data.host || DEFAULT_HOST);
            dialogRefreshMeasurement($dialog, data.granularity);
        }

        const data = get_am_data($am_table, $(this));

        // bind submit to form for edits
        $("#am-edit-form").off('submit').on('submit', function(event) {

            event.preventDefault();

            const host = $("#input-edit-host").val(), measurement = $("#select-edit-measurement").val();
            const granularity = $("#select-edit-granularity").val();
            const threshold = $("#input-edit-threshold").val();

            const data_to_send = {
                action: 'edit',
                threshold: threshold,
                am_host: host,
                measurement: measurement,
                old_am_host: data.host,
                old_measurement: data.measurement,
                granularity: granularity,
                old_granularity: data.granularity,
                csrf: am_csrf
            };

            perform_request(data_to_send);

        });

        // create a closure for reset button
        $('#btn-reset-defaults').off('click').on('click', function() {
            fill_form(data);
        });

        fill_form(data);
        $(`#am-edit-modal span.invalid-feedback`).hide();

    });

    // Disable the already defined measurements for forced_hosts since
    // they are unique
    const dialogDisableUniqueMeasurements = ($dialog, cur_measurement) => {
        const $m_sel = $dialog.find(".measurement-select");
        const measurements_to_skip = {};

        // find out wich unique measurements are already defined
        $am_table.rows().data().each(function(row_data) {
            var m_info = measurements_info[row_data.measurement];

            if(m_info && m_info.force_host)
                measurements_to_skip[row_data.measurement] = true;
        });

        // Populate the measurements dropdown
        $m_sel.find('option').remove();
        var sorted_measurements = $.map(measurements_info, (v,k) => {return(k)}).sort();

        for(var i=0; i<sorted_measurements.length; i++) {
            var k = sorted_measurements[i];
            var m_info = measurements_info[k];

            if((k == cur_measurement) || !measurements_to_skip[k])
                $m_sel.append(`<option value="${k}">${m_info.label}</option>`);
        }
    }

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

        for(let i=0; i<info.granularities.length; i++) {
            let g_info = info.granularities[i];
            if(g_info.value == old_val)
                old_val_ok = true;

            $granularities.append(`<option value="${g_info.value}">${g_info.title}</option>`);
        }

        if(granularity)
            $granularities.val(granularity);
        else if(old_val_ok)
            $granularities.val(old_val);
    }

    const make_data_to_send = (action, am_host, threshold, am_measure, granularity, csrf) => {
        return {
            action: action,
            am_host: am_host,
            threshold: threshold,
            measurement: am_measure,
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

        $(`#am-${action}-modal span.invalid-feedback`).hide();
        $('#am-alert').hide();
        $(`form#am-${action}-modal button[type='submit']`).attr("disabled", "disabled");

        $.post(`${http_prefix}/plugins/edit_active_monitoring_host.lua`, data_to_send)
        .then((data, result, xhr) => {

            // always update the token
            am_csrf = data.csrf;
            $(`form#am-${action}-modal button[type='submit']`).removeAttr("disabled");
            $('#am-alert').addClass('alert-success').removeClass('alert-danger');

            if (data.success) {
                if (!am_alert_timeout) clearTimeout(am_alert_timeout);
                am_alert_timeout = setTimeout(() => {
                    $('#am-alert').fadeOut();
                }, 1000)

                $('#am-alert .alert-body').text(data.message);
                $('#am-alert').fadeIn();
                $(`#am-${action}-modal`).modal('hide');
                $am_table.ajax.reload();
                return;
            }

            const error_message = data.error;
            $(`#am-${action}-modal span.invalid-feedback`).html(error_message).show();
        })
        .fail((status) => {
            $('#am-alert').removeClass('alert-success').addClass('alert-danger');
            $('#am-alert .alert-body').text(i18n.expired_csrf);
        });
    }

    const get_am_data = ($am_table, $button_caller) => {

        const row_data = $am_table.row($button_caller.parent()).data();
        return row_data;
    }

    const $am_table = $("#am-table").DataTable({
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
                $am_table.search(get_host).draw(true);
                $am_table.state.clear();
            }

            setInterval(() => {
                $am_table.ajax.reload()
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
                        const $dialog = $('#am-add-modal');
                        dialogDisableUniqueMeasurements($dialog);

                        // select the first non-disabled option (after dialogDisableUniqueMeasurements)
                        $("#select-add-measurement").val($("#select-add-measurement").find("option:not([disabled]):first").val());

                        $('#input-add-host').val('');
                        $('#input-add-threshold').val(100);
                        $(`#am-add-modal span.invalid-feedback`).hide();
                        $('#am-add-modal').modal('show');
                        dialogRefreshMeasurement($dialog);
                    }
                }
            ],
            dom: {
                button: {
                    className: 'btn btn-link'
                },
                container: {
                    className: 'float-right'
                }
            }
        },
        columns: [
            {
                data: 'url',
		
		render: function(href, type, row) {
                    if(type === 'display' || type === 'filter') {
                        if (href == "" || href == undefined) return "";

			if(row.alerted) {
			    return ` ${href} <i class="fas fa-exclamation-triangle" style="color: #f0ad4e;"></i>`
			} else {
                            return `${href}`
			}
                    }
		    
                    // The raw data must be returned here for sorting
                    return(href);
                }
            },
            {
                data: 'chart',
                class: 'text-center',
                sortable: false,
                render: function(href, type, row) {
                    if(type === 'display' || type === 'filter') {
                        if (href == "" || href == undefined) return "";
                        return `<a href='${href}'><i class='fas fa-chart-area'></i></a>`
                    }

                    // The raw data must be returned here for sorting
                    return(href);
                }
            },
            {
                data: 'threshold',
                className: 'text-center',
                render: function(data, type, row) {
                    if(type === 'display' || type === 'filter') {
                        if(row.threshold)
                            return `${row.threshold} ${row.unit}`
                        else
                            return "";
                    }

                    // The raw data must be returned here for sorting
                    return(data);
                }
            },
            {
                data: 'availability',
                className: 'text-center',
                render: function(data, type, row) {
                    if(type === 'display' || type === 'filter') {
                        if(row.availability != "")
                            return Math.round(row.availability) + "%";
                        else
                            return "";
                    }

                    // The raw data must be returned here for sorting
                    return(data);
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
                sortable: false,
                render: function(data, type, row) {
                    if(type === 'display' || type === 'filter') {
                        if(row.last_measure)
                            return `${row.last_measure} ${row.unit}`
                        else
                            return "";
                    }

                    // The raw data must be returned here for sorting
                    return(data);
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
                        <a class="badge badge-info" data-toggle="modal" href="#am-edit-modal">${i18n.edit}</a>
                        <a class="badge badge-danger" data-toggle="modal" href="#am-delete-modal">${i18n.delete}</a>
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
        dialogRefreshMeasurement($("#am-add-modal"));
    });

    $("#select-edit-measurement").on('change', function(event) {
        dialogRefreshMeasurement($("#am-edit-modal"));
    });
});
