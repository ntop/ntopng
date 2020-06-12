$(document).ready(function () {

    const addStatsSinceFilter = (tableAPI) => {
        DataTableUtils.addFilterDropdown(i18n.snmp.stats_since, statsSinceFilters, 0, '#table-devices_filter', tableAPI);
    }

    const urlParams = new URLSearchParams(window.location.search);
    let dtConfig = DataTableUtils.getStdDatatableConfig(`lB<'dt-search'f>rtip`, [
        {
            text: '<i class="fas fa-plus"></i>',
            action: function(e, dt, node, config) {
                $('#add-snmp-modal').modal('show');
            }
        },
        {
            text: `<i class="fas fa-trash"></i> ${i18n.snmp.delete_all_devices}`,
            className: `${buttonsVisibility.deleteAllDevices ? "" : "d-none"}`,
            action: function(e, dt, node, config) {
                $(`#delete_all_devices_dialog`).modal('show');
            }
        },
        {
            text: `<i class="fas fa-eraser"></i> ${i18n.snmp.delete_unresponsive_devices}`,
            className: `${buttonsVisibility.pruneDevices ? "" : "d-none"}`,
            action: function(e, dt, node, config) {
                $('#prune_unsresponsive_devices_dialog').modal('show')
            }
        }
    ]);
    dtConfig = DataTableUtils.setAjaxConfig(
        dtConfig,
        "/lua/pro/enterprise/get_snmp_devices_list.lua",
        'data',
        'get',
        {
            device_responsiveness: urlParams.get('device_responsiveness'),
            counters_since: urlParams.get('counters_since')
        }
    );
    dtConfig = DataTableUtils.extendConfig(dtConfig, {
        columns: [
            {
                data: "column_device_status",
                visible: false,
            },
            {
                data: "column_ip",
                render: function(data, type, row) {

                    if (type == "display" && row.column_device_status == "unreachable") {
                        return (`
                            <span class='badge-warning badge' title='${i18n.snmp.snmp_device_does_not_respond}'>
                                <i class="fas fa-exclamation-triangle"></i>
                            </span>
                            ${data}
                        `);
                    }

                    return data;
                }
            },
            { data: "column_community" },
            { data: "column_chart" },
            { data: "column_name" },
            { data: "column_descr" },
            { data: "column_err_interfaces" },
            { data: "column_last_update" },
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
            addStatsSinceFilter(tableAPI);

        }
    });

    const $snmpTable = $(`#table-devices`).DataTable(dtConfig);

    $(`#table-devices`).on('click', `a[href='#delete_device_dialog']`, function (e) {

        const rowData = $snmpTable.row($(this).parent()).data();
        $('#snmp_device_to_delete').text(rowData.column_key);

        delete_device_id = rowData.column_key;
    });

});