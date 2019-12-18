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

local script_type = "traffic_element"
local script_subdir = "host"
local confset_id = _GET["confset_id"]

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
               <div class='col-md-12 col-lg-12 mt-3'>
               <table id='hostsScripts' class="table table-striped table-bordered mt-3">
                  <thead>
                     <tr>
                        <th>Enabled</th>
                        <th>Script Name</th>
                        <th>Script Description</th>
                        <th>Script Granularities</th>
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

-- toast to alert operations about saving
print ([[
   <div aria-live="polite" aria-atomic="true">
      <div class="toast script-toast">
         <div class="toast-header">
            <strong class="mr-auto">Esito Operazione</strong>
            <button type="button" class="ml-2 mb-1 close" data-dismiss="toast" aria-label="Close">
               <span aria-hidden="true">&times;</span>
            </button>
         </div>
         <div class="toast-body">
            {message}
         </div>
      </div>
 </div>
]])

-- modal to edit config
print ([[
   <div class="modal fade" role="dialog" id='modal-script'>
      <div class="modal-dialog modal-lg ">
         <div class="modal-content">
            <div class="modal-header">
            <h5 class="modal-title">Script ]].. script_type ..[[ / Config <span id='script-name'></span></h5>
            <button type="button" class="close" data-dismiss="modal" aria-label="Close">
               <span aria-hidden="true">&times;</span>
            </button>
            </div>
            <div class="modal-body">
               <form method='post'>
                  <table class='table table-borderless' id='script-config-editor'>
                     <tbody>
                     </tbody>
                  </table>
               </form>
            </div>
            <div class="modal-footer">
               <button type='button' class='btn btn-warning mr-auto'>Reset Default</button>
               <button type="button" class="btn btn-danger" data-dismiss="modal">Cancel</button>
               <button id="btn-apply" type="button" class="btn btn-primary" data-dismiss="modal">Apply changes</button>
            </div>
         </div>
      </div>
   </div>
]])

