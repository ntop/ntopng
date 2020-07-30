/**
 * (C) 2020 - ntop.org
 *
 * This script implements the logic to manage the pools inside ntopng gui
 */
$(document).ready(function() {

    let poolRowData;

    const renableDisabledOptions = (selector, members) => {
        members.forEach(m => {

            if (!all_members || !all_members[m]) return m;
            // if the member name is not defined the use the member's key
            const name = all_members[m].name || m;

            $(`${selector} option[value='${m}']`)
                .removeAttr("disabled").removeAttr("data-pool-id").text(name);
        });
    }

    const markUsedOptions = (selector, members, poolName, poolId) => {

        members.forEach(m => {
            $(`${selector} option[value='${m}']`)
                .attr("disabled", "disabled")
                .attr("data-pool-id", poolId)
                .text(`${all_members[m].name || m} (${poolName})`);
        });
    }

    const sortSelectByValue = (selector) => {

        const $options = $(`${selector} option`);
        $options.sort((a, b) => $(a).val() - $(b).val());

        $(selector).empty().append($options);
    }

    const arrayToListString = (array, limit) => {

        if (array == undefined) return "";

        if (array.length > limit) {
            const otherStr = ((array.length  - limit) == 1) ? i18n.other : i18n.others;
            return array.slice(0, limit).join(", ") + ` ${i18n.and} ${array.length - limit} ${otherStr.toLowerCase()}`;
        }

        return array.slice(0, limit).join(", ");
    }

    let dtConfig = DataTableUtils.getStdDatatableConfig( [
        {
            text: '<i class="fas fa-plus"></i>',
            action: () => { $(`#add-pool`).modal('show'); }
        }
    ]);
    dtConfig = DataTableUtils.setAjaxConfig(dtConfig, endpoints.get_all_pools, 'rsp');
    dtConfig = DataTableUtils.extendConfig(dtConfig, {
        stateSave: true,
        columns: [
            {
                data: 'name',
                width: "10%",
                render: function(name, type, pool) {

                    if (type == "display" && pool.pool_id == defaultPoolId) {
                        return `<i>${name}</i>`;
                    }

                    return name;
                }
            },
            {
                data: null,
                width: "40%",
                render: function(data, type, row) {

                    /* if it's the default pool then show an unbounded members message */
                    if (type == "display" && row.pool_id == defaultPoolId) return i18n.unbounded_members;

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
                        return arrayToListString(memberNames, 10);
                    }
                }
            },
            {
                data: 'recipients',
                width: '40%',
                render: function(data, type, row) {

                    if (type == "display") {
                        return arrayToListString(data, 10);
                    }
                }
            },
            {
                data: 'configset_details.name',
            },
            {
                data: null, targets: -1, className: 'text-center',
                width: "10%",
                render: function(data, type, pool) {

                    let deleteButton = "";
                    // if the current pool is the default one then don't show the delete button
                    if (pool.pool_id != defaultPoolId) {
                        deleteButton = `
                            <a data-toggle="modal" class="btn btn-danger" href="#remove-pool">
                                <i class="fas fa-trash"></i>
                            </a>
                        `;
                    }

                    return (`
                        <div class='btn-group btn-group-sm'>
                            <a data-toggle="modal" class="btn btn-sm btn-info" href="#edit-pool">
                                <i class="fas fa-edit"></i>
                            </a>
                            ${deleteButton}
                        </div>
                    `);
                }
            }
        ]
    });

    const $poolTable = $(`#table-pools`).DataTable(dtConfig);

    $(`#add-pool form`).modalHandler({
        method: 'post',
        csrf: addCsrf,
        resetAfterSubmit: false,
        endpoint: endpoints.add_pool,
        onModalInit: function() {
            // sort the select entries
            sortSelectByValue(`#add-pool form select[name='members']`);
        },
        beforeSumbit: function() {

            const members = $(`#add-pool form select[name='members']`).val() || [];
            const recipients = $(`#add-pool form select[name='recipients']`).val() || [];

            $(`#add-modal-feedback`).hide();

            return {
                pool_name: $(`#add-pool form input[name='name']`).val().trim(),
                confset_id: $(`#add-pool form select[name='configset']`).val(),
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
            modalHandler.cleanForm();
            $(`#add-pool`).modal('hide');
        }
    }).invokeModalInit();

    const $editModalHandler = $(`#edit-pool form`).modalHandler({
        method: 'post',
        csrf: editCsrf,
        endpoint: endpoints.edit_pool,
        resetAfterSubmit: false,
        onModalInit: function() {

            // disable pool name field if we are editing the default pool
            // also hide the members multiselect
            if (poolRowData.pool_id == defaultPoolId) {
                $(`#edit-pool form input[name='name']`).attr("readonly", "true");
                $(`#edit-pool .members-container`).hide();
            }
            else {
                $(`#edit-pool form input[name='name']`).removeAttr("readonly");
                $(`#edit-pool .members-container`).show();
            }

            sortSelectByValue(`#edit-pool form select[name='members']`);

            // disable all the options whose have a data-pool-id attribute
            $(`#edit-pool form select[name='members'] option[data-pool-id]`).attr("disabled", "disabled");

            // enable only the option used by the pool
            $(`#edit-pool form select[name='members'] option`).each(function() {

                const id = $(this).val();
                // if the id belong to the pool then remove the disabled attribute
                if (poolRowData.members.indexOf(id) > -1) {
                    $(this).removeAttr("disabled");
                }
            });

            $(`#edit-pool-name-input`).off('keyup').on('keyup', function() {
                const name = $(this).val()
                $(`[data-pool-id='${poolRowData.pool_id}']`).each(function() {
                    const m = $(this).val();
                    $(this).text(`${all_members[m].name || m} (${name})`);
                });
            });

            // load the modal with the pool data
            $(`#edit-pool form input[name='name']`).val(poolRowData.name);
            $(`#edit-pool form select[name='configset']`).val(poolRowData.configset_id);
            $(`#edit-pool form select[name='members']`).val(poolRowData.members);
            $(`#edit-pool form select[name='recipients']`).val(poolRowData.recipients || []);

            if (poolType == "host") {
                const href = $(`#edit-link`).attr('href').replace(/pool\=[0-9]+/, `pool=${poolRowData.pool_id}`);
                $(`#edit-link`).attr('href', href);
            }
        },
        beforeSumbit: function() {

            const members = $(`#edit-pool form select[name='members']`).val() || [];
            const recipients = $(`#edit-pool form select[name='recipients']`).val() || [];

            const data = {
                pool: poolRowData.pool_id,
                pool_name: $(`#edit-pool form input[name='name']`).val().trim(),
                confset_id: $(`#edit-pool form select[name='configset']`).val(),
                recipients: recipients.join(',')
            };

            if (poolType != "host") {
                data.pool_members = members.join(',');
            }
            else {
                data.pool_members = poolRowData.members.join(',');
            }

            return data;
        },
        onSubmitSuccess: function (response, textStatus, modalHandler) {

            if (response.rc < 0) {
                $(`#edit-modal-feedback`).html(i18n.rest[response.rc_str]).fadeIn();
                return;
            }

            const newPoolName = $(`#edit-pool form input[name='name']`).val();
            // update the pool name inside the selects if changed
            if (newPoolName != poolRowData.name) {
                $(`option[data-pool-id='${poolRowData.pool_id}']`).each(function() {
                    const value = $(this).val();
                    if (poolType != "host")
                        $(this).text(`${all_members[value].name || value} (${i18n.used_by} ${newPoolName})`)
                });
            }

            // the host pool modals don't have any members
            if (poolType != "host" && poolRowData.pool_id != defaultPoolId) {
                // get the newMembers and the oldMembers and create two subset of them
                const oldMembers = poolRowData.members;
                const newMembers = $(`#edit-pool form select[name='members']`).val();
                // this subset contains the removed members from the pool
                const oldToRenable = oldMembers.filter((m1) => !newMembers.find(m2 => m1 == m2));
                // this subset contains the new members added to the pool
                const newToMark = newMembers.filter((m1) => !oldMembers.find(m2 => m1 == m2));

                renableDisabledOptions(`#add-pool form select[name='members']`, oldToRenable);
                renableDisabledOptions(`#edit-pool form select[name='members']`, oldToRenable);

                markUsedOptions(`#add-pool form select[name='members']`, newToMark, newPoolName, poolRowData.pool_id);
                markUsedOptions(`#edit-pool form select[name='members']`, newToMark, newPoolName, poolRowData.pool_id);
            }

            // clean the form and reload the table
            modalHandler.cleanForm();
            $poolTable.ajax.reload();
            $(`#edit-pool`).modal('hide');
        }
    });

    const $removeModalHandler = $(`#remove-pool form`).modalHandler({
        method: 'post',
        csrf: removeCsrf,
        endpoint: endpoints.delete_pool,
        resetAfterSubmit: false,
        onModalInit: function() {
            $(`#remove-pool form input[name='pool_id']`).val(poolRowData.pool_id);
            $(`#remove-pool form button[type='submit']`).removeAttr("disabled");
            $(`.delete-pool-name`).text(poolRowData.name);
        },
        beforeSumbit: function() {
            return {
                pool: $(`#remove-pool form input[name='pool_id']`).val(),
            };
        },
        onSubmitSuccess: function (response, textStatus, modalHandler) {

            if (response.rc < 0) {
                $(`#remove-modal-feedback`).html(i18n.rest[response.rc_str]).fadeIn();
                return;
            }

            // renable the members removed from the pool inside the modal
            renableDisabledOptions(`#add-pool form select[name='members']`, poolRowData.members);
            renableDisabledOptions(`#edit-pool form select[name='members']`, poolRowData.members);

            modalHandler.cleanForm();
            $poolTable.ajax.reload();
            $(`#remove-pool`).modal('hide');
        }
    });

    $(`#table-pools`).on('click', `a[href='#edit-pool']`, function (e) {
        poolRowData = $poolTable.row($(this).parent().parent()).data();
        $editModalHandler.invokeModalInit();
    });

    $(`#table-pools`).on('click', `a[href='#remove-pool']`, function (e) {
        poolRowData = $poolTable.row($(this).parent().parent()).data();
        $removeModalHandler.invokeModalInit();
    });

});
