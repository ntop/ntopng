// return true if the status code is different from 200
const check_status_code = (status_code, status_text, $error_label) => {
        
    const is_different = status_code != 200;

    if (is_different && $error_label != null) {
        $error_label.text(`${i18n.request_failed_message}: ${status_code} - ${status_text}`).show();
    }
    else if (is_different && $error_label == null) {
        alert(`${i18n.request_failed_message}: ${status_code} - ${status_text}`);
    }

    return is_different;
}

const get_configuration_data = ($config_table, $button_caller) => {

    // get row data
    const row_data = $config_table.row($button_caller.parent().parent()).data();

    return {
        config_id: row_data.id,
        config_name: row_data.name,
        config_targets: row_data.targets
    }
}

function can_clone_config() {
    return((subdir != "system") && (subdir != "syslog"));
}

$(document).ready(function() {

    const $config_table = $("#config-list").DataTable({
        lengthChange: false,
        stateSave: true,
        initComplete: function() {
            // clear searchbox datatable
            $(".dataTables_filter").find("input[type='search']").val('').trigger('keyup');
        },
        language: {
            paginate: {
               previous: '&lt;',
               next: '&gt;'
            }
        },
        ajax: {
            url: `${http_prefix}/lua/get_scripts_configsets.lua?script_subdir=${subdir}`,
            type: 'GET',
            dataSrc: ''
        },
        columns: [
            {
                data: 'name',
                render: function(data, type, row) {
                    return `<b>${data}</b>`
                }
            },
            {
                data: 'targets',
                render: function(data, type, row) {

                    // show targets as a string into display mode
                    // if there aren't ant targets then show an alert
                    if (type == "display" && data.length > 0) {
                        const flat = data.map((f) => f.label);
                        return flat.join(', ');
                    }
                    else if(type == 'display' && data.length == 0 && row.id != 0) {
                        return `<div class='text-warning'>
                                    <i class='fas fa-exclamation-triangle'></i> <b>${i18n.warning}</b>: ${i18n.no_targets_applied}
                                </div>`
                    }

                    // return targets as a string
                    const flat = data.map((f) => f.label);
                    return flat.join(', ');
                }
            },
            {
                targets: -1,
                width: '10%',
                data: null,
                className: 'text-center',
                render: function(data, type, row) {
                    var rv = `
                            <div class='btn-group'>
                                <a href='script_list.lua?confset_id=${data.id}&confset_name=${data.name}&subdir=${subdir}' 
                                    title='${i18n.edit}' 
                                    class='btn btn-sm btn-primary square-btn'>
                                        <i class='fas fa-edit'></i>
                                </a>`
                    if(can_clone_config())
                        rv += `
                                <button title='${i18n.clone}' 
                                        data-toggle="modal"
                                        data-target="#clone-modal"
                                        class='btn btn-sm btn-secondary square-btn' type='button'>
                                <i class='fas fa-clone'></i>
                                </button>
                                <button title='${i18n.apply_to}'
                                    data-toggle='modal' data-target='#applied-modal' ${data.name == 'Default' ? 'disabled' : ''} 
                                    class='btn btn-sm btn-secondary square-btn' 
                                    type='button'>
                                        <i class='fas fa-server'></i>
                                </button>
                                <button title='${i18n.rename}' 
                                        data-toggle="modal"
                                        data-target="#rename-modal" ${data.name == 'Default' ? 'disabled' : ''} 
                                        class='btn btn-sm btn-secondary square-btn' type='button'><i class='fas fa-i-cursor'></i></button>
                                <button title='${i18n.delete}'
                                        data-toggle="modal"
                                        data-target="#delete-modal" ${data.name == 'Default' ? 'disabled' : ''} 
                                        class='btn btn-sm btn-danger square-btn' type='button'><i class='fas fa-times'></i></button>
                            </div>
                    `;

                    return rv;
                }
            }
        ]

    });

    $('#config-list').on('click', 'button[data-target="#clone-modal"]', function(e) {

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
            if (/[\@\#\<\>\\\/\?\'\"\`\~\|\,\.\:\;\,\!\&\*\(\)\{\}\[\]\_\-\+\=\%\$\^]/.test(clonation_name)) {
                $("#clone-error").text(`${i18n.invalid_characters}`).show();
                return;
            }

            // disable button until request hasn't finished
            $button.attr("disabled", "");

            $.post(`${http_prefix}/lua/edit_scripts_configsets.lua`, {
                action: 'clone',
                confset_id: config_id,
                script_subdir: subdir,
                csrf: clone_csrf,
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
                    clone_csrf = data.csrf;
                    return;
                }
                // hide errors and clean modal
                $("#clone-error").hide(); $("#clone-input").val("");
                // reload table
                $config_table.ajax.reload();
                // hide modal
                $("#clone-modal").modal('hide');
                location.reload();

            })
            .fail(({status, statusText}) => {
                check_status_code(status, statusText, $("#clone-error"));

                if (status == 200) {
                    $("#clone-error").text(`${i18n.expired_csrf}`).show();
                }

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

    $('#config-list').on('click', 'button[data-target="#applied-modal"]', function(e) {

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
                applied_value = $("#applied-input").val();
            } 

            $button.attr("disabled");

            $.post(`${http_prefix}/lua/edit_scripts_configsets.lua`, {
                action: 'set_targets',
                confset_id: config_id,
                confset_targets: applied_value,
                script_subdir: subdir,
                csrf: apply_csrf
            })
            .done((data, status, xhr) => {

                // check if the status code is successfull
                if (check_status_code(xhr.status, xhr.statusText, $("#rename-error"))) return;

                $button.removeAttr("disabled");

                if (!data.success) {
                    apply_csrf = data.csrf;
                    $("#apply-error").text(data.error).show();
                    return;
                }

                // hide errors and clean modal
                $("#apply-error").hide(); $("#apply-input").val("");
                // reload table
                $config_table.ajax.reload();
                // hide modal
                $("#applied-modal").modal('hide');
                location.reload();

            })
            .fail(({status, statusText}) => {

                check_status_code(status, statusText, $("#apply-error"));

                if (status == 200) {
                    $("#apply-error").text(`${i18n.expired_csrf}`).show();
                }

                // re-enable button
                $button.removeAttr("disabled");
            })


        });

        $("#applied-modal").on("submit", "form", function (e) {
            
            e.preventDefault();
            $("#btn-confirm-apply").trigger("click");
        });

    });

    $('#config-list').on('click', 'button[data-target="#rename-modal"]', function(e) {

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

            if (/[\@\#\<\>\\\/\?\'\"\`\~\|\,\.\:\;\,\!\&\*\(\)\{\}\[\]\_\-\+\=\%\$\^]/.test(input_value)) {
                $("#rename-error").text(`${i18n.invalid_characters}`).show();
                return;
            }

            $button.attr("disabled");

            $.post(`${http_prefix}/lua/edit_scripts_configsets.lua`, {
                action: 'rename',
                confset_id: config_id,
                csrf: rename_csrf,
                confset_name: input_value
            })
            .done((data, status, xhr) => {

                // check if the status code is successfull
                if (check_status_code(xhr.status, xhr.statusText, $("#rename-error"))) return;

                $button.removeAttr("disabled");

                if (!data.success) {
                    $("#rename-error").text(data.error).show();
                    rename_csrf = data.csrf;
                    return;
                }

                // hide errors and clean modal
                $("#rename-error").hide(); $("#rename-input").val("");
                // reload table
                $config_table.ajax.reload();
                // hide modal
                $("#rename-modal").modal('hide');
                location.reload();

            })
            .fail(({status, statusText}, st, xhr) => {

                check_status_code(status, statusText, $("#rename-error"));

                if (status == 200) {
                    $("#rename-error").text(`${i18n.expired_csrf}`).show();
                }

                // re-enable button
                $button.removeAttr("disabled");
            })
            
        })

        $("#rename-modal").on("submit", "form", function (e) {                
            e.preventDefault();
            $("#btn-confirm-rename").trigger("click");
        });

    });

    $('#config-list').on('click', 'button[data-target="#delete-modal"]', function(e) {

        const {config_id, config_name} = get_configuration_data($config_table, $(this));

        $("#delete-name").html(`<b>${config_name}</b>`)
        $("#delete-error").hide(); 

        $("#delete-modal form").off('submit');
        $("#btn-confirm-delete").off("click").click(function(e) {

            const $button = $(this);

            $button.attr("disabled", "");

            $.post(`${http_prefix}/lua/edit_scripts_configsets.lua`, {
                action: 'delete',
                csrf: delete_csrf,
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

                location.reload();

            })
            .fail(({status, statusText}) => {

                check_status_code(status, statusText, $("#delete-error"));

                if (status == 200) {
                    $("#delete-error").text(`${i18n.expired_csrf}`).show();
                }
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
