$(document).ready(function () {

    const addResponsivenessFilter = (tableAPI) => {
        DataTableUtils.addFilterDropdown(i18n.snmp.device_responsiveness, responsivenessFilters, 0, '#table-devices_filter', tableAPI);
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
                            <span>
                                <span class='badge-warning badge' title='${i18n.snmp.snmp_device_does_not_respond}'>
                                    <i class="fas fa-exclamation-triangle"></i>
                                </span>
                            </span> ${data}
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
                    if (type == "display" && data === 0) return "";
                    if (type == "display" && data > 0) {
                        return (`
                            <a href="#">
                            </a>
                        `);
                    }
                    return data;
                }
            },
            { data: "column_last_update", className: "text-center" },
            { data: "column_last_poll_duration", className: "text-center" },
            /* { data: "column_delta_errors", className: "text-center" }, */
            {
                targets: -1,
                visible: isAdministrator,
                className: 'text-center',
                data: null,
                render: function() {
                    return (`
                        <a data-toggle="modal" class="badge badge-danger" href="#delete_device_dialog">
                            ${i18n.delete}
                        </a>
                    `);
                }
            }
        ],
        stateSave: true,
        initComplete: function(settings, json) {

            const tableAPI = settings.oInstance.api();
            $(`th`).removeClass(`text-center`).removeClass(`text-right`);
            addResponsivenessFilter(tableAPI);
        }
    });

    const $snmpTable = $(`#table-devices`).DataTable(dtConfig);

    $(`#table-devices`).on('click', `a[href='#delete_device_dialog']`, function (e) {

        const rowData = $snmpTable.row($(this).parent()).data();
        $('#snmp_device_to_delete').text(rowData.column_key);

        delete_device_id = rowData.column_key;
    });

});
