$(document).ready(function() {

    const MAX_RECIPIENTS = 3;
    const DEFAULT_MEASUREMENT = "cicmp";
    const INFRASTRUCTURE_ENDPOINT = "/lua/rest/v1/get/system/data.lua";

    const getMeasurementRegex = (measurement) => {
        switch (measurement) {
            default:
            case "http":
            case "https":
                return `${NtopUtils.REGEXES["ipv4WithPort"]}|${NtopUtils.REGEXES["domainNameWithPort"]}`;
            case "icmp":
            case "cicmp":
                return `${NtopUtils.REGEXES["ipv4"]}|${NtopUtils.REGEXES["domainName"]}`
            case "cicmp6":
            case "icmp6":
                return `${NtopUtils.REGEXES["ipv6"]}|${NtopUtils.REGEXES["domainName"]}`
        }
    }

    const addPoolFilter = (tableAPI) => {

        const POOL_COLUMN_INDEX = 8;

        return new DataTableFiltersMenu({
            filterTitle: i18n.pools,
            tableAPI: tableAPI,
            filters: poolsFilter,
            filterMenuKey: 'pools',
            columnIndex: POOL_COLUMN_INDEX
        });
    }

    const addMeasurementFilter = (tableAPI) => {

        const MEASUREMENT_COLUMN_INDEX = 0;

        // build filters for datatable
        const measurements = Object.keys(measurements_info);
        const filters = [];

        for (const measurement of measurements) {
            filters.push({
                key: measurement,
                label: `${measurements_info[measurement].label}`,
                regex: `^(${measurement}://).+`
            });
        }

        // sort the created filters
        filters.sort((a, b) => a.label.localeCompare(b.label));

        return new DataTableFiltersMenu({
            filterTitle: i18n.measurement,
            tableAPI: tableAPI,
            filters: filters,
            filterMenuKey: 'measurement',
            columnIndex: MEASUREMENT_COLUMN_INDEX
        });
    }

    const addAlertedFilter = (tableAPI) => {

        const ALERTED_COLUMN_INDEX = 7;
        const filters = [
            {
                key: 'alerted',
                label: `${i18n.alerted}`,
                regex: `1`
            },
            {
                key: 'not_alerted',
                label: `${i18n.not_alerted}`,
                regex: `0`
            }
        ];

        return new DataTableFiltersMenu({
            filterTitle: i18n.alert_status,
            tableAPI: tableAPI,
            filters: filters,
            filterMenuKey: 'alert-status',
            columnIndex: ALERTED_COLUMN_INDEX
        });
    }

    // Disable the already defined measurements for forced_hosts since
    // they are unique
    const dialogDisableUniqueMeasurements = ($dialog, cur_measurement) => {
        const $m_sel = $dialog.find(".measurement-select");
        const measurements_to_skip = {};

        // find out wich unique measurements are already defined
        $amTable.rows().data().each(function(row_data) {
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

    const dialogRefreshPeriodicity = ($modal) => {

        const $periodicityGroup = $modal.find(`[name='granularity']`).parents('.form-group');
        const selectedMeasurement = $modal.find(".measurement-select").val();
        if (!selectedMeasurement || !measurements_info[selectedMeasurement]) return;
        const measurement = measurements_info[selectedMeasurement];

        if (measurement.granularities.length == 1) {
            $periodicityGroup.hide();
        }
        else {
            $periodicityGroup.show();
        }

    }

    const getAmData = ($am_table, $button_caller) => {

        const row_data = $am_table.row($button_caller.parent().parent()).data();
        return row_data;
    }

    const createHoursHeatmap = (td, data) => {
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

    const $addHostModalHandler = $(`#am-add-form`).modalHandler({
        method: 'post',
        endpoint: `${http_prefix}/plugins/edit_active_monitoring_host.lua`,
        resetAfterSubmit: false,
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

            // set the edit pool link
            const $editPoolLink = $('#am-add-form .edit-pool');
            $editPoolLink.attr('href', NtopUtils.getEditPoolLink($editPoolLink.attr('href'), 0));

            $(`#am-add-form select[name='pool']`).trigger('change');

            dialogRefreshMeasurement($dialog, null, true /* use defaults */);
            dialogRefreshPeriodicity($dialog);
        },
        beforeSumbit: function () {
            const host = $("#input-add-host").val(), measurement = $("#select-add-measurement").val();
            const granularity = $("#select-add-granularity").val();
            const threshold = $("#input-add-threshold").val();
            const pool = $(`#select-add-pool`).val();

            $(`#add-invalid-feedback`).hide();

            return {
                action: 'add',
                am_host: host,
                threshold: threshold,
                measurement: measurement,
                granularity: granularity,
                pool: pool
            }
        },
        onSubmitSuccess: function (response, dataSent) {
            if (response.success) {

                ToastUtils.showToast({
                    title: i18n.success,
                    body: response.message,
                    level: 'success',
                    delay: 3000,
                    id: `am-add-${dataSent.am_host}`
                });

                $(`#am-add-modal`).modal('hide');
                $amTable.ajax.reload();
                return;
            }

            $(`#add-invalid-feedback`).show().text(response.error);
        }
    });

    const $editModalHandler = $(`#am-edit-form`).modalHandler({
        method: 'post',
        endpoint: `${http_prefix}/plugins/edit_active_monitoring_host.lua`,
        csrf: am_csrf,
        onModalInit: function (amData) {
            const DEFAULT_THRESHOLD     = 500;
            const DEFAULT_GRANULARITY   = "min";
            const DEFAULT_MEASUREMENT   = "icmp";
            const DEFAULT_HOST          = "";
            const DEFAULT_POOL          = 0;

            const cur_measurement = amData.measurement || DEFAULT_MEASUREMENT;
            const $dialog = $('#am-edit-modal');
            dialogDisableUniqueMeasurements($dialog, cur_measurement);
            // fill input boxes
            $('#input-edit-threshold').val(amData.threshold || DEFAULT_THRESHOLD);
            $('#select-edit-measurement').val(cur_measurement);
            $('#select-edit-granularity').val(amData.granularity || DEFAULT_GRANULARITY);
            $('#input-edit-host').val(amData.host || DEFAULT_HOST);
            $(`#select-edit-pool`).val(amData.pool || DEFAULT_POOL);

            // set the edit pool link
            const $editPoolLink = $('#am-add-form .edit-pool');
            $editPoolLink.attr('href', NtopUtils.getEditPoolLink($editPoolLink.attr('href'), amData.pool || DEFAULT_POOL));
            $(`#am-edit-form select[name='pool']`).trigger('change');

            dialogRefreshMeasurement($dialog, amData.granularity);
            dialogRefreshPeriodicity($dialog);
        },
        beforeSumbit: function (amData) {

            const host = $("#input-edit-host").val(), measurement = $("#select-edit-measurement").val();
            const granularity = $("#select-edit-granularity").val();
            const threshold = $("#input-edit-threshold").val();
            const pool = $(`#select-edit-pool`).val();

            return {
                action: 'edit',
                threshold: threshold,
                am_host: host,
                measurement: measurement,
                old_am_host: amData.host,
                old_measurement: amData.measurement,
                granularity: granularity,
                old_granularity: amData.granularity,
                pool: pool
            };
        },
        onSubmitSuccess: function (response, dataSent) {
            if (response.success) {

                ToastUtils.showToast({
                    title: i18n.success,
                    body: response.message,
                    level: 'success',
                    delay: 3000,
                    id: `am-edit-${dataSent.am_host}`
                });

                $(`#am-edit-modal`).modal('hide');
                $amTable.ajax.reload();

                return;
            }
        }
    });

    const $removeModalHandler = $(`#am-delete-modal form`).modalHandler({
        method: 'post',
        csrf: am_csrf,
        endpoint: `${http_prefix}/plugins/edit_active_monitoring_host.lua`,
        dontDisableSubmit: true,
        onModalInit: function(amData) {
            $("#delete-host").html(`<b>${amData.url}</b>`);
        },
        beforeSumbit: (amData) => {
            return {
                action: 'delete',
                am_host: amData.host,
                measurement: amData.measurement,
                csrf: am_csrf
            }
        },
        onSubmitSuccess: function (response, dataSent) {
            if (response.success) {
                $(`#am-delete-modal`).modal('hide');
                ToastUtils.showToast({
                    title: i18n.success,
                    body: response.message,
                    level: 'success',
                    delay: 3000,
                    id: `am-delete-${dataSent.am_host}`
                });
                $amTable.ajax.reload();
            }
        }
    });

    let dtConfig = DataTableUtils.getStdDatatableConfig( [
        {
            text: '<i class="fas fa-plus"></i>',
            className: 'btn-link',
            enabled: (get_host === ""),
            action: function(e, dt, node, config) {
                $addHostModalHandler.invokeModalInit();
            }
        },
        {
            text: '<i class="fas fa-sync-alt"></i>',
            className: 'btn-link',
            action: function(e, dt, node, config) {
                $amTable.ajax.reload();
            }
        }
    ], );
    dtConfig = DataTableUtils.setAjaxConfig(dtConfig, `${http_prefix}/plugins/get_active_monitoring_hosts.lua`);
    dtConfig = DataTableUtils.extendConfig(dtConfig, {
        lengthChange: (get_host === ""),
        paging: (get_host === ""),
        initComplete: function(settings, data) {

            if (get_host != "") {
                $amTable.search(get_host).draw(true);
                $amTable.state.clear();
            }

            const table = settings.oInstance.api();
            setInterval(() => { $amTable.ajax.reload(); }, 15000);
        },
        columns: [
            {
                data: 'html_label',
		        render: function(html_label, type, row) {
                    
                    if (type === 'display') {
                        if (html_label == "" || html_label == undefined) return "";

			                if(row.alerted) {
			                    return `${html_label} <i class="fas fa-exclamation-triangle" style="color: #f0ad4e;"></i>`
                            }
                           
                            return html_label;
                    }

                    return (row.label);
                }
            },
            {
                data: 'chart',
                class: 'text-center',
                sortable: false,
                 render: function(href, type, row) {
                    if(type === 'display') {
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
                    createHoursHeatmap(td, data);
                }
            },
            {
                data: 'last_mesurement_time',
                className: 'text-center'
            },
            {
                data: 'last_ip',
                className: 'dt-body-right dt-head-center'
            },
            {
                data: 'last_measure',
                className: 'text-center',
                sortable: false,
                render: function(data, type, row) {
                    if(type === 'display' || type === 'filter') {
                        if (row.last_measure)
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
                render: function(_, type, host) {

                    const disabled = (host.readonly) ? 'disabled' : '';

                    return DataTableUtils.createActionButtons([
                        { class: `btn-info ${disabled}`, icon: 'fa-edit', modal: '#am-edit-modal', },
                        { class: `btn-danger ${disabled}`, icon: 'fa-trash', modal: '#am-delete-modal', }
                    ]);
                }
            }
        ]
    });

    const $amTable = $("#am-table").DataTable(dtConfig);
    addMeasurementFilter($amTable);
    addAlertedFilter($amTable);

    $('#am-table').on('click', `a[href='#am-edit-modal']`, function(e) {
        const amData = getAmData($amTable, $(this));
        $editModalHandler.invokeModalInit(amData);
    });

    $('#am-table').on('click', `a[href='#am-delete-modal']`, function(e) {
        const amData = getAmData($amTable, $(this));
        $removeModalHandler.invokeModalInit(amData);
    });

    $("#select-edit-measurement").on('change', function(event) {
        const selectedMeasurement = $(this).val();
        // change the pattern depending on the selected measurement
        $(`#input-edit-host`).attr('pattern', getMeasurementRegex(selectedMeasurement));
        // trigger form validation
        if ($(`#input-edit-host`).val().length > 0) $(`#am-edit-form`)[0].reportValidity();

        dialogRefreshMeasurement($("#am-edit-modal"));
        dialogRefreshPeriodicity($("#am-edit-modal"));
    });

    // select the first pattern based to the first selected measurement
    // on the input-add-host
    $(`#input-add-host`).attr('pattern', getMeasurementRegex($("#select-add-measurement").val()));

    $("#select-add-measurement").on('change', function(event) {

        const selectedMeasurement = $(this).val();

        // change the pattern depending on the selected measurement
        $(`#input-add-host`).attr('pattern', getMeasurementRegex(selectedMeasurement));
        // trigger form validation
        if ($(`#input-add-host`).val().length > 0) $(`#am-add-form`)[0].reportValidity();

        dialogRefreshMeasurement($("#am-add-modal"));
        dialogRefreshPeriodicity($("#am-add-modal"));
    });

    // on changing the associated pool updates the link to the edit pool
    $(`select[name='pool']`).change(async function() {

        const poolId = $(this).val();
        const $editPoolLink = $(this).parents('.form-group').find('.edit-pool');
        const $recipientsInfo = $(this).parents('.form-group').find('.recipients-info')

        $editPoolLink.attr('href', NtopUtils.getEditPoolLink($editPoolLink.attr('href'), poolId));

        const [success, pool] = await NtopUtils.getPool('active_monitoring', poolId);
        if (!success) return;

        let recipients = pool.recipients;

        if (recipients.length == 0) {
            $recipientsInfo.html(i18n.no_recipients);
            return;
        }

        const recipientNames = NtopUtils.arrayToListString(recipients.map(recipient => recipient.recipient_name), MAX_RECIPIENTS);
        $recipientsInfo.html(i18n.some_recipients.replace('${recipients}', recipientNames));

    });

    $(`#input-add-host`).attr('pattern', getMeasurementRegex(DEFAULT_MEASUREMENT));
    $(`#input-edit-host`).attr('pattern', getMeasurementRegex(DEFAULT_MEASUREMENT));

});
