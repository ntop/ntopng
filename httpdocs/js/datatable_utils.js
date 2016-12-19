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
