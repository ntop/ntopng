--
-- (C) 2013-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local page_utils = require("page_utils")
local alert_consts = require("alert_consts")
local rtt_utils = require("rtt_utils")
local plugins_utils = require("plugins_utils")
local template = require("template_utils")
require("graph_utils")
require("alert_utils")

local ts_creation = plugins_utils.timeseriesCreationEnabled()

if not isAllowedSystemInterface() then
   return
end

sendHTTPContentTypeHeader('text/html')

page_utils.set_active_menu_entry(page_utils.menu_entries.rtt_monitor)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

local page = _GET["page"] or "overview"
local host = _GET["rtt_host"]
local url = plugins_utils.getUrl("rtt_stats.lua") .. "?ifid=" .. getInterfaceId(ifname)

if not isEmptyString(host) then
  url = url .. "&rtt_host=" .. host
end

local title = i18n("graphs.rtt")

if host ~= nil then
   title = title..": " .. rtt_utils.key2label(host)
end

page_utils.print_navbar(title, url,
			{
			   {
			      active = page == "overview" or not page,
			      page_name = "overview",
			      label = "<i class=\"fas fa-lg fa-home\"></i>",
			   },
			   {
			      hidden = not host or not ts_creation,
			      active = page == "historical",
			      page_name = "historical",
			      label = "<i class='fas fa-lg fa-chart-area'></i>",
			   },
			   {
			      hidden = not isAdministrator() or not plugins_utils.hasAlerts(getSystemInterfaceId(), {entity = alert_consts.alertEntity("pinged_host")}),
			      active = page == "alerts",
			      page_name = "alerts",
			      label = "<i class=\"fas fa-lg fa-exclamation-triangle\"></i>",
			   },
			}
)

-- #######################################################

