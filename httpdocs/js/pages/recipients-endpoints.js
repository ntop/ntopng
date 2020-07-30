// @ts-nocheck
$(document).ready(function () {

    let editRowData = null;
    let removeRowData = null;

    function makeFormData(formSelector) {

        const $inputsTemplate = $(`${formSelector} .recipient-template-container [name]`);

        const params = {
            recipient_name: $(`${formSelector} [name='recipient_name']`).val(),
            endpoint_conf_name: $(`${formSelector} [name='endpoint']`).val()
        };

        // load each recipient params inside the template container in params
        $inputsTemplate.each(function (i, input) {
            params[$(this).attr('name')] = $(this).val().trim();
        });

        return params;
    }

    async function testRecipient(data, $feedbackLabel) {

        const body = { action: 'test' };
        $.extend(body, data);

        $feedbackLabel
            .html(`<div class='spinner-border spinner-border-sm'></div> ${i18n.testing_recipient}...`)
            .removeClass(`text-danger`).removeClass(`text-success`).show();

        try {

            const request = await fetchWithTimeout(`${http_prefix}/lua/edit_notification_recipient.lua`, {method: 'post', body: JSON.stringify(body)}, 3000);
            const {result} = await request.json();

            if (result.status == "failed") {
                $feedbackLabel.addClass(`text-danger`).html(result.error.message);
                return;
            }

            // show a green label to alert the endpoint message
            $feedbackLabel.addClass('text-success').html(i18n.working_recipient).fadeOut(2000);
        }
        catch (err) {
            $feedbackLabel.addClass(`text-danger`).html(i18n.timed_out);
        }
    }

    function createTemplateOnSelect(formSelector) {

        const $templateContainer = $(`${formSelector} .recipient-template-container`);
        // on Endpoint Selection load the right template to fill
        $(`${formSelector} select[name='endpoint']`).change(function (e) {
            const $option = $(this).find(`option[value='${$(this).val()}']`);
            const $cloned = loadTemplate($option.data('endpointKey'));
            // show the template inside the modal container
            $templateContainer.empty().append($cloned).fadeIn();
        });
    }

    function loadTemplate(type) {

        const template = $(`template#${type}-template`).html();
        // if the template is not empty then return a copy of the template content
        if (template.trim() != "")
            return $(template);
        // othwerise return a message informing the user there is no inputs to fill
        return $(`<p class='text-center text-muted my-2'>${i18n.empty_template}</p>`);
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
                targets: -1,
                className: 'text-center',
                data: null,
                render: function (data, type, row) {

                    let editButton = "";
                    const endpointType = row.endpoint_conf.endpoint_key
                    // if the template is empty then disabled the edit button
                    const editButtonDisabled = $.trim($(`#${endpointType}-template`).html()) == "";
                    if (!editButtonDisabled) {
                        editButton = `
                            <a data-toggle='modal' href='#edit-recipient-modal' class="btn btn-info">
                                <i class='fas fa-edit'></i>
                            </a>
                        `;
                    }

                    return (`
                        <div class='btn-group btn-group-sm'>
                            ${editButton}
                            <a data-toggle='modal' href='#remove-recipient-modal' class="btn btn-danger">
                                <i class='fas fa-trash'></i>
                            </a>
                        </div>
                    `);
                }
            }
        ]
    });

    const $recipientsTable = $(`table#recipient-list`).DataTable(dtConfig);

    const $editRecipientHandler = $('#edit-recipient-modal form').modalHandler({
        method: 'post',
        csrf: pageCsrf,
        endpoint: `${http_prefix}/lua/edit_notification_recipient.lua`,
        beforeSumbit: function () {
            const data = makeFormData(`#edit-recipient-modal form`);
            data.action = 'edit';
            return data;
        },
        onModalInit: function (data) {
            $(`#edit-recipient-modal .test-feedback`).hide();
            /* load the right template from templates */
            $(`#edit-recipient-modal form .recipient-template-container`)
                .empty().append(loadTemplate(editRowData.endpoint_conf.endpoint_key));
            $(`#edit-recipient-name`).text(editRowData.recipient_name);
            /* load the values inside the template */
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
                testRecipient(data, $(`#edit-recipient-modal .test-feedback`)).then(() => {
                    $self.removeAttr("disabled");
                });
            });
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
            $(`#add-recipient-modal form .recipient-template-container`)
                .empty().append(loadTemplate($(`#add-recipient-modal select[name='endpoint'] option:selected`).data('endpointKey'))).show();
        },
        onSubmitSuccess: function (response) {

            if (response.result.status == "OK") {
                $(`#add-recipient-modal`).modal('hide');
                $(`#add-recipient-modal form .recipient-template-container`).hide();
                cleanForm(`#add-recipient-modal form`);
                $recipientsTable.ajax.reload();
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

        $self.attr("disabled", "disabled");
        testRecipient(makeFormData(`#add-recipient-modal form`), $(`#add-recipient-modal .test-feedback`)).then(() => {
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
                recipient_name: removeRowData.recipient_name
            }
        },
        onSubmitSuccess: function (response) {
            if (response.result.status == "OK") {
                $(`#remove-recipient-modal`).modal('hide');
                $recipientsTable.ajax.reload();
            }
        }
    });

    /* bind remove endpoint event */
    $(`table#recipient-list`).on('click', `a[href='#remove-recipient-modal']`, function (e) {
        removeRowData = $recipientsTable.row($(this).parent().parent()).data();
        removeModalHandler.invokeModalInit();
    });


});
