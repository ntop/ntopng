/**
 * (C) ntop.org - 2020
 * This script manage the GUI for Host Pool Members page
 */

$(function () {

    // this is the current filtering type for the datatable
    let currentType = null;
    const INDEX_MEMBER_FILTER = 0;

    let changable_pool = true;

    for(const pool_names of unchangable_pool_names) {
        if(pool_names === selectedPool.name) {
            changable_pool = false;
            break;
        }
    }

    const filters = [
        {
            regex: NtopUtils.getIPv4RegexWithCIDR(),
            label: i18n.ipv4,
            key: 'ipv4_filter',
            countable: true,
            callback: () => { currentType = "ip"; $hostMembersTable.rows().invalidate(); }
        },
        {
            regex: NtopUtils.getIPv6RegexWithCIDR(),
            label: i18n.ipv6,
            key: 'ipv6_filter',
            countable: true,
            callback: () => { currentType = "ip"; $hostMembersTable.rows().invalidate(); }
        },
        {
            regex: NtopUtils.REGEXES.macAddress,
            label: i18n.mac_filter,
            key: 'mac_filter',
            countable: true,
            callback: () => { currentType = "mac"; $hostMembersTable.rows().invalidate(); }
        },
    ];

    let buttonArray = function() {
	let buttons = [];

	buttons.push({
            text: '<i class="fas fa-plus"></i>',
            action: () => { $(`#add-member-modal`).modal('show'); }
        });

	buttons.push({
            text: '<i class="fas fa-sync"></i>',
            action: function(e, dt, node, config) {
                $hostMembersTable.ajax.reload();
            }
        });

	if(__IS_PRO__ && changable_pool)
	    buttons.push({
	    text: '<i class="fas fa-key"></i>',
            action: () => { location.href = `${http_prefix}/lua/pro/policy.lua?pool=${selectedPool.id}`; }
	    });

	return buttons;
    }

    let dtConfig = DataTableUtils.getStdDatatableConfig(buttonArray());
    dtConfig = DataTableUtils.setAjaxConfig(dtConfig, `${http_prefix}/lua/rest/v2/get/host/pool/members.lua?pool=${queryPoolId}`, `rsp`);
    dtConfig = DataTableUtils.extendConfig(dtConfig, {
        stateSave: true,
        hasFilters: true,
        columns: [
            {
                data: 'name',
                render: function (data, type, row) {

                    if (type == "sort" || type == "type") {
                        if (currentType == "mac") return $.fn.dataTableExt.oSort["mac-address-pre"](data);
                        return $.fn.dataTableExt.oSort["ip-address-pre"](data);
                    }

                    return data;
                }
            },
            {
                data: 'vlan',
                width: '5%',
                className: 'text-center',
                render: function (data, type, row) {

                    if (data == 0 && type == "display") return "";
                    return data;
                }
            },
            {
                data: null, targets: -1, className: 'text-center',
                width: "10%",
                render: () => {
                    return DataTableUtils.createActionButtons([
                        { class: 'btn-danger', icon: 'fa-trash', modal: '#remove-member-host-pool'}
                    ]);
                }
            }
        ]
    });

    const $hostMembersTable = $(`#host-members-table`).DataTable(dtConfig);
    DataTableUtils.addToggleColumnsDropdown($hostMembersTable);

    const hostMemersTableFilters = new DataTableFiltersMenu({
        tableAPI: $hostMembersTable,
        filters: filters,
        filterMenuKey: 'host-members',
        filterTitle: i18n.member_type,
        columnIndex: INDEX_MEMBER_FILTER,
    }).init();

    $(`#host-members-table`).on('click', `a[href='#remove-member-host-pool']`, function (e) {
        const memberRowData = $hostMembersTable.row($(this).parent().parent()).data();
        $removeModalHandler.invokeModalInit(memberRowData);
    });
    
    $(`#select-host-pool`).change(function () {
	const poolId = $(this).val();
	location.href = `${http_prefix}/lua/admin/manage_host_members.lua?pool=${poolId}`;
    });

    $(`[href='#import-modal']`).click(function() {
        $(`.member-name`).html(selectedPool.name);
    });

    $(`input#import-input`).on('change', function () {
        const filename = $(this).val().replace("C:\\fakepath\\", "");
        $(`label[for='#import-input']`).html(filename);
        $(`#btn-confirm-import`).removeAttr("disabled");
    });

    const oldLabelImportInput = $(`label[for='#import-input']`).html();
    $(`#import-modal`).on('hidden.bs.modal', function () {
        $(`#import-input`).val('');
        $(`label[for='#import-input']`).html(oldLabelImportInput);
        $("#import-error").hide().removeClass('text-warning').addClass('invalid-feedback');
        $(`#btn-confirm-import`).attr("disabled", "disabled");
    });

    $(`#import-modal form`).submit(function(e) {
        e.preventDefault();

        const $button = $(`#btn-confirm-import`);

        const inputFilename = $('#import-input')[0].files[0];
        if (!inputFilename) {
            $("#import-error").text(`${i18n.no_file}`).show();
            $button.removeAttr("disabled");
            return;
        }

        const reader = new FileReader();
        reader.readAsText(inputFilename, "UTF-8");

        reader.onload = (function() {
            const req = $.post(`${http_prefix}/lua/rest/v2/import/pool/host_pool/members.lua`, {csrf: importCsrf, pool: selectedPool.id, host_pool_members: reader.result});
            req.then(function(response) {

                if (response.rc < 0) {
                    $("#import-error").show().html(response.rc_str_hr);
                    return;
                }

                location.reload();
            });
            req.fail(function(response) {
                if (response.rc < 0) {
                    $("#import-error").show().html(response.rc_str_hr);
                }
            });
        });
    });

    $(window).on('popstate', function (e) {
        const { state } = e.originalEvent;
        $(`#select-host-pool`).val(state.pool).trigger('change');
    });

    $(`#add-member-modal form`).modalHandler({
        method: 'post',
        csrf: addCsrf,
        resetAfterSubmit: false,
        endpoint: `${http_prefix}/lua/rest/v2/bind/host/pool/member.lua`,
        onModalShow: function () {
            // hide the fields and select default type entry
            const macAndNetworkFields = "#add-member-modal .mac-fields, #add-member-modal .network-fields";
            $(macAndNetworkFields).hide();

            $(`#add-member-modal .ip-fields`).show().find(`input,select`).removeAttr("disabled");
            $(`#add-modal-feedback`).hide();

            $(`#add-member-modal [name='member_type']`).removeAttr('checked').parent().removeClass('active');
            // show the default view
            $(`#add-member-modal #ip-radio`).attr('checked', '').parent().addClass('active');
        },
        onModalInit: function (_, modalHandler) {
            // on select member type shows only the fields interested
            $(`#add-member-modal [name='member_type']`).change(function () {

                const value = $(this).val();
                $(`#add-member-modal [name='member_type']`).removeAttr('checked').parent().removeClass('active');
                $(this).attr('checked', '');

                // clean the members and show the selected one
                $(`#add-member-modal [class*='fields']`).hide();
                $(`#add-member-modal [class*='fields'] input, #add-member-modal [class*='fields'] select`).attr("disabled", "disabled");

                $(`#add-member-modal [class='${value}-fields']`).show().find('input,select').removeAttr("disabled");

                modalHandler.toggleFormSubmission();
            });
        },
        beforeSumbit: function () {

            let member;
            const typeSelected = $(`#add-member-modal [name='member_type']:checked`).val();

            if (typeSelected == "mac") {
                member = $(`#add-member-modal input[name='mac_address']`).val();
            }
            else if (typeSelected == "ip") {

                const ipAddress = $(`#add-member-modal input[name='ip_address']`).val();
                const vlan = $(`#add-member-modal input[name='ip_vlan']`).val() || 0;
                const cidr = NtopUtils.is_good_ipv6(ipAddress) ? 128 : 32;
                member = `${ipAddress}/${cidr}@${vlan}`;
            }
            else {

                const network = $(`#add-member-modal input[name='network']`).val();
                const cidr = $(`#add-member-modal input[name='cidr']`).val();
                const vlan = $(`#add-member-modal input[name='network_vlan']`).val() || 0;

                member = `${network}/${cidr}@${vlan}`;
            }

            return { pool: selectedPool.id, member: member };
        },
        onSubmitSuccess: function (response, textStatus, modalHandler) {

            if (response.rc < 0) {
                $(`#add-modal-feedback`).html(i18n.rest[response.rc_str]).show();
                return;
            }

            $hostMembersTable.ajax.reload();
            $(`#add-member-modal`).modal('hide');
        }
    }).invokeModalInit();

    const $removeModalHandler = $(`#remove-member-host-pool form`).modalHandler({
        method: 'post',
        csrf: removeCsrf,
        endpoint: `${http_prefix}/lua/rest/v2/bind/host/pool/member.lua`,
        onModalShow: function () {
            $(`#remove-modal-feedback`).hide();
        },
        onModalInit: function (hostMember) {
            $(`.remove-member-name`).html(`${hostMember.name}`);
            $(`#remove-pool-name`).html(`<b>${selectedPool.name}</b>`);
        },
        beforeSumbit: function (hostMember) {
            return { pool: defaultPoolId, member: hostMember.member, pool_name: selectedPool.name };
        },
        onSubmitSuccess: function (response, textStatus, modalHandler) {

            if (response.rc < 0) {
                $(`#remove-modal-feedback`).html(i18n.rest[response.rc_str]).fadeIn();
                return;
            }
            $hostMembersTable.ajax.reload();
            $(`#remove-member-host-pool`).modal('hide');
        }
    });
});
