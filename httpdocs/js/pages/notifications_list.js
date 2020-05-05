$(document).ready(function () {

    function makeFormData(formSelector) {

        const $inputsTemplate = $(`${formSelector} .endpoint-template-container [name]`);
        const templateParams = {}
        $inputsTemplate.each(function(i, input){
            templateParams[$(this).attr('name')] = $(this).val();
        });

        return {
            name: $(`${formSelector} [name='name']`).val(),
            type: $(`${formSelector} [name='type']`).val(),
            conf_params: templateParams
        }

    }

    function createTemplateOnSelect(formSelector) {
        const $templateContainer = $(`${formSelector} .endpoint-template-container`);
        $(`${formSelector} select[name='type']`).change(function(e) {
            const template = $(`template#${$(this).val()}-template`).html();
            const $cloned = $(template);
            $templateContainer.empty().append($cloned);
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
            url: `${http_prefix}/lua/get_notification_endpoints.lua`,
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
            endpoint: `${http_prefix}/lua/edit_endpoint.lua`,
            csrf: edit_csrf,
            beforeSumbit: function () {
                return {
                    action: 'edit',
                    JSON: JSON.stringify(makeFormData(`#edit-endpoint-modal form`))
                };
            },
            loadFormData: function () {
                return rowData;
            },
            onModalInit: function (data) {
                /* grant the ability to change template */
                createTemplateOnSelect(`#edit-endpoint-modal form`);
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
        csrf: add_csrf,
        beforeSumbit: function () {
            return {
                action: 'add',
                JSON: JSON.stringify(makeFormData(`#add-endpoint-modal form`))
            };
        },
        onModalInit: function() {
            createTemplateOnSelect(`#add-endpoint-modal`);
        },
        onSubmitSuccess: function (response) {
            if (response.result.status == "OK") {
                $(`#add-endpoint-modal`).modal('hide');
                $endpointsTable.ajax.reload();
            }
        }
    });

    /* bind remove endpoint event */
    $(`table#notification-list`).on('click', `a[href='#remove-endpoint-modal']`, function (e) {

        const rowData = $endpointsTable.row($(this).parent()).data();

        $(`#remove-endpoint-modal form`).modalHandler({
            method: 'post',
            endpoint: `${http_prefix}/lua/edit_endpoint.lua`,
            csrf: remove_csrf,
            beforeSumbit: () => {
                return {
                    action: 'remove',
                    JSON: JSON.stringify({name: $(`#remove-endpoint-modal form [name='endpoint_conf_name']`).val()})
                }
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