--
-- (C) 2013-21 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/pro/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path

require "lua_utils"
local graph_utils = require "graph_utils"
local template = require "template_utils"
local page_utils = require("page_utils")
local host_pools = require "host_pools"
local template = require "template_utils"
local presets_utils = require "presets_utils"
local discover = require "discover_utils"

-- Administrator check
if not isAdministrator() then
   return
end

-- Instantiate host pools
local host_pools_instance = host_pools:create()

local page = _GET["page"] or ""
local policy_filter = _GET["policy_filter"] or ""
local proto_filter = _GET["l7proto"] or ""
local device_type = _GET["device_type"] or "0" -- unknown by default
local category = _GET["category"] or ""
local is_nedge = ntop.isnEdge()

interface.select(ifname)

presets_utils.init()

local base_url = ""
if is_nedge then
   base_url = ntop.getHttpPrefix().."/lua/pro/nedge/admin/nf_edit_user.lua"
else
   base_url = ntop.getHttpPrefix().."/lua/admin/edit_device_protocols.lua"
end

-- ###################################################################

local page_params = {}
local filter_msg = ""

page_params["page"] = page

if not isEmptyString(policy_filter) then
  page_params["policy_filter"] = policy_filter
  local action = presets_utils.actionIDToAction(policy_filter)
  filter_msg = action.text
end

if not isEmptyString(category) then
  page_params["category"] = category
  filter_msg = filter_msg.." "..category
end


if not isEmptyString(proto_filter) then
  page_params["l7proto"] = proto_filter
end

if not isEmptyString(device_type) then
  page_params["device_type"] = device_type
end

-- ###################################################################

function editDeviceProtocols()
   local reload = false
   for k,v in pairs(_POST) do
      if starts(k, "client_policy_") then
         local proto = split(k, "client_policy_")[2]
         local action_id = v
         presets_utils.updateDeviceProto(device_type, "client", proto, action_id)
         reload = true
      end
      if starts(k, "server_policy_") then
         local proto = split(k, "server_policy_")[2]
         local action_id = v
         presets_utils.updateDeviceProto(device_type, "server", proto, action_id)
         reload = true
      end
   end

   if reload then
      presets_utils.reloadDevicePolicies(device_type)
   end
end

-- ###################################################################

local function printDevicePolicyLegenda()
   print[[<div style='float:left;'><ul style='display:inline; padding:0'>]]

   for _, action in ipairs(presets_utils.actions) do
      print("<li style='display:inline-block; margin-right: 14px;'>".. string.gsub(action.icon, "\"", "'") .. " " .. action.text .. "</li>")
   end

   print[[</ul></div>]]
end

-- ###################################################################

