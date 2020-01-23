// 2020 - ntop.org

String.prototype.titleCase = function () {

   return this.toLowerCase().split(' ').map(function(word) {

     return word.replace(word[0], word[0].toUpperCase());
   }).join(' ');

 }

/* ******************************************************* */

const reloadPageAfterPOST = () => {
   if(location.href.indexOf("user_script=") > 0) {
      /* Remove the "user_script" _GET parameter */
      location.href = page_url + location.hash;
   } else {
      /* The URL is still the same as before, need to force a reload */
      location.reload();
   }
}

/* ******************************************************* */

const hasConfigDialog = (item) => {
   return !(item.all_hooks.length > 0 && item.input_handler == undefined);
}

/* ******************************************************* */

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

/* ******************************************************* */

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

/* ******************************************************* */

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

/* ******************************************************* */

/**
 * Generate a multi select with groups 
 */
const generate_multi_select = (params, has_container = true) => {

   const $select = $(`<select multiple class='form-control h-16'></select>`);

   // add groups and items
   params.groups.forEach((category) => {

      const $group = $(`<optgroup label='${category.label}'></optgroup>`);
      category.elements.forEach((element) => {
         $group.append($(`<option value='${element}'>${element.titleCase()}</option>`))
      });

      $select.append($group);
   });

   // add attributes
   if (params.name != undefined) $select.attr('name', params.name);
   if (params.enabled != undefined && !params.enabled) $select.attr('disabled', '');
   if (params.id != undefined) $select.attr('id', params.id);

   if (params.selected_values != undefined) {
      $select.val(params.selected_values);
   }

   if (has_container) {
      return $(`
         <div class='form-group mt-3'>
            <label>${params.label || 'Default Label'}</label>
         </div>
      `).append($select);
   }

   return $select;
}


/* ******************************************************* */

const generate_input_box = (input_settings, has_container = true) => {
   
   const $input_box = $(`<input required type='number' name='${input_settings.name}' class='form-control' />`);

   // set attributes and values
   if (input_settings.max != undefined) $input_box.attr("max", input_settings.max);
   if (input_settings.min != undefined) $input_box.attr("min", input_settings.min);
   if (input_settings.current_value != undefined) $input_box.val(input_settings.current_value);

   if (input_settings.enabled != undefined && !input_settings.enabled) {
      $input_box.attr("readonly", "");
   }

   if (has_container) {
      const $input_container = $(`<div class='form-row mb-2'></div>`);
      return $input_container.append($(`<div class='col-2'></div>`).append($input_box));
   }

   return $input_box;
}

/* ******************************************************* */

const generate_textarea = (textarea_settings) => {

   const $textarea = $(`
         <div class='form-group mt-3'>
            <label class='pl-2'>${textarea_settings.label}</label>
            <textarea ${textarea_settings.class}
               ${textarea_settings.enabled ? '' : 'readonly'}
               name='${textarea_settings.name}'
               placeholder='${textarea_settings.placeholder}'
               class='form-control ml-2'>${textarea_settings.value}</textarea>
            <div class="invalid-feedback"></div>
         </div>
   `);

   return $textarea;
};


/* ******************************************************* */

