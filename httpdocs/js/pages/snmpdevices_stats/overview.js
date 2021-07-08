/**
 * (C) 2020 - ntop.org
 *
 * This script implements the logic for the overview tab inside snmpdevice_stats.lua page.
 */
$(function () {

    // constant for filtering table
    const RESPONSIVE_COLUMN_INDEX = 0;
    const POOL_COLUMN_INDEX = 2;

    // define a constant for the SNMP version dropdown value
    const SNMP_VERSION_THREE = 2;
    const MAX_RECIPIENTS = 3;

    // an object containing ddefault values for the Edit SNMP modal
    const SNMP_DEFAULTS = {
        VERSION : 0,
        DEFAULT_POOL: 0
    };

    // required fields for SNMPv3
    const requiredFields = {};

    const addResponsivenessFilter = (tableAPI) => {
        return new DataTableFiltersMenu({
            filterTitle: i18n.snmp.device_responsiveness,
            filters: responsivenessFilters,
            columnIndex: RESPONSIVE_COLUMN_INDEX,
            tableAPI: tableAPI,
            filterMenuKey: 'responsiveness-filters'
        });
    }

    const addPoolFilters = (tableAPI) => {

        return new DataTableFiltersMenu({
            filterTitle: i18n.pools,
            filters: poolFilters,
            columnIndex: POOL_COLUMN_INDEX,
            tableAPI: tableAPI,
            filterMenuKey: 'pool-filters'
        });
    }

    const toggleSnmpTableButtons = (response) => {

        const thereAreUnresponsiveDevices = response.data.some(
            (device) => (device.column_device_status == "unreachable")
        );

        const thereSnmpDevices = response.data.length > 0;

        if (thereAreUnresponsiveDevices) {
            $(`#btn-prune-devices`).show();
        }
        else {
            $(`#btn-prune-devices`).hide();
        }

        if (thereSnmpDevices) {
            $(`#btn-delete-devices`).show();
        }
        else {
            $(`#btn-delete-devices`).hide();
        }

    }

    function onRequestSuccess(response, textStatus, modalHandler, modalSelector) {

        if (response.rc < 0) {
            // hide the spinner and show a localized error
            $(`${modalSelector} button[type='submit'] span.spinner-border`).fadeOut(() => {
                $(`${modalSelector} span.invalid-feedback`).html(i18n.rest[response.rc_str]).fadeIn()
            });
            return;
        }

        // clean the form if the response was successful
        $snmpTable.ajax.reload(toggleSnmpTableButtons, false);

        $(`${modalSelector} button[type='submit'] span.spinner-border`).hide();
        $(modalSelector).modal('hide');
    }

    function buildDataRequest(modalSelector) {

        const data = {};
        // show the spinner and hide the errors
        $(`${modalSelector} span.invalid-feedback`).hide();
        $(`${modalSelector} button[type='submit'] span.spinner-border`).fadeIn();

        // build the post params
        $(`${modalSelector} form`).find('input,select,textarea').each((idx, element) => {
            data[$(element).attr("name")] = $(element).val();
        });

        return data;
    }

    function bindSNMPHostKeyup(modalSelector) {

        $(`${modalSelector} input[name='snmp_host']`).keyup(function(e) {

            const value = $(this).val();

            if (new RegExp(NtopUtils.REGEXES.domainName).test(value)) {
                $(`${modalSelector} select[name='cidr']`).attr("disabled", "disabled");
            }
            else if (new RegExp(NtopUtils.REGEXES.ipv6).test(value)) {
                $(`${modalSelector} select[name='cidr'] option[value!='128']`).attr("disabled", "disabled");
                $(`${modalSelector} select[name='cidr']`).val(128);
            }
            else {
                $(`${modalSelector} select[name='cidr'] option[value!='128']`).removeAttr("disabled");
                $(`${modalSelector} select[name='cidr']`).removeAttr("disabled");
            }

        });
    }

    function bindSNMPLevelSelect(modalSelector) {

        $(`${modalSelector} select[name='snmp_level']`).change(function(e) {

            const usernameSelector = `${modalSelector} input[name='snmp_username']`;
            const privacySelector = `${modalSelector} select[name='snmp_privacy_protocol'], ${modalSelector} input[name='snmp_privacy_passphrase']`;
            const authSelector = `${modalSelector} input[name='snmp_auth_protocol'], ${modalSelector} select[name='snmp_auth_protocol']`;

            switch ($(this).val()) {
                case "authPriv":
                    $(`${privacySelector},${usernameSelector},${authSelector}`).removeAttr("disabled");
                    break;
                case "noAuthNoPriv":
                    $(`${authSelector},${privacySelector},${usernameSelector}`).attr("disabled", "disabled");
                    break;
                case "authNoPriv":
                    $(`${authSelector},${usernameSelector}`).removeAttr("disabled");
                    $(privacySelector).attr("disabled", "disabled");
                    break;
            }

        });
    }

    function bindSNMPVersionSelect(modalSelector) {

        $(`${modalSelector} select[name='snmp_version']`).change(function() {

            if (!requiredFields[modalSelector]) requiredFields[modalSelector] = {};
            if (!requiredFields[modalSelector]['community'])
                requiredFields[modalSelector]['community'] = $(`.community-field [name][required]`);
            if (!requiredFields[modalSelector]['non-community'])
                requiredFields[modalSelector]['non-community'] = $(`.non-community-field [name][required]`);

            // if the selected SNMPversion is the third one
            // then show the necessary fields (.non-community-field)
            if ($(this).val() == SNMP_VERSION_THREE) {
                $(`.community-field`).fadeOut(500, () => { $(`.non-community-field`).fadeIn(500); });
                requiredFields[modalSelector]['community'].attr("disabled", "disabled");
                requiredFields[modalSelector]['non-community'].removeAttr("disabled");
                return;
            }


            // hide non community fields and show community fields
            $(`.non-community-field`).fadeOut(500, () => { $(`.community-field`).fadeIn(500); });
            requiredFields[modalSelector]['non-community'].attr("disabled", "disabled");
            requiredFields[modalSelector]['community'].removeAttr("disabled");

        });
    }

    function bindReloadingPoolsButton(reloadButtonSelector) {
        $(reloadButtonSelector).click(async function(e) {

            e.preventDefault();

            $(this).attr("disabled", true);

            const request = await fetch(`${http_prefix}/lua/rest/v2/get/snmp/device/pools.lua`);
            const data = await request.json();

            if (data.rc < 0) {
                console.warn("Something went wrong when reloading SNMPPools list!");
                return;
            }

            // update the select if there are new pools
            data.rsp.forEach((pool) => {

                const {pool_id, name} = pool;
                // if there is already the pool then return
                if ($(`#add-select-pool option[value='${pool_id}']`).length != 0) {
                    return;
                }

                $(`#add-select-pool`).append(`<option value='${pool_id}'>${name}</option>`)
            });

            $(this).removeAttr("disabled");
        });
    }

    /* ****************************************************************** */

    bindReloadingPoolsButton(`#add-reload-pools`);
    bindReloadingPoolsButton(`#edit-reload-pools`);

    bindSNMPVersionSelect(`#add-snmp-device-modal`);
    bindSNMPVersionSelect(`#edit-snmp-device-modal`);

    // disable dropdown if the user inputs an hostname
    bindSNMPHostKeyup(`#add-snmp-device-modal`);
    bindSNMPHostKeyup(`#edit-snmp-device-modal`);
    // disable passhphrase if the user selects none
    bindSNMPLevelSelect(`#add-snmp-device-modal`);
    bindSNMPLevelSelect(`#edit-snmp-device-modal`);

    let dtConfig = DataTableUtils.getStdDatatableConfig( [
        {
            text: '<i class="fas fa-plus"></i>',
            action: function(e, dt, node, config) {
                $('#add-snmp-device-modal').modal('show');
            }
        },
        {
            text: '<i class="fas fa-sync"></i>',
            action: function(e, dt, node, config) {
                $snmpTable.ajax.reload(toggleSnmpTableButtons, false);
            }
        }
    ]);
    dtConfig = DataTableUtils.setAjaxConfig(dtConfig, '/lua/pro/enterprise/get_snmp_devices_list.lua', 'data');
    dtConfig = DataTableUtils.extendConfig(dtConfig, {
        orderFixed: { post: [[1, "asc"]] },
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
                            <span class='badge bg-warning' title='${i18n.snmp.snmp_device_does_not_respond}'>
                                <i class="fas fa-exclamation-triangle"></i>
                            </span>
                            ${data}
                        `);
                    }

                    return data;
                }
            },
            {
                data: "column_pool_name"
            },
            { data: "column_chart", className: "text-center", width: "5%" },
            { data: "column_name" },
            { data: "column_descr", width: "20%" },
            {
                data: "column_err_interfaces",
                className: "text-right pre-wrap",
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
            {
                data: "column_last_update",
                className: "text-center",
                render: $.fn.dataTableExt.formatSecondsToHHMMSS
            },
            {
                data: "column_last_poll_duration",
                className: "text-center",
                render: $.fn.dataTableExt.formatSecondsToHHMMSS
            },
            {
                targets: -1,
                visible: isAdministrator,
                className: 'text-center',
                data: null,
                render: function() {

                    if (!isAdministrator) return "";

                    return DataTableUtils.createActionButtons([
                        { class: 'btn-info', icon: 'fa-edit', modal: '#edit-snmp-device-modal' },
                        { class: 'btn-danger', icon: 'fa-trash', modal: '#delete-snmp-device-modal'}
                    ]);
                }
            }
        ],
        stateSave: true,
        hasFilters: true,
        initComplete: function(settings, json) {

            const tableAPI = settings.oInstance.api();
            // remove these styles from the table headers
            $(`th`).removeClass(`text-center`).removeClass(`text-right`);

            // when the data has been fetched check if the url has a column_key param
            // if the recipient is builtin then cancel the modal opening
            DataTableUtils.openEditModalByQuery({
                paramName: 'column_key',
                datatableInstance: tableAPI,
                modalHandler: $editModalHandler,
            });

            setInterval(() => { tableAPI.ajax.reload(toggleSnmpTableButtons, false); }, 30000);

        }
    });

    // initialize the DataTable with the created config
    const $snmpTable = $(`#table-devices`).DataTable(dtConfig);
    DataTableUtils.addToggleColumnsDropdown($snmpTable);

    addPoolFilters($snmpTable).init();
    addResponsivenessFilter($snmpTable).init();

    $(`#add-snmp-device-modal form`).modalHandler({
        method: 'post',
        csrf: addCsrf,
        resetAfterSubmit: false,
        endpoint: `${ http_prefix }/lua/pro/rest/v2/add/snmp/device.lua`,
        beforeSumbit: () => {
            return buildDataRequest(`#add-snmp-device-modal`);
        },
        onModalShow: () => {

            $(`#add-snmp-feedback`).hide();
            // set the edit pool link to the default one when the modal opens
            const $editPoolLink = $('#add-snmp-device-modal .edit-pool');
            const editPoolHref = NtopUtils.buildURL(
                '/lua/admin/manage_pools.lua?', {pool_id: SNMP_DEFAULTS.DEFAULT_POOL, page: 'snmp_device'},
                true
            );
            $editPoolLink.attr('href', editPoolHref);

            // load the recipient lists inside the modal
            $(`#add-snmp-device-modal select[name='pool']`).trigger('change');
        },
        onSubmitSuccess: (response, textStatus, modalHandler) => {
            onRequestSuccess(response, textStatus, modalHandler, '#add-snmp-device-modal');
        }
    }).invokeModalInit();

    const $editModalHandler = $(`#edit-snmp-device-modal form`).modalHandler({
        method: 'post',
        csrf: addCsrf,
        resetAfterSubmit: false,
        endpoint: `${ http_prefix }/lua/pro/rest/v2/edit/snmp/device/device.lua`,
        beforeSumbit: (selectedSNMPDevice) => {
            const data = buildDataRequest('#edit-snmp-device-modal');
            data.snmp_host = selectedSNMPDevice.column_key;
            return data;
        },
        onModalInit: (selectedSNMPDevice) => {

            // if the version is over SNMP_VERSION_THREE then bind it to the default one
            const version = (selectedSNMPDevice.column_version > SNMP_VERSION_THREE) ? SNMP_DEFAULTS.VERSION : selectedSNMPDevice.column_version;

            $(`#edit-snmp-device-modal input[name='snmp_read_community']`).val(selectedSNMPDevice.column_community);
	        $(`#edit-snmp-device-modal input[name='snmp_write_community']`).val(selectedSNMPDevice.column_write_community);
            $(`#edit-snmp-device-modal select[name='snmp_version']`).val(version);
            $(`#edit-snmp-device-modal select[name='pool']`).val(selectedSNMPDevice.column_pool_id);
            $(`#edit-snmp-device-modal .device-name`).text(selectedSNMPDevice.column_key);

            // set the edit pool link
            const $editPoolLink = $('#edit-snmp-device-modal .edit-pool');
            const editPoolHref = NtopUtils.buildURL(
                '/lua/admin/manage_pools.lua?', {pool_id: selectedSNMPDevice.column_pool_id, page: 'snmp_device'},
                true, {column_key: selectedSNMPDevice.column_key}
            );
            $editPoolLink.attr('href', editPoolHref);

            // load the recipient lists inside the modal
            $(`#edit-snmp-device-modal select[name='pool']`).trigger('change');
        },
        onSubmitSuccess: (response, textStatus, modalHandler) => {
            onRequestSuccess(response, textStatus, modalHandler, '#edit-snmp-device-modal');
        }
    });

    const $deleteModalHandler = $(`#delete-snmp-device-modal form`).modalHandler({
        method: 'post',
        csrf: deleteCsrf,
        endpoint: `${ http_prefix }/lua/pro/rest/v2/delete/snmp/device.lua`,
        resetAfterSubmit: false,
        onModalInit: function(selectedSNMPDevice) {
            $(`.delete-snmp-device-name`).text(selectedSNMPDevice.column_key);
        },
        beforeSumbit: function(selectedSNMPDevice) {
            return { host: selectedSNMPDevice.column_key };
        },
        onSubmitSuccess: function (response, textStatus, modalHandler) {

            if (response.rc < 0) {
                $(`#delete-modal-feedback`).html(i18n.rest[response.rc_str]).fadeIn();
                return;
            }

            $snmpTable.ajax.reload();
            $(`#delete-snmp-device-modal`).modal('hide');
        }
    });

    $(`#table-devices`).on('click', `a[href='#delete-snmp-device-modal']`, function (e) {
        const selectedSNMPDevice = $snmpTable.row($(this).parent().parent()).data();
        $deleteModalHandler.invokeModalInit(selectedSNMPDevice);
    });

    $(`#table-devices`).on('click', `a[href='#edit-snmp-device-modal']`, function (e) {
        const selectedSNMPDevice = $snmpTable.row($(this).parent().parent()).data();
        $editModalHandler.invokeModalInit(selectedSNMPDevice);
    });

    // on changing the associated pool updates the link to the edit pool
    $(`select[name='pool']`).change(async function() {

        const poolId = $(this).val();
        const $editPoolLink = $(this).parents('.form-group').find('.edit-pool');
        const $recipientsInfo = $(this).parents('.form-group').find('.recipients-info');

        let url = new URL($editPoolLink.attr('href')).searchParams.get('referer');
        const columnKey = new URL(url).searchParams.get('column_key');

        const editPoolHref = NtopUtils.buildURL(
            '/lua/admin/manage_pools.lua?', {pool_id: poolId, page: 'snmp_device'},
            true, {column_key: columnKey}
        );

        $editPoolLink.attr('href', editPoolHref);

        const [success, pool] = await NtopUtils.getPool('snmp/device', poolId);
        if (!success) return;

        let recipients = pool.recipients;

        if (recipients.length == 0) {
            $recipientsInfo.html(i18n.no_recipients);
            return;
        }

        const recipientNames = NtopUtils.arrayToListString(recipients.map(recipient => recipient.recipient_name), MAX_RECIPIENTS);
        $recipientsInfo.html(i18n.some_recipients.replace('${recipients}', recipientNames));

    });
});
