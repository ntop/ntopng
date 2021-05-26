/**
 * (C) 2020 - ntop.org
 *
 * This script implements the logic to manage the pools inside ntopng gui
 */
$(function() {

    const MAX_RECIPIENTS_TO_SHOW = 10;

    const renableDisabledOptions = (selector, members) => {
        members.forEach(m => {

            if (!all_members || !all_members[m]) return m;
            // if the member name is not defined the use the member's key
            const name = all_members[m].name || m;

            $(`${selector} option[value='${m}']`)
                .removeAttr("disabled").removeAttr("data-pool-id").text(name);
        });
        $(`${selector}`).selectpicker('refresh');
    }

    const markUsedOptions = (selector, members, poolName, poolId) => {
        members.forEach(m => {
            $(`${selector} option[value='${m}']`)
                .attr("disabled", "disabled")
                .attr("data-pool-id", poolId)
                .text(`${all_members[m].name || m} (${poolName})`);
        });
        $(`${selector}`).selectpicker('refresh');
    }

    const makeDataTableColumns = () => {

        const columns = [
            {
                data: 'name',
                width: "10%",
                render: function(name, type, pool) {

                    if (type == "display" && pool.pool_id == DEFAULT_POOL_ID) {
                        return `<i>${name}</i>`;
                    }

                    return name;
                }
            },
            {
                data: null,
                orderable: false,
                width: "40%",
                render: function(data, type, row) {

                    /* if it's the default pool then show an unbounded members message */
                    if (type == "display" && row.pool_id == DEFAULT_POOL_ID) return i18n.unbounded_members;

                    if (type == "display" && row.members.length == 0) return "";
                    // show only the first 10 members, append some dots
                    // if the members are more than 10
                    const memberNames = row.members.map((memberId) => {

                        const member = row.member_details[memberId];
                        if (member.name == undefined && member.hostkey == undefined) return memberId;
                        if (!all_members || !all_members[memberId]) {
                            return member.hostkey || member.name;
                        }

                        if (all_members[memberId].name == undefined) return memberId;
                        return all_members[memberId].name;
                    });

                    if (type == "display") {
                        return NtopUtils.arrayToListString(memberNames, MAX_RECIPIENTS_TO_SHOW);
                    }
                }
            },
            {
                data: 'recipients',
                width: '40%',
                render: function(recipients, type, row) {

                    if (type == "display") {
                        return NtopUtils.arrayToListString(recipients.map(recipient => recipient.recipient_name), MAX_RECIPIENTS_TO_SHOW);
                    }

                    return recipients;
                }
            },
            {
                data: null, targets: -1, className: 'text-center',
                width: "10%",
                render: function(_, type, pool) {
                    let changable_pool = true;

                    for(const pool_names of unchangable_pool_names) {
                        if(pool_names === pool.name) {
                            changable_pool = false;
                            break;
                        }
                    }

                    /* disable actions for ALL_POOL page */
                    if (IS_ALL_POOL) return;

                    const buttons = [
                        { class: 'btn-info', icon: 'fa-edit', modal: '#edit-pool' },
                        { class: `btn-danger ${((pool.pool_id == DEFAULT_POOL_ID || IS_NEDGE) || !changable_pool) ? 'disabled' : '' }`, icon: 'fa-trash', modal: '#remove-pool'}
                    ];

                    if (poolType == "host") {
                        buttons.unshift(
                            {
                                class: `btn-info ${(pool.pool_id == DEFAULT_POOL_ID) ? 'disabled' : '' }`,
                                icon: 'fa-layer-group',
                                href: `${http_prefix}/lua/admin/manage_host_members.lua?pool=${pool.pool_id}`
                            }
                        );
                    }

                    return DataTableUtils.createActionButtons(buttons);
                }
            }
        ];

        // if the ALL_POOL page is selected then show the pool family
        if (IS_ALL_POOL) {
            columns.splice(1, 0, {
                data: 'key',
                render: (key, type, pool) => {
                    if (type == "display") return i18n.poolFamilies[key];
                    return key;
                }
            });
        }

        return columns;
    }

    let dtConfig = DataTableUtils.getStdDatatableConfig( [
        {
            text: '<i class="fas fa-plus"></i>',
            enabled: !ADD_POOL_DISABLED && !IS_ALL_POOL && !IS_NEDGE,
            action: () => { $(`#add-pool`).modal('show'); }
        },
        {
            text: '<i class="fas fa-sync"></i>',
            enabled: !ADD_POOL_DISABLED && !IS_ALL_POOL,
            action: function(e, dt, node, config) {
                $poolTable.ajax.reload();
            }
        }
    ]);
    dtConfig = DataTableUtils.setAjaxConfig(dtConfig, endpoints.get_all_pools, 'rsp');
    dtConfig = DataTableUtils.extendConfig(dtConfig, {
        stateSave: true,
        columns: makeDataTableColumns(),
        initComplete: function(settings, json) {

            const tableAPI = settings.oInstance.api();
            // when the data has been fetched check if the url has a pool params
            DataTableUtils.openEditModalByQuery({
                paramName: 'pool_id',
                datatableInstance: tableAPI,
                modalHandler: $editModalHandler,
            });
        }
    });

    const $poolTable = $(`#table-pools`).DataTable(dtConfig);
    DataTableUtils.addToggleColumnsDropdown($poolTable);

    $(`#add-pool form`).modalHandler({
        method: 'post',
        csrf: addCsrf,
        resetAfterSubmit: false,
        endpoint: endpoints.add_pool,
        beforeSumbit: function() {

            const members = $(`#add-pool form select[name='members']`).val() || [];
            const recipients = $(`#add-pool form select[name='recipients']`).val() || [];

            $(`#add-modal-feedback`).hide();

            return {
                pool_name: $(`#add-pool form input[name='name']`).val().trim(),
                pool_members: members.join(','),
                recipients: recipients.join(',')
            };
        },
        onSubmitSuccess: function (response, textStatus, modalHandler) {

            if (response.rc < 0) {
                $(`#add-modal-feedback`).html(i18n.rest[response.rc_str]).fadeIn();
                return;
            }

            const poolName = $(`#add-pool form input[name='name']`).val().trim();

            if (poolType != "host") {
                // get the new members array
                const members = $(`#add-pool form select[name='members']`).val();
                // mark select entries with the new pool created
                markUsedOptions(`#add-pool form select[name='members']`, members, poolName, response.rsp.pool_id);
                markUsedOptions(`#edit-pool form select[name='members']`, members, poolName, response.rsp.pool_id);
            }

            $poolTable.ajax.reload();
            $(`#add-pool`).modal('hide');
        }
    }).invokeModalInit();

    const $editModalHandler = $(`#edit-pool form`).modalHandler({
        method: 'post',
        csrf: editCsrf,
        endpoint: endpoints.edit_pool,
        resetAfterSubmit: false,
        onModalInit: (pool) => {

            let changable_pool = true;

            for(const pool_names of unchangable_pool_names) {
                if(pool_names === pool.name) {
                    changable_pool = false;
                    break;
                }
            }
            
            // disable pool name field if we are editing the default pool
            // also hide the members multiselect
            if (pool.pool_id == DEFAULT_POOL_ID || !changable_pool) {
                $(`#edit-pool form input[name='name']`).attr("readonly", "true");
                $(`#edit-pool .members-container`).hide();
            }
            else {
                $(`#edit-pool form input[name='name']`).removeAttr("readonly");
                $(`#edit-pool .members-container`).show();
            }

            // disable all the options whose have a data-pool-id attribute
            $(`#edit-pool form select[name='members'] option[data-pool-id]`).attr("disabled", "disabled");

            // enable only the option used by the pool
            $(`#edit-pool form select[name='members'] option`).each(function() {

                const id = $(this).val();
                // if the id belong to the pool then remove the disabled attribute
                if (pool.members.indexOf(id) > -1) {
                    $(this).removeAttr("disabled");
                }
            });

            $(`#edit-pool-name-input`).off('keyup').on('keyup', function() {
                const name = $(this).val()
                $(`[data-pool-id='${pool.pool_id}']`).each(function() {
                    const m = $(this).val();
                    $(this).text(`${all_members[m].name || m} (${name})`);
                });
            });

            // load the modal with the pool data
            $(`#edit-pool form input[name='name']`).val(pool.name);
            $(`#edit-pool form select[name='members']`).val(pool.members);
            $(`#edit-pool form select[name='members']`).selectpicker('refresh');
            $(`#edit-pool form select[name='recipients']`).val(pool.recipients.map(r => r.recipient_id) || []);
            $(`#edit-pool form select[name='recipients']`).selectpicker('refresh');

            if (poolType == "host") {
                const href = $(`#edit-link`).attr('href').replace(/pool\=[0-9]+/, `pool=${pool.pool_id}`);
                $(`#edit-link`).attr('href', href);
            }
        },
        beforeSumbit: (pool) => {

            const members = $(`#edit-pool form select[name='members']`).val() || [];
            const recipients = $(`#edit-pool form select[name='recipients']`).val() || [];

            const data = {
                pool: pool.pool_id,
                pool_name: $(`#edit-pool form input[name='name']`).val().trim(),
                recipients: recipients.join(',')
            };

            if (poolType != "host") {
                data.pool_members = members.join(',');
            }
            else {
                data.pool_members = pool.members.join(',');
            }

            return data;
        },
        onSubmitSuccess:  (response, dataSent, modalHandler) => {

            const oldPoolData = modalHandler.data;

            if (response.rc < 0) {
                $(`#edit-modal-feedback`).html(i18n.rest[response.rc_str]).fadeIn();
                return;
            }

            const newPoolName = $(`#edit-pool form input[name='name']`).val();
            // update the pool name inside the selects if changed
            if (newPoolName != oldPoolData.name) {
                $(`option[data-pool-id='${oldPoolData.pool_id}']`).each(function() {
                    const value = $(this).val();
                    if (poolType != "host")
                        $(this).text(`${all_members[value].name || value} (${i18n.used_by} ${newPoolName})`)
                });
            }

            // the host pool modals don't have any members
            if (poolType != "host" && oldPoolData.pool_id != DEFAULT_POOL_ID) {
                // get the newMembers and the oldMembers and create two subset of them
                const oldMembers = oldPoolData.members;
                const newMembers = $(`#edit-pool form select[name='members']`).val();
                // this subset contains the removed members from the pool
                const oldToRenable = oldMembers.filter((m1) => !newMembers.find(m2 => m1 == m2));
                // this subset contains the new members added to the pool
                const newToMark = newMembers.filter((m1) => !oldMembers.find(m2 => m1 == m2));

                renableDisabledOptions(`#add-pool form select[name='members']`, oldToRenable);
                renableDisabledOptions(`#edit-pool form select[name='members']`, oldToRenable);

                markUsedOptions(`#add-pool form select[name='members']`, newToMark, newPoolName, oldPoolData.pool_id);
                markUsedOptions(`#edit-pool form select[name='members']`, newToMark, newPoolName, oldPoolData.pool_id);
            }

            // clean the form and reload the table
            $poolTable.ajax.reload();
            $(`#edit-pool`).modal('hide');
        }
    });

    const $removeModalHandler = $(`#remove-pool form`).modalHandler({
        method: 'post',
        csrf: removeCsrf,
        endpoint: endpoints.delete_pool,
        resetAfterSubmit: false,
        onModalInit: (pool) => {
            $(`#remove-pool form button[type='submit']`).removeAttr("disabled");
            $(`.delete-pool-name`).text(pool.name);
        },
        beforeSumbit: (pool) => {
            return { pool: pool.pool_id };
        },
        onSubmitSuccess: (response, textStatus, modalHandler) => {

            const oldPoolData = modalHandler.data;

            if (response.rc < 0) {
                $(`#remove-modal-feedback`).html(i18n.rest[response.rc_str]).fadeIn();
                return;
            }

            // renable the members removed from the pool inside the modal
            renableDisabledOptions(`#add-pool form select[name='members']`, oldPoolData.members);
            renableDisabledOptions(`#edit-pool form select[name='members']`, oldPoolData.members);

            $poolTable.ajax.reload();
            $(`#remove-pool`).modal('hide');
        }
    });

    $(`#table-pools`).on('click', `a[href='#edit-pool']`, function (e) {
        const selectedPool = $poolTable.row($(this).parent().parent()).data();
        $editModalHandler.invokeModalInit(selectedPool);
    });

    $(`#table-pools`).on('click', `a[href='#remove-pool']`, function (e) {
        const selectedPool = $poolTable.row($(this).parent().parent()).data();
        $removeModalHandler.invokeModalInit(selectedPool);
    });

});
