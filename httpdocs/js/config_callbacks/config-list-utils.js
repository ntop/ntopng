// 2020 - ntop.org
const special_characters_regex = /[\@\#\<\>\\\/\?\'\"\`\~\|\.\:\;\,\!\&\*\(\)\{\}\[\]\_\-\+\=\%\$\^]/g;

const get_configuration_data = ($config_table, $button_caller) => {

    // get row data
    const row_data = $config_table.row($button_caller.parent()).data();

    return {
        config_id: row_data.id,
        config_name: row_data.name,
        config_targets: row_data.targets
    }
}

const resetConfig = () => {
    var params = {};
    params.csrf = pageCsrf;
    params.action = "reset_config";

    var form = paramsToForm('<form method="post"></form>', params);
    form.appendTo('body').submit();
}

$(document).ready(function() {

    const add_columns = () => {

        const targets_column = {
            data: 'targets',
            render: function(data, type, row) {

                // show targets as a string into display mode
                // if there aren't ant targets then show an alert
                if (type == "display" && data.length > 0) {
                    const flat = data.map((f) => f.label);
                    return flat.join(', ');
                }
                else if (type == 'display' && data.length == 0 && row.id != 0) {
                    return `<div class='text-warning'>
                                <i class='fas fa-exclamation-triangle'></i> <b>${i18n.warning}</b>: ${i18n.no_targets_applied}
                            </div>`
                }
                else if (type == "display" && row.id == 0) {
                    return `<i>${i18n.default}</i>`;
                }

                // return targets as a string
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
            targets: -1,
            width: '10%',
            data: null,
            className: 'text-center',
            render: function(data, type, row) {

                let rv = `
                    <a class="badge badge-info" href='edit_configset.lua?confset_id=${data.id}&subdir=${subdir}' title='${i18n.edit}'>
                        ${i18n.edit}
                    </a>
                `;
                if(!default_config_only)
                    rv += `
                        <a href='#'
                            title='${i18n.clone}'
                            class="badge badge-info"
                            data-toggle="modal"
                            data-target="#clone-modal">
                                ${i18n.clone}
                        </a>
                    `;
                if(data.id != 0)
                    rv += `
                        <a href='#'
                            title='${i18n.apply_to}'
                            data-toggle='modal'
                            class="badge badge-info"
                            data-target='#applied-modal'>
                                ${i18n.apply_to}
                         </a>
                         <a href='#'
                            title='${i18n.rename}'
                            class="badge badge-info"
                            data-toggle="modal"
                            data-target="#rename-modal">
                            ${i18n.rename}
                            </a>
                        <a href='#'
                            title='${i18n.delete}'
                            class="badge badge-danger"
                            data-toggle="modal"
                            data-target="#delete-modal">
                                ${i18n.delete}
                        </a>
                    `;

                return rv;
            }
        }

        if (default_config_only) return [name_column, action_column];

        return [name_column, targets_column, action_column];
    }

    const $config_table = $("#config-list").DataTable({
        lengthChange: false,
        pagingType: 'full_numbers',
        stateSave: true,
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
                if (check_status_code(xhr.status, xhr.statusText, $("#clone-error"))) return;

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

                check_status_code(status, statusText, $("#clone-error"));
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

    // handle apply modal
    $('#config-list').on('click', 'a[data-target="#applied-modal"]', function(e) {

        const {config_id, config_name, config_targets} = get_configuration_data($config_table, $(this));

        if (subdir == "flow" || subdir == "interface") {
            $("#applied-interfaces").val(config_targets.map(d => d.key.toString()))
        }
        else if (subdir == "network"){
            $("#applied-networks").val(config_targets.map(d => d.key.toString()))
        }
        else {
            $("#applied-input").val(config_targets.map(d => d.key.toString()).join(','))
        }

        // hide previous errors
        $("#apply-error").hide();

        $("#apply-name").html(`<b>${config_name}</b>`);
        $("#applied-modal form").off("submit");

        $('#btn-confirm-apply').off('click').click(function(e) {

            const $button = $(this);

            let applied_value = null;

            if (subdir == "flow" || subdir == "interface") {
                applied_value = $("#applied-interfaces").val().join(',');
            }
            else if (subdir == "network"){
                applied_value = $("#applied-networks").val().join(',');
            }
            else {
                applied_value = $("#applied-input").val().trim();
            }

            $button.attr("disabled", "");

            $.post(`${http_prefix}/lua/edit_scripts_configsets.lua`, {
                action: 'set_targets',
                confset_id: config_id,
                confset_targets: applied_value,
                script_subdir: subdir,
                csrf: pageCsrf
            })
            .done((data, status, xhr) => {

                // check if the status code is successfull
                if (check_status_code(xhr.status, xhr.statusText, $("#rename-error"))) return;

                $button.removeAttr("disabled");

                if (!data.success) {
                    $("#apply-error").text(data.error).show();
                    return;
                }

                // hide errors and clean modal
                $("#apply-error").hide(); $("#apply-input").val("");
                // reload table
                $config_table.ajax.reload();
                // hide modal
                $("#applied-modal").modal('hide');


            })
            .fail(({status, statusText}) => {

                check_status_code(status, statusText, $("#apply-error"));

                // re-enable button
                $button.removeAttr("disabled");
            })


        });

        $("#applied-modal").on("submit", "form", function (e) {

            e.preventDefault();
            $("#btn-confirm-apply").trigger("click");
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
                if (check_status_code(xhr.status, xhr.statusText, $("#rename-error"))) return;

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

                check_status_code(status, statusText, $("#rename-error"));

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
                if (check_status_code(xhr.status, xhr.statusText, $("#delete-error"))) return;

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

                check_status_code(status, statusText, $("#delete-error"));

                // re-enable button
                $button.removeAttr("disabled");
            })

        })

        $("#delete-modal").on("submit", "form", function (e) {

            e.preventDefault();
            $("#btn-confirm-delete").trigger("click");
        });

    });

    // handle import modal
    importModalHelper({
        load_config_xhr: (json_conf) => {
          return $.post(`${http_prefix}/lua/rest/set/scripts/config.lua`, {
            csrf: pageCsrf,
            JSON: json_conf,
          });
        }
    });
});
