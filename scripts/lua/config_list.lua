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

-- append css tag on page
print([[<link href="]].. ntop.getHttpPrefix() ..[[/datatables/datatables.min.css" rel="stylesheet">]])

-- TODO: add i18 localazitation
print [[
   <div class='container-fluid mt-3'>
      <ul class="nav nav-pills" role='tablist'>
         <li class="nav-item">
            <a class="nav-link active" data-toggle="tab" href="#hosts" role="tab" aria-controls="hosts">Hosts</a>
         </li>
         <li class="nav-item">
         <a class="nav-link" data-toggle="tab" href="#flows" role="tab" aria-controls="hosts">Flows</a>
         </li>
      </ul>
      <div class="tab-content">
         <div class='tab-pane fade show active' id='hosts' role='tabpanel'>
            <div class='row'>
               <div class='col-md-12 col-lg-12 mt-2'>
               <table id='hostsScripts' class="table table-striped table-bordered mt-1">
                  <thead>
                     <tr>
                        <!-- <th>Enabled</th> -->
                        <th>Script Name</th>
                        <th>Script Description</th>
                        <!-- <th>Script Granularities</th> -->
                        <th>Edit Config</th>
                     </tr>
                  </thead>
                  <tbody>
                  </tbody>
               </table>
               </div>
            </div>
         </div>
      </div>
   </div>
]]

-- modal to edit config
print [[
   <div class="modal fade" role="dialog" id='modal-script'>
      <div class="modal-dialog modal-lg ">
         <div class="modal-content">
            <div class="modal-header">
            <h5 class="modal-title">Script {type} / Config <span id='script-name'></span></h5>
            <button type="button" class="close" data-dismiss="modal" aria-label="Close">
               <span aria-hidden="true">&times;</span>
            </button>
            </div>
            <div class="modal-body">
               <div id='script-config-editor'>
               </div>
            </div>
            <div class="modal-footer">
            <button type='button' class='btn btn-warning mr-auto'>Reset Default</button>
            <button type="button" class="btn btn-danger" data-dismiss="modal">Cancel</button>
            <button type="button" class="btn btn-primary">Apply changes</button>
            </div>
         </div>
      </div>
   </div>
]]

-- include datatable script and datatable plugin
print ([[ <script type="text/javascript" src="]].. ntop.getHttpPrefix() ..[[/datatables/datatables.min.js"></script> ]])
print ([[ <script type="text/javascript" src="]].. ntop.getHttpPrefix() ..[[/datatables/plugin-script-datatable.js"></script> ]])
print ([[
   <script type='text/javascript'>
      $(document).ready(function() {

         const $script_table = $("#hostsScripts").DataTable({
            dom: "Bfrtip",
            ajax: {
               'url': ']].. ntop.getHttpPrefix() ..[[/lua/get_user_scripts.lua?script_type=traffic_element&script_subdir=host',
               'type': 'GET',
               dataSrc: ''
            },
            drawCallback: function(settings) {
               // delegate_checkboxes();
            },
            buttons: [
               {
                  extend: "filterScripts",
                  attr: {
                  id: "all-scripts"
                  },
                  text: "All"
               },
               {
                  extend: "filterScripts",
                  attr: {
                  id: "enabled-scripts"
                  },
                  text: "Enabled"
               },
               {
                  extend: "filterScripts",
                  attr: {
                  id: "disabled-scripts"
                  },
                  text: "Disabled"
               }
            ],
            columns: [
               /*{ 
                  data: 'enabled',
                  render: function (data, type, row) {

                  if (type == 'display') {
                     return `<input class='script-checkbox' type='checkbox' ${data ? 'checked' : ''} />`;
                  }

                  return data;
                  },
               },*/
               { 
                  data: 'title',
                  render: function (data, type, row) {

                  if (type == 'display') {
                     return `<b>${data}</b>`
                  }
                  return data;
                  }
               },
               { data: 'description' },
               //{ data: 'granularities' },
               {
                  targets: -1,
                  data: null,
                  render: function (data, type, row) {
                     return `<button data-toggle="modal" data-target="#modal-script" data-key="${data.key}" class="btn btn-primary w-100">Edit Config</button>`;
                  },
                  sortable: false
               }
            ]
         });

         $('#hostsScripts').on('click', 'button[data-target="#modal-script"]', function(e) {
            
            // get key script
            const key_script = $(this).data('key');
            console.log(key_script);

         });

         function delegate_checkboxes() {
            $(`#hostsScripts tbody td input[type='checkbox']`).click(function (e) {

               const checked = $(this).is(':checked');

               const $disabled_button = $(`#disabled-scripts`);
               const $enabled_button = $(`#enabled-scripts`);

               // update cell data
               const $table_data = $(this).parent();
               $script_table.cell($table_data).data(checked).draw();

               // count scripts
               let enabled_count = 0;
               let disabled_count = 0;
               
               $script_table.data().each(d => {

                  if (d.enabled) {
                  enabled_count++;
                  }
                  else {
                  disabled_count++;
                  }

            });

            $enabled_button.html(`Enabled (${enabled_count})`);
            $disabled_button.html(`Disabled (${disabled_count})`);
            

            });
         }

      });
   </script>
]])

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
