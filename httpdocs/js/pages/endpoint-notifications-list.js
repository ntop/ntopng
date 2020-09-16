$(document).ready(function () {

    const MAX_ENDPOINTS_COUNT = 10;
    const INDEX_COLUMN_ENDPOINT_TYPE = 1;

    const getTypesCount = (configs) => {

        const currentTypesCount = {};
        for (let i = 0; i < configs.length; i++) {

            const config = configs[i];
            if (!currentTypesCount[config.endpoint_key]) {
                currentTypesCount[config.endpoint_key] = 1;
            }
            else {
                currentTypesCount[config.endpoint_key]++;
            }
        }

        return currentTypesCount;
    }

    const disableTypes = (configs) => {

        // count the current types inside the datatable
        const currentTypesCount = getTypesCount(configs);
        for (let [key, max] of Object.entries(endpoints_info)) {
            if (max != -1 && currentTypesCount[key] >= max) {
                $(`#endpoint-type-select option[value='${key}']`).hide();
            }
            else {
                $(`#endpoint-type-select option[value='${key}']`).show();
            }
        }
    }

    const makeFormData = (formSelector) => {

        const $inputsTemplate = $(`${formSelector} .endpoint-template-container [name]`);

        const params = {
            endpoint_conf_name: $(`${formSelector} [name='name']`).val(),
            endpoint_conf_type: $(`${formSelector} [name='type']`).val(),
        };

        $inputsTemplate.each(function (i, input) {
            params[$(this).attr('name')] = $(this).val().trim();
        });

        return params;
    }

    const createTemplateOnSelect = (formSelector) => {

        const $templateContainer = $(`${formSelector} .endpoint-template-container`);
        $(`${formSelector} select[name='type']`).change(function (e) {
            const $cloned = cloneTemplate($(this).val());
            $templateContainer.empty().append($cloned).fadeIn();
        });
    }

    const cloneTemplate = (endpointType) => {
        return $($(`template#${endpointType}-template`).html());
    }

    let dtConfig = DataTableUtils.getStdDatatableConfig([
        {
            text: '<i class="fas fa-plus"></i>',
            className: 'btn-link',
            action: function (e, dt, node, config) {
                $('#add-endpoint-modal').modal('show');
            }
        }
    ]);
    dtConfig = DataTableUtils.setAjaxConfig(dtConfig, `${http_prefix}/lua/get_notification_configs.lua`);
    dtConfig = DataTableUtils.extendConfig(dtConfig, {
        columns: [
            {
                data: 'endpoint_conf_name'
            },
            {
                data: 'endpoint_key',
                render: function (key, type) {
                    if (type == "display") return i18n.endpoint_types[key];
                    return key;
                }
            },
            {
                data: 'recipients',
                render: (recipients, type) => {
                    if (type == "display")
                        return NtopUtils.arrayToListString(recipients.map(recipient => {

                            let badge = "";
                            const isBuiltin = recipient.endpoint_conf.builtin || false;
                            const destPage = NtopUtils.buildURL('/lua/admin/recipients_list.lua', {
                                recipient_id: recipient.recipient_id,
                            });

                            if (isBuiltin) {
                                badge = ` <span class='badge badge-dark'>built-in</span>`;
                            }

                            return `<a href='${destPage}'>${recipient.recipient_name}${badge}</a>`
                        }), MAX_ENDPOINTS_COUNT);
                    return recipients;
                }
            },
            {
                targets: -1,
                className: 'text-center',
                data: null,
                render: (_, type, endpoint) => {

                    const isBuiltin = endpoint.endpoint_conf.builtin || false;
                    if (isBuiltin) return;

                    return (`
                        <div>
                            <a data-toggle='modal' href='#edit-endpoint-modal' class="btn btn-sm btn-info">
                                <i class="fas fa-edit"></i>
                            </a>
                            <a data-toggle='modal' href='#remove-endpoint-modal' class="btn btn-sm btn-danger">
                                <i class="fas fa-trash"></i>
                            </a>
                        </div>
                    `);
                }
            }
        ],
        initComplete: function (settings) {

            const tableAPI = settings.oInstance.api();
            disableTypes(tableAPI.rows().data());

            // add a filter to sort the datatable by endpoint type
            DataTableUtils.addFilterDropdown(
                i18n.endpoint_type, endpointTypeFilters, INDEX_COLUMN_ENDPOINT_TYPE, '#notification-list_filter', tableAPI
            );

            // when the data has been fetched check if the url has a recipient_id param
            // if the recipient is builtin then cancel the modal opening
            DataTableUtils.openEditModalByQuery({
                paramName: 'endpoint_conf_name',
                datatableInstance: tableAPI,
                modalHandler: $editEndpointModal,
                cancelIf: (endpoint) => endpoint.endpoint_conf.builtin,
            });

        }
    });

    const $endpointsTable = $(`table#notification-list`).DataTable(dtConfig);

    /* bind add endpoint event */
    $(`#add-endpoint-modal form`).modalHandler({
        method: 'post',
        endpoint: `${http_prefix}/lua/edit_endpoint.lua`,
        csrf: csrf,
        resetAfterSubmit: false,
        beforeSumbit: () => {

            $(`#add-endpoint-modal form button[type='submit']`).click(function () {
                $(`#add-endpoint-modal form span.invalid-feedback`).hide();
            });

            const body = makeFormData(`#add-endpoint-modal form`);
            body.action = 'add';

            return body;
        },
        onModalInit: () => {
            createTemplateOnSelect(`#add-endpoint-modal`);
        },
        onModalShow: () => {
            // trigger a change event to the select so the template will be loaded
            $(`#add-endpoint-modal select[name='type']`).trigger('change');
        },
        onSubmitSuccess: (response) => {

            if (response.result.status == "OK") {

                $(`#add-endpoint-modal`).modal('hide');
                $(`#add-endpoint-modal form .endpoint-template-container`).hide();
                NtopUtils.cleanForm(`#add-endpoint-modal form`);

                $endpointsTable.ajax.reload(function (data) {
                    // disable endpoint type if a endpoint reached its max num config
                    disableTypes(data);
                    // update the filters counter
                    DataTableUtils.updateFilters(i18n.endpoint_type, $endpointsTable);
                });
                return;
            }

            if (response.result.error) {
                const localizedString = i18n[response.result.error.type];
                $(`#add-endpoint-modal form span.invalid-feedback`).text(localizedString).show();
            }

        }
    }).invokeModalInit();

    const $editEndpointModal = $('#edit-endpoint-modal form').modalHandler({
        method: 'post',
        csrf: csrf,
        endpoint: `${http_prefix}/lua/edit_endpoint.lua`,
        beforeSumbit: function () {
            const body = makeFormData(`#edit-endpoint-modal form`);
            body.action = 'edit';
            return body;
        },
        onModalInit: function (data) {
            /* load the right template from templates */
            $(`#edit-endpoint-modal form .endpoint-template-container`)
                .empty().append(cloneTemplate(data.endpoint_key));
            $(`#endpoint-type`).html(data.endpoint_conf_name);
            /* load the values inside the template */
            $(`#edit-endpoint-modal form [name='name']`).val(data.endpoint_conf_name);
            $(`#edit-endpoint-modal form .endpoint-template-container [name]`).each(function (i, input) {
                $(this).val(data.endpoint_conf[$(this).attr('name')]);
            });
        },
        onSubmitSuccess: function (response) {
            if (response.result.status == "OK") {
                $(`#edit-endpoint-modal`).modal('hide');
                $endpointsTable.ajax.reload();
            }
        }
    });

    const $removeEndpointModal = $(`#remove-endpoint-modal form`).modalHandler({
        method: 'post',
        csrf: csrf,
        dontDisableSubmit: true,
        endpoint: `${http_prefix}/lua/edit_endpoint.lua`,
        beforeSumbit: (endpoint) => {
            return {
                action: 'remove',
                endpoint_conf_name: endpoint.endpoint_conf_name
            };
        },
        onModalInit: (endpoint) => {

            // count recipients that are not builtins
            const recipientsCount = endpoint.recipients.filter(recipient => !recipient.endpoint_conf.builtin).length;
            if (recipientsCount > 0) {
                $(`.count`).show();
                $(`.recipients-count`).html(recipientsCount);
            }
            else {
                $(`.count`).hide();
            }

            $(`.remove-endpoint-name`).text(endpoint.endpoint_conf_name);
        },
        onSubmitSuccess: (response) => {
            if (response.result.status == "OK") {
                $(`#remove-endpoint-modal`).modal('hide');
                $endpointsTable.ajax.reload(function (data) {
                    // re-enable endpoint type
                    disableTypes(data);
                    // update the filters counter
                    DataTableUtils.updateFilters(i18n.endpoint_type, $endpointsTable);
                });
            }
        }
    });

    /* bind edit endpoint event */
    $(`table#notification-list`).on('click', `a[href='#edit-endpoint-modal']`, function (e) {

        const endpointSelected = $endpointsTable.row($(this).parent().parent()).data();

        // prevent the deleting of a builtin element
        if (endpointSelected.endpoint_conf.builtin) {
            e.preventDefault();
            return;
        }

        $editEndpointModal.invokeModalInit(endpointSelected);
    });

    /* bind remove endpoint event */
    $(`table#notification-list`).on('click', `a[href='#remove-endpoint-modal']`, function (e) {

        const endpointSelected = $endpointsTable.row($(this).parent().parent()).data();

        // prevent the deleting of a builtin element
        if (endpointSelected.endpoint_conf.builtin) {
            e.preventDefault();
            return;
        }

        $removeEndpointModal.invokeModalInit(endpointSelected);
    });

    $(`#btn-factory-reset`).click(async function(event) {

        try {

            const response = await NtopUtils.fetchWithTimeout(`${http_prefix}/lua/rest/v1/delete/endpoints.lua`);
            const result = await response.json();
            if (result.rc == 0) {
                $endpointsTable.ajax.reload();
                $(`#factory-reset-modal`).modal('hide');
            }
        }
        catch (error) {

            if (err.message == "Response timed out") {
                $(`#factory-reset-modal .invalid-feedback`).html(i18n.timed_out);
                return;
            }
        }
    });

});
