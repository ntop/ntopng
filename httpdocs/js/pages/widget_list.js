$(document).ready(function() {

    const $widgets_table = $(`#widgets-list`).DataTable({
        pagingType: 'full_numbers',
        lengthChange: false,
        stateSave: true,
        dom: 'lfBrtip',
        initComplete: function() {

        },
        buttons: {
            buttons: [
                {
                    text: '<i class="fas fa-plus"></i>',
                    className: 'btn-link',
                    action: function(e, dt, node, config) {
                        $('#add-widget-modal').modal('show');
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
        ajax: {
            url: `${http_prefix}/lua/get_widgets.lua`,
            type: 'GET',
            dataSrc: ''
        },
        columns: [
            { data: 'name' },
            {
                data: 'key',
	    },
            { data: 'type', render: (type) => `${capitaliseFirstLetter(type)}` },
            {
                data: 'params',
                render: (params) => `<code>${JSON.stringify(params)}</code>`
            },
            {
                targets: -1,
                className: 'text-center',
                data: null,
                render: function() {
                    return (`
                        <a href='#edit-widget-modal' data-toggle='modal' class="badge badge-info">Edit</a>
                        <a href='#embed-widget-modal' data-toggle='modal' class="badge badge-info">Embed</a>
                        <a href='#remove-widget-modal' data-toggle='modal' class="badge badge-danger">Delete</a>
                    `);
                }
            }
        ]
    });

    $(`#widgets-list`).on('click', `a[href='#embed-widget-modal']`, function(e) {
        const row_data = $widgets_table.row($(this).parent()).data();
        $(`#embded-container`).text(`<div class='ntop-widget' data-ntop-widget-key='${row_data.key}'></div>`);
    });

    $(`#widgets-list`).on('click', `a[href='#remove-widget-modal']`, function(e) {

        const rowData = $widgets_table.row($(this).parent()).data();

        $(`#remove-widget-modal form`).modalHandler({
            method: 'post',
            endpoint: `${http_prefix}/lua/edit_widgets.lua`,
            csrf: remove_csrf,
            beforeSumbit: () => {
                return {
                    action: 'remove',
                    JSON: JSON.stringify({
                        widget_key: rowData.key
                    })
                };
            },
            onModalInit: function(data) {
                $(`#remove-widget-modal form input[name='widget_key']`).val(data);
            },
            onSubmitSuccess: function(response) {
                if (response.success) {
                    $widgets_table.ajax.reload();
                    $('#remove-widget-modal').modal('hide');
                }
            }
        });
    });

    $(`#widgets-list`).on('click', `a[href='#edit-widget-modal']`, function(e) {

        const rowData = $widgets_table.row($(this).parent()).data();

        $(`#edit-widget-modal form`).modalHandler({
            method: 'post',
            endpoint: `${http_prefix}/lua/edit_widgets.lua`,
            csrf: edit_csrf,
            beforeSumbit: function() {
                return {
                    action: 'edit',
                    JSON: JSON.stringify(serializeFormArray($(`#edit-widget-modal form`).serializeArray()))
                };
            },
            loadFormData: function() {
                return rowData;
            },
            onModalInit: function(data) {

                const editParams = Object.assign({
                    name:       data.name,
                    type:       data.type,
                    ds_hash:    data.ds_hash,
                    interface:  data.params.ifid,
                    widget_key: data.key,
                }, data.params);

                delete editParams.ifid;

                $(`#edit-widget-modal form`).find('[name]').each(function(e) {
                    $(this).val(editParams[$(this).attr('name')]);
                });
            },
            onSubmitSuccess: function(response) {
                $widgets_table.ajax.reload();
                $('#edit-widget-modal').modal('hide');
            }
        });

    });

    $(`#add-widget-modal form`).modalHandler({
        method: 'post',
        endpoint: `${http_prefix}/lua/edit_widgets.lua`,
        csrf: add_csrf,
        beforeSumbit: function() {
            const submitOptions = {
                action: 'add',
                JSON: JSON.stringify(serializeFormArray($(`#add-widget-modal form`).serializeArray()))
            };
            return submitOptions;
        },
        onSubmitSuccess: function(response) {
            $widgets_table.ajax.reload();
            $('#add-widget-modal').modal('hide');
        }
    });

});