local function printDeviceProtocolsPage()
   local form_id = "device-protocols-form"
   local table_id = "device-protocols-table"

   if is_nedge then
      local pool_name = host_pools_instance.DEFAULT_POOL_NAME
      page_utils.print_page_title(i18n("nedge.user_device_protocols", {user=pool_name}))
   else
      page_utils.print_page_title(i18n("device_protocols.filter_device_protocols", {filter=filter_msg}))
   end

   print[[<table style="width:100%; margin-bottom: 20px;"><tbody>
     <tr>
       <td style="white-space:nowrap; padding-right:1em;">]]

   -- Device type selector
   print(i18n("details.device_type")) print(': <select id="device_type_selector" class="form-select device-type-selector" style="display:inline; width: 200px" onchange="document.location.href=\'?page=device_protocols&l7proto=') print(proto_filter) print('&device_type=\' + $(this).val()">')
   discover.printDeviceTypeSelectorOptions(device_type, false)
   print[[</select></td><td style="width:100%"></td>]]

   -- Active protocol filter
   if not isEmptyString(proto_filter) then
      local proto_name = interface.getnDPIProtoName(tonumber(proto_filter))

      -- table.clone needed to modify some parameters while keeping the original unchanged
      local proto_filter_params = table.clone(page_params)
      proto_filter_params.device_type = device_type
      proto_filter_params.l7proto = nil

      print[[<td style="padding-top: 15px;">
      <form action="]] print(base_url) print[[">]]
      for k,v in pairs(proto_filter_params) do
         print[[<input type="hidden" name="]] print(k) print[[" value="]] print(v) print[[" />]]
      end
      print[[
        <button type="button" class="btn btn-secondary btn-sm" style="margin-bottom: 18px;" onclick="$(this).closest('form').submit();">
          <i class="fas fa-times fa-lg" aria-hidden="true" data-original-title="" title=""></i> ]] print(proto_name) print[[
        </button>
      </form>
    </td>]]
   end

   print[[<td>]]

   -- Remove policy filter on search
   -- table.clone needed to modify some parameters while keeping the original unchanged
   local after_search_params = table.clone(page_params)
   after_search_params.device_type = device_type
   after_search_params.l7proto = nil
   after_search_params.policy_filter = nil
   after_search_params.category = nil

   -- Protocol search form
   print(
      template.gen("typeahead_input.html", {
         typeahead={
            base_id     = "t_app",
            action      = base_url,
            parameters  = after_search_params,
            json_key    = "key",
            query_field = "l7proto",
            query_url   = ntop.getHttpPrefix() .. "/lua/find_app.lua?skip_critical=true",
            query_title = i18n("nedge.search_protocols"),
            style       = "margin-left:1em; width:25em;",
         }
      })
   )

   print[[</td></tr></tbody></table>]]

   print(
	 template.gen("modal_confirm_dialog.html", {
			 dialog={
			    id      = "presetsResetDefaults",
			    action  = "presetsResetDefaults()",
			    title   = i18n("users.reset_to_defaults"),
			    message = i18n("users.reset_to_defaults_confirm", {devtype="<span id='to_reset_devtype'></span>"}),
			    confirm = i18n("reset")
			 }
	 })
      )

      if is_nedge and (ntop.getPref("ntopng.prefs.device_protocols_policing") ~= "1") then
        print([[
  <div class="alert alert-warning alert-dismissible" style="margin-top:2em; margin-bottom:0em;">
    <b>]]..i18n("warning")..[[</b>: ]].. i18n("nedge.device_protocols_blocked_warning", {
      device_protocols_policies = '<a href="'.. ntop.getHttpPrefix() ..
         '/lua/pro/nedge/admin/nf_edit_user.lua?page=settings">'.. i18n("nedge.enable_device_protocols_policies") .. '</a>',
    }) ..[[
      <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>
  </div><br>]])
   end

   -- Table form
   print[[<form id="]] print(form_id) print[[" lass="form-inline" style="margin-bottom: 0px;" method="post">
      <input type="hidden" name="csrf" value="]] print(ntop.getRandomCSRFValue()) print[[">
      <div id="]] print(table_id) print[["></div>
      <button class="btn btn-primary" style="float:right; margin-right:1em; margin-left: auto" disabled="disabled" type="submit">]] print(i18n("save_settings")) print[[</button>
   </form>

   <button class="btn btn-secondary" onclick="$('#to_reset_devtype').html($('#device_type_selector option:selected').text()); $('#presetsResetDefaults').modal('show');" style="float:right; margin-right:1em;"><i class="fas fa-undo" aria-hidden="true" data-original-title="" title=""></i> ]] print(i18n("users.reset_to_defaults")) print[[</button>

   <br>]]

   print[[
     <span>
       <ul>]]
   print("<b>"..i18n("notes").."</b>")
   if is_nedge then
      print [[
       <li>]] print(i18n("nedge.device_protocol_policy_has_higher_priority")) print[[</li>
       <li>]] print(i18n("nedge.protocol_policy_has_higher_priority")) print[[</li>]]
   else
      print [[
       <li>]] print(i18n("device_protocols_description")) print[[</li>]]
   end
   print[[
       </ul>
     </span>]]

   print[[
   <script type="text/javascript">
   function presetsResetDefaults() {
      var params = {};

      params.action = "reset";
      params.device_type = $('#device_type_selector').val();
      params.csrf = "]] print(ntop.getRandomCSRFValue()) print[[";

      var form = NtopUtils.paramsToForm('<form method="post"></form>', params);
      form.appendTo('body').submit();
   }

    aysHandleForm("#]] print(form_id) print[[");
    $("#]] print(form_id) print[[").submit(function() {
      var form = $("#]] print(form_id) print[[");

      // Serialize form data
      var params = {};
      params.csrf = "]] print(ntop.getRandomCSRFValue()) print[[";
      params.edit_device_policy = "";

      datatableForEachRow($("#]] print(table_id) print[["), function() {
        var row = $(this);
        var proto_id = $("td:nth-child(1)", row).html();
        var client_action_id = $("td:nth-child(4)", row).find("input[type=radio]:checked").val();
        var server_action_id = $("td:nth-child(5)", row).find("input[type=radio]:checked").val();
        params["client_policy_" + proto_id] = client_action_id;
        params["server_policy_" + proto_id] = server_action_id;
      });

      aysResetForm("#]] print(form_id) print[[");
      NtopUtils.paramsToForm('<form method="post"></form>', params).appendTo('body').submit();
      return false;
    });

    var url_update = "]] print (ntop.getHttpPrefix())
   print[[/lua/admin/get_device_protocols.lua?device_type=]] print(device_type)
   if not isEmptyString(policy_filter) then print("&policy_filter=" .. policy_filter) end
   if not isEmptyString(proto_filter) then print("&l7proto=" .. proto_filter) end
   if not isEmptyString(category) then print("&category=" .. category) end
   print[[";

    var legend_appended = false;

    $("#]] print(table_id) print[[").datatable({
      url: url_update ,
      class: "table table-striped table-bordered table-sm",
]]

   -- Table preferences
   local preference = tablePreferences("rows_number_policies", _GET["perPage"])
   if isEmptyString(preference) then preference = "10" end
   print ('perPage: '..preference.. ",\n")

   print[[
      tableCallback: function(opts) {
        if (! legend_appended) {
          legend_appended = true;
          $("#]] print(table_id) print[[ .dt-toolbar-container").append("]]

   -- Legenda
   printDevicePolicyLegenda()

   print[[")};
            datatableForEachRow($("#]] print(table_id) print[["), function() {
              var row = $(this);
              var proto_id = $("td:nth-child(1)", row).html();
            });

            aysResetForm("#]] print(form_id) print[[");
      }, showPagination: true, title:"",
      buttons: []]

   -- 'Filter Policies' button
   print('\'<div class="btn-group float-right"><div class="btn btn-link dropdown-toggle" data-bs-toggle="dropdown">'..
         i18n("nedge.filter_policies") .. ternary(not isEmptyString(policy_filter), '<span class="fas fa-filter"></span>', '') ..
         '<span class="caret"></span></div> <ul class="dropdown-menu scrollable-dropdown" role="menu" style="min-width: 90px;">')

   -- 'Filter Policies' dropdown menu
   local entries = { {text=i18n("all"), id=""} }
   entries[#entries + 1] = ""
   for _, action in ipairs(presets_utils.actions) do
      entries[#entries + 1] = {text=action.text, id=action.id, icon=action.icon .. "&nbsp;&nbsp;"}
   end
   for _, entry in pairs(entries) do
      if entry ~= "" then
         page_params["policy_filter"] = entry.id
         print('<li><a class="dropdown-item ' .. ternary(policy_filter == entry.id, 'active', '') .. '" href="' .. getPageUrl(base_url, page_params) .. '">' .. (entry.icon or "") .. entry.text .. '</a></li>')
      else
         print('<li role="separator" class="divider"></li>')
      end
   end
   page_params["policy_filter"] = policy_filter
   print('</ul></div>\', ')

   -- Category filter
   local device_policies = presets_utils.getDevicePolicies(device_type)

   local function categoryCountCallback(cat_id, cat_name)
      local cat_count = 0
      for proto_id,p in pairs(device_policies) do
         local cat = ntop.getnDPIProtoCategory(tonumber(proto_id))
         if cat.name == cat_name and (isEmptyString(policy_filter)
              or policy_filter == p.clientActionId or policy_filter == p.serverActionId) then
            cat_count = cat_count + 1
         end
      end

      return cat_count
   end

   graph_utils.printCategoryDropdownButton(false, category, base_url, page_params, categoryCountCallback)

   -- datatable columns definition
   print[[],
          columns: [
            {
              title: "",
              field: "column_ndpi_application_id",
              hidden: true,
              sortable: false,
            },{
              title: "]] print(i18n("application")) print[[ ",
              field: "column_ndpi_application",
              sortable: true,
                css: {
                  width: '35%',
                  textAlign: 'left',
                  verticalAlign: 'middle',
              }
            },{
              title: "]] print(i18n("category")) print[[ ",
              field: "column_ndpi_category",
              sortable: true,
                css: {
                  width: '30%',
                  textAlign: 'left',
                  verticalAlign: 'middle',
              }
            },{
              title: "]] print(i18n("users.client_policy")) print[[",
              field: "column_client_policy",
              sortable: false,
                css: {
                  width: '280',
                  textAlign: 'center',
                  verticalAlign: 'middle',
              }
            },
            {
              title: "]] print(i18n("users.server_policy")) print[[",
              field: "column_server_policy",
              sortable: false,
                css: {
                  width: '280',
                  textAlign: 'center',
                  verticalAlign: 'middle',
              }
            },
]
  });
       </script>
]]
end

-- ###################################################################

if _POST["edit_device_policy"] ~= nil then
  editDeviceProtocols()
elseif (_POST["action"] == "reset") and (_POST["device_type"] ~= nil) then
   local device_type = tonumber(_POST["device_type"])
   presets_utils.resetDevicePoliciesFromPresets(device_type)
   presets_utils.reloadDevicePolicies(device_type)
end

printDeviceProtocolsPage()