-- include datatable script and datatable plugin
print ([[ <script type="text/javascript" src="]].. ntop.getHttpPrefix() ..[[/datatables/datatables.min.js"></script> ]])
print ([[ <script type="text/javascript" src="]].. ntop.getHttpPrefix() ..[[/datatables/plugin-script-datatable.js"></script> ]])
print ([[
   <script type='text/javascript'>
      $(document).ready(function() {

         const $toast = $('.toast').toast({
            autohide: true,
            delay: 2000
         })

         const $script_table = $("#hostsScripts").DataTable({
            dom: "Bfrtip",
            ajax: {
               'url': ']].. ntop.getHttpPrefix() ..[[/lua/get_user_scripts.lua?script_type=]].. script_type ..[[&script_subdir=]].. script_subdir ..[[',
               'type': 'GET',
               dataSrc: ''
            },
            drawCallback: function(settings) {
               delegate_checkboxes();
            },
            initComplete: function(settings, json) {
               count_scripts();
            },
            order: [ [0, "desc"] ],
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
               { 
                  data: 'is_enabled',
                  render: function (data, type, row) {

                     if (type == 'display') {
                        return `<input class='script-checkbox' type='checkbox' ${data ? 'checked' : ''} />`;
                     }

                  return data;
                  },
               },
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
               { 
                  data: 'enabled_hooks',
                  render: function (data, type, row) {
                     return data.join(', ')
                  }
               },
               {
                  targets: -1,
                  data: null,
                  render: function (data, type, row) {
                     return `<button data-toggle="modal" data-target="#modal-script" class="btn btn-primary w-100">Edit Config</button>`;
                  },
                  sortable: false
               }
            ]
         });

         $('#hostsScripts').on('click', 'button[data-target="#modal-script"]', function(e) {
            
            // get script key and script name
            const row_data = $script_table.row($(this).parent().parent()).data();
            const script_key = row_data.key;
            const script_title = row_data.title;
            
            // change title to modal
            $("#script-name").text(script_title);

            $.when(
               $.get(']].. ntop.getHttpPrefix() ..[[/lua/get_user_script_config.lua', {
                     script_type: ']].. script_type ..[[',
                     script_subdir: ']].. script_subdir ..[[',
                     script_key: script_key
                  }
               )
            )
            .then((data, status, x) => {

               // clean table editor
               const $table_editor = $("#script-config-editor > tbody");
               $table_editor.empty();

               // destructure gui and hooks from data
               const {gui, hooks} = data;
               console.log(data);

               const build_gui = (gui, hooks) => {

                  const build_input_box = ({input_builder, field_max, field_min, fields_unit, field_operator}) => {

                     // TODO: other templates
                     if (input_builder == '') {
                        return $("<p>Not enabled!</p>")
                     }
                     else if (input_builder == 'threshold_cross') {
                        return $(`<div class='input-group template'></div>`)
                           .append(`<div class='input-group-prepend'>
                                 <select class='btn btn-outline-secondary'>
                                       <option>${field_operator == "gt" ? ">" : "<"}</option>
                                       <option>${field_operator != "gt" ? ">" : "<"}</option>
                                 </select>
                           </div>`)
                           .append(`<input type='number' 
                                          class='form-control'
                                          min='${field_min == undefined ? '' : field_min}'
                                          max='${field_max == undefined ? '' : field_max}'>`)
                           .append(`<span class='mt-auto mb-auto ml-2 mr-2'>${fields_unit}</span>`);
                     }

                  }

                  const build_hook = ({label, enabled, script_conf}, granularity) => {

                     const $element = $("<tr></tr>").attr("id", granularity);
                     // create checkbox for hook
                     $element.append(`<td><input type="checkbox" ${enabled ? "checked" : ""} ></td>`);
                     // create label for hook
                     $element.append(`<td><label for=''>${label}</label><td>`);
                     
                     // create input_box
                     const $input_box = build_input_box(gui);
                     // set script conf params
                     $input_box.find("input[type='number']").val(script_conf.threshold);

                     $element.append(`<td></td>`).append($input_box);

                     return $element;
                  }

                  // append hooks to table
                  if ("5mins" in hooks) {
                     $table_editor.append(build_hook(hooks["5mins"], "5mins"));
                  }
                  if ("hour" in hooks) {
                     $table_editor.append(build_hook(hooks["hour"], "hour"));
                  }
                  if ("day" in hooks) {
                     $table_editor.append(build_hook(hooks["day"], "day"));
                  }
                  if ("min" in hooks) {
                     $table_editor.append(build_hook(hooks["min"], "min"));
                  }

               }

               build_gui(gui, hooks);
               
               // bind event to modal_button
               const on_apply = (e) => {

                  // prepare request to save config
                  const data = {}
            
                  $table_editor.children("tr").each(function (index) {

                     const id = $(this).attr("id");
                     const enabled = $(this).find("input[type='checkbox']").is(":checked");
                     const $template = $(this).find(".template");

                     const operator = $template.find("select").val() == ">" ? "gt" : "lt";
                     const threshold = $template.find("input").val();

                     data[id] = {
                        'enabled': enabled,
                        'script_conf': {
                           'operator': operator,
                           'threshold': threshold
                        }
                     }
                  });                 

                  // make post request
                  $.when(
                     $.post(']].. ntop.getHttpPrefix() ..[[/lua/edit_user_script_config.lua', {
                        script_type: ']].. script_type ..[[',
                        script_subdir: ']].. script_subdir ..[[',
                        script_key: script_key,
                        csrf: ']].. ntop.getRandomCSRFValue() ..[[',
                        JSON: JSON.stringify(data),
                        confset_id: ]].. confset_id ..[[
                     })
                  )
                  .then((d, status, xhr) => {

                     console.log(d, status, xhr);
                     $toast.find(".toast-body").html(`The edits has been saved for <b>${script_title}</b>`)
                     $toast.toast('show');

                     location.reload();

                  })

               };
               $("#btn-apply").off("click");
               $("#btn-apply").click(on_apply);

            });


         });

         /**
         * Delegate checkboxes event for datatable plugin
         */
         function delegate_checkboxes() {
            $(`#hostsScripts tbody td input[type='checkbox']`).click(function (e) {

               const checked = $(this).is(':checked');

               // update cell data
               const $table_data = $(this).parent();
               // fix little datatable bug about events
               if ($table_data.length == 0) return;
               $script_table.cell($table_data).data(checked).draw();

               count_scripts();
            });
         }

         /**
         * Count the scripts number inside the table
         */
         function count_scripts() {

            // count scripts
            const $disabled_button = $(`#disabled-scripts`);
            const $all_button = $("#all-scripts");
            const $enabled_button = $(`#enabled-scripts`);

            let enabled_count = 0;
            let disabled_count = 0;
            
            $script_table.data().each(d => {

               if (d.is_enabled) {
                  enabled_count++;
               }
               else {
                  disabled_count++;
               }

            });

            $all_button.html(`All (${enabled_count + disabled_count})`)
            $enabled_button.html(`Enabled (${enabled_count})`);
            $disabled_button.html(`Disabled (${disabled_count})`);
         }

      });
   </script>
]])

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
