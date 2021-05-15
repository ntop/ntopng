--
-- (C) 2017-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local dhcp_utils = require("dhcp_utils")
local ui_utils = require("ui_utils")
local template = require("template_utils")

-- Administrator check
if not isAdministrator() then
  return
end

if _POST["dhcp_ranges"] and _POST["old_dhcp_ranges"] then
  dhcp_utils.editRanges(ifid, _POST["old_dhcp_ranges"], _POST["dhcp_ranges"])
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
<H3>]] print(i18n("dhcp.dhcp")) print[[</H3>

<form id="table-dhcp-form" method="post" data-bs-toggle="validator">
  <div id="table-dhcp"></div>
  <div class='text-end'>
    <button id="dhcp-save" class="btn btn-primary mb-1" onclick="if($(this).hasClass('disabled')) return false;" type="submit">]] print(i18n("save_settings")) print[[</button>
  </div>
</form>

<script>
  var range_to_delete;

  $("#table-dhcp").datatable({
      url: "]]
   print (ntop.getHttpPrefix())
   print [[/lua/get_dhcp_config.lua?ifid=]] print(tostring(ifid)) print[[",
      title: "",
      forceTable: true,
      buttons: [
         '<a id="addRangeBtn" onclick="addDhcpRow()" role="button" class="add-on btn" data-bs-toggle="modal"><i class="fas fa-plus" aria-hidden="true"></i></a>'
      ], columns: [
         {
            title: "]] print(i18n("nedge.dhcp_first_ip")) print[[",
            field: "column_first_ip",
            sortable: true,
            css: {
               textAlign: 'left',
            }
         }, {
            title: "]] print(i18n("nedge.dhcp_last_ip")) print[[",
            field: "column_last_ip",
            sortable: true,
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

        if(datatableIsEmpty("#table-dhcp")) {
          datatableAddEmptyRow("#table-dhcp", "]] print(i18n("dhcp.no_dhcp_ranges")) print[[");
        } else {
          datatableForEachRow("#table-dhcp", function() {
            addInputFields($(this));

            datatableAddDeleteButtonCallback.bind(this)(3, "range_to_delete = " + $(this).index() +"; $('#range-to-delete').html(rowIndexToRange('" + $(this).index() + "')); $('#delete_dhcp_range_dialog').modal('show');", "<i class='fas fa-trash'></i>");
          });
        }

        aysResetForm('#table-dhcp-form');
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

    var container = $("<div class='form-group mb-3 has-feedback' style='margin-bottom:0'></div>");

    var input = $("<input class='form-control' data-ipaddress='ipaddress' required>")
      .attr("name", name)
      .attr("value", value)
      .attr("data-orig-value", value)
      .appendTo(container);

    td.html(container);
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

    if(datatableIsEmpty("#table-dhcp"))
      datatableRemoveEmptyRow("#table-dhcp");

    var tr = $('<tr id="'+ newid +'"><td></td><td></td><td class="text-center"></td></tr>');
    addInputFields(tr);

    datatableAddDeleteButtonCallback.bind(tr)(3, "datatableUndoAddRow('#" + newid + "', ']] print(i18n("host_pools.no_pools_defined")) print[[', '#addRangeBtn', 'onRowAddUndo')", "<i class='fas fa-undo'></i>");
    $("#table-dhcp table").append(tr);
    $("input:first", tr).focus();

    aysRecheckForm("#table-dhcp-form");
  }

  function rowToRange(row) {
    var first_ip = row.find("td:eq(0) input").val();
    var last_ip = row.find("td:eq(1) input").val();

    return first_ip + "-" + last_ip;
  }

  function rowToOrigRange(row) {
    var first_ip = row.find("td:eq(0) input").attr("data-orig-value");
    var last_ip = row.find("td:eq(1) input").attr("data-orig-value");

    return first_ip + "-" + last_ip;
  }

  function rowIndexToRange(row_idx) {
    var row = $("#table-dhcp tr:eq(" + (parseInt(row_idx)+1) +")");
    return rowToRange(row);
  }

  function deleteDhcpRange() {
    var row = $("#table-dhcp tr:eq(" + (parseInt(range_to_delete)+1) +")");
    row.attr("data-skip", "true");

    submitDhcpRanges();
  }

  function submitDhcpRanges() {
    var form = $("#table-dhcp-form");
    var dhcp_ranges = [];
    var old_dhcp_ranges = [];

    datatableForEachRow("#table-dhcp", function() {
      var row = $(this);

      var old_range = rowToOrigRange(row);
      if(old_range != "-")
        old_dhcp_ranges.push(old_range);

      if(!row.attr("data-skip"))
        dhcp_ranges.push(rowToRange(row));
    });

    // Reset the form to avoid form change messages
    aysResetForm('#table-dhcp-form');

    var params = {};
    params.old_dhcp_ranges = old_dhcp_ranges.join(",");
    params.dhcp_ranges = dhcp_ranges.join(",");
    params.csrf = "]] print(ntop.getRandomCSRFValue()) print[[";
    NtopUtils.paramsToForm('<form method="post"></form>', params).appendTo('body').submit();
  }

  aysHandleForm("#table-dhcp-form", {
    handle_datatable: true,
    ays_options: {addRemoveFieldsMarksDirty: true}
  });

  $("#table-dhcp-form").submit(function(event) {
    if (event.isDefaultPrevented() || $("#dhcp-save").hasClass("disabled"))
      return false;

    submitDhcpRanges();

    return false;
  });

  var validator_options = {
    custom: {
      ipaddress: ipAddressValidator,
    }, errors: {
      ipaddress: "]] print(i18n("dhcp.invalid_ip_address")) print[[.",
    }
  }

  $("#table-dhcp-form")
    .validator(validator_options)
</script>

]]

local notes = {
  {content = i18n("dhcp.dhcp_configuration_note")},
  {content = i18n("dhcp.dhcp_alert_note")},
}
print("<div class='my-2'></div>")
print(ui_utils.render_notes(notes))
