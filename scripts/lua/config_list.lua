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

                <table id="config-list" class='table table-striped table-bordered mt-3'>
                    <thead>
                        <tr>
                            <th>Configuration Name</th>
                            <th>Edit Configuration</th>
                            <th>Config Settings<th>
                        </tr>
                    </thead>
                    <tbody>

                    </tbody>
                </table>
            </div>
        </div>
    </div>
]])

-- add datatable script to config list page
print ([[ <script type="text/javascript" src="]].. ntop.getHttpPrefix() ..[[/datatables/datatables.min.js"></script> ]])

print([[
<script type='text/javascript'>
    $(document).ready(function() {


        $("#config-list").DataTable({

            ajax: {
                url: ']].. ntop.getHttpPrefix() ..[[lua/get_scripts_configsets.lua',
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
                    targets: -2,
                    data: null, 
                    render: function(data, type, row) {
                        return `<a href='#' class='btn btn-info'>Edit Config</a>`;
                    }
                },
                {
                    targets: -1,
                    data: null,
                    render: function(data, type, row) {
                        return `
                            <div class='btn-group'>
                                <button class='btn btn-secondary' type='button'>Clone</button>
                                <button class='btn btn-secondary' type='button'>Rename</button>
                                <button class='btn btn-danger' type='button'>Delete</button>
                            </div>
                        `;
                    }
                }
            ]

        });

    })
</script>
]])


