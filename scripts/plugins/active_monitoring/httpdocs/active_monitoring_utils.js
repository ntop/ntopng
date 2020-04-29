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

    let old_submit_handler = null;

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
        if(old_submit_handler)
            $("#am-edit-form").off('submit', old_submit_handler);

        old_submit_handler = function(event) {
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
        };

        $("#am-edit-form").on('submit', old_submit_handler);

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
                $am_table.ajax.reload(function(data) {
                    updateMeasurementFilter(data);
                });
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

    const create_hours_heatmap = (td, data) => {

        const squareLength = 10, squareHeight = 20;
        const colors = ['#d3d3d3', '#28a745', '#f00', '#ffc107'];
        const $svg = $(td).find('svg');
	    const this_hour = new Date().getHours();

        for (let x = 0; x < 24; x++) {
            const $rect = $(document.createElementNS("http://www.w3.org/2000/svg", "rect"));
            $rect.attr('x', x*(squareLength+2)).attr('y', 0).attr('width', squareLength).attr('height', squareHeight);
            const colorIndex = (data.length > 0) ? data[x] : 0;
            $rect.attr('fill', colors[colorIndex]);
            if (this_hour == x) {
		        $rect.attr('stroke', '#000'); /* Add stroke for the current hour */
	        }
            $svg.append($rect);
        }
    }

    const addFilterDropdown = (title, filters, column_index, filter_id, table_api) => {

        /*
            This example show how to define a filters array:
                [
                    {
                        key: '',
                        label: 'label1',
                        regex: 'http://'
                    }
                ]
        */

        const createEntry = (val, key, callback) => {

            const $entry = $(`<li data-filter-key='${key}' class='dropdown-item pointer'>${val}</li>`);

            $entry.click(function(e) {
                // set active filter title and key
                if ($dropdownTitle.parent().find(`i.fas`).length == 0) {
                    $dropdownTitle.parent().prepend(`<i class='fas fa-filter'></i>`);
                }
                $dropdownTitle.html($entry.html());
                $dropdownTitle.attr(`data-filter-key`, key);
                // remove the active class from the li elements
                $menuContainer.find('li').removeClass(`active`);
                // add active class to current entry
                $entry.addClass(`active`);
                // if there is a callback then invoked it
                if (callback) callback(e);
            });
            return $entry;
        }

        const dropdownId = `${title}-filter-menu`;
        const $dropdownContainer = $(`<div id='${dropdownId}' class='dropdown d-inline'></div>`);
        const $dropdownButton = $(`<button class='btn-link btn dropdown-toggle' data-toggle='dropdown' type='button'></button>`);
        const $dropdownTitle = $(`<span>${title}</span>`);
        $dropdownButton.append($dropdownTitle);

        const $menuContainer = $(`<ul class='dropdown-menu' id='${title}-filter'></ul>`);

        // for each filter defined in filters create a dropdown item <li>
        for (let filter of filters) {

            const $entry = createEntry(filter.label, filter.key, (e) => {
                table_api.column(column_index).search(filter.regex, true).draw(true);
            });
            $menuContainer.append($entry);
        }

        // add all filter
        const $allEntry = createEntry(i18n.all, 'all', (e) => {
            $dropdownTitle.parent().find('i.fas.fa-filter').remove();
            $dropdownTitle.html(`${title}`).removeAttr(`data-filter-key`);
            table_api.columns(column_index).search('').draw(true);
        });

        // append the created dropdown inside
        $(filter_id).prepend($dropdownContainer.append($dropdownButton, $menuContainer.prepend($allEntry)));

    }

    const getMeasurementCount = (data) => {
        // get all the measurements available and their count
        const measurements = {};
        data.forEach((v) => {
            const measurement = v.measurement;
            if (!(measurement in measurements)) {
                measurements[measurement] = 1;
                return;
            }
            measurements[measurement]++;
        });
        return measurements;
    }

    const addMeasurementFilter = (table_api, data) => {

        const measurements = getMeasurementCount(data);

        // build filters for datatable
        const filters = [];
        for (let [measurement, count] of Object.entries(measurements)) {
            filters.push({
                key: measurement,
                label: `${measurements_info[measurement].label} (${count})`,
                regex: `${measurement}\:\/\/`
            });
        }

        // sort the created filters
        filters.sort((a, b) => a.label.localeCompare(b.label));

        const MEASUREMENT_COLUMN_INDEX = 0;
        addFilterDropdown(i18n.measurement, filters, MEASUREMENT_COLUMN_INDEX, "#am-table_filter", table_api);
    }

    const updateMeasurementFilter = (data) => {

        const measurements = getMeasurementCount(data);
        for (let [measurement, count] of Object.entries(measurements)) {
            const label = `${measurements_info[measurement].label} (${count})`;
            $(`[data-filter-key='${measurement}']`).text(label);
        }
    }

    const addAlertedFilter = (table_api) => {

        const filters = [
            {
                key: 'alerted',
                label: i18n.alerted,
                regex: `1`
            },
            {
                key: 'not_alerted',
                label: i18n.not_alerted,
                regex: `0`
            }
        ]

        const ALERTED_COLUMN_INDEX = 8;
        addFilterDropdown(i18n.alert_status, filters, ALERTED_COLUMN_INDEX, "#am-table_filter", table_api);
    }

    const $am_table = $("#am-table").DataTable({
        pagingType: 'full_numbers',
        lengthChange: false,
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
        initComplete: function(settings, data) {

            if (get_host != "") {
                $am_table.search(get_host).draw(true);
                $am_table.state.clear();
            }

            const table = settings.oInstance.api();
            addMeasurementFilter(table, data);
            addAlertedFilter(table);

            setInterval(() => {
                $am_table.ajax.reload(function(data) {
                    updateMeasurementFilter(data);
                });
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
                    if (type === 'display' || type === 'filter') {
                        if (href == "" || href == undefined) return "";
			                if(row.alerted) {
			                    return ` ${href} <i class="fas fa-exclamation-triangle" style="color: #f0ad4e;"></i>`
                            }
                            else {
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
                        return Math.round(row.availability) + " %";
                    }

                    // The raw data must be returned here for sorting
                    return(data);
                }
            },
            {
                data: 'hours',
                className: 'text-center dt-head-center',
                sortable: false,
                render: function(data, type) {
                    if (type == 'display') {
                        return `<svg width='288' height='20' viewBox='0 0 288 20'></svg>`;
                    }
                    return data;
                },
                createdCell: function(td, data) {
                    create_hours_heatmap(td, data);
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
                data: 'alerted',
                visible: false,
                sortable: false,
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

    $("#select-add-measurement").on('change', function(event) {
        dialogRefreshMeasurement($("#am-add-modal"));
    });

    $("#select-edit-measurement").on('change', function(event) {
        dialogRefreshMeasurement($("#am-edit-modal"));
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

    aysHandleModal("#am-edit-modal", "#am-edit-form");
    aysHandleModal("#am-add-modal", "#am-add-form");

});
