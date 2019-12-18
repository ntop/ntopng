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

print([[


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
                                <button data-action='rename' ${data.name == 'Default' ? 'disabled' : ''} class='btn btn-secondary' type='button'><i class='fas fa-i-cursor'></i> Rename</button>
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
                if (status == 'success') location.reload();

                // otherwise show a toast with error message
                // TODO

            })

        });

    })
</script>
]])


dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
