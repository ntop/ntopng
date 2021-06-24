// 2020 - ntop.org

String.prototype.titleCase = function () {

   return this.toLowerCase().split(' ').map(function (word) {
      return word.replace(word[0], word[0].toUpperCase());
   }).join(' ');

}

/* ******************************************************* */

const reloadPageAfterPOST = () => {
   if (location.href.indexOf("check=") > 0) {
      /* Go back to the alerts page */
      //location.href = page_url + location.hash;
      window.history.back();
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
      <div class="form-switch"">
         <input
            id='${id}'
            name='enabled'
            class="form-check-input ms-0"
            type="checkbox"
            ${enabled ? "checked" : ""} />
            <label class="form-check-label" for="${id}"></label>
      </div>
   `);

   // bind check event on checkboxes
   $checkbox_enabled.find(`input[type='checkbox']`).change(callback);

   return $checkbox_enabled;
}

/* ******************************************************* */

/**
 * Generate a multi select with groups
 */
const generate_multi_select = (params, has_container = true) => {

   const $select = $(`<select id='multiple-select' style="height: 10rem" multiple class='form-select'></select>`);

   // add groups and items
   if (params.groups.length == 1) {

      params.groups[0].elements.forEach((element) => {
         $select.append($(`<option value='${element[0]}'>${element[1]}</option>`))
      });
   }
   else {

      params.groups.forEach((category) => {

         const $group = $(`<optgroup label='${category.label}'></optgroup>`);
         category.elements.forEach((element) => {
            $group.append($(`<option value='${element[0]}'>${element[1]}</option>`))
         });

         $select.append($group);
      });
   }

   // add attributes
   if (params.name != undefined) $select.attr('name', params.name);
   if (params.enabled != undefined && !params.enabled) $select.attr('disabled', '');
   if (params.id != undefined) $select.attr('id', params.id);

   if (params.selected_values != undefined) {
      $select.val(params.selected_values);
   }

   if (has_container) {
      return $(`
         <div class='form-group mb-3 ${(params.containerCss || "mt-3")}'>
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
      const $input_container = $(`<div class='row'></div>`);
      return $input_container.append($(`<div class='col-2'></div>`).append($input_box));
   }

   return $input_box;
}

/* ******************************************************* */

const generate_single_select = (params, has_container = true) => {

   const $select = $(`<select name='${params.name}' class='form-select' />`);

   if (params.enabled != undefined && !params.enabled) {
      $select.attr("disabled", "");
   }

   params.elements.forEach((element) => {
      $select.append($(`<option value='${element[0]}'>${element[1]}</option>`))
   });

   if (params.current_value != undefined) $select.val(params.current_value);

   if (has_container) {
      const $input_container = $(`<div class='row'></div>`);
      return $input_container.append(
         $(`<div class='col-10'><label class='p-2'>${params.label}</label></div>`),
         $(`<div class='col-2'></div>`).append($select),
      );
   }

   return $input_box;
}

/* ******************************************************* */

