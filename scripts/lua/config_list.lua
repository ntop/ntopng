--
-- (C) 2019 - ntop.org
--
dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
local ts_utils = require("ts_utils")
local info = ntop.getInfo() 
local page_utils = require("page_utils")
local format_utils = require("format_utils")
local os_utils = require "os_utils"

sendHTTPContentTypeHeader('text/html')

page_utils.print_header(i18n("about.about_x", { product=info.product }))


active_page = "about"
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

print([[<link href="]].. ntop.getHttpPrefix() ..[[/datatables/datatables.min.css" rel="stylesheet">]])


print([[
    <div class='container-fluid mt-3'>
        <div class='row'>
            <div class='col-md-12 col-lg-12'>
                <div class='table-responsive'>
                    <table id="config-list" class='table table-striped table-hover mt-3'>
                        <thead>
                            <tr>
                                <th>Configuration Name</th>
                                <th>Config Settings</th>
                            </tr>
                        </thead>
                        <tbody>

                        </tbody>
                    </table>
                </div>
            </div>
        </div>
    </div>
]])

-- rename modal
print([[

    <div class="modal fade" id="rename-modal" tabindex="-1" role="dialog" aria-hidden="true">
        <div class="modal-dialog modal-dialog-centered" role="document">
            <div class="modal-content">
            <div class="modal-header">
                <h5 class="modal-title">Rename Configuration: <span id='config-name'></span></h5>
                <button type="button" class="close" data-dismiss="modal" aria-label="Close">
                    <span aria-hidden="true">&times;</span>
                </button>
            </div>
            <div class="modal-body">
                <form class='form'>
                    <div class='form-group'>
                        <label class='form-label' for='#rename-input'>Type the new name:</label>
                        <input type='text' id='rename-input' class='form-control' />
                        <div class="invalid-feedback" id='rename-error' >
                            {message}
                        </div>
                    </div>
                </form>
            </div>
            <div class="modal-footer">
                <button type="button" class="btn btn-secondary" data-dismiss="modal">Cancel</button>
                <button type="button" id='btn-confirm-rename' class="btn btn-primary">Rename Config</button>
            </div>
            </div>
        </div>
    </div>
]])

-- clone modal
print([[

    <div class="modal fade" id="clone-modal" tabindex="-1" role="dialog" aria-hidden="true">
        <div class="modal-dialog modal-dialog-centered" role="document">
            <div class="modal-content">
            <div class="modal-header">
                <h5 class="modal-title">Cloning Configuration: <span id='clone-name'></span></h5>
                <button type="button" class="close" data-dismiss="modal" aria-label="Close">
                    <span aria-hidden="true">&times;</span>
                </button>
            </div>
            <div class="modal-body">
                <form class='form'>
                    <div class='form-group'>
                        <label class='form-label' for='#clone-input'>Type a name for the clonation:</label>
                        <input type='text' id='clone-input' class='form-control'/>
                        <div class="invalid-feedback" id='clone-error'>
                            {message}
                        </div>
                    </div>
                </form>
            </div>
            <div class="modal-footer">
                <button type="button" class="btn btn-secondary" data-dismiss="modal">Cancel</button>
                <button type="button" id='btn-confirm-clone' class="btn btn-primary">Confirm Cloning</button>
            </div>
            </div>
        </div>
    </div>
]])

-- delete modal
print([[

    <div class="modal fade" id="delete-modal" tabindex="-1" role="dialog" aria-hidden="true">
        <div class="modal-dialog modal-dialog-centered" role="document">
            <div class="modal-content">
            <div class="modal-header">
                <h5 class="modal-title">Deleting Configuration: <span id='delete-name'></span></h5>
                <button type="button" class="close" data-dismiss="modal" aria-label="Close">
                    <span aria-hidden="true">&times;</span>
                </button>
            </div>
            <div class="modal-body">
                Do you want really remove this configuration?<br>
                <b>Attention</b>: this operation is irreversibile
            </div>
            <div class="modal-footer">
                <button type="button" class="btn btn-secondary" data-dismiss="modal">Cancel</button>
                <button type="button" id='btn-confirm-delete' class="btn btn-danger">Delete Config</button>
            </div>
            </div>
        </div>
    </div>
]])

