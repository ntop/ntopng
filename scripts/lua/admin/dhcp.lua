--
-- (C) 2017-18 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local dhcp_utils = require("dhcp_utils")
local template = require("template_utils")

-- Administrator check
if not isAdministrator() then
  return
end

if _POST["dhcp_ranges"] then
  dhcp_utils.setRanges(ifid, _POST["dhcp_ranges"])
end

print(
  template.gen("modal_confirm_dialog.html", {
    dialog={
      id      = "delete_dhcp_range_dialog",
      action  = "deleteDhcpRange()",
      title   = i18n("dhcp.delete_range"),
      message = i18n("dhcp.delete_range_confirm", {range="<span id=\"range-to-delete\"></span>"}),
      confirm = i18n("delete"),
    }
  })
)

print[[
<form id="table-manage-form">
  <div id="table-manage"></div>
  <button class="btn btn-primary" style="float:right; margin-right:1em;" disabled="disabled" type="submit">]] print(i18n("save_settings")) print[[</button>
</form>
<br><br>

<script>
  var range_to_delete;

  $("#table-manage").datatable({
      url: "]]
   print (ntop.getHttpPrefix())
   print [[/lua/get_dhcp_config.lua?ifid=]] print(tostring(ifid)) print[[",
      title: "",
      forceTable: true,
      hidePerPage: true,
      perPage: 8, // TODO
      buttons: [
         '<a id="addRangeBtn" onclick="addDhcpRow()" role="button" class="add-on btn" data-toggle="modal"><i class="fa fa-plus" aria-hidden="true"></i></a>'
      ], columns: [
         {
            title: "]] print(i18n("nedge.dhcp_first_ip")) print[[",
            field: "column_first_ip",
            css: {
               textAlign: 'left',
            }
         }, {
            title: "]] print(i18n("nedge.dhcp_last_ip")) print[[",
            field: "column_last_ip",
            css : {
               textAlign: 'left',
            }
         }, {
            title: "]] print(i18n("actions")) print[[",
            css : {
               width: '15%',
               textAlign: 'center',
            }
         }
      ], tableCallback: function() {
        var pools_ctr = 0;

        if(datatableIsEmpty("#table-manage")) {
          datatableAddEmptyRow("#table-manage", "]] print(i18n("dhcp.no_dhcp_ranges")) print[[");
        } else {
          datatableForEachRow("#table-manage", function() {
            addInputFields($(this));

            datatableAddDeleteButtonCallback.bind(this)(3, "range_to_delete = " + $(this).index() +"; $('#range-to-delete').html(rowIndexToRange('" + $(this).index() + "')); $('#delete_dhcp_range_dialog').modal('show');", "]] print(i18n('delete')) print[[");
          });
        }

        aysResetForm('#table-manage-form');
      }
    });

  var dhcp_row_id = 0;
  var input_id = 0;

  function onRowAddUndo() {
    return true;
  }

  function addInputField(td, value) {
    var name = "input_id_" + input_id;
    input_id++;

    var input = $("<input class='form-control' required>")
      .attr("name", name)
      .attr("value", value);

    td.html(input);
  }

  function addInputFields(row) {
    var first_ip = row.find("td:eq(0)");
    var last_ip = row.find("td:eq(1)");

    addInputField(first_ip, first_ip.html());
    addInputField(last_ip, last_ip.html());
  }

  function addDhcpRow() {
    if($("#addRangeBtn").attr("disabled"))
      return;

    var newid = "dhcp_row_" + dhcp_row_id;
    dhcp_row_id++;

    if(datatableIsEmpty("#table-manage"))
      datatableRemoveEmptyRow("#table-manage");

    var tr = $('<tr id="'+ newid +'"><td></td><td></td><td class="text-center"></td></tr>');
    addInputFields(tr);

    datatableAddDeleteButtonCallback.bind(tr)(3, "datatableUndoAddRow('#" + newid + "', ']] print(i18n("host_pools.no_pools_defined")) print[[', '#addRangeBtn', 'onRowAddUndo')", "]] print(i18n('undo')) print[[");
    $("#table-manage table").append(tr);
    $("input:first", tr).focus();

    aysRecheckForm("#table-manage-form");
  }

  function rowToRange(row) {
    var first_ip = row.find("td:eq(0) input").val();
    var last_ip = row.find("td:eq(1) input").val();

    return first_ip + "-" + last_ip;
  }

  function rowIndexToRange(row_idx) {
    var row = $("#table-manage tr:eq(" + (parseInt(row_idx)+1) +")");
    return rowToRange(row);
  }

  function deleteDhcpRange() {
    var row = $("#table-manage tr:eq(" + (parseInt(range_to_delete)+1) +")");
    row.attr("data-skip", "true");

    submitDhcpRanges();
  }

  function submitDhcpRanges() {
    var form = $("#table-manage-form");
    var dhcp_ranges = [];

    datatableForEachRow("#table-manage", function() {
      var row = $(this);

      if(!row.attr("data-skip"))
        dhcp_ranges.push(rowToRange(row));
    });

    var params = {};
    params.dhcp_ranges = dhcp_ranges.join(",");
    params.csrf = "]] print(ntop.getRandomCSRFValue()) print[[";
    paramsToForm('<form method="post"></form>', params).appendTo('body').submit();
  }

  aysHandleForm("#table-manage-form", {
    handle_datatable: true,
    ays_options: {addRemoveFieldsMarksDirty: true}
  });

  $("#table-manage-form").submit(function(event) {
    if (event.isDefaultPrevented())
      return false;

    submitDhcpRanges();

    return false;
  });
</script>

]] print(i18n("notes")) print[[
  <ul>
    <li>]] print(i18n("dhcp.dhcp_configuration_note")) print[[.</li>
  </ul>
]]