const generate_radio_buttons = (params, has_container = true) => {

   const active_first_button = params.granularity.labels[0] == params.granularity.label;
   const active_second_button = params.granularity.labels[1] == params.granularity.label;
   const active_third_button = params.granularity.labels[2] == params.granularity.label;

   const $radio_buttons = $(`
      <div class="btn-group float-right btn-group-toggle" data-toggle="buttons">
         <label 
            class="btn ${active_first_button ? 'active btn-primary' : 'btn-secondary'} ${params.enabled ? '' : 'disabled'}">
            <input 
               ${params.enabled ? '' : 'disabled'}
               ${active_first_button ? 'checked' : ''}
               value='${params.granularity.values[0]}'
               type="radio"
               name="${params.name}"> ${params.granularity.labels[0]}
         </label>
         <label 
            class="btn ${active_second_button ? 'active btn-primary' : 'btn-secondary'} ${params.enabled ? '' : 'disabled'}">
            <input 
               ${params.enabled ? '' : 'disabled'}
               ${active_second_button ? 'checked' : ''}
               value='${params.granularity.values[1]}'
               type="radio" 
               name="${params.name}"> ${params.granularity.labels[1]}
         </label>
         <label 
            class="btn ${active_third_button ? 'active btn-primary' : 'btn-secondary'} ${params.enabled ? '' : 'disabled'}">
            <input 
               ${params.enabled ? '' : 'disabled'} 
               ${active_third_button ? 'checked' : ''}
               value='${params.granularity.values[2]}'
               type="radio" 
               name="${params.name}"> ${params.granularity.labels[2]}
         </label>
      </div>
   `);

   $radio_buttons.find(`input[type='radio']`).on('click', function(e) {

      // remove active class from every button
      $radio_buttons.find('label').removeClass('active').removeClass('btn-primary').addClass('btn-secondary');
      // remove checked from buttons
      $radio_buttons.find('input').removeAttr('checked');

      // add active class and btn-primary to the new one
      $(this).prop('checked', '').parent().addClass('active btn-primary').removeClass('btn-secondary');
   });

   if (has_container) {

      const $radio_container = $(`<div class='col-3'></div>`);
      return $radio_container.append($radio_buttons);
   }

   return $radio_buttons;
}

/* ******************************************************* */

const reset_radio_button = (name, value) => {

   $(`input[name='${name}']`)
      .removeAttr('checked')
      .parent()
      .removeClass('btn-primary')
      .removeClass('active')
      .addClass('btn-secondary');

   $(`input[name='${name}'][value='${value}']`)
      .attr('checked', '')
      .parent()
      .toggleClass('btn-secondary')
      .toggleClass('btn-primary')
      .toggleClass('active');
}

/* ******************************************************* */

const get_unit_bytes = (bytes) => {

   if (bytes < 1048576 || bytes == undefined || bytes == null) {
      return ["KB", bytes / 1024, 1024];
   }
   else if (bytes >= 1048576 && bytes < 1073741824) {
      return ["MB", bytes / 1048576, 1048576];
   }
   else {
      return ["GB", bytes / 1073741824, 1073741824];
   }

};

/* ******************************************************* */

const get_unit_times = (seconds) => {

   if (seconds < 3600 || seconds == undefined || seconds == null) {
      return ["Minutes", seconds / 60, 60];
   }
   else if (seconds >= 3600 && seconds < 86400) {
      return ["Hours", seconds / 3600, 3600];
   }
   else if (seconds >= 86400) {
      return ["Days", seconds / 86400, 86400];
   }

};

/* ******************************************************* */

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
         if (d.success) reloadPageAfterPOST();
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

/* ******************************************************* */

