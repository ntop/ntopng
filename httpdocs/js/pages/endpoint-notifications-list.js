$(document).ready(function () {

    function makeFormData(formSelector) {

        const $inputsTemplate = $(`${formSelector} .endpoint-template-container [name]`);
        const params = {
            endpoint_conf_name: $(`${formSelector} [name='name']`).val(),
            endpoint_conf_type: $(`${formSelector} [name='type']`).val(),
        };
        $inputsTemplate.each(function(i, input){
            params[$(this).attr('name')] = $(this).val().trim();
        });

        return params;
    }

    function createTemplateOnSelect(formSelector) {
        const $templateContainer = $(`${formSelector} .endpoint-template-container`);
        $(`${formSelector} select[name='type']`).change(function(e) {
            const template = $(`template#${$(this).val()}-template`).html();
            const $cloned = $(template);
            $templateContainer.empty().append($cloned).fadeIn();
        });
    }

    function loadTemplate(type) {
        const template = $(`template#${type}-template`).html();
        return $(template);
    }

    const $endpointsTable = $(`table#notification-list`).DataTable({
        lengthChange: false,
        pagingType: 'full_numbers',
        stateSave: true,
        dom: 'lfBrtip',
        language: {
            info: i18n.showing_x_to_y_rows,
            search: i18n.search,
            infoFiltered: "",
            paginate: {
                previous: '&lt;',
                next: '&gt;',
                first: '«',
                last: '»'
            }
        },
        buttons: {
            buttons: [
                {
                    text: '<i class="fas fa-plus"></i>',
                    className: 'btn-link',
                    action: function (e, dt, node, config) {
                        $('#add-endpoint-modal').modal('show');
                    }
                }
            ],
            dom: {
                button: {
                    className: 'btn btn-link'
                },
                container: {
                    className: 'float-right'
                }
            }
        },
        ajax: {
            url: `${http_prefix}/lua/get_notification_configs.lua`,
            type: 'GET',
            dataSrc: ''
        },
        columns: [
            {
                data: 'endpoint_conf_name'
            },
            {
                data: 'endpoint_key'
            },
            {
                targets: -1,
                className: 'text-center',
                data: null,
                render: function () {
                    return (`
                        <a data-toggle='modal' href='#edit-endpoint-modal' class="badge badge-info">${i18n.edit}</a>
                        <a data-toggle='modal' href='#remove-endpoint-modal' class="badge badge-danger">${i18n.remove}</a>
                    `);
                }
            }
        ]
    });

    /* bind edit endpoint event */
    $(`table#notification-list`).on('click', `a[href='#edit-endpoint-modal']`, function (e) {

        const rowData = $endpointsTable.row($(this).parent()).data();

        $('#edit-endpoint-modal form').modalHandler({
            method: 'post',
            csrf: csrf,
            endpoint: `${http_prefix}/lua/edit_endpoint.lua`,
            beforeSumbit: function () {
                const body = makeFormData(`#edit-endpoint-modal form`);
                body.action = 'edit';
                return body;
            },
            loadFormData: function () {
                return rowData;
            },
            onModalInit: function (data) {
                /* load the right template from templates */
                $(`#edit-endpoint-modal form .endpoint-template-container`)
                    .empty().append(loadTemplate(data.endpoint_key));
                /* load the values inside the template */
                $(`#edit-endpoint-modal form [name='name']`).val(data.endpoint_conf_name);
                $(`#edit-endpoint-modal form .endpoint-template-container [name]`).each(function(i, input) {
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
    });

    /* bind add endpoint event */
    $(`#add-endpoint-modal form`).modalHandler({
        method: 'post',
        endpoint: `${http_prefix}/lua/edit_endpoint.lua`,
        csrf: csrf,
        resetAfterSubmit: false,
        beforeSumbit: function () {

            $(`#add-endpoint-modal form button[type='submit']`).click(function() {
                $(`#add-endpoint-modal form span.invalid-feedback`).hide();
            });

            const body = makeFormData(`#add-endpoint-modal form`);
            body.action = 'add';
            return body;
        },
        onModalInit: function() {
            createTemplateOnSelect(`#add-endpoint-modal`);
        },
        onSubmitSuccess: function (response) {

            if (response.result.status == "OK") {
                $(`#add-endpoint-modal`).modal('hide');
                $(`#add-endpoint-modal form .endpoint-template-container`).hide();
                cleanForm(`#add-endpoint-modal form`);
                $endpointsTable.ajax.reload();
                return;
            }

            if (response.result.error) {
                const localizedString = i18n[response.result.error.type];
                $(`#add-endpoint-modal form span.invalid-feedback`).text(localizedString).show();
            }

        }
    });

    /* bind remove endpoint event */
    $(`table#notification-list`).on('click', `a[href='#remove-endpoint-modal']`, function (e) {

        const rowData = $endpointsTable.row($(this).parent()).data();

        $(`#remove-endpoint-modal form`).modalHandler({
            method: 'post',
            csrf: csrf,
            endpoint: `${http_prefix}/lua/edit_endpoint.lua`,
            beforeSumbit: () => {
                return {
                    action: 'remove',
                    endpoint_conf_name: $(`#remove-endpoint-modal form [name='endpoint_conf_name']`).val()
                };
            },
            loadFormData: () => rowData.endpoint_conf_name,
            onModalInit: function (data) {
                $(`#remove-endpoint-modal form [name='endpoint_conf_name']`).val(data);
            },
            onSubmitSuccess: function (response) {
                if (response.result.status == "OK") {
                    $(`#remove-endpoint-modal`).modal('hide');
                    $endpointsTable.ajax.reload();
                }
            }
        });
    });


});