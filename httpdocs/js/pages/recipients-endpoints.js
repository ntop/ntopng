$(function () {

    const TABLE_DATA_REFRESH = 15000;
    const DEFAULT_RECIPIENT_ID = 0;
    const COLUMN_INDEX_ENDPOINT_TYPE = 1;

    const makeFormData = (formSelector) => {

        const $inputsTemplate = $(`${formSelector} .recipient-template-container [name]`);

        const params = {
            recipient_name: $(`${formSelector} [name='recipient_name']`).val(),
            endpoint_id: $(`${formSelector} [name='endpoint']`).val(),
            recipient_minimum_severity: $(`${formSelector} [name='recipient_minimum_severity']`).val(),
            recipient_check_categories: $(`${formSelector} [name='recipient_check_categories']`).val().join(","),
            bind_to_all_pools: $(`${formSelector} [name='bind_to_all_pools']`).prop('checked')
        };

        // load each recipient params inside the template container in params
        $inputsTemplate.each(function (i, input) {
            params[$(this).attr('name')] = $(this).val().trim();
        });

        return params;
    }

    const generateUsersList = (pools) => {

        const $list = $(`#users-recipient-modal .list-group`);
        // clean the list
        $list.empty();
        // show the list
        $list.show();

        // add a pool link for each pool
        for (const pool of pools) {

            const $listEntry = $(`<a class='list-group-item list-group-item-action' href='#'><b>${pool.name}</b></a>`);
            $listEntry.append($(`<small class='text-muted d-block'>${i18n.pool_types[pool.key]}</small>`));
            $listEntry.attr('href', `${http_prefix}/lua/admin/manage_pools.lua?page=${pool.key}&pool_id=${pool.pool_id}`);
            $list.append($listEntry);
        }

    }

    const testRecipient = async (data, $button, $feedbackLabel) => {

        const body = { action: 'test', csrf: pageCsrf };
        $.extend(body, data);

        $button.attr("disabled", "disabled");
        $button.find('span.spinner-border').fadeIn();
        $feedbackLabel.removeClass(`alert-danger alert-success`).text(`${i18n.testing_recipient}...`).show();

        try {

            const request = await NtopUtils.fetchWithTimeout(`${http_prefix}/lua/edit_notification_recipient.lua`, {
                method: 'post',
                body: JSON.stringify(body),
                headers: {
                    'Content-Type': 'application/json'
                }
            }, 5000);
            const { result } = await request.json();

            if (result.status === "failed") {
                $button.find('span.spinner-border').fadeOut(function () {
                    $feedbackLabel.addClass(`alert-danger`).html(result.error.message);
                });
                return;
            }

            // show a green label to alert the endpoint message
            $button.find('span.spinner-border').fadeOut(function () {
                $feedbackLabel.addClass('alert-success').html(i18n.working_recipient).fadeOut(3000);
            });

        }
        catch (err) {

            $button.find('span.spinner-border').fadeOut(function () {

                $feedbackLabel.addClass(`alert-danger`);

                if (err.message == "Response timed out") {
                    $feedbackLabel.html(i18n.timed_out);
                    return;
                }
                $feedbackLabel.html(i18n.server_error);
            });
        }
        finally {
            $button.removeAttr("disabled");
        }

    }

    const createTemplateOnSelect = (formSelector) => {

        const $templateContainer = $(`${formSelector} .recipient-template-container`);
        // on Endpoint Selection load the right template to fill
        $(`${formSelector} select[name='endpoint']`).change(function (e) {
            const $option = $(this).find(`option[value='${$(this).val()}']`);
            const $cloned = cloneTemplate($option.data('endpointKey'));
            // show the template inside the modal container
            $templateContainer.hide().empty();
            if ($cloned) {
                $templateContainer.append($(`<hr>`));
                $templateContainer.append($cloned).show();
            }
            $(`${formSelector} span.test-feedback`).fadeOut();
        });
    }

    function cloneTemplate(type) {

        const template = $(`template#${type}-template`).html();
        // if the template is not empty then return a copy of the template content
        if (template.trim() != "") {
            const $template = $(template);
            return $template;
        }

        return (null);
    }

    let dtConfig = DataTableUtils.getStdDatatableConfig([
        {
            text: '<i class="fas fa-plus"></i>',
            className: 'btn-link',
            attr: {
                id: 'btn-add-recipient',
            },
            enabled: CAN_CREATE_RECIPIENT,
            action: function (e, dt, node, config) {
                $('#add-recipient-modal').modal('show');
            }
        },
        {
            text: '<i class="fas fa-sync"></i>',
            action: function (e, dt, node, config) {
                $recipientsTable.ajax.reload();
            }
        }
    ]);
    dtConfig = DataTableUtils.setAjaxConfig(dtConfig, `${http_prefix}/lua/get_recipients_endpoint.lua`);
    dtConfig = DataTableUtils.extendConfig(dtConfig, {
        columns: [
            {
                data: 'recipient_name'
            },
            {
                data: `endpoint_key`,
                render: (endpointType, type, recipient) => {

                    if (type == "display") {

                        let badge = '';
                        const isBuiltin = (recipient.endpoint_conf && recipient.endpoint_conf.builtin) || false;

                        if (isBuiltin) {
                            badge = `<span class='badge bg-dark'>built-in</span>`;
                        }

                        return `${i18n.endpoint_types[endpointType]} ${badge}`;
                    }

                    if (type == 'filter') {
                        return endpointType;
                    }

                    return i18n.endpoint_types[endpointType] || ""
                }
            },
            {
                data: 'endpoint_conf_name',
                render: (endpointName, type, recipient) => {

                    if (type == "display") {

                        const destPage = NtopUtils.buildURL(`/lua/admin/endpoint_notifications_list.lua`, {
                            endpoint_conf_name: recipient.endpoint_conf_name
                        });

                        return (`<a href='${destPage}'>${endpointName}</a>`);
                    }

                    return endpointName;
                }
            },
            {
                data: "stats.last_use",
                className: "text-center",
                width: "15%",
                render: $.fn.dataTableExt.absoluteFormatSecondsToHHMMSS
            },
            {
                data: "stats.num_uses",
                className: "text-right",
                width: "10%",
                render: function (data, type) {
                    if (type === "display") return NtopUtils.fint(data);
                    return data;
                }
            },
            {
                data: "stats.num_drops",
                className: "text-right",
                width: "10%",
                render: function (data, type) {
                    if (type == "display") return NtopUtils.fint(data);
                    return data;
                }
            },
            {
                data: "stats.fill_pct",
                className: "text-right",
                width: "5%",
                render: function (data, type) {
                    if (type == "display") return NtopUtils.fpercent(data);
                    return data;
                }
            },
            {
                targets: -1,
                className: 'text-center',
                data: null,
                render: function (_, type, recipient) {

                    if (!recipient.endpoint_conf) return '';

                    const isBuiltin = (recipient.endpoint_conf && recipient.endpoint_conf.builtin) || false;

                    return DataTableUtils.createActionButtons([
                        { class: `btn-info ${isBuiltin ? 'disabled' : ''}`, icon: 'fa fa-users', modal: '#users-recipient-modal' },
                        { class: 'btn-info' /* Builtins are editable to change theis severity */, icon: 'fa-edit', modal: '#edit-recipient-modal' },
                        { class: `btn-danger ${isBuiltin ? 'disabled' : ''}`, icon: 'fa-trash', modal: '#remove-recipient-modal' },
                    ]);
                }
            }
        ],
        hasFilters: true,
        stateSave: true,
        initComplete: function (settings, json) {

            const tableAPI = settings.oInstance.api();

            // initialize add button tooltip
            if (!CAN_CREATE_RECIPIENT) {
                // wrap the button inside a span to show tooltip as request by the bootstrap framework
                $(`#btn-add-recipient`).wrap(function() {
                    return `<span id='suggest-tooltip' title='${i18n.createEndpointFirst}' class='d-inline-block' data-toggle='tooltip'></span>`;
                });
                $(`#suggest-tooltip`).tooltip();
            }

            // when the data has been fetched check if the url has a recipient_id param
            // if the recipient is builtin then cancel the modal opening
            DataTableUtils.openEditModalByQuery({
                paramName: 'recipient_id',
                datatableInstance: tableAPI,
                modalHandler: $editRecipientModal,
                cancelIf: (recipient) => recipient.endpoint_conf.builtin,
            });

            // reload data each TABLE_DATA_REFRESH milliseconds
            setInterval(() => { tableAPI.ajax.reload(); }, TABLE_DATA_REFRESH);
        }
    });

    const $recipientsTable = $(`table#recipient-list`).DataTable(dtConfig);
    DataTableUtils.addToggleColumnsDropdown($recipientsTable);

    const endpointTypeFilterMenu = new DataTableFiltersMenu({
        filterTitle: i18n.endpoint_type,
        filters: endpointTypeFilters,
        columnIndex: COLUMN_INDEX_ENDPOINT_TYPE,
        tableAPI: $recipientsTable,
        filterMenuKey: 'endpoint-type'
    }).init();

    /* bind add endpoint event */
    $(`#add-recipient-modal form`).modalHandler({
        method: 'post',
        endpoint: `${http_prefix}/lua/edit_notification_recipient.lua`,
        csrf: pageCsrf,
        resetAfterSubmit: false,
        beforeSumbit: () => {

            $(`#add-recipient-modal form button[type='submit']`).click(function () {
                $(`#add-recipient-modal form span.invalid-feedback`).hide();
            });

            $(`#add-recipient-modal .test-feedback`).hide();

            const data = makeFormData(`#add-recipient-modal form`);
            data.action = 'add';

            return data;
        },
        onModalInit: () => { createTemplateOnSelect(`#add-recipient-modal`); },
        onModalShow: () => {
            // load the template of the selected endpoint
            const $cloned = cloneTemplate($(`#add-recipient-modal select[name='endpoint'] option:selected`).data('endpointKey'));
            if ($cloned) {
                $(`#add-recipient-modal form .recipient-template-container`).empty().append($(`<hr>`), $cloned).show();
            }
        },
        onSubmitSuccess: function (response) {

            if (response.result.status == "OK") {
                $(`#add-recipient-modal`).modal('hide');
                $(`#add-recipient-modal form .recipient-template-container`).hide();
                $recipientsTable.ajax.reload();
                return;
            }

            if (response.result.error) {
                const localizedString = i18n[response.result.error.type];
                $(`#add-recipient-modal form span.invalid-feedback`).text(localizedString).show();
            }
        }
    }).invokeModalInit();

    const $editRecipientModal = $('#edit-recipient-modal form').modalHandler({
        method: 'post',
        csrf: pageCsrf,
        endpoint: `${http_prefix}/lua/edit_notification_recipient.lua`,
        beforeSumbit: function () {
            const data = makeFormData(`#edit-recipient-modal form`);
            data.action = 'edit';
            data.recipient_id = $(`#edit-recipient-modal form [name='recipient_id']`).val();
            return data;
        },
        onModalInit: function (recipient) {

            $(`#edit-recipient-modal .test-feedback`).hide();

            // if there are no recipients params it means there are no inputs except the recipient's name
            if (recipient.recipient_params.length === undefined) {
                /* load the template from templates inside the page */
                const $cloned = cloneTemplate(recipient.endpoint_key);
                $(`#edit-recipient-modal form .recipient-template-container`)
                    .empty().append($(`<hr>`)).append($cloned).show();
            }
            else {
                $(`#edit-recipient-modal form .recipient-template-container`).empty().hide();
            }

            $(`#edit-recipient-name`).text(recipient.recipient_name);
            /* load the values inside the template */
            $(`#edit-recipient-modal form [name='recipient_id']`).val(recipient.recipient_id || DEFAULT_RECIPIENT_ID);
            $(`#edit-recipient-modal form [name='recipient_name']`).val(recipient.recipient_name);
	    if(recipient.endpoint_conf.builtin)
		$(`#edit-recipient-modal form [name='recipient_name']`).attr('readonly', '');
            $(`#edit-recipient-modal form [name='endpoint_conf_name']`).val(recipient.endpoint_conf_name);
            $(`#edit-recipient-modal form [name='recipient_minimum_severity']`).val(recipient.minimum_severity);
            $(`#edit-recipient-modal form [name='recipient_check_categories']`).val(recipient.check_categories);
            $(`#edit-recipient-modal form [name='recipient_check_categories']`).selectpicker('refresh');
            $(`#edit-recipient-modal form .recipient-template-container [name]`).each(function (i, input) {
                $(this).val(recipient.recipient_params[$(this).attr('name')]);
            });
            /* bind testing button */
            $(`#edit-test-recipient`).off('click').click(async function (e) {
                e.preventDefault();
                const $self = $(this);
                $self.attr("disabled");
                const data = makeFormData(`#edit-recipient-modal form`);
                data.endpoint_id = recipient.endpoint_id;
                testRecipient(data, $(this), $(`#edit-recipient-modal .test-feedback`)).then(() => {
                    $self.removeAttr("disabled");
                });
            });
        },
        onModalShow: function () {
            $(`#edit-recipient-modal .test-feedback`).hide();
        },
        onSubmitSuccess: function (response) {
            if (response.result.status == "OK") {
                $(`#edit-recipient-modal`).modal('hide');
                $recipientsTable.ajax.reload();
            }
        }
    });

    const $removeRecipientModal = $(`#remove-recipient-modal form`).modalHandler({
        method: 'post',
        csrf: pageCsrf,
        endpoint: `${http_prefix}/lua/edit_notification_recipient.lua`,
        dontDisableSubmit: true,
        onModalInit: (recipient) => {
            $(`.removed-recipient-name`).text(`${recipient.recipient_name}`);
        },
        beforeSumbit: (recipient) => {
            return {
                action: 'remove',
                recipient_id: recipient.recipient_id || DEFAULT_RECIPIENT_ID
            }
        },
        onSubmitSuccess: (response) => {
            if (response.result) {
                $(`#remove-recipient-modal`).modal('hide');
                $recipientsTable.ajax.reload();
            }
        }
    });

    /* bind edit recipient event */
    $(`table#recipient-list`).on('click', `a[href='#edit-recipient-modal']`, function (e) {

        const selectedRecipient = $recipientsTable.row($(this).parent().parent()).data();

        $editRecipientModal.invokeModalInit(selectedRecipient);
    });

    /* bind remove endpoint event */
    $(`table#recipient-list`).on('click', `a[href='#remove-recipient-modal']`, function (e) {

        const selectedRecipient = $recipientsTable.row($(this).parent().parent()).data();
        // prevent removing builtin
        if (selectedRecipient.endpoint_conf.builtin) {
            e.preventDefault();
            return;
        }

        $removeRecipientModal.invokeModalInit(selectedRecipient);
    });

    /* bind recipient users button */
    $(`table#recipient-list`).on('click', `a[href='#users-recipient-modal']`, async function () {

        const { recipient_id, recipient_name } = $recipientsTable.row($(this).parent().parent()).data();
        $(`.recipient-name`).text(recipient_name);
        $(`.fetch-failed,.zero-user`).hide();

        try {

            const response = await fetch(`${http_prefix}/lua/rest/v2/get/recipient/pools.lua?recipient_id=${recipient_id}`);
            const { rsp } = await response.json();

            // if there are no pools for the selected recipient shows a message
            if (rsp.length == 0) {
                $(`.zero-user`).show();
                $(`#users-recipient-modal .list-group`).hide();
                return;
            }

            generateUsersList(rsp);

        }
        catch (err) {
            console.warn('Unable to show the recipient users');
            $(`.fetch-failed`).show();
        }

    });

    $(`#add-test-recipient`).click(async function (e) {

        e.preventDefault();

        const $self = $(this);

        testRecipient(makeFormData(`#add-recipient-modal form`), $(this), $(`#add-recipient-modal .test-feedback`))
            .then(() => { $self.removeAttr("disabled"); });
    });

    $(`[name='recipient_check_categories']`).on('changed.bs.select', function (e, clickedIndex, isSelected, previousValue) {

        const lessThanOne = $(this).val().length < 1;

        if (lessThanOne) {
            $(this).val(previousValue);
            $(this).selectpicker('refresh');
        }
    });

});
