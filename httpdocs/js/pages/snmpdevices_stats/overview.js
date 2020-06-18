$(document).ready(function () {

    const addResponsivenessFilter = (tableAPI) => {
        DataTableUtils.addFilterDropdown(
            i18n.snmp.device_responsiveness, responsivenessFilters, 0, '#table-devices_filter', tableAPI
        );
    }

    let dtConfig = DataTableUtils.getStdDatatableConfig(`lB<'dt-search'f>rtip`, [
        {
            text: '<i class="fas fa-plus"></i>',
            action: function(e, dt, node, config) {
                $('#add-snmp-modal').modal('show');
            }
        }
    ]);
    dtConfig = DataTableUtils.setAjaxConfig(
        dtConfig,
        "/lua/pro/enterprise/get_snmp_devices_list.lua",
        'data',
    );
    dtConfig = DataTableUtils.extendConfig(dtConfig, {
        columns: [
            {
                data: "column_device_status",
                visible: false,
            },
            {
                data: "column_ip",
                type: 'ip-address',
                render: function(data, type, row) {

                    if (type == "display" && row.column_device_status == "unreachable") {
                        return (`
                            <span class='badge badge-warning' title='${i18n.snmp.snmp_device_does_not_respond}'>
                                <i class="fas fa-exclamation-triangle"></i>
                            </span>
                            ${data}
                        `);
                    }

                    return data;
                }
            },
            { data: "column_community" },
            { data: "column_chart", className: "text-center" },
            { data: "column_name" },
            { data: "column_descr" },
            {
                data: "column_err_interfaces",
                className: "text-right",
                render: function(data, type, row) {
                    // if the cell contains zero then doesn't show it
                    if (type == "display" && data === 0) return "";
                    if (type == "display" && data > 0) {
                        return data;
                    }
                    return data;
                }
            },
            { data: "column_last_update", className: "text-center" },
            { data: "column_last_poll_duration", className: "text-center" },
            {
                targets: -1,
                visible: isAdministrator,
                className: 'text-center',
                data: null,
                render: function() {

                    if (!isAdministrator) return "";

                    return (`
                        <a data-toggle="modal" class="badge badge-danger" href="#delete_device_dialog">
                            ${i18n.delete}
                        </a>
                    `);
                }
            }
        ],
        stateSave: true,
        hasFilters: true,
        initComplete: function(settings, json) {

            const tableAPI = settings.oInstance.api();
            // remove these styles from the table headers
            $(`th`).removeClass(`text-center`).removeClass(`text-right`);
            // append the responsive filter for the table
            addResponsivenessFilter(tableAPI);

            setInterval(() => { tableAPI.ajax.reload(); }, 30000);

        }
    });

    // initialize the DataTable with the created config
    const $snmpTable = $(`#table-devices`).DataTable(dtConfig);

    $(`#table-devices`).on('click', `a[href='#delete_device_dialog']`, function (e) {

        const rowData = $snmpTable.row($(this).parent()).data();
        $('#snmp_device_to_delete').text(rowData.column_key);
        delete_device_id = rowData.column_key;
    });

    $(`#add-snmp-modal form`).modalHandler({
        method: 'get',
        csrf: addCsrf,
        resetAfterSubmit: false,
        endpoint: `${ http_prefix }/lua/pro/rest/v1/add/snmp/device.lua`,
        beforeSumbit: function() {
            $(`#add-snmp-feedback`).hide();
            return serializeFormArray($(`#add-snmp-modal form`).serializeArray());
        },
        onModalInit: function() {

            // disable dropdown if the user inputs an hostname
            $(`input[name='host']`).keyup(function(e) {
                const value = $(this).val();
                if (new RegExp(REGEXES.domainName).test(value)) {
                    $('#select-cidr').attr("disabled", "disabled");
                }
                else {
                    $('#select-cidr').removeAttr("disabled");
                }
            });
        },
        onSubmitSuccess: function (response) {

            if (response.rc < 0) {
                $(`#add-snmp-feedback`).html(i18n.rest[response.rc_str.toLowerCase()]).show();
                return;
            }

            $snmpTable.ajax.reload();
            $(`#add-snmp-modal`).modal('close');
        }
    }).invokeModalInit();

    // configure import config modal
    importModalHelper({
        load_config_xhr: (jsonConf) => {
          return $.post(`${http_prefix}/lua/pro/enterprise/import_snmp_devices_config.lua`, {
            csrf: importCsrf,
            JSON: jsonConf,
          });
        }, reset_csrf: (newCsrf) => {
            importCsrf = newCsrf;
        }
    });

});
