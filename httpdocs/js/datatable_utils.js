// 2016 - ntop.org

function datatableRemoveEmptyRow(table) {
  $("tbody tr.emptyRow", $(table)).remove();
}

function datatableAddEmptyRow(table, empty_str) {
  var columns = $("thead th", $(table)).filter(function() {
   return $(this).css('display') != 'none';
  }).length;
  $("tbody", $(table)).html('<tr class="emptyRow"><td colspan="' + columns + '"><i>' + empty_str + '</i></td></tr>');
}

function datatableGetNumDisplayedItems(table) {
   return $("tr:not(.emptyRow)", $(table)).length - 1;
}

function datatableIsEmpty(table) {
  return datatableGetNumDisplayedItems(table) == 0;
}

function datatableGetByForm(form) {
  return $("table", $("#dt-top-details", $(form)).parent())
}

function datatableUndoAddRow(new_row, empty_str, bt_to_enable, callback_str) {
  if (bt_to_enable)
     $(bt_to_enable).removeAttr("disabled");

  var form = $(new_row).closest("form");
  $(new_row).remove();
  aysUpdateForm(form);
  var dt = datatableGetByForm(form);

  if (datatableIsEmpty(dt))
     datatableAddEmptyRow(dt, empty_str);

   if (callback_str)
      // invoke
      window[callback_str](new_row);
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

function datatableAddButtonCallback(td_idx, label, bs_class, callback_str, link) {
   $("td:nth-child("+td_idx+")", $(this)).append('<a href="' + link + '" class="add-on btn" style="padding:0.2em;" onclick="' + callback_str + '" role="button"><span class="label ' + bs_class + '">' + label + '</span></a>');
}

function datatableAddDeleteButtonCallback(td_idx, callback_str, label) {
   datatableAddButtonCallback.bind(this)(td_idx, label, "label-danger", callback_str, "javascript:void(0)");
}

function datatableAddActionButtonCallback(td_idx, callback_str, label) {
   datatableAddButtonCallback.bind(this)(td_idx, label, "label-info", callback_str, "javascript:void(0)");
}

function datatableAddLinkButtonCallback(td_idx, link, label) {
   datatableAddButtonCallback.bind(this)(td_idx, label, "label-info", "", link);
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

function datatableOrderedInsert(table, td_idx, to_insert, to_insert_val, cmp_fn) {
   var cmp_fn = cmp_fn || function(a, b) { return b - a; };
   var inserted = false;

   datatableForEachRow(table, function() {
      if(inserted) return;

      var tr = $(this);
      var cmp_val = parseInt($("td:nth-child(" + td_idx + ")", tr).html());

      if ((! isNaN(cmp_val)) && (cmp_fn(cmp_val, to_insert_val) < 0)) {
         tr.before(to_insert);
         inserted = true;
      }
   });

   if (! inserted)
      // default: append
      $(table).append(to_insert);
}

function datatableIsLastPage(table) {
   var lastpage = $("#dt-bottom-details .pagination li:nth-last-child(3)", $(table));
   return !((lastpage.length == 1) && (lastpage.hasClass("active") == false));
}

function datatableGetColumn(table, id_key, id_value) {
   var res = table.data("datatable").resultset.data.filter(function(item) {
      return item[id_key] === id_value;
   });

   if(res) return res[0];
}

function datatableGetColumnIndex(table, column_key) {
   var index = table.data("datatable").options.columns.findIndex(function(item) {
      return item.field === column_key;
   });

   return(index);
}

/* Helper function for refreshable datatables rows.
 *
 * table: the datatable div jquery object
 * column_id: the field key used to indentify the rows
 * first_load: if true, the existing datatable data will be processed.
  */
function datatableRefreshRows(table, column_id, first_load) {
  var $dt = table.data("datatable");
  var rows = $dt.resultset.data;
  var ids = [];
  var id_to_row = {};

  for(var row in rows) {
      var data = rows[row];

      if(data[column_id]) {
         var data_id = data[column_id];
         id_to_row[data_id] = row;
         ids.push(data_id);
    }
  }

  if(ids) {
   var url = $dt.options.url;
   var params = {
      "custom_hosts": ids.join(",")
   };

   var _process_result = function(result) {
      for(var row in result.data) {
         var data = result.data[row];
         var data_id = data[column_id];

         if(data_id && id_to_row[data_id]) {
            var row_idx = id_to_row[data_id];
            var row_html = $dt.rows[row_idx];
            var row_tds = $("td", row_html);

            for(var key in data) {
               var col_idx = datatableGetColumnIndex(table, key);
               var cell = row_tds[col_idx];
               var $cell = $(cell);
               var old_val = $cell.data("trend-cur-val") || $(cell).html();
               var new_val = data[key];
               var arrows = "";

               /* Automatically add up/down trend arrows as long as the original data is a number */
               if(!isNaN(old_val) && !isNaN(new_val)) {
                  /* This is a number */
                  if(!first_load)
                     arrows = " " + drawTrend(parseInt(new_val), parseInt(old_val));

                  /* Rember that this is a number for future invocations */
                  $cell.data("trend-cur-val", new_val);

                  new_val = addCommas(new_val);
               }

               $(cell).html((new_val != 0) ? (new_val + arrows) : "");
            }
         }
      }
   };

   if(first_load)
      _process_result($dt.resultset);
   else {
      $.ajax({
         type: 'GET',
         url: url,
         data: params,
         cache: false,
         success: _process_result,
      });
   }
 }
}
