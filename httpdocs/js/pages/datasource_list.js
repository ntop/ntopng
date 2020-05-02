function serializeFormArrayIntoObject(serializedArray) {

    const serialized = {};
    serializedArray.forEach((obj) => {
        if (obj.name.includes('[]')) {
            const arrayName = obj.name.split("[]")[0];
            if (arrayName in serialized) {
                serialized[arrayName].push(obj.value);
                return;
            }
            serialized[arrayName] = [obj.value];
        }
        else {
            serialized[obj.name] = obj.value;
        }
    });
    return serialized;
}

$(document).ready(function() {

    const $datasources_table = $(`#datasources-list`).DataTable({
        lengthChange: false,
        pagingType: 'full_numbers',
        stateSave: true,
        dom: 'lfBrtip',
        initComplete: function() {

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
        buttons: {
            buttons: [
                {
                    text: '<i class="fas fa-plus"></i>',
                    className: 'btn-link',
                    action: function(e, dt, node, config) {
                        $('#add-datasource-modal').modal('show');
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
            url: `${http_prefix}/lua/get_datasources.lua`,
            type: 'GET',
            dataSrc: ''
        },
        columns: [
	    { data: 'alias' },
            { data: 'hash',
                render: (hash) => `<a target=\"_blank\" href=\"/datasources/${hash}\"'>${hash}</a>`
	    },
            { data: 'scope' },
            { data: 'origin' },
            { data: 'data_retention' },
            {
                targets: -1,
                className: 'text-center',
                data: null,
                render: function() {
                    return (`
                        <a data-toggle='modal' href='#edit-datasource-modal' class="badge badge-info">Edit</a>
                        <a data-toggle='modal' href='#remove-datasource-modal' class="badge badge-danger">Delete</a>
                    `);
                }
            }
        ]
    });

    function submitPost(data_to_send, modal_id, $submit_button) {

        const $invalid_feedback = $(modal_id).find(`span.invalid-feedback`);

        $invalid_feedback.fadeOut().html('');
        $submit_button.attr("disabled", "true");

        $.post(`${http_prefix}/lua/edit_datasources.lua`, data_to_send, function (data) {

            switch (data_to_send.action) {
                case 'add':
                    add_csrf = data.csrf;
                    resetSourceContainer();
                    break;
                case 'edit':
                    edit_csrf = data.csrf;
                    break;
                case 'remove':
                    remove_csrf = data.csrf;
                    break;
            }

            $submit_button.removeAttr("disabled");

            if (data.success) {
                $datasources_table.ajax.reload();
                $(modal_id).modal('hide');
                if ($(modal_id).find('form').length > 0) $(modal_id).find('form')[0].reset();
            }
            else {
                $invalid_feedback.fadeIn().html(data.message);
            }

        });

    }

    $(`#datasources-list`).on('click', `a[href='#remove-datasource-modal']`, function(e) {

        const row_data = $datasources_table.row($(this).parent()).data();
        const $submit_button = $(`#remove-datasource-button`);

        $submit_button.off('click').click(function () {

            const data_to_send = { ds_key: row_data.hash };

            submitPost(
                { action: 'remove', csrf: remove_csrf, JSON: JSON.stringify(data_to_send) },
                `#remove-datasource-modal`,
                $submit_button
            );
        });
    });

    $(`#datasources-list`).on('click', `a[href='#edit-datasource-modal']`, function(e) {

        const $submit_button = $(this).find(`[type='submit']`);
        const row_data = $datasources_table.row($(this).parent()).data();

        // fill edit modal input fields
        $('#edit-datasource-modal form [name]').each(function(e) {
            $(this).val(row_data[$(this).attr('name')]);
        });

        $(`#edit-datasource-modal form`).off('submit').submit(function (e) {

            e.preventDefault();

            const data_to_send = serializeFormArrayIntoObject($(this).serializeArray());
            data_to_send.ds_key = row_data.hash;

            submitPost(
                { action: 'edit', csrf: edit_csrf, JSON: JSON.stringify(data_to_send) },
                `#edit-datasource-modal`,
                $submit_button
            );
        });
    });

    $(`#add-datasource-modal form`).submit(function(e) {

        e.preventDefault();
        const $submit_button = $(this).find(`[type='submit']`);
        const data_to_send = serializeFormArrayIntoObject($(this).serializeArray());

        submitPost(
            { action: 'add', csrf: add_csrf, JSON: JSON.stringify(data_to_send) },
            `#add-datasource-modal`,
            $submit_button
        );
    });

    /* **************************************************************************************** */

    function createNewSource(name) {

        const template = $(`template#ds-source`)[0];
        const clone = template.content.cloneNode(true);

        const $cloneContainer = $(clone).find('.card');
        const $cardTitle = $(clone).find(`a[data-toggle='collapse']`);
        const $btnRemoveSource = $(clone).find(`.btn-remove-source`);
        const $seriesSelect = $(clone).find(`select[name='series[]']`);
        const $schemasSelect = $(clone).find(`select[name='schemas[]']`);
        const $metricsSelect = $(clone).find(`select[name='metrics[]']`);

        $cardTitle.attr('href', `#source-${name}`);
        $(clone).find(`div.collapse.show`).attr('id', `source-${name}`)

        const steps = [
            $(clone).find('.step-1'), $(clone).find('.step-2')
        ];

        $schemasSelect.change(function() {
            const value = $(this).val();
            $seriesSelect.find(`optgroup[label!='${value}']`).hide();
            $seriesSelect.find(`optgroup[label='${value}']`).show();
            steps[0].fadeIn();
        });

        $seriesSelect.change(function() {
            $cardTitle.html(`<b>${$(this).val()}</b>`);
            const value = $(this).val();
            $metricsSelect.find(`optgroup[label!='${value}']`).hide();
            $metricsSelect.find(`optgroup[label='${value}']`).show();
            steps[1].fadeIn();
        });

        $metricsSelect.change(function() {
            $cardTitle.html(`<b>${$seriesSelect.val()} - ${$(this).val()}</b>`);
        });

        $btnRemoveSource.click(function(e) {
            e.preventDefault();
            $cloneContainer.fadeOut(200, function() {
                $(this).remove();
            });
        })

        return clone;
    }

    function resetSourceContainer() {
        $(`#ds-source-container`).fadeOut().empty();
        $(`#btn-add-source`).fadeOut();
    }

    let temp = 0;

    $(`#btn-add-source`).click(function(e) {
        e.preventDefault(); e.stopPropagation();
        const $sourcesContainer = $(`#ds-source-container`);
        $sourcesContainer.append(createNewSource(++temp));
    });

    $(`#add-datasource-modal form select[name='origin']`).change(function(e) {

        const isTimeseries = $(this).val() == "timeseries.lua";
        const $sourcesContainer = $(`#ds-source-container`);
        const $btnAddSource = $(`#btn-add-source`);

        if (!isTimeseries) {
            $sourcesContainer.fadeOut().empty();
            $btnAddSource.fadeOut();
            return;
        }

        $sourcesContainer.append(createNewSource('0'));
        $sourcesContainer.fadeIn();
        $btnAddSource.fadeIn();
    });

});