-- create modal
print([[

    <div class="modal fade" id="create-modal" tabindex="-1" role="dialog" aria-hidden="true">
        <div class="modal-dialog modal-dialog-centered" role="document">
            <div class="modal-content">
            <div class="modal-header">
                <h5 class="modal-title">Create New Configuration</h5>
                <button type="button" class="close" data-dismiss="modal" aria-label="Close">
                    <span aria-hidden="true">&times;</span>
                </button>
            </div>
            <div class="modal-body">
                <form class='form'>
                    <div class='form-group'>
                        <label class='form-label' for='#create-input'>Type a new name:</label>
                        <input type='text' id='create-input' class='form-control' />
                        <div class="invalid-feedback" id='create-error' >
                            {message}
                        </div>
                    </div>
                </form>
            </div>
            <div class="modal-footer">
                <button type="button" class="btn btn-secondary" data-dismiss="modal">Cancel</button>
                <button type="button" id='btn-confirm-creation' class="btn btn-primary">Create Config</button>
            </div>
            </div>
        </div>
    </div>


]])

-- add datatable script to config list page
print ([[ <script type="text/javascript" src="]].. ntop.getHttpPrefix() ..[[/datatables/datatables.min.js"></script> ]])

print([[
<script type='text/javascript'>
    $(document).ready(function() {


        const $config_table = $("#config-list").DataTable({
            dom: "Bfrtip",
            ajax: {
                url: ']].. ntop.getHttpPrefix() ..[[/lua/get_scripts_configsets.lua',
                type: 'GET',
                dataSrc: ''
            },
            buttons: [
                {
                    text: 'Add New Config',
                    attr: {
                        class: 'btn btn-primary'
                    },
                    action: function(event, table) {
                        $("#create-modal").modal('show');
                    }
                }
            ],
            columns: [
                {
                    data: 'name',
                    render: function(data, type, row) {
                        return `<b>${data}</b>`
                    }
                },
                {
                    targets: -1,
                    width: '20%',
                    data: null,
                    render: function(data, type, row) {
                        return `
                            <div class='btn-group'>
                                <a href='script_list.lua?confset_id=${data.id}' title='Edit' class='btn btn-info'><i class='fas fa-edit'></i></a>
                                <button title='Clone' data-toggle="modal" data-target="#clone-modal" class='btn btn-secondary' type='button'><i class='fas fa-clone'></i></button>
                                <button title='Rename' data-toggle="modal" data-target="#rename-modal" ${data.name == 'Default' ? 'disabled' : ''} class='btn btn-secondary' type='button'><i class='fas fa-i-cursor'></i></button>
                                <button title='Delete' data-toggle="modal" data-target="#delete-modal" ${data.name == 'Default' ? 'disabled' : ''} class='btn btn-danger' type='button'><i class='fas fa-times'></i></button>
                            </div>
                        `;
                    }
                }
            ]

        });

        $("#btn-confirm-creation").click(function() {

            const $button = $(this);
            const input_value = $('#create-input').val();

            if (input_value == null || input_value == undefined || input_value == null) {

                $("#create-error").text("The name for the new configuration cannot be null!").show();
                return;
            }

            $button.attr("disabled", "");

            $.when(
                $.get(']].. ntop.getHttpPrefix() ..[[/lua/edit_scripts_configsets.lua', {
                    action: 'add',
                    confset_name: input_value    
                })
            )
            .then((data, status, xhr) => {
                
                $button.removeAttr("disabled");

                const is_empty = !Object.keys(data).length;
                if (!is_empty) {
                    $("#create-error").text(data.error).show();
                    return;
                }

                // hide errors and clean modal
                $("#create-error").hide(); $("#create-input").val("");
                // reload table
                $config_table.ajax.reload();
                // hide modal
                $("#create-modal").modal('hide');

            });

        })

        $('#config-list').on('click', 'button[data-target="#clone-modal"]', function(e) {

            const row_data = $config_table.row($(this).parent().parent()).data();
            const conf_name = `${row_data.name}`;
            const conf_id = row_data.id;

            $("#clone-name").html(`<b>${conf_name}</b>`)
            $("#clone-input").attr("placeholder", `i.e. ${conf_name} (Clone)`);

            $("#btn-confirm-clone").off("click");
            $("#btn-confirm-clone").click(function(e) {

                const clonation_name = $("#clone-input").val();
                const $button = $(this);

                if (clonation_name == null || clonation_name == "" || clonation_name == undefined) {

                    $("#clone-error").text("The name cannot be empty!").show();
                    return;
                }

                $button.attr("disabled", "");

                $.when(
                    $.get(']].. ntop.getHttpPrefix() ..[[/lua/edit_scripts_configsets.lua', {
                        action: 'clone',
                        confset_id: conf_id,
                        confset_name: clonation_name    
                    })
                )
                .then((data, status, xhr) => {
                    
                    $button.removeAttr("disabled");

                    const is_empty = !Object.keys(data).length;
                    if (!is_empty) {
                        $("#clone-error").text(data.error).show();
                        return;
                    }

                    // hide errors and clean modal
                    $("#clone-error").hide(); $("#clone-input").val("");
                    // reload table
                    $config_table.ajax.reload();
                    // hide modal
                    $("#clone-modal").modal('hide');

                });
            })


        });

        $('#config-list').on('click', 'button[data-target="#rename-modal"]', function(e) {

            const row_data = $config_table.row($(this).parent().parent()).data();
            const conf_id = row_data.id;

            $("#config-name").html(`<b>${row_data.name}</b>`);
            $("#rename-input").attr('placeholder', row_data.name);

            // bind rename click event

            $("#btn-confirm-rename").off('click');

            $("#btn-confirm-rename").click(function(e) {

                const $button = $(this);
                const input_value = $("#rename-input").val();

                // show error message if the input is empty
                if (input_value == "" || input_value == null || input_value == undefined) {
                    $("#rename-error").text("The new name cannot be empty!").show();
                    return;
                }

                $button.attr("disabled");

                $.when(
                    $.get(']].. ntop.getHttpPrefix() ..[[/lua/edit_scripts_configsets.lua', {
                        action: 'rename',
                        confset_id: conf_id,
                        confset_name: input_value
                    })
                )
                .then((data, status, xhr) => {

                    $button.removeAttr("disabled");

                    const is_empty = !Object.keys(data).length;
                    if (!is_empty) {
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


            })


        });

        $('#config-list').on('click', 'button[data-target="#delete-modal"]', function(e) {

            const row_data = $config_table.row($(this).parent().parent()).data();
            const conf_id = row_data.id;

            $("#btn-confirm-delete").off("click");
            $("#btn-confirm-delete").click(function(e) {

                const $button = $(this);
                $button.attr("disabled", "");

                $.when(
                    $.get(']].. ntop.getHttpPrefix() ..[[/lua/edit_scripts_configsets.lua', {
                        action: 'delete',
                        confset_id: conf_id,
                    })
                )
                .then((data, status, xhr) => {
                    
                    $button.removeAttr("disabled");

                    const is_empty = !Object.keys(data).length;
                    if (!is_empty) {
                        $("#delete-error").text(data.error).show();
                        return;
                    }

                    $("#delete-error").hide(); 
                    // reload table
                    $config_table.ajax.reload();
                    // hide modal
                    $("#delete-modal").modal('hide');
    
                });

            })

            

        });

    })
</script>
]])


dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
