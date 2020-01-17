/**
  *  This function return true if the status code is different from 200
  */
 const check_status_code = (status_code, status_text, $error_label) => {

   const is_different = status_code != 200;

   if (is_different && $error_label != null) {
      $error_label.text(`${i18n.request_failed_message}: ${status_code} - ${status_text}`).fadeIn();
   }
   else if (is_different && $error_label == null) {
      alert(`${i18n.request_failed_message}: ${status_code} - ${status_text}`);
   }

   return is_different;
}

/**
 * This function select the correct tab for script filtering 
 */
const select_script_filter = (enabled_count) => {

   // get hash from url
   let hash = window.location.hash;

   if (hash == undefined || hash == null || hash == "") {
      // if no tab is active, show the "enabled" tab if there are any enabled
      // scripts, otherwise show the "all-scripts" tab
      hash = enabled_count ? '#enabled' : '#all-scripts';
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
}

// Templates and template builder

const generate_checkbox_enabled = (id, enabled, callback) => {

   const $checkbox_enabled = $(`
      <input 
         id='${id}'
         name='enabled' 
         type="checkbox" 
         ${enabled ? "checked" : ""} />
   `);

   // bind check event on checkboxes
   $checkbox_enabled.change(callback);

   return $checkbox_enabled;
}

const generate_input_box = (input_settings, has_container, change_callback) => {
   
   const $input_box = $(`
      <input 
         ${input_settings.enabled ? '' : 'readonly'}
         min='${input_settings.min}' max='${input_settings.max}'
         type='number'
         value='${input_settings.current_value}'
         name='${input_settings.name}'
         class='form-control' />
   `);

   if (has_container) {
      
      const $input_container = $(`<div class='form-row'></div>`);
      return $input_container.append($(`<div class='col-2'></div>`).append($input_box));
   }

   return $input_box;
}

const generate_radio_buttons = (name, enabled, settings, has_container, change_callback) => {

   const $radio_buttons = $(`
      <div class="btn-group float-right btn-group-toggle" data-toggle="buttons">
         <label class="btn btn-secondary ${enabled ? '' : 'disabled'}">
            <input ${enabled ? '' : 'disabled'} value="${settings[0].value}" type="radio" name="${name}"> ${settings[0].label}
         </label>
         <label class="btn btn-secondary ${enabled ? '' : 'disabled'}">
            <input ${enabled ? '' : 'disabled'} value="${settings[0].value}" type="radio" name="${name}"> ${settings[1].label}
         </label>
         <label class="btn btn-secondary ${enabled ? '' : 'disabled'}">
            <input ${enabled ? '' : 'disabled'} value="${settings[0].value}" type="radio" name="${name}"> ${settings[2].label}
         </label>
      </div>
   `);

   if (has_container) {

      const $radio_container = $(`<div class='col-10'></div>`);
      return $radio_container.append($radio_buttons);
   }

   return $radio_buttons;

}

const apply_edits_script = (template_data, script_subdir, script_key) => {

   const $apply_btn = $('#btn-apply');
   const $error_label = $("#apply-error");

   // remove dirty class from form
   $('#edit-form').removeClass('dirty')
   $apply_btn.attr('disabled', '');

   $.post(`${http_prefix}/lua/edit_user_script_config.lua`, {
      script_subdir: script_subdir,
      script_key: script_key,
      csrf: csrf_edit_config,
      JSON: JSON.stringify(template_data),
      confset_id: confset_id
   })
   .done((d, status, xhr) => {

         if (check_status_code(xhr.status, xhr.statusText, $error_label)) return;

         if (!d.success) {

            $error_label.text(d.error).show();
            // update token
            csrf_edit_config = d.csrf;
            // re enable button
            $apply_btn.removeAttr('disabled');
         }

         // if the operation was successfull then reload the page
         if (d.success) location.reload();
      })
   .fail(({ status, statusText }) => {

      check_status_code(status, statusText, $error_label);

      if (status == 200) {
         $error_label.text(`${i18n.expired_csrf}`).show();
      }

      $apply_btn.removeAttr('disabled');
   });
}

const reset_script_defaults = (script_key, script_subdir, callback_reset) => {

   const $error_label = $('#apply-error');

   $.get(`${http_prefix}/lua/get_user_script_config.lua`, {
      script_subdir: script_subdir,
      script_key: script_key
   })
   .done((reset_data, status, xhr) => {

      // if there is an error about the http request
      if (check_status_code(xhr.status, xhr.statusText, $error_label)) return;

      // call callback function to reset fields
      callback_reset(reset_data);

      // add dirty class to form
      $('#edit-form').addClass('dirty');
   })
   .fail(({ status, statusText }) => {

      check_status_code(status, statusText, $error_label);
      // hide modal if there is error
      $("#modal-script").modal("toggle");
   })
}

const ThresholdCross = (gui, hooks, script_subdir, script_key) => {

   const $table_editor = $("#script-config-editor");

   const render_template = () => {

      const { field_operator, fields_unit, field_min, field_max } = gui;
      const operators = ['gt', 'lt'];

      // save input fields
      const $input_fields = {};

      // iterate over keys to create each hooks
      for (const key in hooks) {

         if (key == undefined) continue;

         // get hook
         const hook = hooks[key];

         // enable readonly in inputboxes and selects if enabled field is false
         const $select = $(`
               <select 
                  name='${key}-select'
                  ${hook.enabled ? '' : 'disabled'} 
                  class='btn btn-outline-secondary'></select>
            `);

         // select the right operator
         if (hook.script_conf.operator != undefined) {
            $select.val(hook.script_conf.operator)
         }

         operators.forEach((op) => {
            /* If a field_operator is set, only show that operator */
            if ((!field_operator) || (field_operator == op)) {
               $select.append($(`<option value="${op}">&${op}</option>`))
            }
         });

         const $field = $(`<div class='input-group template w-75'></div>`);
         $field.append(`<div class='input-group-prepend'></div>`).html($select);
         $field.append(`<input 
                           type='number'
                           class='form-control'
                           name='${key}-input'
                           ${hook.enabled ? '' : 'readonly'}
                           value='${hook.script_conf.threshold == undefined ? '' : hook.script_conf.threshold}'
                           min='${field_min == undefined ? '' : field_min}' 
                           max='${field_max == undefined ? '' : field_max}'>`);
         $field.append(`<span class='mt-auto mb-auto ml-2 mr-2'>${fields_unit ? fields_unit : ""}</span>`);
         $field.append(`<div class='invalid-feedback'></div>`);

         const $input_container = $(`<tr id='${key}'></tr>`);
         const $checkbox = $(`<input name="${key}-check" type="checkbox" ${hook.enabled ? "checked" : ""} >`);

         // bind check event on checkboxes
         $checkbox.change(function (e) {

            const checked = $(this).prop('checked');

            // if the checked option is false the disable the elements
            if (!checked) {
               $field.find(`input[type='number']`).attr("readonly", "");
               $select.attr("disabled", "");
               return;
            }

            $field.find(`input[type='number']`).removeAttr("readonly");
            $select.removeAttr("disabled");
         });

         // append label and checkbox inside the row
         $input_container.append(
            $(`<td class='text-center'></td>`).append($checkbox),
            $(`<td>${hook.label}</td>`),
            $(`<td></td>`).append($field)
         );

         // save input field
         $input_fields[key] = $input_container;

      }

      // clean script editor table from previous state
      $table_editor.empty();

      // append each hooks to the table
      $table_editor.append(`<tr><th class='text-center'>Enabled</th></tr>`)
      
      if ("min" in $input_fields) {
         $table_editor.append($input_fields['min']);
      }
      if ("5mins" in $input_fields) {
         $table_editor.append($input_fields['5mins']);
      }
      if ("hour" in $input_fields) {
         $table_editor.append($input_fields['hour']);
      }
      if ("day" in $input_fields) {
         $table_editor.append($input_fields['day']);
      }


   };

   const apply_event = (event) => {

      // prepare request to save config
      const data = {};
      // variable for checking errors
      let error = false;

      // iterate over granularities
      $table_editor.find("tr[id]").each(function (index) {

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

      // check if there are any errors on input values
      if (error) return;

      apply_edits_script(data, script_subdir, script_key);
   };

   const reset_event = (event) => {

      reset_script_defaults(script_key, script_subdir, (data) => {

         const { hooks } = data;

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
      });

   }

   return {
      apply_click_event: apply_event,
      reset_click_event:reset_event,
      render: render_template,
   }
}

const ItemsList = (gui, hooks, script_subdir, script_key) => {

   const $table_editor = $("#script-config-editor");

   const render_template = () => {

      const $component_container = $(`<tr></tr>`);
      const callback_checkbox = function(e) {

         const checked = $(this).prop('checked');

         // if the checked option is false the disable the elements
         if (!checked) {
            $text_area.find(`#itemslist-textarea`).attr("readonly", "");
            return;
         }

         $text_area.find(`#itemslist-textarea`).removeAttr("readonly", "");
      };

      const $checkbox_enabled = generate_checkbox_enabled(
         'itemslist-checkbox', hooks.all.enabled, callback_checkbox
      );

      const items_list = hooks.all.script_conf.items;
      const $text_area = $(`
         <td>
            <div class='form-group template w-100'>
               <textarea 
                  ${!hooks.all.enabled ? "readonly" : ""} 
                  name='items-list' 
                  id='itemslist-textarea' 
                  class="w-100 form-control" 
                  style="height: 5rem;">${items_list.length > 0 ? items_list.join(',') : ''}</textarea>
                  <small>${i18n.blacklisted_country}</small>
               <div class="invalid-feedback"></div>
            </div>
         </td>
      `);

      $component_container.append($(`<td class='text-center'></td>`).append($checkbox_enabled), $text_area);

      $table_editor.empty();

      $table_editor.append(`<tr><th class='text-center w-25'>Enabled</th><th>Blacklisted Countries list:</th></tr>`)
      $table_editor.append($component_container);
   }

   const apply_event = (event) => {

      const special_char_regexp = /[\@\#\<\>\\\/\?\'\"\`\~\|\.\:\;\!\&\*\(\)\{\}\[\]\_\-\+\=\%\$\^]/g;
      const hook_enabled = $('#itemslist-checkbox').prop('checked');

      let $error_label = $('#itemslist-textarea').parent().find('.invalid-feedback');
      $error_label.fadeOut();

      const textarea_value = $('#itemslist-textarea').val().trim();

      // if the textarea value contains special characters such as #, @, ... then alert the user
      if (special_char_regexp.test(textarea_value)) {
         $error_label.fadeIn().text(`${i18n.items_list_comma}`);
         return;
      }

      // hide label
      $error_label.hide();

      const items_list = textarea_value ? textarea_value.split(',').map(x => x.trim().toUpperCase()) : [];

      const template_data = {
         all: {
            enabled: hook_enabled,
            script_conf: {
               items: items_list
            } 
         } 
      };

      // make post request to save edits
      apply_edits_script(template_data, script_subdir, script_key);

   }

   const reset_event = (event) => {

      reset_script_defaults(script_key, script_subdir, (reset_data) => {

         const items_list = reset_data.hooks.all.script_conf.items;
         const enabled = reset_data.hooks.all.enabled;

         // set textarea value with default's one
         $('#itemslist-textarea').val(items_list.join(','));
         $('#itemslist-checkbox').prop('checked', enabled);

         // turn on readonly to textarea if enabled is false
         if (!enabled) {
            $('#itemslist-textarea').attr('readonly', '');
         }

      });

   }

   return {
      apply_click_event: apply_event,
      reset_click_event: reset_event,
      render: render_template,
   }
}

const LongLived = (gui, hooks, script_subdir, script_key) => {

   const $table_editor = $("#script-config-editor");
   $("#script-config-editor").empty();
   
   const render_template = () => {

      const enabled = hooks.all.enabled;
      const granularity = hooks.all.script_conf.granularity;
      const items_list = hooks.all.script_conf.items;

      const current_value = hooks.all.current_value;

      const input_settings = {
         name: 'script_value',
         min: 0,
         max: 0,
         enabled: enabled,
      };
      const $time_input_box = generate_input_box(input_settings, true, null);

      const $textarea_ds = $(`
         <div class='form-group mt-3'>
            <label>Excluded applications and categories:</label>
            <textarea ${enabled ? '' : 'readonly'} name='items_list' class='form-control'>${items_list.join(',')}</textarea>
            <small>Examples...</small>
         </div>
      `);

      // time-ds stands for: time duration selection
      const $time_radio_buttons = generate_radio_buttons(
         'granularities', enabled, 
         [
            {label: 'Mins', value: 60}, {label: 'Hours', value: 3600}, {label: 'Days', value: 860400}
         ], 
         true, null
      );

      // clamp values on radio change
      $time_radio_buttons.find(`input[type='radio']`).on('change', function() {

         const time_selected = $(this).val();
     
         // set min/max bounds to input box
         if (time_selected == 60) {
            $time_input_box.find('input').attr("max", 60);
         }
         else if (time_selected == 3600) {
            $time_input_box.find('input').attr("max", 24);
         }
         else {
            $time_input_box.find('input').attr("max", 365);
         }

      });

      const callback_checkbox = function (e) {

         const checked = $(this).prop('checked');

         // if the checked option is false the disable the elements
         if (!checked) {
            $time_input_box.find(`input[name='script_value']`).attr("readonly", "").val('');
            $time_radio_buttons.find(`input[type='radio']`).attr("disabled", "").parent().addClass('disabled');
            $textarea_ds.find('textarea').attr("readonly", "");
            return;
         }

         $time_input_box.find(`input[name='script_value']`).removeAttr("readonly");
         $time_radio_buttons.find(`input[type='radio']`).removeAttr("disabled").parent().removeClass('disabled');
         $textarea_ds.find('textarea').removeAttr("readonly");

      };

      const $checkbox_enabled = generate_checkbox_enabled(
         'ds-checkbox', hooks.all.enabled, callback_checkbox
      );

      // append elements on table
      const $input_container = $(`<td></td>`);
      $input_container.append($time_input_box.prepend($time_radio_buttons), $textarea_ds);

      const $container = $(`<tr></tr>`).append(
         $(`<td class='text-center'></td>`).append($checkbox_enabled),
         $input_container
      );

      $table_editor.append(`<tr class='text-center'><th>Enabled</th></tr>`)
      $table_editor.append($container);
   }

   const apply_event = (event) => {

      const special_char_regexp = /[\@\#\<\>\\\/\?\'\"\`\~\|\.\:\;\!\&\*\(\)\{\}\[\]\_\-\+\=\%\$\^]/g;
      const textarea_value = $(`textarea[name='items_list']`).val();
      
      let $error_label = null;

      // TODO: data logic
      const template_data = {
         all: {
            enabled: $(`#ds-checkbox`).prop('checked'),
            script_conf: {
               
            }
         }
      }

      // make post request to save data
      apply_edits_script(template_data, script_subdir, script_key);

   }

   const reset_event = (event) => {

      reset_script_defaults(script_key, script_subdir, (data_reset) => {
         // TODO: reset button logic

      });
   }

   return {
      apply_click_event: apply_event,
      reset_click_event: reset_event,
      render: render_template,
   }
}

const ElephantFlows = (gui, hooks, script_subdir, script_key) => {

   const $table_editor = $("#script-config-editor");
   $("#script-config-editor").empty();

   const render_template = () => {

      const enabled = hooks.all.enabled;
      const granularity = hooks.all.script_conf.granularity;
      const items_list = hooks.all.script_conf.items;

      const current_value = hooks.all.current_value;

      const input_settings = {
         max: 0,
         min: 0,
         name: 'script_value',
         enabled: enabled
      };
      const $bytes_input_box = generate_input_box(input_settings, true, null);

      const $textarea_bytes = $(`
         <div class='form-group mt-3'>
            <label>Excluded applications and categories:</label>
            <textarea ${enabled ? '' : 'readonly'} name='items_list' class='form-control'>${(items_list || []).join(',')}</textarea>
            <small>Examples...</small>
         </div>
      `);

      const $bytes_radio_buttons = generate_radio_buttons(
         'bytes', enabled, 
         [
            {label: 'KB', value: 60}, {label: 'MB', value: 3600}, {label: 'GB', value: 860400}
         ], 
         true, null
      );

      // clamp values on radio change
      $bytes_radio_buttons.find(`input[type='radio']`).on('change', function() {

         const bytes_selected = $(this).val();
     
         // set min/max bounds to input box
         if (bytes_selected == 60) {
            $time_input_box.find('input').attr("max", 60);
         }
         else if (bytes_selected == 3600) {
            $bytes_selected.find('input').attr("max", 24);
         }
         else {
            $time_input_box.find('input').attr("max", 365);
         }

      });

      const callback_checkbox = function (e) {

         const checked = $(this).prop('checked');

         // if the checked option is false the disable the elements
         if (!checked) {
            $bytes_input_box.find(`input[name='script_value']`).attr("readonly", "").val('');
            $bytes_radio_buttons.find(`input[type='radio']`).attr("disabled", "").parent().addClass('disabled');
            $textarea_bytes.find('textarea').attr("readonly", "");
            return;
         }

         $bytes_input_box.find(`input[name='script_value']`).removeAttr("readonly");
         $bytes_radio_buttons.find(`input[type='radio']`).removeAttr("disabled").parent().removeClass('disabled');
         $textarea_bytes.find('textarea').removeAttr("readonly");
      };

      const $checkbox_enabled = generate_checkbox_enabled(
         'elephant-flows-checkbox', enabled, callback_checkbox
      );

      // append elements on table
      const $input_container = $(`<td></td>`);
      $input_container.append($bytes_input_box.prepend($bytes_radio_buttons), $textarea_bytes);

      const $container = $(`<tr></tr>`).append(
         $(`<td class='text-center'></td>`).append($checkbox_enabled),
         $input_container
      );

      $table_editor.append(`<tr class='text-center'><th>Enabled</th></tr>`)
      $table_editor.append($container);

   }

   const apply_event = (event) => {

      const special_char_regexp = /[\@\#\<\>\\\/\?\'\"\`\~\|\.\:\;\!\&\*\(\)\{\}\[\]\_\-\+\=\%\$\^]/g;
      const textarea_value = $(`textarea[name='items_list']`).val();
      
      let $error_label = null;

      // TODO: data logic

      const template_data = {
         all: {
            enabled: $(`#elephant-flows-checkbox`).prop('checked'),
            script_conf: {
               
            }
         }
      }

      return;

      apply_edits_script(template_data, script_subdir, script_key);

   }

   const reset_event = (event) => {

      reset_script_defaults(script_key, script_subdir, (reset_data) => {

         // TODO: reset button logic

      });

   }

   return {
      apply_click_event: apply_event,
      reset_click_event: reset_event,
      render: render_template,
   }
}

const EmptyTemplate = (gui = null, hooks = null, script_subdir = null, script_key = null) => {
   return {
      apply_click_event: function() {},
      reset_click_event: function() {},
      render: function() {},
   }
}

const TemplateBuilder = ({gui, hooks}, script_subdir, script_key) => {

   // get template name
   const template_name = gui.input_builder;

   const templates = {
      threshold_cross: ThresholdCross(gui, hooks, script_subdir, script_key),
      items_list: ItemsList(gui, hooks, script_subdir, script_key),
      long_lived: LongLived(gui, hooks, script_subdir, script_key),
      elephant_flows: ElephantFlows(gui, hooks, script_subdir, script_key)
   }

   const template_chosen = templates[template_name];

   if (template_chosen == null || template_chosen == undefined) {
      template_chosen = EmptyTemplate();
      throw(`the template ${template_name} was not implemented yet!`);
   }

   return template_chosen;
}

// End templates and template builder

$(document).ready(function() {

   // initialize script table 
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
      initComplete: function (settings, json) {

         const [enabled_count, disabled_count] = count_scripts();

         // select the correct tab
         select_script_filter(enabled_count);

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
      order: [[0, "asc"]],
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

               if (type == 'display') return `<b>${data}</b>`
               return data;
            },
            width: '15%'
         },
         {
            data: 'description',
            render: function (data, type, row) {

               if (type == "display") {
                  return `<span 
                           ${data.length >= 64 ? `data-toggle='popover'  data-placement='top' data-html='true'` : ``}
                           title="${row.title}"
                           data-content="${data}" >
                              ${data.substr(0, 64)}${data.length >= 64 ? '...' : ''}
                           </span>`;
               }

               return data;

            },
            width: '35%'
         },
         {
            data: 'enabled_hooks',
            sortable: false,
            className: 'text-center',
            render: function (data, type, row) {

               // if the type is flter return true if the data length is greather or equal
               // than 0 so the script table can detect if a plugin is enabled
               if (data.length <= 0 && type == "filter") {
                  return false;
               }
               if (data.length > 0 && type == "filter") {
                  return true;
               }

               // it means there is only all
               if (data.length == 1) {
                  return data[0];
               }

               return data.map(enabled_hook => {
                  return row.all_hooks.find((current) => current.key === enabled_hook).label
               }).join(', ');
            },
            createdCell: function (td, cellData, row, rowIndex, col) {

               if (row.all_hooks.length > 0 && row.input_handler == undefined) {

                  const $toggle_buttons = $(`
                     <div class="btn-group btn-group-toggle" data-toggle="buttons">
                        <label class="btn btn-sm btn-secondary ${row.is_enabled ? "active btn-success" : ""}">
                           <input value='true' type="radio" name="${row.key}-check" ${row.is_enabled ? "checked" : ""}> On
                        </label>
                        <label class="btn btn-sm btn-secondary ${!row.is_enabled ? "active btn-danger" : ""}">
                           <input value='false' type="radio" name="${row.key}-check" ${row.is_enabled ? "checked" : ""}> Off
                        </label>
                     </div>
                 `);

                  // remove text inside cell
                  $(td).text('');

                  $toggle_buttons.find(`input[name='${row.key}-check']`).on('click', function (e) {

                     const $this = $(this); const value = $this.val();
                     const hooks = row.all_hooks;

                     const data = {
                        all: {
                           script_conf: {
                           },
                           enabled: (value == "true")
                        }
                     };

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
                              $("#alert-row-buttons").text(d.error).removeClass('d-none').show();
                              // update csrf
                              csrf_toggle_buttons = d.csrf;
                           }

                           if (d.success) location.reload();

                     })
                     .fail(({ status, statusText }) => {

                           check_status_code(status, statusText, $("#alert-row-buttons"));

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

            },
            width: '25%'
         },
         {
            targets: -1,
            data: null,
            className: 'text-center',
            render: function (data, type, row) {

               const edit_script_btn = `
                      <a href='#'
                         title='${i18n.edit_script}'
                         class='badge badge-info'
                         data-toggle="modal"
                         data-target="#modal-script">
                           ${i18n.edit}
                     </a>
               `;
               const edit_url_btn = `
                      <a href='${data.edit_url}'
                        class='badge badge-secondary'
                        title='${i18n.view_src_script}'>
                           ${i18n.view}
                      </a>
               `;

               return `
                      ${row.input_handler == undefined ? '' : edit_script_btn}
                      ${!data.edit_url ? '' : edit_url_btn}
                `;
            },
            sortable: false,
            width: '10%'
         }
      ]
   });

   // initialize are you sure
   $("#edit-form").areYouSure({ message: i18n.are_you_sure });

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
   })
   .on("shown.bs.modal", function(e) {
      // add focus to btn apply to enable focusing on the modal hence user can press escape button to
      // close the modal
      $("#btn-apply").trigger('focus');
   });

   // load templates for the script
   $('#scripts-config').on('click', 'a[data-target="#modal-script"]', function(e) {

      // get script key and script name
      const row_data = $script_table.row($(this).parent()).data();
      const script_key = row_data.key;
      const script_title = row_data.title;

      // change title to modal
      $("#script-name").html(`<b>${script_title}</b>`);

      $("#modal-script form").off('submit');
      $("#modal-script").on("submit", "form", function (e) {
          e.preventDefault();

          $('#edit-form').trigger('reinitialize.areYouSure').removeClass('dirty');
          $("#btn-apply").trigger("click");
      });

      $.get(`${http_prefix}/lua/get_user_script_config.lua`, 
         {
            script_subdir: script_subdir,
            confset_id: confset_id,
            script_key: script_key
         }
      )
      .then((data, status, xhr) => {

         // check status code
         if (check_status_code(xhr.status, xhr.statusText, null)) return;

         // hide previous error
         $("#apply-error").hide();

         // data.gui.input_builder = 'elephant_flows';
         // data.hooks.all.script_conf.enabled = true;
         // data.hooks.all.script_conf.granularity = "gb";
         // data.hooks.all.current_value = 5;

         const template = TemplateBuilder(data, script_subdir, script_key);
         
         // render template
         template.render();

         // bind on_apply event on apply button
         $("#btn-apply").off("click").click(template.apply_click_event);
         $("#btn-reset").off("click").click(template.reset_click_event);

         // bind are you sure to form
         $('#edit-form').trigger('rescan.areYouSure').trigger('reinitialize.areYouSure');


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
