$(document).ready(function () {

    // define a constant for the snmp version dropdown value
    const SNMP_VERSION_THREE = 2;
    const requiredFieldsAdd = {
        community: [],
        nonCommunity: []
    };

    $(`.community-field input[required], .community-field select[required]`)
    .each(function() {
        requiredFieldsAdd.community.push($(this));
    });

    $(`.non-community-field input[required], .non-community-field select[required]`)
    .each(function() {
        requiredFieldsAdd.nonCommunity.push($(this));
        $(this).removeAttr("required");
    });

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
        },
        {
            text: '<i class="fas fa-sync"></i>',
            action: function(e, dt, node, config) {
                $snmpTable.ajax.reload();
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
            { data: "column_chart", className: "text-center", width: "5%" },
            { data: "column_name" },
            { data: "column_descr", width: "20%" },
            {
                data: "column_err_interfaces",
                className: "text-right",
                width: "5%",
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
        method: 'post',
        csrf: addCsrf,
        resetAfterSubmit: false,
        endpoint: `${ http_prefix }/lua/pro/rest/v1/add/snmp/device.lua`,
        beforeSumbit: function() {
            $(`#add-snmp-feedback`).hide();
            $(`#snmp-add-spinner`).fadeIn();
            return serializeFormArray($(`#add-snmp-modal form`).serializeArray());
        },
        onModalInit: function() {

            // disable dropdown if the user inputs an hostname
            $(`input[name='snmp_host']`).keyup(function(e) {
                const value = $(this).val();
                if (new RegExp(REGEXES.domainName).test(value)) {
                    $('#select-cidr').attr("disabled", "disabled");
                }
                else {
                    $('#select-cidr').removeAttr("disabled");
                }
            });

            // Disable passhphrase if the user selects none
            $(`select#select-privacy-protocol-snmp`).change(function(e) {

                const value = $(this).val();
                if (value == "none") {
                    $(`#input-privacy-passphrase`).attr("disabled", "disabled");
                }
                else {
                    $(`#input-privacy-passphrase`).removeAttr("disabled");
                }

            });
        },
        onSubmitSuccess: function (response, textStatus, modalHandler) {

            if (response.rc < 0) {
                // hide the spinner and show a localized error
                $(`#snmp-add-spinner`).fadeOut(() => {
                    $(`#add-snmp-feedback`).html(i18n.rest[response.rc_str]).fadeIn()
                });
                return;
            }

            // clean the form if the response was successful
            modalHandler.cleanForm();
            $snmpTable.ajax.reload();
            $(`#snmp-add-spinner`).hide();
            $(`#add-snmp-modal`).modal('hide');

        }
    }).invokeModalInit();

    $(`#select-snmp_version`).change(function() {

        const value = $(this).val();

        // if the selected snmp version is the third one
        // then show the necessary fields (.non-community-field)

        if (value == SNMP_VERSION_THREE) {

            $(`.community-field`).fadeOut(500, function() {
                requiredFieldsAdd.community.forEach(($input) => {
                    $input.removeAttr("required");
                });
                requiredFieldsAdd.nonCommunity.forEach(($input) => {
                    $input.attr("required", "");
                });
                $(`.non-community-field`).fadeIn(500);
            });
            return;
        }

        $(`.non-community-field`).fadeOut(500, function() {
            requiredFieldsAdd.nonCommunity.forEach(($input) => {
                $input.removeAttr("required");
            });
            requiredFieldsAdd.community.forEach(($input) => {
                $input.attr("required", "");
            });
            $(`.community-field`).fadeIn(500);
        });

    });

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
