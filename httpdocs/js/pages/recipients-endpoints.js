// @ts-nocheck
$(document).ready(function () {

    const DEFAULT_RECIPIENT_ID = 0;
    const INDEX_COLUMN_ENDPOINT_TYPE = 2;

    let editRowData = null;
    let removeRowData = null;

    function makeFormData(formSelector) {

        const $inputsTemplate = $(`${formSelector} .recipient-template-container [name]`);

        const params = {
            recipient_name: $(`${formSelector} [name='recipient_name']`).val(),
            endpoint_conf_name: $(`${formSelector} [name='endpoint']`).val(),
        };

        // load each recipient params inside the template container in params
        $inputsTemplate.each(function (i, input) {
            params[$(this).attr('name')] = $(this).val().trim();
        });

        return params;
    }

    async function testRecipient(data, $button, $feedbackLabel) {

        const body = { action: 'test', csrf: pageCsrf };
        $.extend(body, data);

        $button.find('span.spinner-border').fadeIn();
        $feedbackLabel.removeClass(`text-danger text-success`).text(`${i18n.testing_recipient}...`).show();

        try {

            const request = await NtopUtils.fetchWithTimeout(`${http_prefix}/lua/edit_notification_recipient.lua`, {
		method: 'post',
		body: JSON.stringify(body),
		headers: {
		    'Content-Type': 'application/json'
		}
	    }, 5000);
            const {result} = await request.json();

            if (result.status == "failed") {
                $button.find('span.spinner-border').fadeOut(function() {
                    $feedbackLabel.addClass(`text-danger`).html(result.error.message);
                });
                return;
            }

            // show a green label to alert the endpoint message
            $button.find('span.spinner-border').fadeOut(function() {
                $feedbackLabel.addClass('text-success').html(i18n.working_recipient).fadeOut(3000);
            });

        }
        catch (err) {

            $button.find('span.spinner-border').fadeOut(function() {

                $feedbackLabel.addClass(`text-danger`);

                if (err.message == "Response timed out") {
                    $feedbackLabel.html(i18n.timed_out);
                    return;
                }

                $feedbackLabel.html(i18n.server_error);

            });
        }

    }

    function createTemplateOnSelect(formSelector) {

        const $templateContainer = $(`${formSelector} .recipient-template-container`);
        // on Endpoint Selection load the right template to fill
        $(`${formSelector} select[name='endpoint']`).change(function (e) {
            const $option = $(this).find(`option[value='${$(this).val()}']`);
            const $cloned = loadTemplate($option.data('endpointKey'));
            // show the template inside the modal container
            $templateContainer.hide().empty();
            if ($cloned) {
                $templateContainer.append($cloned).fadeIn();
            }
            $(`${formSelector} span.test-feedback`).fadeOut();
        });
    }

    function loadTemplate(type) {

        const template = $(`template#${type}-template`).html();
        // if the template is not empty then return a copy of the template content
        if (template.trim() != "") return $(template);

        return null;
    }

    let dtConfig = DataTableUtils.getStdDatatableConfig([
        {
            text: '<i class="fas fa-plus"></i>',
            className: 'btn-link',
            action: function (e, dt, node, config) {
                $('#add-recipient-modal').modal('show');
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
                data: 'endpoint_conf.endpoint_conf_name'
            },
            {
                data: `endpoint_conf.endpoint_key`,
                render: function(endpointType) {
                    return i18n.endpoint_types[endpointType];
                }
            },
            {
                targets: -1,
                className: 'text-center',
                data: null,
                render: function (data, type, row) {
                    return (`
                        <div class='btn-group btn-group-sm'>
                            <a data-toggle='modal' href='#edit-recipient-modal' class="btn btn-info" >
                                <i class='fas fa-edit'></i>
                            </a>
                            <a data-toggle='modal' href='#remove-recipient-modal' class="btn btn-danger">
                                <i class='fas fa-trash'></i>
                            </a>
                        </div>
                    `);
                }
            }
        ],
        hasFilters: true,
        stateSave: true,
        initComplete: function(settings, json) {

            const tableAPI = settings.oInstance.api();

            // add a filter to sort the datatable by endpoint type
            DataTableUtils.addFilterDropdown(
                i18n.endpoint_type, endpointTypeFilters, INDEX_COLUMN_ENDPOINT_TYPE, '#recipient-list_filter', tableAPI
            );

        }
    });

    const $recipientsTable = $(`table#recipient-list`).DataTable(dtConfig);

    const $editRecipientHandler = $('#edit-recipient-modal form').modalHandler({
        method: 'post',
        csrf: pageCsrf,
        endpoint: `${http_prefix}/lua/edit_notification_recipient.lua`,
        beforeSumbit: function () {
            const data = makeFormData(`#edit-recipient-modal form`);
            data.action = 'edit';
            data.recipient_id = $(`#edit-recipient-modal form [name='recipient_id']`).val();
            return data;
        },
        onModalInit: function (data) {
            $(`#edit-recipient-modal .test-feedback`).hide();
            const $cloned = loadTemplate(editRowData.endpoint_conf.endpoint_key);
            /* load the right template from templates */
            if ($cloned) {
                $(`#edit-recipient-modal form .recipient-template-container`).empty().append($(`<hr>`)).append($cloned).show();
            }
            else {
                $(`#edit-recipient-modal form .recipient-template-container`).empty().hide();
            }
            $(`#edit-recipient-name`).text(editRowData.recipient_name);
            /* load the values inside the template */
            $(`#edit-recipient-modal form [name='recipient_id']`).val(editRowData.recipient_id || DEFAULT_RECIPIENT_ID);
            $(`#edit-recipient-modal form [name='recipient_name']`).val(editRowData.recipient_name);
            $(`#edit-recipient-modal form [name='endpoint_conf_name']`).val(editRowData.endpoint_conf.endpoint_conf_name);
            $(`#edit-recipient-modal form .recipient-template-container [name]`).each(function (i, input) {
                $(this).val(editRowData.recipient_params[$(this).attr('name')]);
            });
            /* bind testing button */
            $(`#edit-test-recipient`).off('click').click(async function(e) {
                e.preventDefault();
                const $self = $(this);
                $self.attr("disabled");
                const data = makeFormData(`#edit-recipient-modal form`);
                data.endpoint_conf_name = editRowData.endpoint_conf.endpoint_conf_name;
                testRecipient(data, $(this), $(`#edit-recipient-modal .test-feedback`)).then(() => {
                    $self.removeAttr("disabled");
                });
            });
        },
        onModalShow: function() {
            $(`#edit-recipient-modal .test-feedback`).hide();
        },
        onSubmitSuccess: function (response) {
            if (response.result.status == "OK") {
                $(`#edit-recipient-modal`).modal('hide');
                $recipientsTable.ajax.reload();
            }
        }
    });

    /* bind edit recipient event */
    $(`table#recipient-list`).on('click', `a[href='#edit-recipient-modal']`, function (e) {
        editRowData = $recipientsTable.row($(this).parent().parent()).data();
        $editRecipientHandler.invokeModalInit();
    });

    /* bind add endpoint event */
    $(`#add-recipient-modal form`).modalHandler({
        method: 'post',
        endpoint: `${http_prefix}/lua/edit_notification_recipient.lua`,
        csrf: pageCsrf,
        resetAfterSubmit: false,
        beforeSumbit: function () {

            $(`#add-recipient-modal form button[type='submit']`).click(function () {
                $(`#add-recipient-modal form span.invalid-feedback`).hide();
            });

            $(`#add-recipient-modal .test-feedback`).hide();

            const data = makeFormData(`#add-recipient-modal form`);
            data.action = 'add';

            return data;
        },
        onModalInit: function () {
            createTemplateOnSelect(`#add-recipient-modal`);
        },
        onModalShow: function () {
            // load the template of the selected endpoint
            const $cloned = loadTemplate($(`#add-recipient-modal select[name='endpoint'] option:selected`).data('endpointKey'));
            if ($cloned) {
                $(`#add-recipient-modal form .recipient-template-container`).empty().append($cloned).show();
            }

        },
        onSubmitSuccess: function (response) {

            if (response.result.status == "OK") {
                $(`#add-recipient-modal`).modal('hide');
                $(`#add-recipient-modal form .recipient-template-container`).hide();
                NtopUtils.cleanForm(`#add-recipient-modal form`);
                $recipientsTable.ajax.reload(function() {
                    DataTableUtils.updateFilters(i18n.endpoint_type, $recipientsTable);
                });
                return;
            }

            if (response.result.error) {
                const localizedString = i18n[response.result.error.type];
                $(`#add-recipient-modal form span.invalid-feedback`).text(localizedString).show();
            }
        }
    }).invokeModalInit();

    $(`#add-test-recipient`).click(async function(e) {
        e.preventDefault();

        const $self = $(this);

        testRecipient(makeFormData(`#add-recipient-modal form`), $(this), $(`#add-recipient-modal .test-feedback`)).then(() => {
            $self.removeAttr("disabled");
        });
    });

    const removeModalHandler = $(`#remove-recipient-modal form`).modalHandler({
        method: 'post',
        csrf: pageCsrf,
        endpoint: `${http_prefix}/lua/edit_notification_recipient.lua`,
        dontDisableSubmit: true,
        onModalInit: function () {
            $(`.removed-recipient-name`).text(`${removeRowData.recipient_name}`);
        },
        beforeSumbit: function () {
            return {
                action: 'remove',
                recipient_id: removeRowData.recipient_id || DEFAULT_RECIPIENT_ID
            }
        },
        onSubmitSuccess: function (response) {
            if (response.result.status == "OK") {
                $(`#remove-recipient-modal`).modal('hide');
                $recipientsTable.ajax.reload(function() {
                    DataTableUtils.updateFilters(i18n.endpoint_type, $recipientsTable);
                });
            }
        }
    });

    /* bind remove endpoint event */
    $(`table#recipient-list`).on('click', `a[href='#remove-recipient-modal']`, function (e) {
        removeRowData = $recipientsTable.row($(this).parent().parent()).data();
        removeModalHandler.invokeModalInit();
    });


});
