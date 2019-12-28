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

active_page = "scripts_list"

local script_subdir = _GET["subdir"]
local confset_id = _GET["confset_id"]
local confset_name = _GET["confset_name"]

local titles = {
   ["host"] = i18n("config_scripts.granularities.host"),
   ["snmp_device"] = i18n("config_scripts.granularities.snmp_device"),
   ["system"] = i18n("config_scripts.granularities.system"),
   ["flow"] = i18n("config_scripts.granularities.flow"),
   ["interface"] = i18n("config_scripts.granularities.interface"),
   ["network"] = i18n("config_scripts.granularities.network"),
   ["syslog"] = i18n("config_scripts.granularities.syslog")
}

page_utils.print_header(i18n("scripts_list.scripts_x", { subdir=titles[script_subdir], config=confset_name }))

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")


if confset_id == nil or confset_id == "" then
   print([[<div class='alert alert-danger'>
      <b>Attention!</b> The page was not found! <a class='text-danger' href='#' onclick='history.back()'>Click here to return to the previous page!</a>
   </div>]])
else

   -- append css tag on page
   print([[<link href="]].. ntop.getHttpPrefix() ..[[/datatables/datatables.min.css" rel="stylesheet">]])

   -- TODO: add i18 localazitation
   print ([[
      <div class='container-fluid mt-3'>
         <nav aria-label="breadcrumb">
            <ol class="breadcrumb">
               <li class="breadcrumb-item" aria-current="page"><a href='/lua/config_list.lua'>]].. i18n("config_scripts.config_list", {}) ..[[</a></li>
               <li class="breadcrumb-item" aria-current="page"><a href='/lua/config_list.lua?subdir=]].. script_subdir ..[['>]].. titles[script_subdir] ..[[</a></li>
               <li class="breadcrumb-item active" aria-current="page">]].. i18n("scripts_list.config", {}) ..[[ <b>]].. confset_name ..[[</b></li>
            </ol>
         </nav>   
         <div class='row'>
                  <div class='col-md-12 col-lg-12 mt-3'>
                     <table id='hostsScripts' class="table w-100 table-striped table-hover table-bordered mt-3">
                        <thead>
                           <tr>
                              <th>]].. i18n("name", {}) ..[[</th>
                              <th>]].. i18n("description", {}) ..[[</th>
                              <th>]].. i18n("enabled", {}) ..[[</th>
                              <th>]].. i18n("action", {})..[[</th>
                           </tr>
                        </thead>
                        <tbody>
                        </tbody>
                     </table>
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
                  <h5 class="modal-title">Script / ]].. i18n("scripts_list.config", {}) ..[[ <span id='script-name'></span></h5>
               </div>
               <div class="modal-body">
                  <form id='edit-form' method='post'>
                     <table class='table table-borderless' id='script-config-editor'>
                        <thead>
                           <tr>
                              <th class='text-center'>]].. i18n("enabled", {}) ..[[</th>
                           </tr>
                        </thead>
                        <tbody></tbody>
                     </table>
                  </form>
               </div>
               <div class="modal-footer">
                  <button id='btn-reset' title='Reset Default ntopng values' type='button' class='btn btn-danger mr-auto'>]].. i18n("scripts_list.reset_default") ..[[</button>
                  <button type="button" title=']].. i18n("cancel", {}) ..[[' class="btn btn-secondary" data-dismiss="modal">]].. i18n("cancel", {}) ..[[</button>
                  <button id="btn-apply" title=']].. i18n("apply", {}) ..[[' type="button" class="btn btn-primary" data-dismiss="modal">]].. i18n("apply", {}) ..[[</button>
               </div>
            </div>
         </div>
      </div>
   ]])

   -- include datatable script and datatable plugin
   print ([[
      <script type='text/javascript'>

         $(document).ready(function() {

            const $script_table = $("#hostsScripts").DataTable({
               dom: "Bfrtip",
               language: {
                  paginate: {
                     previous: '&lt;',
                     next: '&gt;'
                  }
               },
               lengthChange: false,
               ajax: {
                  'url': ']].. ntop.getHttpPrefix() ..[[/lua/get_user_scripts.lua?confset_id=]].. confset_id ..[[&script_subdir=]].. script_subdir ..[[',
                  'type': 'GET',
                  dataSrc: ''
               },
               stateSave: true,
               initComplete: function(settings, json) {
                  // select the correct tab
                  (() => {
                     
                     // get hash from url
                     const hash = window.location.hash;

                     // redirect to correct tab
                     if (hash == undefined || hash == null || hash == "" || hash == "#enabled") {
                        $(`#enabled-scripts`).addClass("active").trigger("click");
                     }
                     else if (hash == "#disabled") {
                        $(`#disabled-scripts`).addClass("active").trigger("click");
                     }
                     else {
                        $(`#all-scripts`).addClass("active").trigger("click");
                     }

                  })();

                  // clean searchbox
                  $(".dataTables_filter").find("input[type='search']").val('').trigger('keyup');

                  // counts scripts inside table
                  count_scripts();
               },
               order: [ [0, "asc"] ],
               buttons: [
                  {
                     extend: "filterScripts",
                     attr: {
                        id: "all-scripts",
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
                     sortable: false,
                     className: 'text-center',
                     render: function (data, type, row) {

                        if (data.length <= 0 && type != "display") {
                           return false;
                        }
                        if (data.length > 0 && type != "display") {
                           return true;
                        }

                        if (data.length >= 0 && type == "display" && row.all_hooks.length > 0 && row.input_handler == undefined) {

                           $('#hostsScripts').on('click', `input[name='${row.key}-check']`, function(e) {

                              const $this = $(this);
                              const value = $this.val();
                              const hooks = row.all_hooks;
                              const data = {};

                              hooks.forEach(d => {
                                 data[d] = {
                                    enabled: (value == "true")
                                 }
                              })

                              console.log(data);

                              $.when(
                                 $.post(']].. ntop.getHttpPrefix() ..[[/lua/edit_user_script_config.lua', {
                                    script_subdir: ']].. script_subdir ..[[',
                                    script_key: row.key,
                                    csrf: ']].. ntop.getRandomCSRFValue() ..[[',
                                    JSON: JSON.stringify(data),
                                    confset_id: ]].. confset_id ..[[
                                 })
                              )
                              .then((d, status, xhr) => {
                                 location.reload();
                              })

                           });

                           return `
                           <form type='post'>
                              <div class="btn-group btn-group-toggle" data-toggle="buttons">
                                 <label class="btn btn-sm btn-secondary ${row.is_enabled ? "active" : ""}">
                                    <input value='true' type="radio" name="${row.key}-check" ${row.is_enabled ? "checked" : ""}> On
                                 </label>
                                 <label class="btn btn-sm btn-secondary ${!row.is_enabled ? "active" : ""}">
                                    <input value='false' type="radio" name="${row.key}-check" ${row.is_enabled ? "checked" : ""}> Off
                                 </label>
                              </div>
                           </form>`;

                        }
                       
                        return data.join(', ')
                     }
                  },
                  {
                     targets: -1,
                     data: null,
                     className: 'text-center',
                     render: function (data, type, row) {
                        return `
                           <div class='btn-group'>
                              <button ${row.input_handler == undefined ? "disabled" : ""} data-toggle="modal" title='Edit Script' data-target="#modal-script" class="btn btn-square btn-sm btn-primary">
                                 <i class='fas fa-edit'></i>
                              </button>
                              <a href='${data.edit_url}' title='View Source Script' class='btn btn-square btn-sm btn-secondary'><i class='fas fa-scroll'></i></a>
                           </div>
                        `;
                     },
                     sortable: false
                  }
               ]
            });

            $("#edit-form").areYouSure({
               'message':']].. i18n("scripts_list.are_you_sure", {}) ..[['
            });

            // handle modal-script close event
            $("#modal-script").on("hide.bs.modal", function(e) {

               // if the forms is dirty then ask to the user
               // if he wants save edits
               if ($('#edit-form').hasClass('dirty')) {
                  
                  // ask to user if he REALLY wants close modal
                  const result = confirm("The changes will not be saved. Are you sure?");
                  if (!result) e.preventDefault();
                  
                  // remove dirty class from form
                  $('#edit-form').removeClass('dirty');
               }
            });

            $('#hostsScripts').on('click', 'button[data-target="#modal-script"]', function(e) {
               
               // get script key and script name
               const row_data = $script_table.row($(this).parent().parent()).data();
               const script_key = row_data.key;
               const script_title = row_data.title;
               
               // change title to modal
               $("#script-name").html(`<b>${script_title}</b>`);

               $("#modal-script form").off('submit');

               $("#modal-script").on("submit", "form", function (e) {
             
                  e.preventDefault();
                  $('#edit-form').trigger('reinitialize.areYouSure');

                  $('#edit-form').removeClass('dirty');
                  $("#btn-apply").trigger("click");
               });

               $.when(
                  $.get(']].. ntop.getHttpPrefix() ..[[/lua/get_user_script_config.lua', {
                        script_subdir: ']].. script_subdir ..[[',
                        confset_id: ]].. confset_id ..[[,
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

                  const build_gui = (gui, hooks) => {

                     const build_input_box = ({input_builder, field_max, field_min, fields_unit, field_operator}) => {

                        if (input_builder == '' || input_builder == undefined || input_builder == null) {
                           return $("<p>Not enabled!</p>")
                        }
                        else if (input_builder == 'threshold_cross') {
                           return $(`<div class='input-group template w-75'></div>`)
                              .append(`<div class='input-group-prepend'>
                                    <select class='btn btn-outline-secondary'>
                                          <option selected value="gt">&gt</option>
                                          <option value="lt">&lt;</option>
                                    </select>
                              </div>`)
                              .append(`<input type='number' 
                                             class='form-control'
                                             min='${field_min == undefined ? '' : field_min}'
                                             max='${field_max == undefined ? '' : field_max}'>`)
                              .append(`<span class='mt-auto mb-auto ml-2 mr-2'>${fields_unit}</span>`)
                              .append(`<div class="invalid-feedback">{message}</div>`)
                        }

                     }

                     const build_hook = ({label, enabled, script_conf}, granularity) => {

                        // create table row inside the edit form
                        const $element = $("<tr></tr>").attr("id", granularity);

                        // create checkbox for hook
                        $element.append(`<td class='text-center'>
                           <input name="${granularity}-check" type="checkbox" ${enabled ? "checked" : ""} >
                        </td>`);

                        // create label for hook
                        $element.append(`<td><label>${label}</label></td>`);
                        
                        // create input_box
                        const $input_box = build_input_box(gui);

                        // enable readonly in inputboxes and selects if enabled field is false
                        if (!enabled) {
                           $input_box.find("input[type='number']").attr("readonly", "");
                           $input_box.find("select").attr("disabled", "");
                        }

                        // select the right operator
                        if (script_conf.operator != undefined) {
                           $input_box.find("select").attr("name", `${granularity}-select`).val(script_conf.operator)
                        }
                        // set input name
                        $input_box.find("input[type='number']").attr("name", `${granularity}-input`)
                        // set script conf params
                        $input_box.find("input[type='number']").val(script_conf.threshold);
                        // set placeholder
                        // $input_box.find("input[type='number']").attr("placeholder", script_conf.threshold);

                        // bind check event on checkboxes
                        $element.on('change', "input[type='checkbox']", function(e) {

                           const checked = $(this).prop('checked');

                           if (!checked) {
                              $input_box.find("input[type='number']").attr("readonly", "");
                              $input_box.find("select").attr("disabled", "");
                              return;
                           }
                           
                           $input_box.find("input[type='number']").removeAttr("readonly");
                              $input_box.find("select").removeAttr("disabled");

                        })

                        const $input_container = $(`<td></td>`).append($input_box);
                        $element.append($input_container);

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

                  // append gui on the edit modal
                  build_gui(gui, hooks);
               
                  // bind event to modal_button
                  const on_apply = (e) => {

                     const $button = $(this);

                     // prepare request to save config
                     const data = {}
               
                     // variable for checking errors
                     let error = false;

                     // iterate over granularities
                     $table_editor.children("tr").each(function (index) {

                        const id = $(this).attr("id");
                     
                        const enabled = $(this).find("input[type='checkbox']").is(":checked");
                        const $template = $(this).find(".template");

                        const operator = $template.find("select").val();
                        const threshold = $template.find("input").val();

                        // hide before errors
                        $template.find(`.invalid-feedback`).hide();

                        // if operator is empty then alert the user
                        if (enabled && (operator == "" || operator == undefined || operator == null)) {

                           $template.find(`.invalid-feedback`).text("Please select an operator!").show();
                           error = true;
                           return;
                        }

                        // if the value is empty then alert the user (only for checked granularities)
                        if (enabled && (threshold == null || threshold == undefined || threshold == "")) {
                           $template.find(`.invalid-feedback`).text("Please fill the input box!").show();
                           error = true;
                           return;
                        }

                        // save data into dictonary
                        data[id] = {
                           'enabled': enabled,
                           'script_conf': {
                              'operator': operator,
                              'threshold': threshold
                           }
                        }
                     });        
                     
                     // check if there are any errors on input values
                     if (error) return;

                     // remove dirty class from form
                     $('#edit-form').removeClass('dirty')

                     // disable button
                     $button.attr("disabled", "");

                     console.log(data)

                     // make post request
                     $.when(
                        $.post(']].. ntop.getHttpPrefix() ..[[/lua/edit_user_script_config.lua', {
                           script_subdir: ']].. script_subdir ..[[',
                           script_key: script_key,
                           csrf: ']].. ntop.getRandomCSRFValue() ..[[',
                           JSON: JSON.stringify(data),
                           confset_id: ]].. confset_id ..[[
                        })
                     )
                     .then((d, status, xhr) => {
                        location.reload();
                     })

                  };

                  // bind event on reset defaults button
                  const on_reset = (e) => {

                     // get default values for config
                     $.when(
                        $.get(']].. ntop.getHttpPrefix() ..[[/lua/get_user_script_config.lua', {
                           script_subdir: ']].. script_subdir ..[[',
                           script_key: script_key
                        })
                     )
                     .then((data, status, xhr) => {

                        const {hooks} = data;

                        // reset default values
                        for (key in hooks) {
                           
                           const granularity = hooks[key];

                           $(`input[name='${key}-check']`).prop('checked', granularity.enabled);

                           if (granularity.script_conf.threshold === undefined) {
                              $(`input[name='${key}-input']`).val('');
                           }
                           else {
                              $(`input[name='${key}-input']`).val(granularity.script_conf.threshold);
                           }

                           if (granularity.enabled) {
                              $(`select[name='${key}-select']`).removeAttr("disabled");
                              $(`input[name='${key}-input']`).removeAttr("readonly");
                           }
                           else {
                              $(`input[name='${key}-input']`).attr("readonly", "");
                              $(`select[name='${key}-select']`).attr("disabled", "");
                           }                  

                           $(`select[name='${key}-select']`).val(granularity.script_conf.operator);

                        }

                        // remove dirty class from form
                        $('#edit-form').removeClass('dirty')
                     });

                  }

                  // bind click event to btn-apply
                  $("#btn-apply").off("click").click(on_apply);

                  // bind reset default click event
                  $("#btn-reset").off("click").click(on_reset);

                  // bind are you sure to form
                  $('#edit-form').trigger('rescan.areYouSure');
                  $('#edit-form').trigger('reinitialize.areYouSure');

               });


            });

            /**
            * Count the scripts that are enabled, disabled inside the script table
            */
            const count_scripts = () => {

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

               $all_button.html(`]].. i18n("all", {}) ..[[ (${enabled_count + disabled_count})`)
               $enabled_button.html(`]].. i18n("enabled", {}) ..[[ (${enabled_count})`);
               $disabled_button.html(`]].. i18n("disabled", {}) ..[[ (${disabled_count})`);
            }

         });
      </script>
   ]])
end

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
