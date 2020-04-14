function serializeFormArrayIntoObject(serializedArray) {

    const serialized = {};
    serializedArray.forEach((obj) => {
        serialized[obj.name] = obj.value;
    });

    return serialized;
}

$(document).ready(function() {

    function submitPost(data_to_send, modal_id, $submit_button) {

        const $invalid_feedback = $(modal_id).find(`span.invalid-feedback`);
        $invalid_feedback.fadeOut().html('');
        $submit_button.attr("disabled", "true");

        $.post(`${http_prefix}/lua/edit_widgets.lua`, data_to_send, function (data) {

            switch (data_to_send.action) {
                case 'add':
                    add_csrf = data.csrf;
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
                $widgets_table.ajax.reload();
                $(modal_id).modal('hide');
                if ($(modal_id).find('form').length > 0) $(modal_id).find('form')[0].reset();
            }
            else {
                $invalid_feedback.fadeIn().html(data.message);
            }

        });

    }

    const $widgets_table = $(`#widgets-list`).DataTable({
        lengthChange: false,
        pagingType: 'full_numbers',
        stateSave: true,
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
       ajax: {
            url: `${http_prefix}/lua/get_widgets.lua`,
            type: 'GET',
            dataSrc: ''
        },
        columns: [
            { data: 'name' },
            {
                data: 'key',
                render: (key) => `<a target="_newtab" href="/widgets/${key}'>${key}</a>`
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
                        <a href='#embded-widget-modal' data-toggle='modal' class="badge badge-info">Embeded</a>
                        <a href='#remove-widget-modal' data-toggle='modal' class="badge badge-danger">Remove</a>
                    `);
                }
            }
        ]
    });

    $(`#widgets-list`).on('click', `a[href='#remove-widget-modal']`, function(e) {

        const row_data = $widgets_table.row($(this).parent()).data();
        const $submit_button = $(this).find(`[type='submit']`);

        $(`#remove-widget-button`).off('click').click(function () {

            const data_to_send = { widget_key: row_data.key };
            submitPost(
                { action: 'remove', JSON: JSON.stringify(data_to_send), csrf: remove_csrf },
                '#remove-widget-modal',
                $submit_button
            );
        });
    });

    $(`#widgets-list`).on('click', `a[href='#edit-widget-modal']`, function(e) {

        const $submit_button = $(this).find(`[type='submit']`);
        const row_data = $widgets_table.row($(this).parent()).data();
        row_data.key_ip = row_data.params.key_ip;
        row_data.key_mac = row_data.params.key_mac;
        row_data.key_asn = row_data.params.key_asn;
        row_data.interface = row_data.params.ifid;

        // Luca this is the magic line, it fills edit-modal input fields
        $('#edit-widget-modal form [name]').each(function(e) {
            $(this).val(row_data[$(this).attr('name')]);
        });

        $(`#edit-widget-modal form`).off('submit').submit(function (e) {

            e.preventDefault();

            const data_to_send = serializeFormArrayIntoObject($(this).serializeArray());
            data_to_send.widget_key = row_data.key;

            submitPost(
                { action: 'edit', JSON: JSON.stringify(data_to_send), csrf: edit_csrf },
                `#edit-widget-modal`,
                $submit_button
            );
        });
    });

    $(`#add-widget-modal form`).submit(function(e) {

        e.preventDefault();
        const $submit_button = $(this).find(`[type='submit']`);
        const data_to_send = serializeFormArrayIntoObject($(this).serializeArray());

        submitPost(
            { action: 'add', csrf: add_csrf, JSON: JSON.stringify(data_to_send) },
            `#add-widget-modal`,
            $submit_button
        );
    });

});