const ThresholdCross = (gui, hooks, script_subdir, script_key) => {

   const $table_editor = $("#script-config-editor");

   const render_select_operator = (operators, key, hook) => {

      const $select = $(`
      <select 
         name='${key}-select'
         required
         ${hook.enabled ? '' : 'disabled'} 
         class='btn btn-outline-secondary'></select>
      `);

      operators.forEach((op) => {
         $select.append($(`<option selected value="${op}">&${op}</option>`));
      });

      // select the right operator
      if (hook.script_conf.operator != undefined) {
         $select.val(hook.script_conf.operator)
      }

      return $select;
   }

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
         
         let $select = null;
         if (field_operator == undefined) {
            $select = render_select_operator(operators, key, hook);
         }
         else {
            $select = $(`<span class='input-group-text'>&${field_operator}</span>`).data('value', field_operator);
         }

         const $field = $(`<div class='input-group template w-50'></div>`);
         $field.append($(`<div class='input-group-prepend'></div>`).append($select));
         $field.append(`<input 
                           type='number'
                           class='form-control text-right'
                           required
                           name='${key}-input'
                           ${hook.enabled ? '' : 'readonly'}
                           value='${hook.script_conf.threshold == undefined ? '' : hook.script_conf.threshold}'
                           min='${field_min == undefined ? '' : field_min}' 
                           max='${field_max == undefined ? '' : field_max}'>`);
         $field.append(`<span class='mt-auto mb-auto ml-2 mr-2'>${fields_unit ? fields_unit.titleCase() : ""}</span>`);
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
            $(`<td>${(hook.label ? hook.label.titleCase() : "")}</td>`),
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
         delete $input_fields['min'];
      }
      if ("5mins" in $input_fields) {
         $table_editor.append($input_fields['5mins']);
         delete $input_fields['5mins'];
      }
      if ("hour" in $input_fields) {
         $table_editor.append($input_fields['hour']);
         delete $input_fields['hour'];
      }
      if ("day" in $input_fields) {
         $table_editor.append($input_fields['day']);
         delete $input_fields['day'];
      }

      var other_keys = [];

      for(var key in $input_fields)
         other_keys.push(key);

      /* Guarantees the sort order */
      other_keys.sort();

      $.each(other_keys, function(idx, item) {
         $table_editor.append($input_fields[item]);
      });

      console.log($input_fields);
   };

   const apply_event = (event) => {

      // prepare request to save config
      const data = {};

      // iterate over granularities
      $table_editor.find("tr[id]").each(function (index) {

         const id = $(this).attr("id");

         const enabled = $(this).find("input[type='checkbox']").is(":checked");
         const $template = $(this).find(".template");
         const $error_label = $template.find(`.invalid-feedback`);

         let operator = $template.find("select").val();
         // if operator is undefined it means there isn't any select, so take the value from span
         if (operator == undefined) {
            operator = $template.find('span.input-group-text').data('value');
         }

         const $input_box = $template.find("input");

         let threshold = parseInt($input_box.val());

         // hide before errors
         $error_label.hide();
         
         // remove class error
         $input_box.removeClass('is-invalid');

         // save data into dictonary
         data[id] = {
            'enabled': enabled,
            'script_conf': {
               'operator': operator,
               'threshold': parseInt(threshold)
            }
         }
      });

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

/* ******************************************************* */

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

      const items_list = textarea_value ? textarea_value.split(',').map(x => x.trim()) : [];

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

/* ******************************************************* */

const LongLived = (gui, hooks, script_subdir, script_key) => {

   const $table_editor = $("#script-config-editor");
   $("#script-config-editor").empty();
   
   const render_template = () => {

      const enabled = hooks.all.enabled;
      const items_list = hooks.all.script_conf.items || []; 
      const current_value = hooks.all.script_conf.min_duration || 60;
      const times_unit = get_unit_times(current_value);

      const input_settings = {
         name: 'duration_value',
         current_value: times_unit[1],
         min: 1,
         max: (times_unit[0] == "Minutes" ? 59 : (times_unit[0] == "Hours" ? 23 : 365)),
         enabled: enabled,
      };

      const $time_input_box = generate_input_box(input_settings);

      const $multiselect_ds = generate_multi_select({
         enabled: enabled,
         name: 'item_list',
         label: `${i18n.scripts_list.templates.excluded_applications}:`,
         selected_values: items_list,
         groups: apps_and_categories
      });

      // time-ds stands for: time duration selection
      const radio_values = {
         labels: ["Minutes", "Hours", "Days"], 
         label: times_unit[0],
         values: [60, 3600, 86400]
      }
      const $time_radio_buttons = generate_radio_buttons({
         name: 'ds_time',
         enabled: enabled,
         granularity: radio_values
      });

      // clamp values on radio change
      $time_radio_buttons.find(`input[type='radio']`).on('change', function() {

         const time_selected = $(this).val();
     
         // set min/max bounds to input box
         if (time_selected == 60) {
            $time_input_box.find('input').attr("max", 59);
         }
         else if (time_selected == 3600) {
            $time_input_box.find('input').attr("max", 23);
         }
         else {
            $time_input_box.find('input').attr("max", 365);
         }

      });

      const callback_checkbox = function (e) {

         const checked = $(this).prop('checked');

         // if the checked option is false the disable the elements
         if (!checked) {
            $time_input_box.find(`input[name='duration_value']`).attr("readonly", "");
            $time_radio_buttons.find(`input[type='radio']`).attr("disabled", "").parent().addClass('disabled');
            $multiselect_ds.find('select').attr("disabled", "");
            return;
         }

         $time_input_box.find(`input[name='duration_value']`).removeAttr("readonly");
         $time_radio_buttons.find(`input[type='radio']`).removeAttr("disabled").parent().removeClass('disabled');
         $multiselect_ds.find('select').removeAttr("disabled");

      };

      const $checkbox_enabled = generate_checkbox_enabled(
         'ds-checkbox', hooks.all.enabled, callback_checkbox
      );

      // append elements on table
      const $input_container = $(`<td></td>`);
      $input_container.append(
         $time_input_box.prepend($time_radio_buttons).prepend(
            $(`<div class='col-7'><label class='p-2'>${i18n.scripts_list.templates.flow_duration_threshold}:</label></div>`)
         ), 
         $multiselect_ds
      );

      // initialize table row
      const $container = $(`<tr></tr>`).append(
         $(`<td class='text-center'></td>`).append($checkbox_enabled),
         $input_container
      );

      $table_editor.append(`
         <tr class='text-center'>
            <th>${i18n.enabled}</th>
         </tr>
      `);

      $table_editor.append($container);

   }

   const apply_event = (event) => {

      const hook_enabled = $('#ds-checkbox').prop('checked');
      const items_list = $(`select[name='item_list']`).val();

      // get the bytes_unit
      const times_unit = $(`input[name='ds_time']:checked`).val();
      const min_duration_input = $(`input[name='duration_value']`).val();

      const parsed_duration = parseInt(min_duration_input);

      const template_data = {
         all: {
            enabled: hook_enabled,
            script_conf: {
               items: items_list,
               min_duration: parseInt(times_unit) * parsed_duration,
            }
         }
      }

      // make post request to save data
      apply_edits_script(template_data, script_subdir, script_key);

   }

   const reset_event = (event) => {

      reset_script_defaults(script_key, script_subdir, (data_reset) => {
         
         // reset textarea content
         const items_list = data_reset.hooks.all.script_conf.items || [];
         $(`select[name='item_list']`).val(items_list);

         // get min_duration value
         const min_duration = data_reset.hooks.all.script_conf.min_duration || 60;
         const times_unit = get_unit_times(min_duration);
         $(`input[name='duration_value']`).val(times_unit[1]);

         // select the correct radio button
         reset_radio_button('ds_time', times_unit[2]);

         const enabled = data_reset.hooks.all.enabled || false;
         $('#ds-checkbox').prop('checked', enabled);
         
         if (!enabled) {
            $(`input[name='duration_value']`).attr('readonly', '');
            $(`select[name='item_list'],input[name='ds_time']`).attr('disabled', '').parent().addClass('disabled');
         }
         else {
            $(`input[name='duration_value']`).removeAttr('readonly');
            $(`select[name='item_list'],input[name='ds_time']`).removeAttr('disabled').parent().removeClass('disabled');
         }

      });
   }

   return {
      apply_click_event: apply_event,
      reset_click_event: reset_event,
      render: render_template,
   }
}

/* ******************************************************* */

const ElephantFlows = (gui, hooks, script_subdir, script_key) => {

   const $table_editor = $("#script-config-editor");
   $("#script-config-editor").empty();

   const render_template = () => {

      const enabled = hooks.all.enabled;
      const items_list = hooks.all.script_conf.items || []; 

      let l2r_bytes_value = hooks.all.script_conf.l2r_bytes_value; 
      let r2l_bytes_value = hooks.all.script_conf.r2l_bytes_value; 

      // get units and values
      const l2r_unit = get_unit_bytes(l2r_bytes_value);
      const r2l_unit = get_unit_bytes(r2l_bytes_value);

      // configure local to remote input
      const input_settings_l2r = {
         min: 1,
         max: 1023,
         current_value: l2r_unit[1],
         name: 'l2r_value',
         enabled: enabled
      };
      const $input_box_l2r = generate_input_box(input_settings_l2r);

      // configure remote to locale input
      const input_settings_r2l = {
         min: 1,
         max: 1023,
         current_value: r2l_unit[1],
         name: 'r2l_value',
         enabled: enabled
      };
      const $input_box_r2l = generate_input_box(input_settings_r2l);

      // create textarea to append
      const $multiselect_bytes = generate_multi_select({
         enabled: enabled,
         name: 'item_list',
         label: `${i18n.scripts_list.templates.excluded_applications}:`,
         selected_values: items_list,
         groups: apps_and_categories
      });

      // create radio button with its own values
      const radio_values_l2r = {
         labels: ["KB", "MB", "GB"],
         label: l2r_unit[0],
         values: [1024, 1048576, 1073741824]
      };
      const radio_values_r2l = {
         labels: ["KB", "MB", "GB"],
         label: r2l_unit[0],
         values: [1024, 1048576, 1073741824]
      };

      const $radio_button_l2r = generate_radio_buttons({
            name: 'bytes_l2r', 
            enabled: enabled,
            granularity: radio_values_l2r
         }
      );
      const $radio_button_r2l = generate_radio_buttons({
            name: 'bytes_r2l', 
            enabled: enabled,
            granularity: radio_values_r2l
         }
      );

      const $checkbox_enabled = generate_checkbox_enabled(
         'elephant-flows-checkbox', enabled, function (e) {

            const checked = $(this).prop('checked');
   
            // if the checked option is false the disable the elements
            if (!checked) {
               $input_box_r2l.find(`input`).attr("readonly", "");
               $input_box_l2r.find(`input`).attr("readonly", "");
               $radio_button_l2r.find(`input[type='radio']`).attr("disabled", "").parent().addClass('disabled');
               $radio_button_r2l.find(`input[type='radio']`).attr("disabled", "").parent().addClass('disabled');
               $multiselect_bytes.find('select').attr("disabled", "");
               return;
            }

            $input_box_r2l.find(`input`).removeAttr("readonly", "");
            $input_box_l2r.find(`input`).removeAttr("readonly", "");
            $radio_button_l2r.find(`input[type='radio']`).removeAttr("disabled").parent().removeClass('disabled');
            $radio_button_r2l.find(`input[type='radio']`).removeAttr("disabled").parent().removeClass('disabled');
            $multiselect_bytes.find('select').removeAttr("disabled");
         }
      );

      // append elements on table
      const $input_container = $(`<td></td>`);
      $input_container.append(
         $input_box_l2r
            .prepend($radio_button_l2r)
            .prepend($(`<div class='col-7'><label class='pl-2'>${i18n.scripts_list.templates.elephant_flows_l2r}</label></div>`)), 
         $input_box_r2l
            .prepend($radio_button_r2l)
            .prepend($(`<div class='col-7'><label class='pl-2'>${i18n.scripts_list.templates.elephant_flows_r2l}</label></div>`)), 
         $multiselect_bytes
      );

      // initialize table row
      const $container = $(`<tr></tr>`).append(
         $(`<td class='text-center'></td>`).append($checkbox_enabled),
         $input_container
      );

      $table_editor.append(`
         <tr class='text-center'>
            <th>${i18n.enabled}</th>
         </tr>
      `);

      // append all inside the table
      $table_editor.append($container);

   }

   const apply_event = (event) => {

      const hook_enabled = $('#elephant-flows-checkbox').prop('checked');

      const items_list = $(`select[name='item_list']`).val();

      // get the bytes_unit
      const unit_l2r = $(`input[name='bytes_l2r']:checked`).val();
      const unit_r2l = $(`input[name='bytes_r2l']:checked`).val();

      const input_l2r = $(`input[name='l2r_value']`).val();
      const input_r2l = $(`input[name='r2l_value']`).val();

      const template_data = {
         all: {
            enabled: hook_enabled,
            script_conf: {
               items: items_list,
               l2r_bytes_value: parseInt(unit_l2r) * parseInt(input_l2r),
               r2l_bytes_value: parseInt(unit_r2l) * parseInt(input_r2l)
            }
         }
      }

      apply_edits_script(template_data, script_subdir, script_key);

   }

   const reset_event = (event) => {

      reset_script_defaults(script_key, script_subdir, (data_reset) => {

         // reset textarea content
         const items_list = data_reset.hooks.all.script_conf.items || [];
         $(`select[name='item_list']`).val(items_list);
 
         // get min_duration value
         const bytes_l2r = data_reset.hooks.all.script_conf.l2r_bytes_value || 1024;
         const bytes_r2l = data_reset.hooks.all.script_conf.r2l_bytes_value || 1024;

         const bytes_unit_l2r = get_unit_bytes(bytes_l2r);
         const bytes_unit_r2l = get_unit_bytes(bytes_r2l);
         $(`input[name='l2r_value']`).val(bytes_unit_l2r[1]);
         $(`input[name='r2l_value']`).val(bytes_unit_r2l[1]);
 
         // select the correct radio button
         reset_radio_button('bytes_l2r', bytes_unit_l2r[2]);
         reset_radio_button('bytes_r2l', bytes_unit_r2l[2]);
          
         const enabled = data_reset.hooks.all.enabled || false;
         $('#elephant-flows-checkbox').prop('checked', enabled);
          
         if (!enabled) {
            $(`input[name='l2r_value'],input[name='r2l_value']`).attr('readonly', '');
            $(`select[name='item_list'],input[name='bytes_l2r']`).attr('disabled', '').parent().addClass('disabled');
            $(`input[name='bytes_r2l']`).attr('disabled', '').parent().addClass('disabled');
         }
         else {
            $(`input[name='l2r_value'],input[name='r2l_value']`).removeAttr('readonly');
            $(`select[name='item_list'],input[name='bytes_l2r']`).removeAttr('disabled').parent().removeClass('disabled');
            $(`input[name='bytes_r2l']`).removeAttr('disabled').parent().removeClass('disabled');
         }

      });

   }

   return {
      apply_click_event: apply_event,
      reset_click_event: reset_event,
      render: render_template,
   }
}

/* ******************************************************* */

const EmptyTemplate = (gui = null, hooks = null, script_subdir = null, script_key = null) => {
   return {
      apply_click_event: function() {},
      reset_click_event: function() {},
      render: function() {},
   }
}

/* ******************************************************* */

// get script key and script name
   

const initScriptConfModal = (script_key, script_title) => {
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

      const template = TemplateBuilder(data, script_subdir, script_key);
      
      // render template
      template.render();

      // bind on_apply event on apply button
      $("#edit-form").off("submit").on('submit', template.apply_click_event);
      $("#btn-reset").off("click").on('click', template.reset_click_event);

      // bind are you sure to form
      $('#edit-form').trigger('rescan.areYouSure').trigger('reinitialize.areYouSure');
    })
   .fail(({status, statusText}) => {

      check_status_code(status, statusText, null);
      // hide modal if there is error
      $("#modal-script").modal("toggle");
   })
}

