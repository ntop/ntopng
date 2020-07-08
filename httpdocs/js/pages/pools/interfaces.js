$(document).ready(function() {

    const removeMemberFromModals = (members) => {
        $(`#add-pool form select[name='members'] option, #edit-pool form select[name='members'] option`).each(function() {
            const val = $(this).val();
            if (members.indexOf(val) > -1) $(this).remove();
        });
    }

    const addMembersIntoModal = (selector, members, addClass = false) => {
        members.forEach(function(member) {

            // if the member is already in the list then don't add it
            const $member = $(selector).find(`option[value='${member.id}']`);
            if ($member.length > 0 && $member.hasClass('added')) {
                $member.removeClass('added');
                return;
            }

            $(selector).append(`<option ${ addClass ? "class='added'" : ""} value='${member.id}'>${member.name}</option>`);
        });
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

            $poolTable.ajax.reload();

            // remove the selected members
            const members = $(`#add-pool form select[name='members']`).val();
            removeMemberFromModals(members);

            // clean the form and hide the modal
            modalHandler.cleanForm();
            $(`#add-pool`).modal('hide');

        }
    }).invokeModalInit();

    const $editModalHandler = $(`#edit-pool form`).modalHandler({
        method: 'post',
        csrf: addCsrf,
        endpoint: `${ http_prefix }/lua/rest/v1/edit/interface/pool.lua`,
        resetAfterSubmit: false,
        onModalInit: function() {

            $(`#edit-pool form input[name='pool_id']`).val(poolRowData.pool_id);
            $(`#edit-pool form input[name='name']`).val(poolRowData.name);
            $(`#edit-pool form select[name='configset']`).val(poolRowData.configset_id);

            // render the pool's member inside the modal
            const members = poolRowData.members.map(m => {
                return { id: m, name: poolRowData.member_details[m].name }
            });
            const membersId = members.map(m => m.id);
            // delete the old members from prevuius session
            $(`#edit-pool form select[name='members'] option.added`).remove();
            addMembersIntoModal(`#edit-pool form select[name='members']`, members, true);

            $(`#edit-pool form select[name='members']`).val(membersId);
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

            const oldMembers = poolRowData.members.map(m => {
                return { id: m, name: $(`#edit-pool form select[name='members'] option[value='${m}']`).text() }
            });
            const newMembers = $(`#edit-pool form select[name='members']`).val().map(m => {
                return { id: m, name: $(`#edit-pool form select[name='members'] option[value='${m}']`).text() }
            });

            let members = [];

            if (newMembers.length > oldMembers.length) {
                removeMemberFromModals(newMembers.map(m => m.id));
            }
            else if (newMembers.length < oldMembers.length) {

                // get only the removed member
                oldMembers.forEach(member => {
                    if (newMembers.find(m2 => member.id == m2.id)) return;
                    members.push(member);
                });

                // add the removed member into add modal
                addMembersIntoModal(`#add-pool form select[name='members']`, members);
                addMembersIntoModal(`#edit-pool form select[name='members']`, members);
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

            // add deleted member to the modals
            const members = poolRowData.members.map(m => {
                return { id: m, name: poolRowData.member_details[m].name }
            });
            console.log(members);
            addMembersIntoModal(`#add-pool form select[name='members']`, members);
            addMembersIntoModal(`#edit-pool form select[name='members']`, members);

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