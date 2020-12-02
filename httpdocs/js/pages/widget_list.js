$(document).ready(function() {

    let dtConfig = DataTableUtils.getStdDatatableConfig([
        {
            text: '<i class="fas fa-plus"></i>',
            action: function(e, dt, node, config) {
                $('#add-widget-modal').modal('show');
            }
        },
        {
            text: '<i class="fas fa-sync"></i>',
            action: function (e, dt, node, config) {
                $widgetTable.ajax.reload();
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
                width: '10%',
                className: 'text-center',
                data: null,
                render: function () {
                    return DataTableUtils.createActionButtons([
                        { class: 'btn-info', icon: 'fa-code', modal: '#embed-widget-modal' },
                        { class: 'btn-info', icon: 'fa-edit', modal: '#edit-widget-modal' },
                        { class: 'btn-danger', icon: 'fa-trash', modal: '#remove-widget-modal' },
                    ]);
                }
            }
        ]
    });

    const $widgetTable = $(`#widgets-list`).DataTable(dtConfig);

    $(`#widgets-list`).on('click', `a[href='#embed-widget-modal']`, function(e) {
        const rowData = $widgetTable.row($(this).parent().parent()).data();
        $(`#embded-container`).text(`
            <div class='ntop-widget' data-ntop-widget-params='${JSON.stringify(rowData.params)}' data-ntop-widget-key='${rowData.key}'></div>
        `);
    });

    const $removeWidgetHandler = $(`#remove-widget-modal form`).modalHandler({
        method: 'post',
        endpoint: `${http_prefix}/lua/edit_widgets.lua`,
        csrf: remove_csrf,
        dontDisableSubmit: true,
        beforeSumbit: (selectedWidget) => {
            return {
                action: 'remove',
                JSON: JSON.stringify({ widget_key: selectedWidget.key })
            };
        },
        onModalInit: function(selectedWidget) {
            $(`.widget-name`).text(selectedWidget.name);
        },
        onSubmitSuccess: function(response) {
            if (response.success) {
                $widgetTable.ajax.reload();
                $('#remove-widget-modal').modal('hide');
            }
            else {
                $(`#remove-widget-modal .invalid-feedback`).show().text(response.message);
            }
        }
    });

    $(`#widgets-list`).on('click', `a[href='#remove-widget-modal']`, function(e) {
        const selectedWidget = $widgetTable.row($(this).parent().parent()).data();
        $removeWidgetHandler.invokeModalInit(selectedWidget);
    });


    const $editWidgetHandler = $(`#edit-widget-modal form`).modalHandler({
        method: 'post',
        endpoint: `${http_prefix}/lua/edit_widgets.lua`,
        csrf: edit_csrf,
        resetAfterSubmit: false,
        beforeSumbit: function(selectedWidget) {

            const data = NtopUtils.serializeFormArray($(`#edit-widget-modal form`).serializeArray());
            data.widget_key = selectedWidget.key;

            return {
                action: 'edit',
                JSON: JSON.stringify(data)
            };
        },
        onModalInit: function(data) {

            const editParams = Object.assign({
                name:       data.name,
                type:       data.type,
                ds_hash:    data.ds_hash,
                interface:  data.params.ifid,
            }, data.params);

            // remove duplicated interfaceid
            delete editParams.ifid;

            $(`.widget-name`).text(editParams.name);
            $(`#edit-widget-modal form`).find('[name]').each(function(e) {
                $(this).val(editParams[$(this).attr('name')]);
            });
        },
        onSubmitSuccess: function(response) {
            if (response.success) {
                $widgetTable.ajax.reload();
                $('#edit-widget-modal').modal('hide');
            }
            else {
                $(`#edit-widget-modal .invalid-feedback`).show().text(response.message);
            }
        }
    });

    $(`#widgets-list`).on('click', `a[href='#edit-widget-modal']`, function(e) {
        const selectedWidget = $widgetTable.row($(this).parent().parent()).data();
        $editWidgetHandler.invokeModalInit(selectedWidget);
    });

    $(`#add-widget-modal form`).modalHandler({
        method: 'post',
        endpoint: `${http_prefix}/lua/edit_widgets.lua`,
        csrf: add_csrf,
        resetAfterSubmit: false,
        beforeSumbit: function() {
            const submitOptions = {
                action: 'add',
                JSON: JSON.stringify(NtopUtils.serializeFormArray($(`#add-widget-modal form`).serializeArray()))
            };
            return submitOptions;
        },
        onSubmitSuccess: function(response) {
            if (response.success){
                $widgetTable.ajax.reload();
                $('#add-widget-modal').modal('hide');
            }
            else {
                $(`#add-widget-modal .invalid-feedback`).show().text(response.message);
            }
        }
    }).invokeModalInit();

});