/* ******************************************************* */

const TemplateBuilder = ({gui, hooks}, script_subdir, script_key) => {

   // get template name
   const template_name = gui.input_builder;

   const templates = {
      threshold_cross: ThresholdCross(gui, hooks, script_subdir, script_key),
      items_list: ItemsList(gui, hooks, script_subdir, script_key),
      long_lived: LongLived(gui, hooks, script_subdir, script_key),
      elephant_flows: ElephantFlows(gui, hooks, script_subdir, script_key)
   }

   let template_chosen = templates[template_name];

   if (!template_chosen) {
      template_chosen = EmptyTemplate();
      throw(`${i18n.scripts_list.templates.template_not_implemented}`);
   }

   return template_chosen;
}

/* ******************************************************* */

// End templates and template builder

const create_enabled_button = (row_data) => {

   const {is_enabled} = row_data;

   const $button = $(`<button type='button' class='badge border-0'></button>`);

   if (!is_enabled) {   
      
      const has_all_hook = row_data.all_hooks.find(e => e.key == 'all');

      if (!has_all_hook && hasConfigDialog(row_data)) $button.css('visibility', 'hidden');

      $button.text(`${i18n.enable || 'Enable'}`);
      $button.addClass('badge-success');

   }
   else {

      if (row_data.enabled_hooks.length < 1) $button.css('visibility', 'hidden');

      $button.text(`${i18n.disable || 'Disable'}`);
      $button.addClass('badge-danger');
   }

   $button.off('click').on('click', function() {

      $.post(`${http_prefix}/lua/toggle_user_script.lua`, {
         script_subdir: script_subdir,
         script_key: row_data.key,
         csrf: csrf_toggle_buttons,
         action: (is_enabled) ? 'disable' : 'enable',
         confset_id: confset_id
      })
      .done((d, status, xhr) => {
   
         if (!d.success) {
            $("#alert-row-buttons").text(d.error).removeClass('d-none').show();
            // update csrf
            csrf_toggle_buttons = d.csrf;
         }
   
         if (d.success) reloadPageAfterPOST();
   
      })
      .fail(({ status, statusText }) => {
   
         check_status_code(status, statusText, $("#alert-row-buttons"));
   
         // if the csrf has expired 
         if (status == 200) {
            $("#alert-row-buttons").text(`${i18n.expired_csrf}`).removeClass('d-none').show();
         }
   
            // re eanble buttons
         $button.removeAttr("disabled").removeClass('disabled');
      });
   })

   return $button;
};

