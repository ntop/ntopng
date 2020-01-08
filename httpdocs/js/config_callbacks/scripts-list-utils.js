
  /**
  *  This function true if the status code is different from 200
  */
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

$(document).ready(function() {

    const $script_table = $("#scripts-config").DataTable({
       dom: "Bfrtip",
       pagingType: 'full_numbers',
       language: {
          paginate: {
             previous: '&lt;',
             next: '&gt;',
             first: '«',
             last: '»'
          }
       },
       lengthChange: false,
       ajax: {
          'url': `${http_prefix}/lua/get_user_scripts.lua?confset_id=${confset_id}&script_subdir=${script_subdir}`,
          'type': 'GET',
          dataSrc: ''
       },
       stateSave: true,
       initComplete: function(settings, json) {

          const [enabled_count, disabled_count] = count_scripts();

          // select the correct tab
          (() => {

             // get hash from url
             var hash = window.location.hash;

             if(hash == undefined || hash == null || hash == "") {
               // if no tab is active, show the "enabled" tab if there are any enabled
               // scripts, otherwise show the "all-scripts" tab
               if(enabled_count)
                 hash = "#enabled";
               else
                 hash = "#all-scripts";
             }

             // redirect to correct tab
             if (hash == "#enabled") {
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

          // update the tabs counters
          const $disabled_button = $(`#disabled-scripts`);
          const $all_button = $("#all-scripts");
          const $enabled_button = $(`#enabled-scripts`);

          $all_button.html(`${i18n.all} (${enabled_count + disabled_count})`)
          $enabled_button.html(`${i18n.enabled} (${enabled_count})`);
          $disabled_button.html(`${i18n.disabled} (${disabled_count})`);
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
             },
             className: 'w-25',
          },
          { 
             data: 'description',
             render: function (data, type, row) {
               
               if (type == "display") {
                  return `<abbr title='${data}'>${data.substr(0, 64)}...</abbr>`
               }

               return data;

             },
          },
          {
             data: 'enabled_hooks',
             sortable: false,
             className: 'text-center',
             render: function (data, type, row) {

              if (data.length <= 0 && type == "filter") {
                 return false;
              }
              if (data.length > 0 && type == "filter") {
                 return true;
              }

              return data.join(', ');
             },
             createdCell: function(td, cellData, row, rowIndex, col) {
                
              if (row.all_hooks.length > 0 && row.input_handler == undefined) {        

                 const $toggle_buttons = $(`<div class="btn-group btn-group-toggle" data-toggle="buttons">
                 <label class="btn btn-sm btn-secondary ${row.is_enabled ? "active btn-success" : ""}">
                    <input value='true' type="radio" name="${row.key}-check" ${row.is_enabled ? "checked" : ""}> On
                 </label>
                 <label class="btn btn-sm btn-secondary ${!row.is_enabled ? "active btn-danger" : ""}">
                    <input value='false' type="radio" name="${row.key}-check" ${row.is_enabled ? "checked" : ""}> Off
                 </label>
                 </div>`);

                 // remove text inside cell
                 $(td).text('');
                 
                 $toggle_buttons.find(`input[name='${row.key}-check']`).on('click', function(e) {

                    const $this = $(this); const value = $this.val();
                    const hooks = row.all_hooks; const data = {};

                    hooks.forEach(d => data[d] = { enabled: (value == "true")})

                    // hide alert
                    $("#alert-row-buttons").hide();

                    // disable all buttons to prevent more requests
                    $("#scripts-config input[name$='-check']").attr("disabled", "").parent().addClass("disabled");

                    $.post(`${http_prefix}/lua/edit_user_script_config.lua`, {
                       script_subdir: script_subdir,
                       script_key: row.key,
                       csrf: csrf_toggle_buttons,
                       JSON: JSON.stringify(data),
                       confset_id: confset_id
                    })
                    .done((d, status, xhr) => {

                       if (!d.success) {
                           $("#alert-row-buttons").text(data.error).removeClass('d-none').show();
                           // update csrf
                           csrf_toggle_buttons = d.csrf;
                       }
                       
                       if (d.success) location.reload();

                    })
                    .fail(({status, statusText}) => {
                      
                       check_status_code(status, statusText, null);

                       // if the csrf has expired 
                       if (status == 200) {
                           $("#alert-row-buttons").text(`${i18n.expired_csrf}`).removeClass('d-none').show();
                       }

                       // re eanble buttons
                       $("#scripts-config input[name$='-check']").removeAttr("disabled").parent().removeClass("disabled");
                    })

                 });

                 $(td).append($toggle_buttons);

              }

             }
          },
          {
             targets: -1,
             data: null,
             className: 'text-center',
             render: function (data, type, row) {

               const edit_script_btn = `
                  <button ${row.input_handler == undefined ? "disabled" : ""}
                     data-toggle="modal"
                     title='${i18n.edit_script}'
                     data-target="#modal-script"
                     class="btn btn-square btn-sm btn-primary">
                        <i class='fas fa-edit'></i>
                  </button>
               `;

                return `
                   <div class='btn-group'>
                      ${row.all_hooks.length > 0 && row.input_handler == undefined ? '' : edit_script_btn}
                      <a
                         href='${data.edit_url}'
                         title='${i18n.view_src_script}'
                         class='btn btn-square btn-sm btn-secondary ${!data.edit_url ? "disabled" : ""}'>
                             <i class='fas fa-scroll'></i>
                      </a>
                   </div>
                `;
             },
             sortable: false
          }
       ]
    });

    // initialize are you sure
    $("#edit-form").areYouSure({
       'message': i18n.are_you_sure
    });

    // handle modal-script close event
    $("#modal-script").on("hide.bs.modal", function(e) {

       // if the forms is dirty then ask to the user
       // if he wants save edits
       if ($('#edit-form').hasClass('dirty')) {

          // ask to user if he REALLY wants close modal
          const result = confirm(`${i18n.are_you_sure}`);
          if (!result) e.preventDefault();

          // remove dirty class from form
          $('#edit-form').removeClass('dirty');
       }
    });

    // load templates for the script
    $('#scripts-config').on('click', 'button[data-target="#modal-script"]', function(e) {

       // get script key and script name
       const row_data = $script_table.row($(this).parent().parent()).data();
       const script_key = row_data.key;
       const script_title = row_data.title;

       // change title to modal
       $("#script-name").html(`<b>${script_title}</b>`);

       $("#modal-script form").off('submit');

       $("#modal-script").on("submit", "form", function (e) {

          e.preventDefault();
          $('#edit-form')
             .trigger('reinitialize.areYouSure')
             .removeClass('dirty');

          $("#btn-apply").trigger("click");
       });

       $.get(`${http_prefix}/lua/get_user_script_config.lua`, {
             script_subdir: script_subdir,
             confset_id: confset_id,
             script_key: script_key
          }
       )
       .then((data, status, xhr) => {

         // check status code
         if (check_status_code(xhr.status, xhr.statusText, null)) return;

         // clean table editor
         const $table_editor = $("#script-config-editor > tbody");
         $table_editor.empty();

         // destructure gui and hooks from data
         const {gui, hooks} = data;

         // hide previous error
         $("#apply-error").hide();

         const build_gui = (gui, hooks) => {

          const build_input_box = ({ input_builder, field_max, field_min, fields_unit, field_operator }) => {

             if (input_builder == '' || input_builder == undefined || input_builder == null) {
                return $(`<p>${i18n.template_not_found}</p>`)
             }
             else if (input_builder == 'threshold_cross') {
                var operators = ["gt", "lt"];
                var select = $(`<select class='btn btn-outline-secondary'></select>`);

                operators.forEach((op) => {
                  /* If a field_operator is set, only show that operator */
                  if((!field_operator) || (field_operator == op))
                    select.append($(`<option value="${op}">&${op}</option>`))
                });

                return $(`<div class='input-group template w-75'></div>`)
                   .append(`<div class='input-group-prepend'></div>`).html(select)
                   .append(`<input type='number' 
                                  class='form-control'
                                  min='${field_min == undefined ? '' : field_min}'
                                  max='${field_max == undefined ? '' : field_max}'>`)
                   .append(`<span class='mt-auto mb-auto ml-2 mr-2'>${fields_unit}</span>`)
                   .append(`<div class="invalid-feedback"></div>`)
             }

          }

          const build_hook = ({ label, enabled, script_conf }, granularity) => {

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
             $element.on('change', "input[type='checkbox']", function (e) {

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
             if ("min" in hooks) {
               $table_editor.append(build_hook(hooks["min"], "min"));
             }
             if ("5mins" in hooks) {
                $table_editor.append(build_hook(hooks["5mins"], "5mins"));
             }
             if ("hour" in hooks) {
                $table_editor.append(build_hook(hooks["hour"], "hour"));
             }
             if ("day" in hooks) {
                $table_editor.append(build_hook(hooks["day"], "day"));
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
                const $error_label = $template.find(`.invalid-feedback`);

                const operator = $template.find("select").val();
                const threshold = $template.find("input").val();

                // hide before errors
                $error_label.hide();

                // if operator is empty then alert the user
                if (enabled && (operator == "" || operator == undefined || operator == null)) {

                   $error_label.text(i18n.select_operator).show();
                   error = true;
                   return;
                }

                // if the value is empty then alert the user (only for checked granularities)
                if (enabled && (threshold == null || threshold == undefined || threshold == "")) {
                   $error_label.text(i18n.empty_input_box).show();
                   error = true;
                   return;
                }

                // save data into dictonary
                data[id] = {
                   'enabled': enabled,
                   'script_conf': {
                      'operator': operator,
                      'threshold': parseInt(threshold)
                   }
                }
             });

             const $error_label = $("#apply-error");
             
             // check if there are any errors on input values
             if (error) return;
             // remove dirty class from form
             $('#edit-form').removeClass('dirty')
             // disable button
             $button.attr("disabled", "");

             $.post(`${http_prefix}/lua/edit_user_script_config.lua`, {
                script_subdir: script_subdir,
                script_key: script_key,
                csrf: csrf_edit_config,
                JSON: JSON.stringify(data),
                confset_id: confset_id
             })
             .done((d, status, xhr) => {

                if (check_status_code(xhr.status, xhr.statusText, $error_label)) return;

                if (!d.success) {

                    $error_label.text(d.error).show();
                    // update token
                    csrf_edit_config = d.csrf;
                }

                // if the operation was successfull then reload the page
                if (d.success) location.reload();
             })
             .fail(({status, statusText}) => {

                check_status_code(status, statusText, $error_label);
                // hide modal if there is error
                $("#modal-script").modal("toggle");
             })

          };

         // bind event on reset defaults button
         const on_reset = (e) => {

             // get default values for config
             $.get(`${http_prefix}/lua/get_user_script_config.lua`, {
                script_subdir: script_subdir,
                script_key: script_key
             })
             .done((data, status, xhr) => {

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
             })
             .fail(({status, statusText}) => {

                check_status_code(status, statusText, null);
                // hide modal if there is error
                $("#modal-script").modal("toggle");
             })
          }

         // bind click event to btn-apply
         $("#btn-apply").off("click").click(on_apply);

         // bind reset default click event
         $("#btn-reset").off("click").click(on_reset);

         // bind are you sure to form
         $('#edit-form')
            .trigger('rescan.areYouSure')
            .trigger('reinitialize.areYouSure');

       })
       .fail(({status, statusText}) => {

          check_status_code(status, statusText, null);
          // hide modal if there is error
          $("#modal-script").modal("toggle");
       })

    });

    /**
     * Count the scripts that are enabled, disabled inside the script table
     */
    const count_scripts = () => {
       let enabled_count = 0;
       let disabled_count = 0;

       $script_table.data().each(d => {

          if (d.is_enabled) {
             enabled_count++;
             return;
          }

          disabled_count++;
       });

       return [enabled_count, disabled_count];
    }

 });
