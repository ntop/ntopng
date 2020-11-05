// 2020 - ntop.org
const special_characters_regex = /[\@\#\<\>\\\/\?\'\"\`\~\|\.\:\;\,\!\&\*\(\)\{\}\[\]\_\-\+\=\%\$\^]/g;

const get_configuration_data = ($config_table, $button_caller) => {

    // get row data
    const row_data = $config_table.row($button_caller.parent().parent()).data();

    return {
        config_id: row_data.id,
        config_name: row_data.name,
        config_pools: row_data.pools
    }
}

const resetConfig = () => {
    var params = {};
    params.csrf = pageCsrf;
    params.action = "reset_config";

    var form = NtopUtils.paramsToForm('<form method="post"></form>', params);
    form.appendTo('body').submit();
}

$(document).ready(function() {

    const add_columns = () => {

        const pools_column = {
            data: 'pools',
            render: function(data, type, row) {

                // show pools as a string into display mode
                // if there aren't ant pools then show an alert
                if (type == "display" && data.length > 0) {
                    const flat = data.map((f) => f.label);
                    return flat.join(', ');
                }
                else if (type == 'display' && data.length == 0) {
                    return `<i>${i18n.no_pools_applied}</i>`
                }

                // return pools as a string
                const flat = data.map((f) => f.label);
                return flat.join(', ');
            }
        }

        const name_column = {
            data: 'name',
            defaultContent: '{Config Name}',
            render: (data, type, row) => `<b>${data}</b>`
        }

        const action_column = {
            pools: -1,
            width: '200px',
            data: null,
            className: 'text-center',
            render: function(data, type, row) {

                let rv = `
                    <a class="btn btn-info btn-sm" href='edit_configset.lua?confset_id=${data.id}&subdir=${subdir}' title='${i18n.edit}'>
                        <i class='fas fa-edit'></i>
                    </a>
                    <a href='#' title='${i18n.clone}' class="btn btn-sm btn-info ${DEFAULT_CONFIG_ONLY ? "disabled" : ''}"  data-toggle="modal" data-target="#clone-modal">
                        <i class='fas fa-clone'></i>
                    </a>
                    <a href='#' title='${i18n.rename}' class="btn btn-sm btn-info ${(data.id == 0 || DEFAULT_CONFIG_ONLY) ? `disabled` : ''}" data-toggle="modal" data-target="#rename-modal">
                        <i class='fas fa-pencil-alt'></i>
                    </a>
                    <a href='#' title='${i18n.delete}' class="btn btn-sm btn-danger ${(data.id == 0 || DEFAULT_CONFIG_ONLY) ? 'disabled' : ''}" data-toggle="modal" data-target="#delete-modal">
                        <i class='fas fa-trash'></i>
                    </a>
                `;

                return `<div>${rv}</div>`;
            }
        }

        if (DEFAULT_CONFIG_ONLY) return [name_column, action_column];

        return [name_column, pools_column, action_column];
    }

    const $config_table = $("#config-list").DataTable({
        lengthChange: false,
        dom: "<'d-flex'<'mr-auto'l><'dt-search'f>B>rtip",
        pagingType: 'full_numbers',
        stateSave: true,
        buttons: {
            buttons: [
                {
                    text: '<i class="fas fa-sync"></i>',
                    className: 'btn-link',
                    action: function (e, dt, node, config) {
                        $config_table.ajax.reload();
                    }
                }
            ],
            dom: {
                button: {
                    className: 'btn btn-link'
                },
                container: {
                    className: 'border-left ml-1 float-right'
                }
            }
        },
        initComplete: function() {
            // clear searchbox datatable
            $(".dataTables_filter").find("input[type='search']").val('').trigger('keyup');
        },
        language: {
            info: i18n.showing_x_to_y_rows,
            search: i18n.config_search,
            infoFiltered: "",
            paginate: {
               previous: '&lt;',
               next: '&gt;',
               first: '«',
                last: '»'
            }
        },
        ajax: {
            url: `${http_prefix}/lua/get_scripts_configsets.lua?script_subdir=${subdir}`,
            type: 'GET',
            dataSrc: ''
        },
        columns: add_columns()
    });

    // handle clone modal
    $('#config-list').on('click', 'a[data-target="#clone-modal"]', function(e) {

        const {config_id, config_name} = get_configuration_data($config_table, $(this));

        // set title to modal
        $("#clone-name").html(`<b>${config_name}</b>`)
        // set a placeholder for the clone input
        $("#clone-input").attr("placeholder", `i.e. ${config_name} (Clone)`);
        $("#clone-error").hide();

        // unbind events from button and form to prevent older events attached
        $("#clone-modal form").off("submit");
        $("#btn-confirm-clone").off("click").click(function(e) {

            // get the new name for the clonation
            let clonation_name = $("#clone-input").val();
            const $button = $(this);

            clonation_name = clonation_name.trim();

            if (clonation_name == null || clonation_name == "" || clonation_name == undefined) {
                $("#clone-error").text(`${i18n.empty_value_message}`).show();
                return;
            }

            if (clonation_name.length > 16) {
                $("#clone-error").text(`${i18n.max_input_length}`).show();
                return;
            }

            // check if there is any special characters
            if (special_characters_regex.test(clonation_name)) {
                $("#clone-error").text(`${i18n.invalid_characters}`).show();
                return;
            }

            // disable button until request hasn't finished
            $button.attr("disabled", "");

            $.post(`${http_prefix}/lua/edit_scripts_configsets.lua`, {
                action: 'clone',
                confset_id: config_id,
                script_subdir: subdir,
                csrf: pageCsrf,
                confset_name: clonation_name
            })
            .then((data, result, xhr) => {

                // check if the status code is successfull
                if (NtopUtils.check_status_code(xhr.status, xhr.statusText, $("#clone-error"))) return;

                // re-enable button
                $button.removeAttr("disabled");
                // if the operation was not successful then show an error
                if (!data.success) {
                    $("#clone-error").text(data.error).show();
                    return;
                }
                // hide errors and clean modal
                $("#clone-error").hide(); $("#clone-input").val("");
                // reload table
                $config_table.ajax.reload();
                // hide modal
                $("#clone-modal").modal('hide');


            })
            .fail(({status, statusText}) => {

                NtopUtils.check_status_code(status, statusText, $("#clone-error"));
                // re-enable button
                $button.removeAttr("disabled");
            })

        })

        $("#clone-modal").on("submit", "form", function (e) {
            // prevent default form submit
            e.preventDefault();
            $("#btn-confirm-clone").trigger("click");
        });
    });

    // handle rename modal
    $('#config-list').on('click', 'a[data-target="#rename-modal"]', function(e) {

        const {config_id, config_name} = get_configuration_data($config_table, $(this));

        $("#config-name").html(`<b>${config_name}</b>`);
        $("#rename-input").attr('value', config_name);

        // bind rename click event
        $("#rename-modal form").off("submit");
        $("#btn-confirm-rename").off('click').click(function(e) {

            const $button = $(this);
            let input_value = $("#rename-input").val();

            input_value = input_value.trim();

            // show error message if the input is empty
            if (input_value == "" || input_value == null || input_value == undefined) {
                $("#rename-error").text(`${i18n.empty_value_message}`).show();
                return;
            }

            if (input_value.length > 16) {
                $("#rename-error").text(`${i18n.max_input_length}`).show();
                return;
            }

            if (special_characters_regex.test(input_value)) {
                $("#rename-error").text(`${i18n.invalid_characters}`).show();
                return;
            }

            $button.attr("disabled", "");

            $.post(`${http_prefix}/lua/edit_scripts_configsets.lua`, {
                action: 'rename',
                confset_id: config_id,
                csrf: pageCsrf,
                confset_name: input_value
            })
            .done((data, status, xhr) => {

                // check if the status code is successfull
                if (NtopUtils.check_status_code(xhr.status, xhr.statusText, $("#rename-error"))) return;

                $button.removeAttr("disabled");

                if (!data.success) {
                    $("#rename-error").text(data.error).show();
                    return;
                }

                // hide errors and clean modal
                $("#rename-error").hide(); $("#rename-input").val("");
                // reload table
                $config_table.ajax.reload();
                // hide modal
                $("#rename-modal").modal('hide');


            })
            .fail(({status, statusText}, st, xhr) => {

                NtopUtils.check_status_code(status, statusText, $("#rename-error"));

                // re-enable button
                $button.removeAttr("disabled");
            })

        })

        $("#rename-modal").on("submit", "form", function (e) {
            e.preventDefault();
            $("#btn-confirm-rename").trigger("click");
        });

    });

    // handle delete modal
    $('#config-list').on('click', 'a[data-target="#delete-modal"]', function(e) {

        const {config_id, config_name} = get_configuration_data($config_table, $(this));

        $("#delete-name").html(`<b>${config_name}</b>`)
        $("#delete-error").hide();

        $("#delete-modal form").off('submit');
        $("#btn-confirm-delete").off("click").click(function(e) {

            const $button = $(this);

            $button.attr("disabled", "");

            $.post(`${http_prefix}/lua/edit_scripts_configsets.lua`, {
                action: 'delete',
                csrf: pageCsrf,
                confset_id: config_id,
            })
            .done((data, status, xhr) => {

                // check if the status code is successfull
                if (NtopUtils.check_status_code(xhr.status, xhr.statusText, $("#delete-error"))) return;

                $button.removeAttr("disabled");

                if (!data.success) {
                    $("#delete-error").text(data.error).show();
                    return;
                }

                $("#delete-error").hide();
                // reload table
                $config_table.ajax.reload();
                // hide modal
                $("#delete-modal").modal('hide');



            })
            .fail(({status, statusText}) => {

                NtopUtils.check_status_code(status, statusText, $("#delete-error"));

                // re-enable button
                $button.removeAttr("disabled");
            })

        })

        $("#delete-modal").on("submit", "form", function (e) {

            e.preventDefault();
            $("#btn-confirm-delete").trigger("click");
        });

    });

});
