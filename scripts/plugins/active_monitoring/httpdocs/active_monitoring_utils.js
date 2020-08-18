$(document).ready(function() {

    const POOL_COLUMN_INDEX = 8;
    let row_data = null;

    const getMeasurementRegex = (measurement) => {

        switch (measurement) {
            default:
            case "http":
            case "https":
            case "icmp":
            case "cicmp":
                return `${NtopUtils.REGEXES["ipv4"]}|${NtopUtils.REGEXES["domainName"]}`
            case "cicmp6":
            case "icmp6":
                return `${NtopUtils.REGEXES["ipv6"]}|${NtopUtils.REGEXES["domainName"]}`
        }
    }

    const addPoolFilter = (tableAPI) => {
        DataTableUtils.addFilterDropdown(
            i18n.pools, poolsFilter, POOL_COLUMN_INDEX, '#am-table_filter', tableAPI
        );
    }

    const $removeModalHandler = $(`#am-delete-modal form`).modalHandler({
        method: 'post',
        csrf: am_csrf,
        endpoint: `${http_prefix}/plugins/edit_active_monitoring_host.lua`,
        dontDisableSubmit: true,
        onModalInit: function() {
            $("#delete-host").html(`<b>${row_data.url}</b>`);
        },
        beforeSumbit: () => {
            return {
                action: 'delete',
                am_host: row_data.host,
                measurement: row_data.measurement,
                csrf: am_csrf
            }
        },
        onSubmitSuccess: function (response) {
            if (response.success) {
                $(`#am-delete-modal`).modal('hide');
                AlertNotificationUtils.showAlert({
                    title: i18n.success,
                    body: response.message,
                    level: 'success',
                    delay: 3000,
                    id: 'am-delete'
                });
                $am_table.ajax.reload();
            }
        }
    });

    $('#am-table').on('click', `a[href='#am-delete-modal']`, function(e) {
        row_data = get_am_data($am_table, $(this));
        $removeModalHandler.invokeModalInit();
    });

    let edit_host_data = null;

    $("#select-edit-measurement").on('change', function(event) {
        const selected_measurement = $(this).val();
        // change the pattern depending on the selected measurement
        $(`#input-edit-host`).attr('pattern', getMeasurementRegex(selected_measurement));

        dialogRefreshMeasurement($("#am-edit-modal"));
    });

    const $editModalHandler = $(`#am-edit-form`).modalHandler({
        method: 'post',
        endpoint: `${http_prefix}/plugins/edit_active_monitoring_host.lua`,
        csrf: am_csrf,
        onModalInit: function () {
            const DEFAULT_THRESHOLD     = 500;
            const DEFAULT_GRANULARITY   = "min";
            const DEFAULT_MEASUREMENT   = "icmp";
            const DEFAULT_HOST          = "";
            const DEFAULT_POOL          = 0;

            const cur_measurement = edit_host_data.measurement || DEFAULT_MEASUREMENT;
            const $dialog = $('#am-edit-modal');
            dialogDisableUniqueMeasurements($dialog, cur_measurement);
            // fill input boxes
            $('#input-edit-threshold').val(edit_host_data.threshold || DEFAULT_THRESHOLD);
            $('#select-edit-measurement').val(cur_measurement);
            $('#select-edit-granularity').val(edit_host_data.granularity || DEFAULT_GRANULARITY);
            $('#input-edit-host').val(edit_host_data.host || DEFAULT_HOST);
            $(`#select-edit-pool`).val(edit_host_data.pool || DEFAULT_POOL);
            dialogRefreshMeasurement($dialog, edit_host_data.granularity);
        },
        beforeSumbit: function () {

            const host = $("#input-edit-host").val(), measurement = $("#select-edit-measurement").val();
            const granularity = $("#select-edit-granularity").val();
            const threshold = $("#input-edit-threshold").val();
            const pool = $(`#select-edit-pool`).val();

            return {
                action: 'edit',
                threshold: threshold,
                am_host: host,
                measurement: measurement,
                old_am_host: edit_host_data.host,
                old_measurement: edit_host_data.measurement,
                granularity: granularity,
                old_granularity: edit_host_data.granularity,
                pool: pool
            };
        },
        onSubmitSuccess: function (response) {
            if (response.success) {

                AlertNotificationUtils.showAlert({
                    title: i18n.success,
                    body: response.message,
                    level: 'success',
                    delay: 3000,
                    id: 'am-edit'
                });

                $(`#am-edit-modal`).modal('hide');
                $am_table.ajax.reload(function(data) {
                    updateMeasurementFilter(data);
                });
            }
        }
    });

    $('#am-table').on('click', `a[href='#am-edit-modal']`, function(e) {
        edit_host_data = get_am_data($am_table, $(this));
        $editModalHandler.invokeModalInit();
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

    /* Called whenever the measurment of a dialog changes/is initialized. */
    const dialogRefreshMeasurement = ($dialog, granularity, use_defaults) => {
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

        const $threshold = $dialog.find(".measurement-threshold");

        if(info.max_threshold)
            $threshold.attr("max", info.max_threshold);
        else
            $threshold.removeAttr("max");

        if(use_defaults && info.default_threshold)
            $threshold.val(info.default_threshold);

        if(granularity)
            $granularities.val(granularity);
        else if(old_val_ok)
            $granularities.val(old_val);
    }

    const get_am_data = ($am_table, $button_caller) => {

        const row_data = $am_table.row($button_caller.parent().parent()).data();
        return row_data;
    }

    const create_hours_heatmap = (td, data) => {
        const squareLength = 7, squareHeight = 20;
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
                table_api.column(column_index).search(filter.regex, true, false).draw();
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
                regex: `^(${measurement}://).+`
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

    const countAlertedHosts = (data) => {

        const alertedCounts = { alerted: 0, not_alerted: 0 };
        data.forEach((row) => {
            if (row.alerted) {
                alertedCounts.alerted++;
            }
            else {
                alertedCounts.not_alerted++;
            }
        });
        return alertedCounts;
    }

    const updateAlertFilter = (data) => {

        const count = countAlertedHosts(data);
        for (const [key, value] of Object.entries(count)) {
            const label = `${i18n[key]} (${value})`;
            $(`[data-filter-key='${key}']`).text(label);
        }
    }

    const addAlertedFilter = (table_api, data) => {
        const count = countAlertedHosts(data);

        const filters = [
            {
                key: 'alerted',
                label: `${i18n.alerted} (${count.alerted})`,
                regex: `1`
            },
            {
                key: 'not_alerted',
                label: `${i18n.not_alerted} (${count.not_alerted})`,
                regex: `0`
            }
        ]

        const ALERTED_COLUMN_INDEX = 7;
        addFilterDropdown(i18n.alert_status, filters, ALERTED_COLUMN_INDEX, "#am-table_filter", table_api);
    }

    // select the first pattern based to the first selected measurement
    // on the input-add-host
    $(`#input-add-host`).attr('pattern', getMeasurementRegex($("#select-add-measurement").val()));

    $("#select-add-measurement").on('change', function(event) {

        const selected_measurement = $(this).val();
        // change the pattern depending on the selected measurement
        $(`#input-add-host`).attr('pattern', getMeasurementRegex(selected_measurement));

        dialogRefreshMeasurement($("#am-add-modal"));
    });

    const add_host_modal = $(`#am-add-form`).modalHandler({
        method: 'post',
        endpoint: `${http_prefix}/plugins/edit_active_monitoring_host.lua`,
        csrf: am_csrf,
        onModalInit: function () {
            const $dialog = $('#am-add-modal');
            dialogDisableUniqueMeasurements($dialog);

            // select the first non-disabled option (after dialogDisableUniqueMeasurements)
            $("#select-add-measurement").val($("#select-add-measurement").find("option:not([disabled]):first").val());

            $('#input-add-host').val('');
            $('#input-add-threshold').val(100);
            $(`#am-add-modal span.invalid-feedback`).hide();
            $('#am-add-modal').modal('show');
            dialogRefreshMeasurement($dialog, null, true /* use defaults */);
        },
        beforeSumbit: function () {
            const host = $("#input-add-host").val(), measurement = $("#select-add-measurement").val();
            const granularity = $("#select-add-granularity").val();
            const threshold = $("#input-add-threshold").val();
            const pool = $(`#select-add-pool`).val();

            return {
                action: 'add',
                am_host: host,
                threshold: threshold,
                measurement: measurement,
                granularity: granularity,
                pool: pool
            }
        },
        onSubmitSuccess: function (response) {
            if (response.success) {

                AlertNotificationUtils.showAlert({
                    title: i18n.success,
                    body: response.message,
                    level: 'success',
                    delay: 3000,
                    id: 'am-add'
                });

                $(`#am-add-modal`).modal('hide');
                $am_table.ajax.reload(function(data) {
                    updateMeasurementFilter(data);
                });
            }
        }
    });

    let dt_config = DataTableUtils.getStdDatatableConfig( [
        {
            text: '<i class="fas fa-plus"></i>',
            className: 'btn-link',
            action: function(e, dt, node, config) {
                add_host_modal.invokeModalInit();
            }
        }
    ]);
    dt_config = DataTableUtils.setAjaxConfig(
        dt_config,
        `${http_prefix}/plugins/get_active_monitoring_hosts.lua`,
    );
    dt_config = DataTableUtils.extendConfig(dt_config, {
        initComplete: function(settings, data) {

            if (get_host != "") {
                $am_table.search(get_host).draw(true);
                $am_table.state.clear();
            }

            const table = settings.oInstance.api();
            addMeasurementFilter(table, data);
            addAlertedFilter(table, data);
            addPoolFilter(table);

            setInterval(() => {
                $am_table.ajax.reload(function(data) {
                    updateMeasurementFilter(data);
                    updateAlertFilter(data);
                });
            }, 15000);
        },
        columns: [
            {
                data: 'url',
		        render: function(href, type, row) {
                    if (type === 'display') {
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
                data: 'hours',
                className: 'text-center dt-head-center',
                sortable: false,
                render: function(data, type) {
                    if (type == 'display') {
                        return `<svg width='220' height='20' viewBox='0 0 220 20'></svg>`;
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
                data: 'pool',
                visible: false,
                sortable: false
            },
            {
                data: 'jitter',
                className: 'dt-body-right dt-head-center',
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
                        <div class="btn-group btn-group-sm">
                            <a class="btn btn-info" data-toggle="modal" href="#am-edit-modal">
                                <i class='fas fa-edit'></i>
                            </a>
                            <a class="btn btn-danger" data-toggle="modal" href="#am-delete-modal">
                                <i class='fas fa-trash'></i>
                            </a>
                        </div>
                    `;
                }
            }
        ]
    });

    const $am_table = $("#am-table").DataTable(dt_config);

    NtopUtils.importModalHelper({
        load_config_xhr: (json_conf) => {
          return $.post(http_prefix + "/plugins/import_active_monitoring_config.lua", {
            csrf: import_csrf,
            JSON: json_conf,
          });
        }, reset_csrf: (new_csrf) => {
            import_csrf = new_csrf;
        }
    });
});