$(document).ready(function() {


   // initialize script table 
   const $script_table = $("#scripts-config").DataTable({
      dom: "Bfrtip",
      autoWidth: true,
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
         url: `${http_prefix}/lua/get_user_scripts.lua?confset_id=${confset_id}&script_subdir=${script_subdir}`,
         type: 'get',
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

         if (script_key_filter) {
            let elem = json.filter((x) => { return(x.key == script_key_filter); })[0];

            if (elem) {
               let title = elem.title;
               this.DataTable().search(title).draw();

               if(hasConfigDialog(elem)) {
                  initScriptConfModal(script_key_filter, title);
                  $("#modal-script").modal("show");
               }
            }
         }
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

               if (type == 'display') return `<b>${data}</b>`;
               return data;
            },
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
               if (data.length == 1) return data[0];

               return data.map(enabled_hook => {
                  return row.all_hooks.find((current) => current.key === enabled_hook).label
               }).join(', ');
            },
         },
         {
            targets: -1,
            data: null,
            name: 'actions',
            className: 'text-center',
            sortable: false,
            render: function (data, type, row) {

               const edit_script_btn = `
                      <a href='#'
                         title='${i18n.edit_script}'
                         class='badge badge-info'
                         style="visibility: ${!row.input_handler ? 'hidden' : 'visible'}"
                         data-toggle="modal"
                         data-target="#modal-script">
                         
                           ${i18n.edit}
                     </a>
               `;
               const edit_url_btn = `
                      <a href='${data.edit_url}'
                        class='badge badge-secondary'
                        style="visibility: ${!data.edit_url ? 'hidden' : 'visible'}"
                        title='${i18n.view_src_script}'>
                           ${i18n.view}
                      </a>
               `;

               return `${edit_script_btn}${edit_url_btn}`;
            },
            createdCell: function(td, cellData, row) {
                       
               const enabled_button = create_enabled_button(row);
               $(td).prepend(enabled_button);
            }
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

      const row_data = $script_table.row($(this).parent()).data();
      const script_key = row_data.key;
      const script_title = row_data.title;

      initScriptConfModal(script_key, script_title);
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
