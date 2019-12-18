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
                <table id="config-list" class='table table-striped table-hover mt-3'>
                    <thead>
                        <tr>
                            <th>Configuration Name</th>
                            <th>Edit Configuration</th>
                            <th>Config Settings</th>
                        </tr>
                    </thead>
                    <tbody>

                    </tbody>
                </table>
            </div>
        </div>
    </div>
]])

-- rename modal
print([[

    <!-- Modal -->
    <div class="modal" id="rename-modal" tabindex="-1" role="dialog" aria-hidden="true">
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
                <button type="button" class="btn btn-secondary" data-dismiss="modal"><i class='fas fa-times'></i> Cancel</button>
                <button type="button" id='btn-confirm-rename' class="btn btn-primary"><i class='fas fa-save'></i> Rename Config</button>
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
                    text: '<i class="fas fa-plus-circle"></i> Add New Config',
                    attr: {
                        class: 'btn btn-success'
                    },
                    action: function(event, table) {
                        console.log(event)
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
                    targets: -2,
                    data: null, 
                    width: '10%',
                    render: function(data, type, row) {
                        return `<a href='script_list.lua?confset_id=${data.id}' class='btn btn-info w-100'><i class='fas fa-edit'></i> Edit Config</a>`;
                    }
                },
                {
                    targets: -1,
                    data: null,
                    width: '16%',
                    render: function(data, type, row) {
                        return `
                            <div class='btn-group'>
                                <button data-action='clone' class='btn btn-secondary' type='button'><i class='fas fa-clone'></i> Clone</button>
                                <button data-action='rename' data-toggle="modal" data-target="#rename-modal" ${data.name == 'Default' ? 'disabled' : ''} class='btn btn-secondary' type='button'><i class='fas fa-i-cursor'></i> Rename</button>
                                <button data-action='delete' ${data.name == 'Default' ? 'disabled' : ''} class='btn btn-danger' type='button'><i class='fas fa-times'></i> Delete</button>
                            </div>
                        `;
                    }
                }
            ]

        });

        $('#config-list').on('click', 'button[data-action="clone"]', function(e) {

            const row_data = $config_table.row($(this).parent().parent()).data();
            const conf_name = `${row_data.name} (Clone)`;
            const conf_id = row_data.id;

            $.when(
                $.get(']].. ntop.getHttpPrefix() ..[[/lua/edit_scripts_configsets.lua', {
                    action: 'clone',
                    confset_id: conf_id,
                    confset_name: conf_name
                })
            )
            .then((data, status, xhr) => {
                
                // if success then reload the page
                if (status == 'success') location.reload();

                // otherwise show a toast with error message
                // TODO

            })

        });

        $('#config-list').on('click', 'button[data-action="rename"]', function(e) {

            const row_data = $config_table.row($(this).parent().parent()).data();
            const conf_id = row_data.id;

            $("#config-name").html(`<b>${row_data.name}</b>`);
            $("#rename-input").attr('placeholder', row_data.name);

            // bind rename click event

            $("#btn-confirm-rename").off('click');

            $("#btn-confirm-rename").click(function(e) {

                const input_value = $("#rename-input").val();

                // show error message if the input is empty
                if (input_value == "" || input_value == null || input_value == undefined) {
                    $("#rename-error").text("The new name cannot be empty!").show();
                    return;
                }

                // show error message if the new name equals the older one
                if (input_value == row_data.name) {
                    $("#rename-error").text("The new name cannot be the older one!").show();
                    return;
                }

                $.when(
                    $.get(']].. ntop.getHttpPrefix() ..[[/lua/edit_scripts_configsets.lua', {
                        action: 'rename',
                        confset_id: conf_id,
                        confset_name: input_value
                    })
                )
                .then((data, status, xhr) => {

                    console.log(data);

                    if (status == 'success') location.reload();
        
                    if (data.error != null) {
                        $("#rename-error").text(data.error).show();
                    }

                })


            })


        });

        $('#config-list').on('click', 'button[data-action="delete"]', function(e) {

            const row_data = $config_table.row($(this).parent().parent()).data();
            const conf_id = row_data.id;

            $.when(
                $.get(']].. ntop.getHttpPrefix() ..[[/lua/edit_scripts_configsets.lua', {
                    action: 'delete',
                    confset_id: conf_id,
                })
            )
            .then((data, status, xhr) => {
                
                // if success then reload the page
                if (status == 'success' && data.error != null) location.reload();

                // otherwise show a toast with error message
                // TODO

            })

        });

    })
</script>
]])


dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