if(page == "overview") then
  if isAdministrator() then
    if(_POST["rtt_hosts"] ~= nil) then
      local rtt_hosts_args = string.split(_POST["rtt_hosts"], ",") or {_POST["rtt_hosts"]}
      local rtt_hosts = {}

      -- process arguments
      for _, host_line in pairs(rtt_hosts_args) do
	local parts = string.split(host_line, "|")
	local key = table.remove(parts, 1)
	local old_host = table.remove(parts, 1)
	local value = table.concat(parts, "|")

	rtt_hosts[key] = {old_host, value}
      end

      -- Delete changed
      for host, value in pairs(rtt_hosts) do
	local old_host = value[1]

	if((not isEmptyString(old_host)) and (host ~= old_host)) then
	  rtt_utils.removeHost(old_host)
	end
      end

      -- Add new
      for host, value in pairs(rtt_hosts) do
	local conf = value[2]

	rtt_utils.addHost(host, conf)
      end
    elseif((_POST["action"] == "delete") and (_POST["rtt_host"] ~= nil)) then
      rtt_utils.removeHost(_POST["rtt_host"])
    end
  end

  print(
    template.gen("modal_confirm_dialog.html", {
      dialog={
	id      = "delete_host_dialog",
	action  = "deleteRttHost()",
	title   = i18n("system_stats.delete_rtt_host"),
	message = i18n("system_stats.delete_rtt_confirm", {host="<span id=\"host-to-delete\"></span>"}),
	confirm = i18n("delete"),
      }
    })
  )

  print[[
<form id="table-hosts-form" method="post" data-toggle="validator">
  <div id="table-hosts"></div>
  <button id="hosts-save" class="btn btn-primary" style="float:right; margin-right:1em; margin-left: auto" onclick="if($(this).hasClass('disabled')) return false;" type="submit">]] print(i18n("save_settings")) print[[</button>
</form>
<br><br>

	 <script>
    var key_field_idx = 9;
    var action_field_idx = 9;

	 $("#table-hosts").datatable({
	 	url: "]]
  print (getPageUrl(plugins_utils.getUrl("get_rtt_hosts.lua"), {rtt_host = host}))
      print[[",
      title: "",
      forceTable: true,
      buttons: [
      ]]
      if isAdministrator() then
	print[['<a id="addRowBtn" onclick="addRow()" role="button" class="add-on btn" data-toggle="modal"><i class="fas fa-plus" aria-hidden="true"></i></a>']]
      end
      print[[
      ],
		showPagination: true,]]

      local preference = tablePreferences("rows_number", _GET["perPage"])
      if (preference ~= "") then print ('perPage: '..preference.. ",\n") end

    print[[
	columns: [
	{
	  title: "]] print(i18n("traffic_profiles.host_traffic")) print[[",
	  field: "column_host",
	  sortable: true,
	  css: {

	    width: "20%",
	  }
	}, {
	  title: "]] print(i18n("chart")) print[[",
	  field: "column_chart",
	  hidden: ]] if not ts_creation then print("true") else print("false") end print[[,
	  sortable: false,
	  css: {
	    textAlign: 'center',
	    width: "5%",
	  }
	}, {
	  title: "]] print(i18n("flows_page.ip_version")) print[[",
	  field: "column_iptype",
	  sortable: true,
	  css: {
	    textAlign: 'center',
	    width: "10%",
	  }
	}, {
	  title: "]] print(i18n("system_stats.probe")) print[[",
	  field: "column_probetype",
	  sortable: true,
	  css: {
	    textAlign: 'center',
	    width: "10%",
	  }
	}, {
	  title: "]] print(i18n("system_stats.max_rtt")) print[[",
	  field: "column_max_rrt",
	  sortable: true,
	  css: {
	    textAlign: 'center',

	  }
	}, {
	  title: "]] print(i18n("system_stats.last_rtt")) print[[",
	  field: "column_last_rrt",
	  sortable: true,
	  css: {
	    textAlign: 'center',
	    width: "10%",
	  }
	}, {
	  title: "]] print(i18n("system_stats.last_ip")) print[[",
	  field: "column_last_ip",
	  sortable: true,
	  css: {
	    textAlign: 'center',
	    width: "10%",
	  }
	}, {
	  title: "]] print(i18n("category_lists.last_update")) print[[",
	  field: "column_last_update",
	  sortable: true,
	  css: {
	    textAlign: 'center',
	    width: "10%",
	  }
	}, {
	  title: "]] print(i18n("actions")) print[[",
	  field: "column_actions",
	  hidden: ]] print(tostring(not isAdministrator())) print[[,
	  css: {
	    textAlign: 'center',
	    width: "10%",
	  }
	}, {
	  field: "column_key",
	  hidden: true,
	}
		],
    tableCallback: function() {
	if(datatableIsEmpty("#table-hosts")) {
	  datatableAddEmptyRow("#table-hosts", "]] print(i18n("system_stats.no_hosts_configured")) print[[");
	} else {
	  datatableForEachRow("#table-hosts", function() {
	    var host = $(this).find("td:eq(0)").html();
	    var key = $(this).find("td:eq("+ key_field_idx +")").html();
	    addInputFields($(this));

	    datatableAddDeleteButtonCallback.bind(this)(action_field_idx, "elem_to_delete = '" + key + "'; $('#host-to-delete').html('" + host + "'); $('#delete_host_dialog').modal('show');", "]] print(i18n('delete')) print[[");
	  });
	}

	aysResetForm('#table-hosts-form');
      }
  });

  var rtt_row_id = 0;
  var input_id = 0;
  var elem_to_delete = null;

  function addInputField(td, value, other_html) {
    var name = "rtt_input_id_" + input_id;
    input_id++;

    var container = $("<div class='form-group has-feedback' style='margin-bottom:0'></div>");

    var input = $("<input class='form-control' " + (other_html || "") + "required>")
      .attr("name", name)
      .attr("value", value)
      .appendTo(container);

    td.html(container);
  }

  function addSelectField(td, value, arr, other_html, other_classes) {
    var name = "rtt_input_id_" + input_id;
    input_id++;

    var sel = $("<select class='form-control " + (other_classes ? other_classes : "") + "' " + (other_html || "") + ">")
      .attr("name", name);
    td.html(sel);

    $(arr).each(function() {
      sel.append($("<option>").attr('value',this.val)
	.text(this.text)
	.prop('selected', this.val == value));
    });
  }

  function checkIPVersionEnabled(row) {
/*
    var iptype = row.find("td:eq(2) select");
    var probetype = row.find("td:eq(3) select").val();

    if(probetype == "icmp")
      iptype.removeAttr("disabled");
    else
      iptype.attr("disabled", "disabled");
*/

    // always enabled for now
  }

  function addInputFields(row) {
    var host = row.find("td:eq(0)");
    var iptype = row.find("td:eq(2)");
    var probetype = row.find("td:eq(3)");
    var maxrtt = row.find("td:eq(4)");
    var key = row.find("td:eq(" + key_field_idx +")");

    var iptypes = [
      {val : "ipv4", text: ']] print(i18n("ipv4")) print[['},
      {val : "ipv6", text: ']] print(i18n("ipv6")) print[['},
    ];

    var probetypes = [
      {val : "icmp", text: ']] print(i18n("icmp")) print[['},
      {val : "http_get", text: ']] print(i18n("system_stats.http_get")) print[['},
    ];

    addInputField(host, host.html(), ' data-orig-value="' + key.html() + '"');
    addInputField(maxrtt, maxrtt.html() || "100", 'autocomplete="off" style="width:12em;" type="number" min="1"');
    addSelectField(iptype, iptype.html(), iptypes);
    addSelectField(probetype, probetype.html(), probetypes, null, "probe-type-selector");

    checkIPVersionEnabled(row);
  }

  function onRowAddUndo() {
    if(datatableIsEmpty("#table-hosts"))
      datatableAddEmptyRow("#table-hosts", "]] print(i18n("system_stats.no_hosts_configured")) print[[");
  }

  function deleteRttHost() {
    var params = {};
    params.rtt_host = elem_to_delete;
    params.action = "delete";
    params.csrf = "]] print(ntop.getRandomCSRFValue()) print[[";
    paramsToForm('<form method="post"></form>', params).appendTo('body').submit();
  }

  function addRow() {
    if($("#addRowBtn").attr("disabled"))
      return;

    var newid = "rtt_row_" + rtt_row_id;
    rtt_row_id++;

    if(datatableIsEmpty("#table-hosts"))
      datatableRemoveEmptyRow("#table-hosts");

    var tr = $('<tr id="'+ newid +'"><td></td><td></td><td class="text-center"></td><td class="text-center"></td><td class="text-center"></td><td class="text-center"></td><td class="text-center"></td><td class="text-center"></td><td class="text-center"></td></tr>');
    addInputFields(tr);

    datatableAddDeleteButtonCallback.bind(tr)(action_field_idx, "datatableUndoAddRow('#" + newid + "', ']] print(i18n("host_pools.no_pools_defined")) print[[', '#addRowBtn', 'onRowAddUndo')", "]] print(i18n('undo')) print[[");
    $("#table-hosts table").append(tr);
    $("input:first", tr).focus();

    aysRecheckForm("#table-hosts-form");
  }

  function host2key(host, ipver, probetype) {
    /* NOTE: keep in sync with rtt_utils.host2key */
    fields = [host, ipver, probetype];
    return fields.join("@");
  }

  function rowToData(row) {
    var host = row.find("td:eq(0) input").val();
    var orig_host = row.find("td:eq(0) input").attr("data-orig-value");
    var iptype = row.find("td:eq(2) select").val();
    var probetype = row.find("td:eq(3) select").val();
    var max_rtt = row.find("td:eq(4) input").val();

    return [host2key(host, iptype, probetype), orig_host, host, iptype, probetype, max_rtt].join("|");
  }

  function submitRttHosts() {
    var form = $("#table-hosts-form");
    var rtt_hosts = [];

    datatableForEachRow("#table-hosts", function() {
      var row = $(this);

      if(!row.attr("data-skip"))
	rtt_hosts.push(rowToData(row));
    });

    // Reset the form to avoid form change messages
    aysResetForm('#table-hosts-form');

    var params = {};
    params.rtt_hosts = rtt_hosts.join(",");
    params.csrf = "]] print(ntop.getRandomCSRFValue()) print[[";
    paramsToForm('<form method="post"></form>', params).appendTo('body').submit();
  }

  $(document).on("change", ".probe-type-selector", function() {
    checkIPVersionEnabled($(this).closest("tr"));
  })

  aysHandleForm("#table-hosts-form", {
    handle_datatable: true,
    ays_options: {addRemoveFieldsMarksDirty: true}
  });

  $("#table-hosts-form").submit(function(event) {
    if(event.isDefaultPrevented() || $("#hosts-save").hasClass("disabled"))
      return false;

    submitRttHosts();

    return false;
  });
  </script>]]
elseif((page == "historical") and (host ~= nil)) then
   local schema = _GET["ts_schema"] or "monitored_host:rtt"
   local selected_epoch = _GET["epoch"] or ""
   local tags = {ifid=getSystemInterfaceId(), host=host}
   url = url.."&page=historical&rtt_host=" .. host

   local rtt_host = rtt_utils.getHost(host)
   local timeseries = {
    { schema="monitored_host:rtt",              label=i18n("graphs.num_ms_rtt") },
   }

   if(rtt_host and (rtt_host.probetype == "http_get")) then
     timeseries = table.merge(timeseries, {
       { schema="monitored_host:http_stats",              label=i18n("graphs.http_stats"),
	  metrics_labels = { i18n("graphs.name_lookup"), i18n("graphs.app_connect"), i18n("other") }},
     })
   end

   drawGraphs(getSystemInterfaceId(), schema, tags, _GET["zoom"], url, selected_epoch, {
      timeseries = timeseries,
   })
elseif((page == "alerts") and isAdministrator()) then
   local old_ifname = ifname
   local ts_utils = require("ts_utils")
   local influxdb = ts_utils.getQueryDriver()
   interface.select(getSystemInterfaceId())

   _GET["ifid"] = getSystemInterfaceId()
   _GET["entity"] = alert_consts.alertEntity("pinged_host")
   _GET["entity_val"] = _GET["rtt_host"]

   drawAlerts()

   interface.select(old_ifname)
end

-- #######################################################

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