const generate_textarea = (textarea_settings) => {

   const $textarea = $(`
         <div class='form-group mb-3 mt-3'>
            <label class='pl-2'>${textarea_settings.label}</label>
            <textarea ${textarea_settings.class}
               ${textarea_settings.enabled ? '' : 'readonly'}
               name='${textarea_settings.name}'
               placeholder='${textarea_settings.placeholder}'
               class='form-control ms-2'>${textarea_settings.value}</textarea>
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

   let $radio_buttons = $(`
      <div class="btn-group float-end btn-group-toggle" data-bs-toggle="buttons">
         <input
               ${params.enabled ? '' : 'disabled'}
               ${active_first_button ? 'checked' : ''}
               value='${params.granularity.values[0]}'
               id="first_button_${params.name}"
               type="radio"
               class="btn-check"
               autocomplete="off"
               name="${params.name}">
<label class="btn ${active_first_button ? 'active btn-primary' : 'btn-secondary'} ${params.enabled ? '' : 'disabled'}" for="first_button_${params.name}">
 ${params.granularity.labels[0]} </label>

         <input
               ${params.enabled ? '' : 'disabled'}
               ${active_second_button ? 'checked' : ''}
               value='${params.granularity.values[1]}'
               id="second_button_${params.name}"
               type="radio"
               class="btn-check"
               autocomplete="off"
               name="${params.name}">
<label class="btn ${active_second_button ? 'active btn-primary' : 'btn-secondary'} ${params.enabled ? '' : 'disabled'}" for="second_button_${params.name}">
 ${params.granularity.labels[1]} </label>

         <input
               ${params.enabled ? '' : 'disabled'}
               ${active_third_button ? 'checked' : ''}
               value='${params.granularity.values[2]}'
               type="radio"
               id="third_button_${params.name}"
               class="btn-check"
               autocomplete="off"
               name="${params.name}"> 
<label class="btn ${active_third_button ? 'active btn-primary' : 'btn-secondary'} ${params.enabled ? '' : 'disabled'}" for="third_button_${params.name}">
${params.granularity.labels[2]}
         </label>
      </div>
   `);

   $radio_buttons.find(`label`).on('click', function (e) {
      // Remove active class from every button
      $radio_buttons.find('label').removeClass('active').removeClass('btn-primary').addClass('btn-secondary');

      // Remove checked from buttons
      const checked_input_id = $(this).attr('for');
      const checked_input = $("#" + checked_input_id);

      // Add attribute checked to the input associated to this label      
      checked_input.attr('checked', '');
      // Set the right classes to this active label
      $(this).addClass('active btn-primary').removeClass('btn-secondary');
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
      return [`${i18n.metrics.minutes}`, seconds / 60, 60];
   }
   else if (seconds >= 3600 && seconds < 86400) {
      return [`${i18n.metrics.hours}`, seconds / 3600, 3600];
   }
   else if (seconds >= 86400) {
      return [`${i18n.metrics.days}`, seconds / 86400, 86400];
   }

};

/* ******************************************************* */

function getSanitizedScriptExList(script_exclusion_list) {
   var ex_list_purified;

   // IP only are supported at the moment, values are listed without <name>=
   // as this is more intuitive for the user, however the backend 
   // handles <name>=<value> (see also appendExclusionList)
   //ex_list_purified = script_exclusion_list.split("\n").join(";");

   ex_list_purified = script_exclusion_list.split(" ").join(""); 
   ex_list_purified = ex_list_purified.split("\n").join("");
   if (ex_list_purified.length > 0) 
     ex_list_purified = "ip="+ex_list_purified;
   ex_list_purified = ex_list_purified.split(",").join(";ip=");

   return ex_list_purified.split(" ").join("");
}

/* ******************************************************* */

const apply_edits_script = (template_data, check_subdir, script_key) => {
   const exclusionList = $(`#script-config-editor textarea[name='exclusion-list']`).val();
   var script_exclusion_list = exclusionList || undefined;

   const $apply_btn = $('#btn-apply');
   const $error_label = $("#apply-error");

   if (script_exclusion_list !== undefined) {
      script_exclusion_list = getSanitizedScriptExList(script_exclusion_list);
   }

   // remove dirty class from form
   $('#edit-form').removeClass('dirty')
   $apply_btn.attr('disabled', '');

   $.post(`${http_prefix}/lua/edit_check_config.lua`, {
      check_subdir: check_subdir,
      script_key: script_key,
      csrf: pageCsrf,
      script_exclusion_list: script_exclusion_list,
      JSON: JSON.stringify(template_data)
   })
      .done((d, status, xhr) => {

         if (NtopUtils.check_status_code(xhr.status, xhr.statusText, $error_label)) return;

         if (!d.success) {

            $error_label.text(d.error).show();
            // re enable button
            $apply_btn.removeAttr('disabled');
         }

         // if the operation was successfull then reload the page
         if (d.success) reloadPageAfterPOST();
      })
      .fail(({ status, statusText }, a, b) => {

         NtopUtils.check_status_code(status, statusText, $error_label);

         if (status == 200) {
            $error_label.text(`${i18n.expired_csrf}`).show();
         }

         $apply_btn.removeAttr('disabled');
      });
}

const reset_script_defaults = (script_key, check_subdir, callback_reset) => {

   const $error_label = $('#apply-error');

   $.get(`${http_prefix}/lua/get_check_config.lua`, {
      check_subdir: check_subdir,
      script_key: script_key,
      factory: 'true'
   })
      .done((reset_data, status, xhr) => {

         // if there is an error about the http request
         if (NtopUtils.check_status_code(xhr.status, xhr.statusText, $error_label)) return;

         const { metadata } = reset_data;
         const exclusionList = $(`#script-config-editor textarea[name='exclusion-list']`).val();
         const script_exclusion_list = exclusionList || undefined;

         /* Creating the default string for the exclusion list when reset is called */
         if (script_exclusion_list) {
            let ex_list_str = ""
            const scriptConfExList = reset_data.filters;

            if (scriptConfExList) {
               const scriptConfCurrFil = scriptConfExList.current_filters;
               if (scriptConfCurrFil) {
                  for (const [index, filters] of Object.entries(scriptConfCurrFil)) {
                     for (const [name, value] of Object.entries(filters)) {
                        // Concat the string to create a human readable string
                        if (name === "str_format") {
                           // Temporary check, needs to be removed in a few time
                           continue;
                        }
                        ex_list_str = ex_list_str + name + "=" + value + ",";
                     }

                     ex_list_str = ex_list_str.slice(0, -1);
                     ex_list_str = ex_list_str + "\n";
                  }
               }

               $(`#script-config-editor textarea[name='exclusion-list']`).val(ex_list_str);
            }
         }

          // call callback function to reset fields
         callback_reset(reset_data);

         // add dirty class to form
         $('#edit-form').addClass('dirty');
      })
      .fail(({ status, statusText }) => {

         NtopUtils.check_status_code(status, statusText, $error_label);
         // hide modal if there is error
         $("#modal-script").modal("toggle");
      })
}

/* ******************************************************* */

// TEMPALTES:

const ThresholdCross = (gui, hooks, check_subdir, script_key) => {

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
         $select.append($(`<option value="${op}">&${op}</option>`));
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

         const $field = $(`<div class='input-group template' style='width: 14rem'></div>`);
         $field.append($select);
         $field.append(`<input
                           type='number'
                           class='form-control text-end'
                           required
                           name='${key}-input'
                           ${hook.enabled ? '' : 'readonly'}
                           value='${hook.script_conf.threshold == undefined ? '' : hook.script_conf.threshold}'
                           min='${field_min == undefined ? '' : field_min}'
                           max='${field_max == undefined ? '' : field_max}'>`);
         $field.append(`<span class='mt-auto mb-auto ms-2 me-2'>${fields_unit ? fields_unit : ""}</span>`);
         $field.append(`<div class='invalid-feedback'></div>`);

         const $input_container = $(`<tr id='${key}'></tr>`);
         const $checkbox = $(`
            <div class="form-switch">
               <input class="form-check-input ms-0" id="id-${key}-check" name="${key}-check" type="checkbox" ${hook.enabled ? "checked" : ""} >
               <label class="form-check-label" for="id-${key}-check"></label>
            </div>
         `);

         // bind check event on checkboxes
         $checkbox.find(`input[type='checkbox']`).change(function (e) {

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
            $(`<td class='text-center align-middle'></td>`).append($checkbox),
            $(`<td class='align-middle'>${(hook.label ? hook.label.titleCase() : "")}</td>`),
            $(`<td></td>`).append($field)
         );

         // save input field
         $input_fields[key] = $input_container;

      }

      // clean script editor table from previous state
      $table_editor.empty();

      // append each hooks to the table
      $table_editor.append(`<tr><th class='text-center'>${i18n.enabled}</th></tr>`)

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

      let other_keys = [];

      for (let key in $input_fields) other_keys.push(key);

      /* Guarantees the sort order */
      other_keys.sort();

      $.each(other_keys, function (idx, item) {
         $table_editor.append($input_fields[item]);
      });

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

      apply_edits_script(data, check_subdir, script_key);
   };

   const reset_event = (event) => {

      reset_script_defaults(script_key, check_subdir, (data) => {

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
      reset_click_event: reset_event,
      render: render_template,
   }
}

/* ******************************************************* */

const ItemsList = (gui, hooks, check_subdir, script_key) => {

   const $table_editor = $("#script-config-editor");

   const render_template = () => {
      let enabled = undefined;

      if(hooks.all) 
         enabled = hooks.all.enabled
      else
         enabled = hooks["5mins"] ? hooks["5mins"].enabled : hooks.min.enabled;

      const $component_container = $(`<tr></tr>`);
      const callback_checkbox = function (e) {

         const checked = $(this).prop('checked');

         // if the checked option is false the disable the elements
         if (!checked) {
            $text_area.find(`#itemslist-textarea`).attr("readonly", "");
            return;
         }

         $text_area.find(`#itemslist-textarea`).removeAttr("readonly", "");
      };

      const $checkbox_enabled = generate_checkbox_enabled(
         'itemslist-checkbox', enabled, callback_checkbox
      );

      const items_list = hooks.all ? hooks.all.script_conf.items : ( (hooks["5mins"] ? hooks["5mins"].script_conf.items : hooks.min.script_conf.items) || []); 
      const $text_area = $(`
         <td>
            <div class='form-row'>
               <textarea
                  ${!enabled ? "readonly" : ""}
                  name='items-list'
                  id='itemslist-textarea'
                  class="w-100 form-control"
                  rows='3'>${items_list.length > 0 ? items_list.join(',') : ''}</textarea>
                  <small>${gui.input_description || i18n.blacklisted_country}</small>
               <div class="invalid-feedback"></div>
               <label></label>
            </div>
         </td>
      `);

      $component_container.append($(`<td class='text-center'></td>`).append($checkbox_enabled), $text_area);

      $table_editor.empty();

      $table_editor.append(`<tr><th class='text-center w-25'>${i18n.enabled}</th><th>${gui.input_title || i18n.scripts_list.templates.blacklisted_country_list}:</th></tr>`)
      $table_editor.append($component_container);
   }

   const apply_event = (event) => {

      const hook_enabled = $('#itemslist-checkbox').prop('checked');
      const textarea_value = $('#itemslist-textarea').val().trim();

      const items_list = textarea_value ? textarea_value.split(',').map(x => x.trim()) : [];
      const hook = (hooks.all === undefined) ? ((hooks["5mins"] === undefined) ? "min" : "5mins") : "all";
      const template_data = {
         [hook]: {
            enabled: hook_enabled,
            script_conf: {
               items: items_list
            }
         }
      };

      // make post request to save edits
      apply_edits_script(template_data, check_subdir, script_key);

   }

   const reset_event = (event) => {

      reset_script_defaults(script_key, check_subdir, (reset_data) => {
         const enabled = reset_data.hooks.all ? reset_data.hooks.all.enabled : (reset_data.hooks["5mins"] ? reset_data.hooks["5mins"].enabled : reset_data.hooks.min.enabled);
         const items_list = reset_data.hooks.all ? reset_data.hooks.all.script_conf.items : (reset_data.hooks["5mins"] ? reset_data.hooks["5mins"].script_conf.items : reset_data.hooks.min.script_conf.items);

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

const LongLived = (gui, hooks, check_subdir, script_key) => {

   const $table_editor = $("#script-config-editor");
   $("#script-config-editor").empty();

   const render_template = () => {

      const enabled = hooks.all.enabled;
      const items_list = hooks.all.script_conf.items || [];
      const current_value = hooks.all.script_conf.min_duration || 60;
      const times_unit = get_unit_times(current_value);

      const max_time = (times_unit[0] == `${i18n.metrics.minutes}` ? 59 : (times_unit[0] == `${i18n.metrics.hours}` ? 23 : 365));

      const input_settings = {
         name: 'duration_value',
         current_value: times_unit[1],
         min: 1,
         max: max_time,
         enabled: enabled,
      };

      const $time_input_box = generate_input_box(input_settings);
      /* Currently disabled multi-select for appl and categories
            const $multiselect_ds = generate_multi_select({
               enabled: enabled,
               name: 'item_list',
               label: `${i18n.scripts_list.templates.excluded_applications}:`,
               selected_values: items_list,
               groups: apps_and_categories
            });
      */
      // time-ds stands for: time duration selection
      const radio_values = {
         labels: [`${i18n.metrics.minutes}`, `${i18n.metrics.hours}`, `${i18n.metrics.days}`],
         label: times_unit[0],
         values: [60, 3600, 86400]
      }
      const $time_radio_buttons = generate_radio_buttons({
         name: 'ds_time',
         enabled: enabled,
         granularity: radio_values
      });

      // clamp values on radio change
      $time_radio_buttons.find(`input[type='radio']`).on('change', function () {

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

            const $duration_input = $time_input_box.find(`input[name='duration_value']`);

            $duration_input.attr("readonly", "");
            $time_radio_buttons.find(`input[type='radio']`).attr("disabled", "").parent().addClass('disabled');
            //$multiselect_ds.find('select').attr("disabled", "");

            // if the user left the input box empty then reset previous values
            if ($duration_input.val() == "") {
               $duration_input.val(times_unit[1]);
               $duration_input.attr('max', max_time);
               reset_radio_button('ds_time', times_unit[2]);
            }

            return;
         }

         $time_input_box.find(`input[name='duration_value']`).removeAttr("readonly");
         $time_radio_buttons.find(`input[type='radio']`).removeAttr("disabled").parent().removeClass('disabled');
         //$multiselect_ds.find('select').removeAttr("disabled");

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
         //$multiselect_ds
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
      apply_edits_script(template_data, check_subdir, script_key);

   }

   const reset_event = (event) => {

      reset_script_defaults(script_key, check_subdir, (data_reset) => {

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

const ElephantFlows = (gui, hooks, check_subdir, script_key) => {

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

      /* Currently disabled textarea
            // create textarea to append
            const $multiselect_bytes = generate_multi_select({
               enabled: enabled,
               name: 'item_list',
               label: `${i18n.scripts_list.templates.excluded_applications}:`,
               selected_values: items_list,
               groups: apps_and_categories
            });
      */

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
            const $r2l_input = $input_box_r2l.find(`input[name='r2l_value']`);
            const $l2r_input = $input_box_l2r.find(`input[name='l2r_value']`);

            // if the checked option is false the disable the elements
            if (!checked) {
               $r2l_input.attr("readonly", "");
               $l2r_input.attr("readonly", "");
               $radio_button_l2r.find(`input[type='radio']`).attr("disabled", "").parent().addClass('disabled');
               $radio_button_r2l.find(`input[type='radio']`).attr("disabled", "").parent().addClass('disabled');
               //$multiselect_bytes.find('select').attr("disabled", "");

               // if the user left the input box empty then reset previous values
               if ($r2l_input.val() == "") {
                  $r2l_input.val(r2l_unit[1]);
                  reset_radio_button('bytes_r2l', r2l_unit[2]);
               }
               if ($l2r_input.val() == "") {
                  $l2r_input.val(l2r_unit[1]);
                  reset_radio_button('bytes_l2r', l2r_unit[2]);
               }

               return;
            }

            $r2l_input.removeAttr("readonly", "");
            $l2r_input.removeAttr("readonly", "");
            $radio_button_l2r.find(`input[type='radio']`).removeAttr("disabled").parent().removeClass('disabled');
            $radio_button_r2l.find(`input[type='radio']`).removeAttr("disabled").parent().removeClass('disabled');
            //$multiselect_bytes.find('select').removeAttr("disabled");
         }
      );

      // append elements on table
      const $input_container = $(`<td></td>`);
      $input_container.append(
         $input_box_l2r
            .prepend($radio_button_l2r)
            .prepend($(`<label class='col'>${i18n.scripts_list.templates.elephant_flows_l2r}</label>`)),
         $input_box_r2l
            .prepend($radio_button_r2l)
            .prepend($(`<label class='col'>${i18n.scripts_list.templates.elephant_flows_r2l}</label>`)),
         //$multiselect_bytes
      );

      // initialize table row
      const $container = $(`<tr></tr>`).append(
         $(`<td class='text-center'></td>`).append($checkbox_enabled),
         $input_container
      );

      $table_editor.append(`<tr class='text-center'><th>${i18n.enabled}</th></tr>`);

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

      apply_edits_script(template_data, check_subdir, script_key);

   }

   const reset_event = (event) => {

      reset_script_defaults(script_key, check_subdir, (data_reset) => {

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

const MultiSelect = (gui, hooks, check_subdir, script_key) => {

   const $table_editor = $("#script-config-editor");
   $("#script-config-editor").empty();

   const render_template = () => {

      const enabled = hooks.all.enabled;
      const items_list = hooks.all.script_conf.items || [];
      // create textarea to append
      const $multiselect = generate_multi_select({
         enabled: enabled,
         name: 'item_list',
         label: gui.i8n_multiselect_label,
         containerCss: 'm-0',
         selected_values: items_list,
         groups: gui.groups
      });

      const $checkbox_enabled = generate_checkbox_enabled(
         'multiselect-checkbox', enabled, function (e) {

            const checked = $(this).prop('checked');
            // if the checked option is false the disable the elements
            (!checked)
               ? $multiselect.find('select').attr("disabled", "")
               : $multiselect.find('select').removeAttr("disabled");
         }
      );

      // append elements on table
      const $input_container = $(`<td></td>`);
      $input_container.append($multiselect);

      // initialize table row
      const $container = $(`<tr></tr>`).append(
         $(`<td class='text-center'></td>`).append($checkbox_enabled),
         $input_container
      );

      $table_editor.append(`<tr class='text-center'><th>${i18n.enabled}</th></tr>`);

      // append all inside the table
      $table_editor.append($container);
   }

   const apply_event = (event) => {

      const hook_enabled = $('#multiselect-checkbox').prop('checked');
      const items_list = $(`select[name='item_list']`).val();

      const template_data = {
         all: {
            enabled: hook_enabled,
            script_conf: {
               items: items_list,
            }
         }
      }

      apply_edits_script(template_data, check_subdir, script_key);
   }

   const reset_event = (event) => {
      reset_script_defaults(script_key, check_subdir, (data_reset) => {

         // reset textarea content
         const items_list = data_reset.hooks.all.script_conf.items || [];
         $(`select[name='item_list']`).val(items_list);

         const enabled = data_reset.hooks.all.enabled || false;
         $('#multiselect-checkbox').prop('checked', enabled);
      });
   }

   return {
      apply_click_event: apply_event,
      reset_click_event: reset_event,
      render: render_template,
   }
}

/* ******************************************************* */

const DefaultTemplate = (gui, hooks, check_subdir, script_key) => {

   const $tableEditor = $("#script-config-editor");

   return {
      apply_click_event: function () {

         const template_data = {
            all: {
               enabled: true,
               script_conf: {}
            }
         }

         apply_edits_script(template_data, check_subdir, script_key);
      },
      reset_click_event: function () {
         reset_script_defaults(script_key, check_subdir, (data_reset) => { });
      },
      render: function () {
         $tableEditor.empty();
      },
   }
}

/* ******************************************************* */

const EmptyTemplate = (gui = null, hooks = null, check_subdir = null, script_key = null) => {

   const $tableEditor = $("#script-config-editor");

   return {
      apply_click_event: function () { },
      reset_click_event: function () { },
      render: function () {

         // add an info alert to inform the user about the problem
         const $alert = $("<div class='alert alert-info'></div>");
         $alert.html(i18n.scripts_list.templates.template_not_implemented);
         $tableEditor.append($alert);
         // hide the apply and the reset button because there are no inputs to fill
         $(`#btn-apply,#btn-reset`).hide();
      },
   }
}

// END OF TEMPLATES


/* ******************************************************* */

// get script key and script name
const initScriptConfModal = (script_key, script_title, script_desc) => {
   // change title to modal
   $("#script-name").html(script_title);
   $('#script-description').html(script_desc);

   $("#modal-script form").off('submit');
   $("#modal-script").on("submit", "form", function (e) {
      e.preventDefault();

      $('#edit-form').trigger('reinitialize.areYouSure').removeClass('dirty');
      $("#btn-apply").trigger("click");
   });

   $.get(`${http_prefix}/lua/get_check_config.lua`,
      {
         check_subdir: check_subdir,
         script_key: script_key,
         factory: false
      }
   )
      .then((data, status, xhr) => {

         // check status code
         if (NtopUtils.check_status_code(xhr.status, xhr.statusText, null)) return;

         // hide previous error
         $("#apply-error").hide();

         const template = TemplateBuilder(data, check_subdir, script_key);

         // render template
         template.render();

	 // append the exclusion list 
	 appendExclusionList(data);

         // bind on_apply event on apply button
         $("#edit-form").off("submit").on('submit', template.apply_click_event);
         $("#btn-reset").off("click").on('click', template.reset_click_event);

         // bind are you sure to form
         $('#edit-form').trigger('rescan.areYouSure').trigger('reinitialize.areYouSure');
      })
      .fail(({ status, statusText }) => {

         NtopUtils.check_status_code(status, statusText, null);
         // hide modal if there is error
         $("#modal-script").modal("toggle");
      })
}

/* ******************************************************* */

/**
 * This function return the search criteria for the datatable
 * 'true': apply filter categories criteria only on enabled scripts
 * 'false': apply filter categories criteria only on disabled scripts
 * '': apply filter categories criteria for all scripts
 *
 * @returns {string} 'true'|'false'|''
 */
const get_search_toggle_value = hash => hash == "#enabled" ? 'true' : (hash == "#disabled" ? 'false' : '');

/* ******************************************************* */

const TemplateBuilder = ({ gui, hooks, metadata }, check_subdir, script_key) => {

   // get template name
   const template_name = gui.input_builder;


   const templates = {
      threshold_cross: ThresholdCross(gui, hooks, check_subdir, script_key),
      items_list: ItemsList(gui, hooks, check_subdir, script_key),
      long_lived: LongLived(gui, hooks, check_subdir, script_key),
      elephant_flows: ElephantFlows(gui, hooks, check_subdir, script_key),
      multi_select: MultiSelect(gui, hooks, check_subdir, script_key)
   }

   const isSubdirFlow = (check_subdir === "flow")
   let template_chosen = templates[template_name];
   if (!template_chosen && !(isSubdirFlow)) {
      template_chosen = EmptyTemplate();
      // this message is for the developers
      console.warn("The chosen template doesn't exist yet. See the avaible templates.")
   }
   else if (!template_chosen && (isSubdirFlow)) {
      template_chosen = DefaultTemplate(gui, hooks, check_subdir, script_key);
   }

   // check if the script has an action button
   const hasActionButton = gui.input_action_i18n !== undefined && gui.input_action_url !== undefined;
   if (hasActionButton) {
      $(`.action-button-container`).show();
      delegateActionButton(gui);
   }
   else {
      $(`.action-button-container`).hide();
      $(`#action-error`).hide();
   }

   // restore Apply/Reset button
   $(`#btn-apply,#btn-reset`).show();

   return template_chosen;
}

/* ******************************************************* */

// End templates and template builder

const createScriptStatusButton = (row_data) => {

   const { is_enabled } = row_data;

   const $button = $(`<button type='button' class='btn btn-sm'></button>`);
   $button.addClass('btn-success');

   if (!is_enabled && row_data.input_handler) {
      $button.html(`<i class='fas fa-toggle-on'></i>`);
      $button.attr('data-bs-target', '#modal-script');
      $button.attr('data-bs-toggle', 'modal');
      return $button;
   }

   if (!is_enabled && !row_data.input_handler) {
      $button.html(`<i class='fas fa-toggle-on'></i>`);
   }
   else {

      $button.html(`<i class='fas fa-toggle-off'></i>`);
      $button.addClass('btn-danger');

      if (row_data.enabled_hooks.length < 1) {
         $button.addClass('disabled');
         return $button;
      }
   }

   $button.off('click').on('click', function () {

      $.post(`${http_prefix}/lua/toggle_check.lua`, {
         check_subdir: check_subdir,
         script_key: row_data.key,
         csrf: pageCsrf,
         action: (is_enabled) ? 'disable' : 'enable'
      })
         .done((d, status, xhr) => {

            if (!d.success) {
               $("#alert-row-buttons").text(d.error).removeClass('d-none').show();
            }

            if (d.success) reloadPageAfterPOST();
         })
         .fail(({ status, statusText }) => {
            NtopUtils.check_status_code(status, statusText, $("#alert-row-buttons"));
         })
         .always(() => {
            $button.removeAttr("disabled").removeClass('disabled');
         })
   })

   return $button;
};

function appendExclusionList(data) {
   let ex_list_str = ""
   const scriptConfExList = data.filters;

   if (scriptConfExList) {
      const scriptConfCurrFil = scriptConfExList.current_filters;
      if (scriptConfCurrFil) {
         for (const [index, filters] of Object.entries(scriptConfCurrFil)) {
            for (const [name, value] of Object.entries(filters)) {
               // Concat the string to create a human readable string
               if (name === "str_format") {
                  // Temporary check, needs to be removed in a few time
                  continue;
               }
               // IP only are supported at the moment, just list the values without <name>=
               // as this is more intuitive for the user
               //ex_list_str = ex_list_str + name + "=" + value + ",";
               ex_list_str = ex_list_str + value + ",";
            }

            //ex_list_str = ex_list_str.slice(0, -1);
            //ex_list_str = ex_list_str + "\n";
         }
         if (ex_list_str.length > 0) 
           ex_list_str = ex_list_str.slice(0, -1);
      }
   }

    if ($(`#exclusion-list-template`).length) {
         /* Only show exclusion lists configuration textarea for those entities that support it */
         let $container;
         const $textarea = $($(`#exclusion-list-template`).html());
         const label = i18n.scripts_list.exclusion_list_title;

         if (["elephant_flows", "long_lived", "items_list"].includes(data.gui.input_builder)) {
            $container = $(`<tr></tr>`);
            $container.append($(`<td></td>`), $(`<td></td>`).append($(`<div class='form-row'></div>`).append(
            $(`<label class='col-3 col-form-label'>${label}</label>`),
            $(`<div class='col-12'></div>`).append($textarea))));
         } else {
            $container = $(`<tr><td></td></tr>`);
            $container.append($(`<td class='align-middle'>${label}</td>`), $(`<td></td>`).append($(`<div class='form-row'></div>`).append($textarea)));
         }

         $(`#script-config-editor`).append($container);
         $(`#script-config-editor Textarea[name='exclusion-list']`).val(ex_list_str);
    }
}

function delegateActionButton(gui) {

   const $button = $(`#btn-action`);
   $button.text(gui.input_action_i18n);
   $button.off('click').click(function (e) {

      e.preventDefault();

      if (gui.input_action_confirm && !window.confirm(gui.input_action_i18n_confirm)) {
         return;
      }

      $button.attr("disabled", "disabled");
      const $alert = $(`#action-error`);
      $alert.hide();

      const req = $.post(`${http_prefix}/${gui.input_action_url}`, { csrf: pageCsrf });
      req.then(function ({ rc, rc_str }) {

         // if the return code is zero then everything went alright
         if (rc == 0) {
            $alert.removeClass('alert-danger').addClass('alert-success').html(i18n.rest[rc_str]).show().fadeOut(3000);
            return;
         }
         // otherwise show an error!
         $alert.removeClass('alert-success').addClass('alert-danger').html(i18n.rest[rc_str]).show();
      });
      req.fail(function (jqXHR) {
         if (jqXHR.status == 404) {
            NtopUtils.check_status_code(jqXHR.status, jqXHR.statusText, $alert);
            return;
         }
         const { rc_str } = jqXHR.responseJSON;
         $alert.removeClass('alert-success').addClass('alert-danger').html(i18n.rest[rc_str]).show();
      });
      req.always(function () {
         $button.removeAttr("disabled");
      });
   });
}

function delegateTooltips() {
   $(`span[data-bs-toggle='popover']`).popover({
      trigger: 'manual',
      html: true,
      animation: false,
   })
      .on('mouseenter', function () {
         let self = this;
         $(this).popover("show");
         $(".popover").on('mouseleave', function () {
            $(self).popover('hide');
         });
      })
      .on('mouseleave', function () {
         let self = this;
         setTimeout(function () {
            if (!$('.popover:hover').length) {
               $(self).popover('hide');
            }
         }, 50);
      });
}

$(function () {

   const CATEGORY_COLUMN_INDEX = 1;
   const VALUES_COLUMN_INDEX = 3;

   const add_filter_categories_dropdown = () => {

      const $dropdown = $(`
         <div id='category-filter-menu' class='dropdown d-inline'>
            <button class='btn btn-link dropdown-toggle' data-bs-toggle='dropdown' type='button'>
               <span>${i18n.filter_categories}</span>
            </button>
            <div id='category-filter' class='dropdown-menu'>
            </div>
         </div>
      `);

      $dropdown.find('#category-filter').append(

         scripts_categories.map((c, index) => {

            // list element to append inside the dropdown selector
            const $list_element = $(`<li class='dropdown-item pointer'>${c.label}</li>`);

            // when a user click the filter category then the datatable
            // will be filtered
            $list_element.click(function () {

               // if the category is not inside the array
               // it means the filter category is `All`
               if (c.disableFilter) {
                  $script_table
                     .column(CATEGORY_COLUMN_INDEX).search('')
                     .column(VALUES_COLUMN_INDEX).search(get_search_toggle_value(location.hash))
                     .draw();
                  $dropdown.find('button span').text(`${i18n.filter_categories}`);
                  return;
               }

               $dropdown.find('button span').html(`<i class='fas fa-filter'></i> ${c.label}`);
               $script_table
                  .column(CATEGORY_COLUMN_INDEX).search(c.label)
                  .column(VALUES_COLUMN_INDEX).search(get_search_toggle_value(location.hash))
                  .draw();
            });

            return $list_element;
         })
      );

      $('#scripts-config_filter').prepend($dropdown);

      return $dropdown;
   }

   const hide_categories_dropdown = () => {

      // get current category filter
      const current_category_filter = $script_table.column(CATEGORY_COLUMN_INDEX).search();
      // get alla categories from current datatable instance
      const data_rows = $script_table
         .column(CATEGORY_COLUMN_INDEX)
         .search('')
         .rows({ filter: 'applied' }).data();
      const categories_set = new Set();

      for (let i = 0; i < data_rows.length; i++) {
         categories_set.add(data_rows[i].category_title);
      }

      const enabled_categories = [...categories_set];

      if (enabled_categories.indexOf(current_category_filter) == -1) {

         $('#category-filter-menu button span').text(`${i18n.filter_categories}`);
         $script_table.column(CATEGORY_COLUMN_INDEX).search('').draw();
      }

      $('#category-filter li').each(function (index, element) {

         const value = $(this).text();

         // all filter must be always enabled
         if (scripts_categories.find(e => e.label == value).disableFilter) return;

         // hide category
         if (enabled_categories.indexOf(value) == -1) {
            $(this).hide();
            return;
         }

         $(this).show();

      });

   }

   const truncate_string = (str, lim, strip_html = false) => {

      if (strip_html) {
         let str_sub = str.replace(/(<([^>]+)>)/ig, "");
         return (str_sub.length > lim) ? str_sub.substr(0, lim) + '...' : str_sub;
      }

      return (str.length > lim) ? str.substr(0, lim) + '...' : str;
   }

   // initialize script table
   const $script_table = $("#scripts-config").DataTable({
      dom: "Bfrtip",
      pagingType: 'full_numbers',
      language: {
         info: i18n.showing_x_to_y_rows,
         search: i18n.script_search,
         infoFiltered: "",
         paginate: {
            previous: '&lt;',
            next: '&gt;',
            first: '«',
            last: '»'
         }
      },
      lengthChange: false,
      ajax: {
         url: `${http_prefix}/lua/get_checks.lua?check_subdir=${check_subdir}`,
         type: 'get',
         dataSrc: ''
      },
      stateSave: true,
      initComplete: function (settings, json) {

         // add categories dropdown
         const $categories_filter = add_filter_categories_dropdown();

         // check if there is a previous filter
         if (settings.oLoadedState != null) {
            const loaded_filter = settings.oLoadedState.columns[CATEGORY_COLUMN_INDEX].search.search;
            if (loaded_filter != "") $categories_filter.find('button span').html(`<i class='fas fa-filter'></i> ${loaded_filter}`);
         }

         const [enabled_count, disabled_count] = count_scripts();
         // enable the disable all button if there are more than one enabled scripts
         if (enabled_count > 0) $(`#btn-disable-all`).removeAttr('disabled');

         // clean searchbox
         $(".dataTables_filter").find("input[type='search']").val('').trigger('keyup');

         // hide category in base selected pill
         hide_categories_dropdown();
         $('#all-scripts,#enabled-scripts,#disabled-scripts').click(function () {
            hide_categories_dropdown();
         });

         delegateTooltips();

         // update the tabs counters
         const INDEX_SEARCH_COLUMN = 3;

         const $disabled_button = $(`#disabled-scripts`);
         const $all_button = $("#all-scripts");
         const $enabled_button = $(`#enabled-scripts`);

         $all_button.html(`${i18n.all} (${enabled_count + disabled_count})`)
         $enabled_button.html(`${i18n.enabled} (${enabled_count})`);
         $disabled_button.html(`${i18n.disabled} (${disabled_count})`);

         const filterButonEvent = ($button, searchValue, tab) => {
            $('.filter-scripts-button').removeClass('active');
            $button.addClass('active');
            this.DataTable().columns(INDEX_SEARCH_COLUMN).search(searchValue).draw();
            window.history.replaceState(undefined, undefined, tab);
            delegateTooltips();
         }

         $all_button.click(function () {
            filterButonEvent($(this), "", "#all");
         });
         $enabled_button.click(function () {
            filterButonEvent($(this), "true", "#enabled");
         });
         $disabled_button.click(function () {
            filterButonEvent($(this), "false", "#disabled");
         });

         // select the correct tab
         select_script_filter(enabled_count);

         if (script_search_filter) {
            this.DataTable().columns(INDEX_SEARCH_COLUMN).search("").draw(true);
            this.DataTable().search(script_search_filter).draw(true);
            // disable the search box
            $(`#scripts-config_filter input[type='search']`).attr("readonly", "");
         }

         if (script_key_filter) {
            let elem = json.filter((x) => { return (x.key == script_key_filter); })[0];

            if (elem) {
               let title = elem.title;
               let desc = elem.description;
               this.DataTable().search(title).draw();

               if (hasConfigDialog(elem)) {
                  initScriptConfModal(script_key_filter, title, desc);
                  $("#modal-script").modal("show");
               }
            }
         }
      },
      order: [[0, "asc"]],
      buttons: {
         buttons: [
            {
               text: '<i class="fas fa-sync"></i>',
               className: 'btn-link',
               action: function (e, dt, node, config) {
                  $script_table.ajax.reload(function () {
                     const [enabled_count, disabled_count] = count_scripts();
                     // enable the disable all button if there are more than one enabled scripts
                     if (enabled_count > 0) $(`#btn-disable-all`).removeAttr('disabled');
                     $("#all-scripts").html(`${i18n.all} (${enabled_count + disabled_count})`)
                     $(`#enabled-scripts`).html(`${i18n.enabled} (${enabled_count})`);
                     $(`#disabled-scripts`).html(`${i18n.disabled} (${disabled_count})`);
                  }, false);
               }
            }
         ],
         dom: {
            button: {
               className: 'btn btn-link'
            },
            container: {
               className: 'border-start ms-1 float-end'
            }
         }
      },
      columns: [
         {
            data: 'title',
            render: function (data, type, row) {
               if (type == 'display') return `<b>${data}</b>`;
               return data;
            },
         },
         {
            data: null,
            sortable: true,
            searchable: true,
            className: 'text-center',
            render: function (data, type, row) {
               const icon = (!row.category_icon) ? '' : `<i class='fa ${row.category_icon}'></i>`;
               if (type == "display") return `${icon}`;
               return row.category_title;
            }
         },
         {
            data: 'description',
            render: function (data, type, row) {

               if (type == "display") {

                  return `<span
                           ${data.length >= 120 ? `data-bs-toggle='popover'  data-placement='top' data-html='true' title="${row.title}" data-bs-content="${data}"` : ``}
                           data-content="${data}" >
                              ${truncate_string(data, 120, true)}
                           </span>`;
               }

               return data;

            },
         },
         {
            data: 'enabled_hooks',
            sortable: false,
            className: 'text-start',
            render: function (data, type, row) {

               // if the type is flter return true if the data length is greather or equal
               // than 0 so the script table can detect if a plugin is enabled
               if (data.length <= 0 && type == "filter") return false;
               if (data.length > 0 && type == "filter") return true;

               return (type == 'display') ? `
                  <span
                     title="${i18n.values}"
                     ${row.value_description.length >= 32 ? `data-bs-toggle='popover'  data-placement='top'` : ``}
                     data-content='${row.value_description}'>
                     ${row.value_description.substr(0, 32)}${row.value_description.length >= 32 ? '...' : ''}
                  </span>
               ` : '';

            },
         },
         {
            targets: -1,
            data: null,
            name: 'actions',
            className: 'text-center',
            sortable: false,
            width: 'auto',
            render: function (data, type, script) {

               const isScriptEnabled = script.is_enabled;
               const isSubdirFlow = (check_subdir === "flow");
               const srcCodeButtonEnabled = data.edit_url && isScriptEnabled ? '' : 'disabled';
               const editScriptButtonEnabled = ((!script.input_handler && !isSubdirFlow) || !isScriptEnabled) ? 'disabled' : '';

               return DataTableUtils.createActionButtons([
                  { class: `btn-info ${editScriptButtonEnabled}`, modal: '#modal-script', icon: 'fa-edit' },
                  { class: `btn-secondary ${srcCodeButtonEnabled}`, icon: 'fa-file-code', href: data.edit_url }
               ]);
            },
            createdCell: function (td, cellData, row) {

               const $enableButton = createScriptStatusButton(row);
               $(td).find('div').prepend($enableButton);
            }
         }
      ]
   });

   // initialize are you sure
   $("#edit-form").areYouSure({ message: i18n.are_you_sure });

   // handle modal-script close event
   $("#modal-script").on("hide.bs.modal", function (e) {

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
      .on("shown.bs.modal", function (e) {
         // add focus to btn apply to enable focusing on the modal hence user can press escape button to
         // close the modal
         $("#btn-apply").trigger('focus');
      });

   // load templates for the script
   $('#scripts-config').on('click', '[href="#modal-script"],[data-bs-target="#modal-script"]', function (e) {

      const row_data = $script_table.row($(this).parent().parent()).data();
      const script_key = row_data.key;
      const script_title = row_data.title;
      const script_desc = row_data.description;

      initScriptConfModal(script_key, script_title, script_desc);
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

   $(`.filter-scripts-button`).click(function () {
      $(`#scripts-config a[href^='/lua/code_viewer.lua']`).each(function () {
         const encoded = encodeURIComponent(`${location.pathname}${location.search}${location.hash}`);
         $(this).attr('href', `${$(this).attr('href')}&referal_url=${encoded}`);
      });
   });

   $(`#disable-all-modal #btn-confirm-action`).click(async function () {

      $(this).attr("disabled", "disabled");
      $.post(`${http_prefix}/lua/toggle_all_checks.lua`, {
         action: 'disable',
         check_subdir: check_subdir,
         csrf: pageCsrf
      })
         .then((result) => {
            if (result.success) location.reload();
         })
         .catch((error) => {
            console.error(error);
         })
         .always(() => {
            $(`#btn-disable-all`).removeAttr("disabled");
         })
   })

});
