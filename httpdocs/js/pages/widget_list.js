$(document).ready(function() {

    let dtConfig = DataTableUtils.getStdDatatableConfig([
        {
            text: '<i class="fas fa-plus"></i>',
            className: 'btn-link',
            action: function(e, dt, node, config) {
                $('#add-widget-modal').modal('show');
            }
        }
    ]);
    dtConfig = DataTableUtils.setAjaxConfig(dtConfig, `${http_prefix}/lua/get_widgets.lua`);
    dtConfig = DataTableUtils.extendConfig(dtConfig, {
        columns: [
            { data: 'name' },
            { data: 'key' },
            { data: 'type', render: (type) => `${NtopUtils.capitaliseFirstLetter(type)}` },
            {
                data: 'params',
                render: (params) => `<code>${JSON.stringify(params)}</code>`
            },
            {
                targets: -1,
                className: 'text-center',
                data: null,
                render: function () {
                    return (`
                    <div class='btn-group btn-group-sm'>
                        <a href='#edit-widget-modal' data-toggle='modal' class="btn btn-info">
                            <i class="fas fa-edit"></i>
                        </a>
                        <a href='#embed-widget-modal' data-toggle='modal' class="btn btn-info">
                            <i class="fas fa-code"></i>
                        </a>
                        <a href='#remove-widget-modal' data-toggle='modal' class="btn btn-danger">
                            <i class="fas fa-trash"></i>
                        </a>
                    </div>
                `);
                }
            }
        ]
    });

    const $widgets_table = $(`#widgets-list`).DataTable(dtConfig);

    $(`#widgets-list`).on('click', `a[href='#embed-widget-modal']`, function(e) {
        const rowData = $widgets_table.row($(this).parent().parent()).data();
        console.log(rowData);
        $(`#embded-container`).text(`
            <div
                class='ntop-widget'
                data-ntop-widget-params='${JSON.stringify(rowData.params)}'
                data-ntop-widget-key='${rowData.key}'>
            </div>
        `);
    });

    let removeWRowData = null;

    const remove_widget_modal = $(`#remove-widget-modal form`).modalHandler({
        method: 'post',
        endpoint: `${http_prefix}/lua/edit_widgets.lua`,
        csrf: remove_csrf,
        dontDisableSubmit: true,
        beforeSumbit: () => {
            return {
                action: 'remove',
                JSON: JSON.stringify({
                    widget_key: removeWRowData.key
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

    $(`#widgets-list`).on('click', `a[href='#remove-widget-modal']`, function(e) {
        removeWRowData = $widgets_table.row($(this).parent().parent()).data();
        remove_widget_modal.invokeModalInit();
    });

    let editWRowData = null;

    const edit_widget_modal = $(`#edit-widget-modal form`).modalHandler({
        method: 'post',
        endpoint: `${http_prefix}/lua/edit_widgets.lua`,
        csrf: edit_csrf,
        beforeSumbit: function() {
            return {
                action: 'edit',
                JSON: JSON.stringify(NtopUtils.serializeFormArray($(`#edit-widget-modal form`).serializeArray()))
            };
        },
        loadFormData: function() {
            return editWRowData;
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

    $(`#widgets-list`).on('click', `a[href='#edit-widget-modal']`, function(e) {
        editWRowData = $widgets_table.row($(this).parent().parent()).data();
        edit_widget_modal.invokeModalInit();
    });

    $(`#add-widget-modal form`).modalHandler({
        method: 'post',
        endpoint: `${http_prefix}/lua/edit_widgets.lua`,
        csrf: add_csrf,
        beforeSumbit: function() {
            const submitOptions = {
                action: 'add',
                JSON: JSON.stringify(NtopUtils.serializeFormArray($(`#add-widget-modal form`).serializeArray()))
            };
            return submitOptions;
        },
        onSubmitSuccess: function(response) {
            $widgets_table.ajax.reload();
            $('#add-widget-modal').modal('hide');
        }
    }).invokeModalInit();

});
