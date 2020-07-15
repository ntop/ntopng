/**
 * (C) 2020 - ntop.org
 *
 * This script implements the logic to manage the pools inside ntopng gui
 */
$(document).ready(function() {

    let poolRowData;

    const renableDisabledOptions = (selector, members) => {
        members.forEach(m => {
            $(`${selector} option[value='${m}']`)
                .removeAttr("disabled").removeAttr("data-pool-id").text(all_members[m].name);
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
            { data: 'name', width: "20%" },
            {
                data: null,
                width: "40%",
                render: function(data, type, row) {

                    if (type == "display" && row.members.length == 0) return "";
                    // show only the first 10 members, append some dots
                    // if the members are more than 10
                    const memberNames = row.members.map((memberId) => {
                        if (all_members[memberId].name == undefined) return memberId;
                        return all_members[memberId].name;
                    });
                    return memberNames.slice(0, 10).join("; ") + (memberNames.length >= 10 ? "..." : "");
                }
            },
            {
                data: 'configset_details.name',
            },
            {
                data: null, targets: -1, className: 'text-center',
                width: "10%",
                render: function() {
                    return (`
                        <div class='btn-group btn-group-sm'>
                            <a data-toggle="modal" class="btn btn-sm btn-info" href="#edit-pool">
                                <i class="fas fa-edit"></i>
                            </a>
                            <a data-toggle="modal" class="btn btn-danger" href="#remove-pool">
                                <i class="fas fa-trash"></i>
                            </a>
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

            $(`#add-modal-feedback`).hide();

            return {
                pool_name: $(`#add-pool form input[name='name']`).val().trim(),
                pool_members: $(`#add-pool form select[name='members']`).val().join(','),
                confset_id: $(`#add-pool form select[name='configset']`).val(),
            };
        },
        onSubmitSuccess: function (response, textStatus, modalHandler) {

            if (response.rc < 0) {
                $(`#add-modal-feedback`).html(i18n.rest[response.rc_str]).fadeIn();
                return;
            }

            const poolName = $(`#add-pool form input[name='name']`).val().trim();
            // get the new members array
            const members = $(`#add-pool form select[name='members']`).val();
            // mark select entries with the new pool created
            markUsedOptions(`#add-pool form select[name='members']`, members, poolName, response.rsp.pool_id);
            markUsedOptions(`#edit-pool form select[name='members']`, members, poolName, response.rsp.pool_id);

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

            // load the modal with the pool data
            $(`#edit-pool form input[name='name']`).val(poolRowData.name);
            $(`#edit-pool form select[name='configset']`).val(poolRowData.configset_id);
            $(`#edit-pool form select[name='members']`).val(poolRowData.members);
        },
        beforeSumbit: function() {
            return {
                pool: poolRowData.pool_id,
                pool_name: $(`#edit-pool form input[name='name']`).val().trim(),
                pool_members: $(`#edit-pool form select[name='members']`).val().join(','),
                confset_id: $(`#edit-pool form select[name='configset']`).val(),
            };
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
                    $(this).text(`${all_members[value].name} (${i18n.used_by} ${newPoolName})`)
                });
            }

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
            $(`#delete-pool-name`).text(poolRowData.name);
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