$(document).ready(function() {

    const renableDisabledOptions = (selector, members) => {
        members.forEach(m => {
            $(`${selector} option[value='${m}']`).removeAttr("disabled").removeAttr("data-pool-id").text(all_members[m].name);
        });
    }

    const markUsedOptions = (selector, members, poolName, poolId) => {
        members.forEach(m => {
            $(`${selector} option[value='${m}']`)
                .attr("disabled", "disabled")
                .attr("data-pool-id", poolId)
                .text(`${all_members[m].name} (${i18n.used_by} ${poolName})`);
        });
    }

    const sortSelectByValue = (selector) => {

        const $options = $(`${selector} option`);
        $options.sort((a, b) => $(a).val() - $(b).val());

        $(selector).empty().append($options);
    }

    let poolRowData;

    let dtConfig = DataTableUtils.getStdDatatableConfig( [
        {
            text: '<i class="fas fa-plus"></i>',
            action: () => { $(`#add-pool`).modal('show'); }
        }
    ]);
    dtConfig = DataTableUtils.setAjaxConfig(dtConfig, `${http_prefix}/lua/rest/v1/get/interface/pools.lua`, 'rsp');
    dtConfig = DataTableUtils.extendConfig(dtConfig, {
        stateSave: true,
        columns: [
            { data: 'pool_id' },
            { data: 'name' },
            {
                data: null, targets: -1, className: 'text-center',
                render: function() {
                    return (`
                        <a data-toggle="modal" class="badge badge-info" href="#edit-pool">
                            ${i18n.edit}
                        </a>
                        <a data-toggle="modal" class="badge badge-danger" href="#remove-pool">
                            ${i18n.delete}
                        </a>
                    `);
                }
            }
        ]
    });

    const $poolTable = $(`#interfaces-pool`).DataTable(dtConfig);

    $(`#add-pool form`).modalHandler({
        method: 'post',
        csrf: addCsrf,
        resetAfterSubmit: false,
        endpoint: `${http_prefix}/lua/rest/v1/add/interface/pool.lua`,
        onModalInit: function() {
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
            const members = $(`#add-pool form select[name='members']`).val();
            markUsedOptions(`#add-pool form select[name='members']`, members, poolName, response.rsp.pool_id);
            markUsedOptions(`#edit-pool form select[name='members']`, members, poolName, response.rsp.pool_id);

            // reload the pool table
            $poolTable.ajax.reload();
            // clean the form and hide the modal
            modalHandler.cleanForm();
            $(`#add-pool`).modal('hide');
        }
    }).invokeModalInit();

    const $editModalHandler = $(`#edit-pool form`).modalHandler({
        method: 'post',
        csrf: editCsrf,
        endpoint: `${ http_prefix }/lua/rest/v1/edit/interface/pool.lua`,
        resetAfterSubmit: false,
        onModalInit: function() {

            $(`#edit-pool form select[name='members'] option[data-pool-id]`).attr("disabled", "disabled");

            $(`#edit-pool form select[name='members'] option`).each(function() {

                const id = $(this).val();
                if (poolRowData.members.indexOf(id) > -1) {
                    $(this).removeAttr("disabled");
                }
            });

            $(`#edit-pool form input[name='pool_id']`).val(poolRowData.pool_id);
            $(`#edit-pool form input[name='name']`).val(poolRowData.name);
            $(`#edit-pool form select[name='configset']`).val(poolRowData.configset_id);
            $(`#edit-pool form select[name='members']`).val(poolRowData.members);
        },
        beforeSumbit: function() {
            return {
                pool: $(`#edit-pool form input[name='pool_id']`).val(),
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
            const oldMembers = poolRowData.members;
            const newMembers = $(`#edit-pool form select[name='members']`).val();

            // update the pool name inside the selects
            if (newPoolName != poolRowData.name) {
                $(`option[data-pool-id='${poolRowData.pool_id}']`).each(function() {
                    const value = $(this).val();
                    $(this).text(`${all_members[value].name} (${i18n.used_by} ${newPoolName})`)
                });
            }

            if (newMembers.length > oldMembers.length) {
                markUsedOptions(`#add-pool form select[name='members']`, newMembers, newPoolName, poolRowData.pool_id);
                markUsedOptions(`#edit-pool form select[name='members']`, newMembers, newPoolName, poolRowData.pool_id);
            }
            else if (newMembers.length < oldMembers.length) {

                let members = [];

                oldMembers.forEach(m1 => {
                    if (newMembers.find(m2 => m1 == m2)) return;
                    members.push(m1);
                });

                renableDisabledOptions(`#add-pool form select[name='members']`, members);
                renableDisabledOptions(`#edit-pool form select[name='members']`, members);
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
        endpoint: `${ http_prefix }/lua/rest/v1/delete/interface/pool.lua`,
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

            renableDisabledOptions(`#add-pool form select[name='members']`, poolRowData.members);
            renableDisabledOptions(`#edit-pool form select[name='members']`, poolRowData.members);

            modalHandler.cleanForm();
            $poolTable.ajax.reload();
            $(`#remove-pool`).modal('hide');
        }
    });

    $(`#interfaces-pool`).on('click', `a[href='#edit-pool']`, function (e) {
        poolRowData = $poolTable.row($(this).parent()).data();
        $editModalHandler.invokeModalInit();
    });

    $(`#interfaces-pool`).on('click', `a[href='#remove-pool']`, function (e) {
        poolRowData = $poolTable.row($(this).parent()).data();
        $removeModalHandler.invokeModalInit();
    });

});