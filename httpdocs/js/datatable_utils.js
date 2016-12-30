// 2016 - ntop.org

function datatableRemoveEmptyRow(table) {
  $("tbody tr.emptyRow", $(table)).remove();
}

function datatableAddEmptyRow(table, empty_str) {
  $("tbody", $(table)).html('<tr class="emptyRow"><td colspan="3"><i>' + empty_str + '</i></td></tr>');
}

function datatableIsEmpty(table) {
  return $("tr:not(.emptyRow)", $(table)).length == 1;
}

function datatableGetByForm(form) {
  return $("table", $("#dt-top-details", $(form)).parent())
}

function datatableUndoAddRow(new_row, empty_str, bt_to_enable) {
  if (bt_to_enable)
     $(bt_to_enable).removeAttr("disabled");

  var form = $(new_row).closest("form");
  $(new_row).remove();
  aysUpdateForm(form);
  var dt = datatableGetByForm(form);

  if (datatableIsEmpty(dt))
     datatableAddEmptyRow(dt, empty_str);
}

function datatableForEachRow(table, callbacks) {
   $("tr:not(:first)", table).each(function(row_i) {
      if(typeof callbacks === 'function') {
         callbacks.bind(this)(row_i);
      } else {
         var i;
         for (i=0; i<callbacks.length; i++)
            callbacks[i].bind(this)(row_i);
      }
   });
}

function datatableAddDeleteButtonCallback(td_idx, callback_str, label) {
   $("td:nth-child("+td_idx+")", $(this)).html('<a href="javascript:void(0)" class="add-on" onclick="' + callback_str + '" role="button"><span class="label label-danger">' + label + '</span></a>');
}

function datatableMakeSelectUnique(tr_obj, added_rows_prefix, options) {
   options = paramsExtend({
      on_change: $.noop,                     /* A callback to be called when the select input changes */
      selector_fn: function(obj) {           /* A callback which receives a tr object and returns a single select input */
         return obj.find("select").first();
      },
   }, options);

   function datatableForeachSelectOtherThan(this_select, added_rows_prefix, selector_fn, callback) {
      $("[id^=" + added_rows_prefix + "]").each(function(){
         var other = selector_fn($(this));
         if (other[0] != this_select[0])
            callback(other);
      });
   }

   function datatableOptionChangeStatus(option_obj, enable) {
      if (enable) {
         option_obj.removeAttr("disabled");
      } else {
         var select_obj = option_obj.closest("select");
         var should_reset = (select_obj.val() == option_obj.val());
         option_obj.attr("disabled", "disabled");

         if(should_reset) {
            var new_val = select_obj.find("option:not([disabled])").first().val();
            select_obj.val(new_val);
            select_obj.attr("data-old-val", new_val);
         }
      }
   }

   function datatableOnSelectEntryChange(added_rows_prefix, selector_fn, change_callback) {
      var old_value = $(this).attr("data-old-val") || "";
      var new_value = $(this).val() || "";
      var others = [];

      if (old_value == new_value)
         old_value = "";

      datatableForeachSelectOtherThan($(this), added_rows_prefix, selector_fn, function(other) {
         datatableOptionChangeStatus(other.find("option[value='" + old_value + "']"), true);
         datatableOptionChangeStatus(other.find("option[value='" + new_value + "']"), false);
         others.push(other);
      });

      change_callback($(this), old_value, new_value, others, datatableOptionChangeStatus);

      $(this).attr("data-old-val", new_value);
   }

   function datatableOnAddSelectEntry(select_obj, added_rows_prefix, selector_fn) {
      select_obj.val("");

      // Trigger an update on other inputs in order to disable entries on the select_obj
      datatableForeachSelectOtherThan(select_obj, added_rows_prefix, selector_fn, function(other) {
         //datatableOptionChangeStatus(select_obj.find("option[value='" + other.val() + "']"), false);
         other.trigger("change");
      });

      // select first available entry
      var new_sel = select_obj.find("option:not([disabled])").first();
      var new_val = new_sel.val();

      // trigger change event to update other entries
      select_obj.val(new_val);
      select_obj.trigger("change");
   }

   var select = options.selector_fn(tr_obj);
   select.on("change", function() { datatableOnSelectEntryChange.bind(this)(added_rows_prefix, options.selector_fn, options.on_change); });
   select.on("remove", function() {$(this).val("").trigger("change")});
   datatableOnAddSelectEntry(select, added_rows_prefix, options.selector_fn);
}
