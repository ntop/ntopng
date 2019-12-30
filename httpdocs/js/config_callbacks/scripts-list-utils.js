
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
        language: {
           paginate: {
              previous: '&lt;',
              next: '&gt;'
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

                    $('#scripts-config').on('click', `input[name='${row.key}-check']`, function(e) {

                       const $this = $(this);
                       const value = $this.val();
                       const hooks = row.all_hooks;
                       const data = {};

                       hooks.forEach(d => {
                          data[d] = {
                             enabled: (value == "true")
                          }
                       })

                       $.post(`${http_prefix}/lua/edit_user_script_config.lua`, {
                          script_subdir: script_subdir,
                          script_key: row.key,
                          csrf: csrf_toggle_buttons,
                          JSON: JSON.stringify(data),
                          confset_id: confset_id
                       })
                       .done((d, status, xhr) => {
                          location.reload();
                       })
                       .fail(({status, statusText}) => {
                          check_status_code(status, statusText, null);
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
                       <button ${row.input_handler == undefined ? "disabled" : ""}
                          data-toggle="modal"
                          title='Edit Script'
                          data-target="#modal-script"
                          class="btn btn-square btn-sm btn-primary">

                          <i class='fas fa-edit'></i>

                       </button>
                       <a
                          href='${data.edit_url}'
                          title='View Source Script'
                          class='btn btn-square btn-sm btn-secondary'>
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

          const build_gui = (gui, hooks) => {

           const build_input_box = ({ input_builder, field_max, field_min, fields_unit, field_operator }) => {

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
                 const $error_label = $template.find(`.invalid-feedback`);

                 const operator = $template.find("select").val();
                 const threshold = $template.find("input").val();

                 // hide before errors
                 $error_label.hide();

                 // if operator is empty then alert the user
                 if (enabled && (operator == "" || operator == undefined || operator == null)) {

                    $error_label.text("Please select an operator!").show();
                    error = true;
                    return;
                 }

                 // if the value is empty then alert the user (only for checked granularities)
                 if (enabled && (threshold == null || threshold == undefined || threshold == "")) {
                    $error_label.text("Please fill the input box!").show();
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
                 // if the operation was successfull then reload the page
                 location.reload();
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

        // count scripts
        const $disabled_button = $(`#disabled-scripts`);
        const $all_button = $("#all-scripts");
        const $enabled_button = $(`#enabled-scripts`);

        let enabled_count = 0;
        let disabled_count = 0;

        $script_table.data().each(d => {

           if (d.is_enabled) {
              enabled_count++;
              return;
           }

           disabled_count++;
        });

        $all_button.html(`${i18n.all} (${enabled_count + disabled_count})`)
        $enabled_button.html(`${i18n.enabled} (${enabled_count})`);
        $disabled_button.html(`${i18n.disabled} (${disabled_count})`);
     }

  });