--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/timeseries/drivers/?.lua;" .. package.path -- for influxdb
if((dirs.scriptdir ~= nil) and (dirs.scriptdir ~= "")) then package.path = dirs.scriptdir .. "/lua/modules/?.lua;" .. package.path end
require "lua_utils"
require "prefs_utils"
local alert_utils = require "alert_utils"
local template = require "template_utils"
local callback_utils = require "callback_utils"
local lists_utils = require "lists_utils"
local telemetry_utils = require "telemetry_utils"
local alert_consts = require "alert_consts"
local recording_utils = require "recording_utils"
local data_retention_utils = require "data_retention_utils"
local page_utils = require("page_utils")
local ts_utils = require("ts_utils")
local influxdb = require("influxdb")
local plugins_utils = require("plugins_utils")
local nindex_utils = nil
local info = ntop.getInfo()
local auth = require "auth"

local email_peer_pattern = [[^([a-zA-Z0-9.!#$%&'*+\/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*)$]]

if(ntop.isPro()) then
  package.path = dirs.installdir .. "/scripts/lua/pro/?.lua;" .. package.path
  package.path = dirs.installdir .. "/scripts/lua/pro/modules/?.lua;" .. package.path
  if hasNindexSupport() then
     nindex_utils = require("nindex_utils")
  end
end

sendHTTPContentTypeHeader('text/html')

local alerts_disabled = false
local product = ntop.getInfo().product
local message_info = ""
local message_severity = "alert-warning"

-- NOTE: all the auth methods should be listed below
local auth_toggles = {
  ["local"] = "toggle_local_auth",
  ["ldap"] = "toggle_ldap_auth",
  ["http"] = "toggle_http_auth",
  ["radius"] = "toggle_radius_auth",
}

if auth.has_capability(auth.capabilities.preferences) then
  if not table.empty(_POST) then
    if _GET["tab"] == "auth" then
      local one_enabled = false

      for k, v in pairs(auth_toggles) do
        if _POST[v] == "1" then
          one_enabled = true
          break
        end
      end
    end
  end

   if(_GET["tab"] == "ext_alerts") then
     local available_endpoints = plugins_utils.getLoadedAlertEndpoints()

     for _, endpoint in ipairs(available_endpoints) do
       if(endpoint.handlePost) then
         local mi, ms = endpoint.handlePost()

         if mi then message_info = mi end
         if ms then message_severity = ms end
       end
     end
   end

   if(_POST["disable_alerts_generation"] == "1") then
    local alert_utils = require "alert_utils"
      alert_utils.disableAlertsGeneration()
   elseif (_POST["timeseries_driver"] == "influxdb") then
      local url = string.gsub(string.gsub( _POST["ts_post_data_url"], "http:__", "http://"), "https:__", "https://")

      if ntop.getPref("ntopng.prefs.timeseries_driver") ~= "influxdb"
        or (url ~= ntop.getPref("ntopng.prefs.ts_post_data_url"))
        or (_POST["influx_dbname"] ~= ntop.getPref("ntopng.prefs.influx_dbname"))
        or (_POST["influx_retention"] ~= ntop.getPref("ntopng.prefs.influx_retention"))
        or (_POST["toggle_influx_auth"] ~= ntop.getPref("ntopng.prefs.influx_auth_enabled"))
        or (_POST["influx_username"] ~= ntop.getPref("ntopng.prefs.influx_username"))
        or (_POST["influx_password"] ~= ntop.getPref("ntopng.prefs.influx_password")) then
         local username = nil
         local password = nil

         if _POST["toggle_influx_auth"] == "1" then
           username = _POST["influx_username"]
           password = _POST["influx_password"]
         end

         local ok, message = influxdb.init(_POST["influx_dbname"], url, tonumber(_POST["influx_retention"]),
            username, password, false --[[verbose]])
         if not ok then
            -- NOTE: already logged
            --~ message_info = message
            --~ message_severity = "alert-danger"

            -- reset driver to the old one
            _POST["timeseries_driver"] = nil
         elseif message then
            message_info = message
            message_severity = "alert-success"
         end
      end

   elseif(_POST["n2disk_license"] ~= nil) then
      recording_utils.setLicense(_POST["n2disk_license"])
   end

   if _POST["timeseries_driver"] or _POST["data_retention_days"] then
      ts_utils.setupAgain()
   end

   page_utils.set_active_menu_entry(page_utils.menu_entries.preferences)

   dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

   prefs = ntop.getPrefs()

   if not isEmptyString(message_info) then
      print[[<div class="alert alert-dismissable ]] print(message_severity) print[[" role="alert">]]
      print(message_info)
      print[[<button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>]]
      print[[</div>]]
   end

  local show_advanced_prefs = false

  if toboolean(_POST["show_advanced_prefs"]) ~= nil then
    ntop.setPref(show_advanced_prefs_key, _POST["show_advanced_prefs"])
    show_advanced_prefs = toboolean(_POST["show_advanced_prefs"])
    notifyNtopng(show_advanced_prefs_key, _POST["show_advanced_prefs"])
 else
    show_advanced_prefs = toboolean(ntop.getPref(show_advanced_prefs_key))
    if isEmptyString(show_advanced_prefs) then show_advanced_prefs = false end
 end

 if _GET['show_advanced_prefs'] ~= nil then
  show_advanced_prefs = (_GET['show_advanced_prefs'] == '1')
 end

   page_utils.print_page_title(i18n("prefs.runtime_prefs"))

   if(false) then
      io.write("------- SERVER ----------------\n")
      tprint(_SERVER)
      io.write("-------- GET ---------------\n")
      tprint(_GET)
      io.write("-------- POST ---------------\n")
      tprint(_POST)
      io.write("-----------------------\n")
   end

   if hasAlertsDisabled() then
    alerts_disabled = true
   end

local subpage_active, tab = prefsGetActiveSubpage(show_advanced_prefs, _GET["tab"])

-- ================================================================================

function printInterfaces()
  print('<form method="post">')
  print('<table class="table">')

  print('<thead class="table-primary"><tr><th colspan=2 class="info">'..i18n("prefs.zmq_interfaces")..'</th></tr></thead>')

  prefsInputFieldPrefs(subpage_active.entries["ignored_interfaces"].title,
		       subpage_active.entries["ignored_interfaces"].description,
		       "ntopng.prefs.",
		       "ignored_interfaces",
		       "",
		       false, nil, nil, nil,  {attributes={spellcheck="false", pattern="^([0-9]+,)*[0-9]+$", maxlength=32}})

  prefsToggleButton(subpage_active, {
	field = "toggle_dst_with_post_nat_dst",
	default = "0",
	pref = "override_dst_with_post_nat_dst",
  })

  prefsToggleButton(subpage_active, {
	field = "toggle_src_with_post_nat_src",
	default = "0",
	pref = "override_src_with_post_nat_src",
  })

  print('<tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px" disabled="disabled">'..i18n("save")..'</button></th></tr>')
  print('</table>')
  print [[<input name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />
  </form> ]]
end

-- ================================================================================

function printAlerts()
   print('<form method="post">')
   print('<table class="table">')
   print('<thead class="table-primary"><tr><th colspan=2 class="info">'..i18n("show_alerts.alerts")..'</th></tr></thead>')

   local elementToSwitch = {
      "row_toggle_emit_flow_alerts", "row_toggle_emit_host_alerts",
      "max_entity_alerts",
      "max_num_secs_before_delete_alert",
   }

   prefsToggleButton(subpage_active, {
			field = "disable_alerts_generation",
			default = "0",
			to_switch = elementToSwitch,
			on_value = "0",     -- On  means alerts enabled and thus disable_alerts_generation == 0
			off_value = "1",    -- Off for enabled alerts implies 1 for disable_alerts_generation
   })

   if ntop.getPref("ntopng.prefs.disable_alerts_generation") == "1" then
      showElements = false
   else
      showElements = true
   end

   prefsToggleButton(subpage_active, {
			field = "toggle_emit_flow_alerts",
			default = "1",
			pref = "emit_flow_alerts",
			on_value = "1",     -- On  flow alerts are generated
			off_value = "0",    -- Off NO flow alerts are generated
			hidden = not showElements,
   })

   prefsToggleButton(subpage_active, {
			field = "toggle_emit_host_alerts",
			default = "1",
			pref = "emit_host_alerts",
			on_value = "1",     -- On  alerts are generated
			off_value = "0",    -- Off NO alerts are generated
			hidden = not showElements,
   })

   prefsInputFieldPrefs(subpage_active.entries["max_entity_alerts"].title, subpage_active.entries["max_entity_alerts"].description,
			"ntopng.prefs.", "max_entity_alerts", prefs.max_entity_alerts, "number", showElements, false, nil, {min=1, --[[ TODO check min/max ]]})

   prefsInputFieldPrefs(subpage_active.entries["max_num_secs_before_delete_alert"].title, subpage_active.entries["max_num_secs_before_delete_alert"].description,
			"ntopng.prefs.", "max_num_secs_before_delete_alert", prefs.max_num_secs_before_delete_alert, "number", showElements, false, nil, {min=1, tformat="d"--[[ TODO check min/max ]]})

   print('<tr><th colspan=2 style="text-align:right;">')
   print('<button type="submit" class="btn btn-primary" style="width:115px" disabled="disabled">'..i18n("save")..'</button>')
   print('</th></tr>')
   print('</table>')
   print [[<input name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />
  </form>
  ]]
end

-- ================================================================================

function printProtocolPrefs()
  print('<form method="post">')

  print('<table class="table">')

  print('<thead class="table-primary"><tr><th colspan=2 class="info">HTTP / TLS / QUIC / DNS</th></tr></thead>')

  prefsToggleButton(subpage_active, {
    field = "toggle_top_sites",
    pref = "host_top_sites_creation",
    default = "0",
  })

  --[[
  print('<tr><th colspan=2 class="info">TCP</th></tr>')

  prefsInputFieldPrefs(subpage_active.entries["ewma_alpha_percent"].title, subpage_active.entries["ewma_alpha_percent"].description,
		       "ntopng.prefs.", "ewma_alpha_percent", prefs.ewma_alpha_percent, "number",
		       true,
		       nil, nil, {min=1, max=99,})
  --]]

  print('<tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px" disabled="disabled">'..i18n("save")..'</button></th></tr>')

  print('</table>')
  print [[<input name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />
  </form> ]]
end

-- ================================================================================

function printNetworkDiscovery()
   print('<form method="post">')
   print('<table class="table">')

   print('<thead class="table-primary"><tr><th colspan=2 class="info">'..i18n("prefs.network_discovery")..'</th></tr></thead>')

   local elementToSwitch = {"network_discovery_interval"}

   prefsToggleButton(subpage_active, {
    field = "toggle_network_discovery",
    default = "0",
    pref = "is_periodic_network_discovery_enabled",
    to_switch = elementToSwitch,
  })

   local showNetworkDiscoveryInterval = false
   if ntop.getPref("ntopng.prefs.is_periodic_network_discovery_enabled") == "1" then
      showNetworkDiscoveryInterval = true
   end

   local interval = ntop.getPref("ntopng.prefs.network_discovery_interval")

   if isEmptyString(interval) then -- set a default value
      interval = 15 * 60 -- 15 minutes
      ntop.setPref("ntopng.prefs.network_discovery_interval", tostring(interval))
   end

   prefsInputFieldPrefs(subpage_active.entries["network_discovery_interval"].title, subpage_active.entries["network_discovery_interval"].description,
    "ntopng.prefs.", "network_discovery_interval", interval, "number", showNetworkDiscoveryInterval, nil, nil, {min=60 * 15, tformat="mhd"})

   print('<tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px" disabled="disabled">'..i18n("save")..'</button></th></tr>')

   print('</table>')
  print [[<input name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />
    </form>]]
end


-- ================================================================================

function printTelemetry()
   print('<form method="post">')
   print('<table class="table">')

   print('<thead class="table-primary"><tr><th colspan=2 class="info">'..i18n("prefs.telemetry")..'</th></tr></thead>')

   local t_labels = {i18n("prefs.telemetry_do_not_contribute")..' <i class="fas fa-frown-o"></i>',
		     i18n("prefs.telemetry_contribute")..' <i class="fas fa-heart"></i>'}
   local t_values = {"0", "1"}
   local elementToSwitch = {"telemetry_email"}
   local showElementArray = {false, true}

   multipleTableButtonPrefs(subpage_active.entries["toggle_send_telemetry_data"].title,
			    subpage_active.entries["toggle_send_telemetry_data"].description,
			    t_labels, t_values,
			    "", -- leave the default empty so one is forced to either chose opt-in or opt-out
			    "primary", "toggle_send_telemetry_data", "ntopng.prefs.send_telemetry_data", nil,
			    elementToSwitch, showElementArray, nil, true--[[show]])

   prefsInputFieldPrefs(subpage_active.entries["telemetry_email"].title,
			subpage_active.entries["telemetry_email"].description,
		       "ntopng.prefs.",
		       "telemetry_email",
		       "",
		       false,
		       telemetry_utils.telemetry_enabled(),
		       nil, nil,  {attributes={spellcheck="false"}, pattern=email_peer_pattern, required=false})

   print('<tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px" disabled="disabled">'..i18n("save")..'</button></th></tr>')

   print('</table>')
  print [[<input name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />
    </form>]]
end

-- ================================================================================

function printRecording()
  local n2disk_info = recording_utils.getN2diskInfo()

  print('<form method="post">')
  print('<table class="table">')

  print('<thead class="table-primary"><tr><th colspan=2 class="info">'..i18n("prefs.license")..'</th></tr></thead>')

  prefsInputFieldPrefs(subpage_active.entries["n2disk_license"].title, subpage_active.entries["n2disk_license"].description
      ..i18n("prefs.n2disk_license_description_enterprise_l").."<br>"
      ..ternary(n2disk_info.version ~= nil, i18n("prefs.n2disk_license_version", {version=n2disk_info.version}).."<br>", "")
      ..ternary(n2disk_info.systemid ~= nil, i18n("prefs.n2disk_license_systemid", {systemid=n2disk_info.systemid}), ""),
    "ntopng.prefs.", "n2disk_license",
    ternary(n2disk_info.license ~= nil, n2disk_info.license, ""),
    false, nil, nil, nil, {style={width="25em;"}, min = 50, max = 64,
    pattern = getLicensePattern(), disabled = ntop.isEnterpriseL() })

  print('<thead class="table-primary"><tr><th colspan=2 class="info">'..i18n("traffic_recording.settings")..'</th></tr></thead>')

  prefsInputFieldPrefs(subpage_active.entries["max_extracted_pcap_bytes"].title,
     subpage_active.entries["max_extracted_pcap_bytes"].description,
    "ntopng.prefs.", "max_extracted_pcap_bytes", prefs.max_extracted_pcap_bytes,
    "number", true, nil, nil, {min=10*1024*1024, format_spec = FMT_TO_DATA_BYTES, tformat="mg"})

  -- ######################

  print('<tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px" disabled="disabled">'..i18n("save")..'</button></th></tr>')
  print('</table>')
  print [[<input name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />
    </form>]]
end

-- ================================================================================

function printDataRetention()
  print('<form method="post">')
  print('<table class="table">')

  print('<thead class="table-primary"><tr><th colspan=2 class="info">'..i18n("prefs.data_retention")..'</th></tr></thead>')

  prefsInputFieldPrefs(subpage_active.entries["data_retention"].title,
		       subpage_active.entries["data_retention"].description,
		       "ntopng.prefs.", "data_retention_days", data_retention_utils.getDefaultRetention(), "number", nil, nil, nil, {min=1, max=365 * 10})

  print('<tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px" disabled="disabled">'..i18n("save")..'</button></th></tr>')
  print('</table>')
  print [[<input name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />
    </form>]]
end

-- ================================================================================

function printGUI()
  print('<form method="post">')
  print('<table class="table">')

  print('<thead class="table-primary"><tr><th colspan=2 class="info">'..i18n("prefs.web_user_interface")..'</th></tr></thead>')

  if prefs.is_autologout_enabled == true then
    prefsToggleButton(subpage_active, {
      field = "toggle_autologout",
      default = "1",
      pref = "is_autologon_enabled",
    })
  end

  -- ######################

  local t_labels = {i18n("default"), i18n("light"), i18n("dark")}
  local t_values = {"default", "light", "dark"}
  local label = "toggle_theme"

  multipleTableButtonPrefs(subpage_active.entries[label].title,
			   subpage_active.entries[label].description,
			   t_labels, t_values, "default", "primary",
			   label, "ntopng.user." .. _SESSION["user"] .. ".theme")

  -- ######################

  prefsInputFieldPrefs(subpage_active.entries["max_ui_strlen"].title, subpage_active.entries["max_ui_strlen"].description,
		       "ntopng.prefs.", "max_ui_strlen", prefs.max_ui_strlen, "number", nil, nil, nil, {min=3, max=128})

  prefsInputFieldPrefs(subpage_active.entries["mgmt_acl"].title, subpage_active.entries["mgmt_acl"].description,
		       "ntopng.prefs.",
		       "http_acl_management_port",
		       "", false, nil, nil, nil, {style = {width = "25em;"},
						  attributes = {spellcheck = "false", maxlength = 512, pattern = getACLPattern()}})

  -- #####################

  print('<tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px" disabled="disabled">'..i18n("save")..'</button></th></tr>')
  print('</table>')
  print [[<input name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />
    </form>]]
end

-- ######################

function printMisc()
  print('<form method="post">')
  print('<table class="table">')

  print('<thead class="table-primary"><tr><th colspan=2 class="info">'..i18n("prefs.report")..'</th></tr></thead>')

  local t_labels = {i18n("bytes"), i18n("packets")}
  local t_values = {"bps", "pps"}

  multipleTableButtonPrefs(subpage_active.entries["toggle_thpt_content"].title, subpage_active.entries["toggle_thpt_content"].description,
			   t_labels, t_values, "bps", "primary", "toggle_thpt_content", "ntopng.prefs.thpt_content")

  -- ######################

  if ntop.isPro() then
     t_labels = {i18n("topk_heuristic.precision.disabled"),
		 i18n("topk_heuristic.precision.more_accurate"),
		 i18n("topk_heuristic.precision.less_accurate"),
		 i18n("topk_heuristic.precision.aggressive")}
     t_values = {"disabled", "more_accurate", "accurate", "aggressive"}

     multipleTableButtonPrefs(subpage_active.entries["topk_heuristic_precision"].title,
			      subpage_active.entries["topk_heuristic_precision"].description,
			      t_labels, t_values, "more_accurate", "primary", "topk_heuristic_precision",
			      "ntopng.prefs.topk_heuristic_precision")
  end

  -- ######################

  if(isAdministratorOrPrintErr()) then
     print('<thead class="table-primary"><tr><th colspan=2 class="info">'..i18n("hosts")..'</th></tr></thead>')

     local h_labels = {i18n("prefs.no_host_mask"), i18n("prefs.local_host_mask"), i18n("prefs.remote_host_mask")}
     local h_values = {"0", "1", "2"}

     multipleTableButtonPrefs(subpage_active.entries["toggle_host_mask"].title,
			      subpage_active.entries["toggle_host_mask"].description,
			      h_labels, h_values, "0", "primary", "toggle_host_mask", "ntopng.prefs.host_mask")
  end

  print('<thead class="table-primary"><tr><th colspan=2 class="info">'..i18n("prefs.flow_table")..'</th></tr></thead>')

  local h_labels = {i18n("prefs.duration"), i18n("prefs.last_seen")}
  local h_values = {"0", "1"}

  multipleTableButtonPrefs(subpage_active.entries["flow_table_time"].title,
          subpage_active.entries["flow_table_time"].description,
          h_labels, h_values, "0", "primary", "flow_table_time", "ntopng.prefs.flow_table_time")

  print('<tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px" disabled="disabled">'..i18n("save")..'</button></th></tr>')
  print('</table>')
  print [[<input name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />
    </form>]]
end

-- ================================================================================

function printUpdates()
  print('<form method="post">')
  print('<table class="table">')

  print('<thead class="table-primary"><tr><th colspan=2 class="info">'..i18n("prefs.updates")..'</th></tr></thead>')
    prefsToggleButton(subpage_active, {
      field = "toggle_autoupdates",
      default = "0",
      pref = "is_autoupdates_enabled",
    })

  -- #####################

  print('<tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px" disabled="disabled">'..i18n("save")..'</button></th></tr>')
  print('</table>')
  print [[<input name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />
    </form>]]

end

-- ================================================================================

local function printAuthDuration()
  print('<thead class="table-primary"><tr><th colspan=2 class="info">'..i18n("prefs.authentication_duration")..'</th></tr></thead>')

  prefsInputFieldPrefs(subpage_active.entries["authentication_duration"].title, subpage_active.entries["authentication_duration"].description,
		       "ntopng.prefs.","auth_session_duration",
		       prefs.auth_session_duration, "number", true, nil, nil,
		       {min = 60 --[[ 1 minute --]], max = 86400 * 7 --[[ 7 days --]],
			tformat="mhd"})

  prefsToggleButton(subpage_active, {
  		       field = "toggle_auth_session_midnight_expiration",
  		       default = "0",
  		       pref = "auth_session_midnight_expiration",
  })

end

-- ================================================================================

local function printLdapAuth()
  if not ntop.isPro() then return end

  print('<thead class="table-primary"><tr><th colspan=2 class="info">'..i18n("prefs.ldap_authentication")..'</th></tr></thead>')

  local elementToSwitch = {"row_multiple_ldap_account_type", "row_toggle_ldap_anonymous_bind","server","bind_dn", "bind_pwd", "ldap_server_address", "search_path", "user_group", "admin_group", "row_toggle_ldap_referrals"}

  prefsToggleButton(subpage_active, {
	      field = auth_toggles.ldap,
	      pref = "ldap.auth_enabled",
	      default = "0",
	      to_switch = elementToSwitch,

        -- Similar to "to_switch" but for nested items (e.g. "local hosts cache" only
        -- enabled when both "host cache" and "cache" are enabled).
        -- The following inputs will be shown/hidden when this preference changes.
        nested_to_switch = {
          -- input: the input ID to toggle (e.g. the "local hosts cache")
          -- parent: the parent of the input which affects the input logic (e.g. "host cache")
          -- parent_enabled_value: the parent input value that should make the child input visible
          -- pref_enabled_value: this preference value that should make the child input visible (e.g. "1" when "cache" is enabled)
          {input="bind_dn", parent="input-toggle_ldap_anonymous_bind", parent_enabled_value="0", pref_enabled_value="1"},
          {input="bind_pwd", parent="input-toggle_ldap_anonymous_bind", parent_enabled_value="0", pref_enabled_value="1"},
        },
	})

  local showElements = (ntop.getPref("ntopng.prefs.ldap.auth_enabled") == "1")

  local labels_account = {i18n("prefs.posix"), i18n("prefs.samaccount")}
  local values_account = {"posix","samaccount"}
  multipleTableButtonPrefs(subpage_active.entries["multiple_ldap_account_type"].title, subpage_active.entries["multiple_ldap_account_type"].description,
        labels_account, values_account, "posix", "primary", "multiple_ldap_account_type", "ntopng.prefs.ldap.account_type", nil, nil, nil, nil, showElements)

  prefsInputFieldPrefs(subpage_active.entries["ldap_server_address"].title, subpage_active.entries["ldap_server_address"].description,
        "ntopng.prefs.ldap", "ldap_server_address", "ldap://localhost:389", nil, showElements, true, true, {attributes={pattern="ldap(s)?://[0-9.\\-A-Za-z]+(:[0-9]+)?", spellcheck="false", required="required", maxlength=255}})

  local elementToSwitchBind = {"bind_dn","bind_pwd"}
  prefsToggleButton(subpage_active, {
      field = "toggle_ldap_anonymous_bind",
      default = "1",
      pref = "ldap.anonymous_bind",
      to_switch = elementToSwitchBind,
      reverse_switch = true,
      hidden = not showElements,
    })

  local showEnabledAnonymousBind = false
    if ntop.getPref("ntopng.prefs.ldap.anonymous_bind") == "0" then
  showEnabledAnonymousBind = true
  end
  local showElementsBind = showElements
  if showElements == true then
    showElementsBind = showEnabledAnonymousBind
  end

  prefsInputFieldPrefs(subpage_active.entries["bind_dn"].title, subpage_active.entries["bind_dn"].description .. "\"CN=ntop_users,DC=ntop,DC=org,DC=local\".", "ntopng.prefs.ldap", "bind_dn", "", nil, showElementsBind, true, false, {attributes={spellcheck="false", maxlength=255}})
  prefsInputFieldPrefs(subpage_active.entries["bind_pwd"].title, subpage_active.entries["bind_pwd"].description, "ntopng.prefs.ldap", "bind_pwd", "", "password", showElementsBind, true, false, {attributes={maxlength=255}})
  prefsInputFieldPrefs(subpage_active.entries["search_path"].title, subpage_active.entries["search_path"].description, "ntopng.prefs.ldap", "search_path", "", "text", showElements, nil, nil, {attributes={spellcheck="false", maxlength=255}})
  prefsInputFieldPrefs(subpage_active.entries["user_group"].title, subpage_active.entries["user_group"].description, "ntopng.prefs.ldap", "user_group", "", "text", showElements, nil, nil, {attributes={spellcheck="false", maxlength=255}})
  prefsInputFieldPrefs(subpage_active.entries["admin_group"].title, subpage_active.entries["admin_group"].description, "ntopng.prefs.ldap", "admin_group", "", "text", showElements, nil, nil, {attributes={spellcheck="false", maxlength=255}})

  prefsToggleButton(subpage_active, {
    field = "toggle_ldap_referrals",
    default = "1",
    pref = "ldap.follow_referrals",
    reverse_switch = true,
    hidden = not showElements,
  })
end

-- #####################

local function printRadiusAuth()
  if subpage_active.entries["toggle_radius_auth"].hidden then
    return
  end

  print('<thead class="table-primary"><tr><th colspan=2 class="info">'..i18n("prefs.radius_auth")..'</th></tr></thead>')

  local elementToSwitch = {"radius_server_address", "radius_secret", "radius_admin_group"}

  prefsToggleButton(subpage_active, {
	      field = auth_toggles.radius,
	      pref = "radius.auth_enabled",
	      default = "0",
	      to_switch = elementToSwitch,
	})

  local showElements = (ntop.getPref("ntopng.prefs.radius.auth_enabled") == "1")

  prefsInputFieldPrefs(subpage_active.entries["radius_server"].title, subpage_active.entries["radius_server"].description,
    "ntopng.prefs.radius", "radius_server_address", "127.0.0.1:1812", nil, showElements, true, false,
    {attributes={spellcheck="false", maxlength=255, required="required", pattern="[0-9.\\-A-Za-z]+:[0-9]+"}})

  -- https://github.com/FreeRADIUS/freeradius-client/blob/7b7473ab78ca5f99e083e5e6c16345b7c2569db1/include/freeradius-client.h#L395
  prefsInputFieldPrefs(subpage_active.entries["radius_secret"].title, subpage_active.entries["radius_secret"].description,
    "ntopng.prefs.radius", "radius_secret", "", "password", showElements, true, false,
    {attributes={spellcheck="false", maxlength=48, required="required"}})

  prefsInputFieldPrefs(subpage_active.entries["radius_admin_group"].title, subpage_active.entries["radius_admin_group"].description,
    "ntopng.prefs.radius", "radius_admin_group", "", nil, showElements, true, false,
    {attributes={spellcheck="false", maxlength=255, pattern="[^\\s]+"}})
end

-- #####################

local function printHttpAuth()
  print('<thead class="table-primary"><tr><th colspan=2 class="info">'..i18n("prefs.http_auth")..'</th></tr></thead>')

  local elementToSwitch = {"http_auth_url"}

  prefsToggleButton(subpage_active, {
	      field = auth_toggles.http,
	      pref = "http_authenticator.auth_enabled",
	      default = "0",
	      to_switch = elementToSwitch,
	})

  local showElements = (ntop.getPref("ntopng.prefs.http_authenticator.auth_enabled") == "1")

  prefsInputFieldPrefs(subpage_active.entries["http_auth_server"].title, subpage_active.entries["http_auth_server"].description,
    "ntopng.prefs.http_authenticator", "http_auth_url", "", nil, showElements, true, true --[[ allowUrls ]],
    {attributes={spellcheck="false", maxlength=255, required="required", pattern=getURLPattern()}})
end

-- #####################

local function printLocalAuth()
  print('<thead class="table-primary"><tr><th colspan=2 class="info">'..i18n("prefs.local_auth")..'</th></tr></thead>')

  prefsToggleButton(subpage_active, {
	      field = auth_toggles["local"],
	      pref = "local.auth_enabled",
	      default = "1",
	})
end

-- #####################

function printAuthentication()
  print('<form method="post">')
  print('<table class="table">')

  local entries = subpage_active.entries

  printAuthDuration()

  -- Note: order must correspond to evaluation order in Ntop.cpp
  print('<thead class="table-primary"><tr><th class="info" colspan="2">'..i18n("prefs.client_x509_auth")..'</th></tr></thead>')
  prefsToggleButton(subpage_active,{
	field = "toggle_client_x509_auth",
	default = "0",
	pref = "is_client_x509_auth_enabled",
  })
  if not entries.toggle_ldap_auth.hidden then
    printLdapAuth()
  end
  if not entries.toggle_radius_auth.hidden then
    printRadiusAuth()
  end
  if not entries.toggle_http_auth.hidden then
    printHttpAuth()
  end
  if not entries.toggle_local_auth.hidden then
    printLocalAuth()
  end

  if not ntop.isnEdge() then
    prefsInformativeField(i18n("notes"), i18n("prefs.auth_methods_order"))
  else
    prefsInformativeField(i18n("notes"), i18n("nedge.authentication_gui_and_captive_portal",
      {product = product, url = ntop.getHttpPrefix() .. "/lua/pro/nedge/system_setup_ui/captive_portal.lua"}))
  end

  print('<tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px" disabled="disabled">'..i18n("save")..'</button></th></tr>')
  print('</table>')
  print [[<input name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />]]
  print('</form>')
end

-- #####################

function printNetworkBehaviour()

   if not ntop.isEnterpriseL() then return end
   
   local LEARNING_STATUS = { -- Keep it in sync with ntop_typedefs.h ServiceAcceptance
      ALLOWED = "0",
      DENIED = "1",
      UNDECIDED = "2"
   }
   
   print('<form method="post">')
   print('<table class="table">')

   -- ######################

   print('<thead class="table-primary"><tr><th colspan=2 class="info">'..i18n("prefs.traffic_behaviour")..'</th></tr></thead>')
   -- Behavior analysis for asn, network and l7proto (iface)
 
   prefsToggleButton(subpage_active, {
			field = "toggle_behaviour_analysis",
			default = "0",
			pref = "is_behaviour_analysis_enabled", -- redis preference
			to_switch = {"learning-status-thead", "behaviour_analysis_learning_period", "row_behaviour_analysis_learning_status_during_learning", "row_behaviour_analysis_learning_status_post_learning"},
   })

   local is_behaviour_analysis_enabled = ntop.getPref("ntopng.prefs.is_behaviour_analysis_enabled") == "1"

   prefsInputFieldPrefs(
      subpage_active.entries["behaviour_analysis_learning_period"].title, 
      subpage_active.entries["behaviour_analysis_learning_period"].description,
      "ntopng.prefs.","behaviour_analysis_learning_period",
      prefs.behaviour_analysis_learning_period,
      "number", is_behaviour_analysis_enabled, nil, nil, {min=3600, tformat="hd"})

   multipleTableButtonPrefs(
      subpage_active.entries["behaviour_analysis_learning_status_during_learning"].title,
      subpage_active.entries["behaviour_analysis_learning_status_during_learning"].description,
      {i18n("traffic_behaviour.undecided"), i18n("traffic_behaviour.allowed"), i18n("traffic_behaviour.denied")}, 
      {LEARNING_STATUS.UNDECIDED, LEARNING_STATUS.ALLOWED, LEARNING_STATUS.DENIED},
      LEARNING_STATUS.ALLOWED, -- [default value]
      "primary", -- [selected color]
      "behaviour_analysis_learning_status_during_learning",
      "ntopng.prefs.behaviour_analysis_learning_status_during_learning",  -- [redis key]
      false, -- [disabled]
      {}, nil, nil, is_behaviour_analysis_enabled --[[show]])
   
   multipleTableButtonPrefs(
      subpage_active.entries["behaviour_analysis_learning_status_post_learning"].title,
      subpage_active.entries["behaviour_analysis_learning_status_post_learning"].description,
      {i18n("traffic_behaviour.undecided"), i18n("traffic_behaviour.allowed"), i18n("traffic_behaviour.denied")}, 
      {LEARNING_STATUS.UNDECIDED, LEARNING_STATUS.ALLOWED, LEARNING_STATUS.DENIED},
      LEARNING_STATUS.ALLOWED, -- [default value]
      "primary",
      "behaviour_analysis_learning_status_post_learning",
      "ntopng.prefs.behaviour_analysis_learning_status_post_learning", 
      false,
      {}, nil, nil, is_behaviour_analysis_enabled --[[show]])

   prefsInputFieldPrefs(
      subpage_active["iec60870_learning_period"].title, 
      subpage_active["iec60870_learning_period"].description,
      "ntopng.prefs.","iec60870_learning_period",
      prefs.iec60870_learning_period,
      "number", nil, nil, nil, {min=21600, tformat="hd"})

   -- #####################
   
   print('<tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px" disabled="disabled">'..i18n("save")..'</button></th></tr>')

   print('</table>')
   print [[<input name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />]]
   print('</form>')
end

-- ================================================================================

function printInMemory()
  print('<form id="localRemoteTimeoutForm" method="post">')

  print('<table class="table">')
  print('<thead class="table-primary"><tr><th colspan=2 class="info">'..i18n("prefs.stats_reset")..'</th></tr></thead>')
  prefsToggleButton(subpage_active, {
    field = "toggle_midnight_stats_reset",
    default = "0",
    pref = "midnight_stats_reset_enabled",
  })

  print('<thead class="table-primary"><tr><th colspan=2 class="info">'..i18n("prefs.local_hosts_cache_settings")..'</th></tr></thead>')

  prefsToggleButton(subpage_active, {
    field = "toggle_local_host_cache_enabled",
    default = "1",
    pref = "is_local_host_cache_enabled",
    to_switch = {"local_host_cache_duration","row_toggle_active_local_host_cache_enabled","active_local_host_cache_interval"},

    -- Similar to "to_switch" but for nested items (e.g. "local hosts cache" only
    -- enabled when both "host cache" and "cache" are enabled).
    -- The following inputs will be shown/hidden when this preference changes.
    nested_to_switch = {
      -- input: the input ID to toggle (e.g. the "local hosts cache")
      -- parent: the parent of the input which affects the input logic (e.g. "host cache")
      -- parent_enabled_value: the parent input value that should make the child input visible
      -- pref_enabled_value: this preference value that should make the child input visible (e.g. "1" when "cache" is enabled)
      {input="active_local_host_cache_interval", parent="input-toggle_active_local_host_cache_enabled", parent_enabled_value="1", pref_enabled_value="1"},
    },
  })

  local showLocalHostCacheInterval = false
  if ntop.getPref("ntopng.prefs.is_local_host_cache_enabled") == "1" then
    showLocalHostCacheInterval = true
  end

  prefsInputFieldPrefs(subpage_active.entries["local_host_cache_duration"].title, subpage_active.entries["local_host_cache_duration"].description,
    "ntopng.prefs.","local_host_cache_duration", prefs.local_host_cache_duration, "number", showLocalHostCacheInterval, nil, nil, {min=60, tformat="mhd"})

  prefsToggleButton(subpage_active, {
    field = "toggle_active_local_host_cache_enabled",
    default = "0",
    pref = "is_active_local_host_cache_enabled",
    to_switch = {"active_local_host_cache_interval"},
  })

  local showActiveLocalHostCacheInterval = false
  if ntop.getPref("ntopng.prefs.is_active_local_host_cache_enabled") == "1" then
    showActiveLocalHostCacheInterval = true
  end

  prefsInputFieldPrefs(subpage_active.entries["active_local_host_cache_interval"].title, subpage_active.entries["active_local_host_cache_interval"].description,
    "ntopng.prefs.", "active_local_host_cache_interval", prefs.active_local_host_cache_interval or 3600, "number", showActiveLocalHostCacheInterval, nil, nil, {min=60, tformat="mhd"})

  print('</table>')

  print('<table class="table">')
  print('<thead class="table-primary"><tr><th colspan=2 class="info">'..i18n("prefs.idle_timeout_settings")..'</th></tr></thead>')

  prefsInputFieldPrefs(subpage_active.entries["local_host_max_idle"].title, subpage_active.entries["local_host_max_idle"].description,
		       "ntopng.prefs.","local_host_max_idle", prefs.local_host_max_idle, "number", nil, nil, nil,
		       {min=1, max=7*86400, tformat="smh", attributes={["data-localremotetimeout"]="localremotetimeout"}})

  prefsInputFieldPrefs(subpage_active.entries["non_local_host_max_idle"].title, subpage_active.entries["non_local_host_max_idle"].description,
		       "ntopng.prefs.", "non_local_host_max_idle", prefs.non_local_host_max_idle, "number", nil, nil, nil,
		       {min=1, max=7*86400, tformat="smh"})

  prefsInputFieldPrefs(subpage_active.entries["flow_max_idle"].title, subpage_active.entries["flow_max_idle"].description,
		       "ntopng.prefs.", "flow_max_idle", prefs.flow_max_idle, "number", nil, nil, nil,
		       {min=1, max=3600, tformat="smh"})

  prefsInputFieldPrefs(subpage_active.entries["housekeeping_frequency"].title,
		       subpage_active.entries["housekeeping_frequency"].description,
		       "ntopng.prefs.", "housekeeping_frequency", prefs.housekeeping_frequency, "number", nil, nil, nil, {min = 5, max = 60, step = 5})

  print('<tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px" disabled="disabled">'..i18n("save")..'</button></th></tr>')
  print('</table>')
  print [[<input name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />
  </form>

  <script>
    function localRemoteTimeoutValidator() {
      var form = $("#localRemoteTimeoutForm");
      var local_timeout = resol_selector_get_raw($("input[name='local_host_max_idle']", form));
      var remote_timeout = resol_selector_get_raw($("input[name='non_local_host_max_idle']", form));

      if ((local_timeout != null) && (remote_timeout != null)) {
        if (local_timeout < remote_timeout)
          return false;
      }

      return true;
    }

    var idleFormValidatorOptions = {
      disable: true,
      custom: {
         localremotetimeout: localRemoteTimeoutValidator,
      }, errors: {
         localremotetimeout: "Cannot be less then Remote Host Idle Timeout",
      }
   }

   $("#localRemoteTimeoutForm")
      .validator(idleFormValidatorOptions);

   /* Retrigger the validation every second to clear outdated errors */
   setInterval(function() {
      $("#localRemoteTimeoutForm").data("bs.validator").validate();
    }, 1000);
  </script>
  ]]
end

-- ================================================================================

function printStatsTimeseries()
  print('<form method="post">')
  print('<table class="table">')

  local force_rrd = false --ntop.isWindows()

  if not force_rrd then
    print('<thead class="table-primary"><tr><th colspan=2 class="info">'..i18n('prefs.timeseries_database')..'</th></tr></thead>')
  end

  local elementToSwitch = {"ts_post_data_url", "influx_dbname", "influx_retention", "row_toggle_influx_auth", "influx_username", "influx_password", "row_ts_high_resolution"}
  local showElementArray = {false, true, false}

  local active_driver = "rrd"
  local influx_active = false

  if not force_rrd then
    -- Similar to "to_switch" but for nested items (e.g. "local hosts cache" only
    -- enabled when both "host cache" and "cache" are enabled).
    -- The following inputs will be shown/hidden when this preference changes.
    local nested_to_switch = {
      -- input: the input ID to toggle (e.g. the "local hosts cache")
      -- parent: the parent of the input which affects the input logic (e.g. "host cache")
      -- parent_enabled_value: the parent input value that should make the child input visible
      -- pref_enabled_value: this preference value that should make the child input visible (e.g. "1" when "cache" is enabled)
      {input="influx_username", parent="input-toggle_influx_auth", parent_enabled_value="1", pref_enabled_value="influxdb"},
      {input="influx_password", parent="input-toggle_influx_auth", parent_enabled_value="1", pref_enabled_value="influxdb"},
    }

    multipleTableButtonPrefs(subpage_active.entries["multiple_timeseries_database"].title,
				    subpage_active.entries["multiple_timeseries_database"].description,
				    {"RRD", "InfluxDB 1.x"}, {"rrd", "influxdb" },
				    "rrd",
				    "primary",
				    "timeseries_driver",
				    "ntopng.prefs.timeseries_driver", nil,
				    elementToSwitch, showElementArray, nested_to_switch, true--[[show]])

    active_driver = ntop.getPref("ntopng.prefs.timeseries_driver")
    influx_active = (active_driver == "influxdb")
  end

  prefsInputFieldPrefs(subpage_active.entries["influxdb_url"].title,
		       subpage_active.entries["influxdb_url"].description,
		       "ntopng.prefs.",
		       "ts_post_data_url",
		       "http://localhost:8086",
		       false, influx_active, nil, nil,  {attributes={spellcheck="false"}, pattern=getURLPattern(), required=true})

  if ntop.isnEdge() and ntop.getPref("ntopng.prefs.influx_dbname") == "ntopng edge" then
     -- Fixes issue #1939 with wrong deployed nedge db name
     ntop.delCache("ntopng.prefs.influx_dbname")
  end
  prefsInputFieldPrefs(subpage_active.entries["influxdb_dbname"].title, subpage_active.entries["influxdb_dbname"].description,
		       "ntopng.prefs.", "influx_dbname", product:gsub(' ' , '_'), nil, influx_active, nil, nil, {pattern="[A-z,0-9,_]+"})

  prefsToggleButton(subpage_active, {
	field = "toggle_influx_auth",
	default = "0",
	pref = "influx_auth_enabled",
	to_switch = {"influx_username", "influx_password"},
  hidden = not influx_active,
  })

  local auth_enabled = influx_active and (ntop.getPref("ntopng.prefs.influx_auth_enabled") == "1")

  prefsInputFieldPrefs(subpage_active.entries["influxdb_username"].title, subpage_active.entries["influxdb_username"].description,
		       "ntopng.prefs.",
		       "influx_username", "",
           false, auth_enabled, nil, nil,  {attributes={spellcheck="false"}, pattern="[^\\s]+"})

  prefsInputFieldPrefs(subpage_active.entries["influxdb_password"].title, subpage_active.entries["influxdb_password"].description,
		       "ntopng.prefs.",
		       "influx_password", "",
           "password", auth_enabled, nil, nil,  {attributes={spellcheck="false"}, pattern="[^\\s]+"})

  local resolutions_labels = {"1m", "5m"}
  local resolutions_values = {"60", "300"}

  multipleTableButtonPrefs(subpage_active.entries["timeseries_resolution_resolution"].title,
				    subpage_active.entries["timeseries_resolution_resolution"].description .. "<br><b>" .. i18n("notes") .. [[</b>:<ul>
      <li>]] .. i18n("prefs.ts_resolution_note2", {
        external_icon = "<i class='fas fa-external-link-alt'></i>",
        url="https://docs.influxdata.com/influxdb/v1.8/query_language/manage-database/#delete-a-database-with-drop-database"
      }) .. [[</li>
      </ul>]],
				    resolutions_labels, resolutions_values,
				    "300",
				    "primary",
				    "ts_high_resolution",
				    "ntopng.prefs.ts_resolution", nil,
				    nil, nil, nil, influx_active)

  prefsInputFieldPrefs(subpage_active.entries["influxdb_query_timeout"].title, subpage_active.entries["influxdb_query_timeout"].description,
            "ntopng.prefs.", "influx_query_timeout", "10", "number", influx_active, nil, nil, {min=1})

  print('<thead class="table-primary"><tr><th colspan=2 class="info">'..i18n('prefs.interfaces_timeseries')..'</th></tr></thead>')

  -- TODO: make also per-category interface RRDs
  local l7_rrd_labels = {i18n("prefs.none"),
		  i18n("prefs.per_protocol"),
		  i18n("prefs.per_category"),
		  i18n("prefs.both")
                  }
  local l7_rrd_values = {"none",
		  "per_protocol",
		  "per_category",
		  "both"}

  local elementToSwitch = { }
  local showElementArray = nil -- { true, false, false }

  prefsToggleButton(subpage_active, {
	field = "toggle_interface_traffic_rrd_creation",
	default = "1",
	pref = "interface_rrd_creation",
	to_switch = {"row_interfaces_ndpi_timeseries_creation"},
  })

  local showElement = ntop.getPref("ntopng.prefs.interface_rrd_creation") == "1"

  retVal = multipleTableButtonPrefs(subpage_active.entries["toggle_ndpi_timeseries_creation"].title,
				    subpage_active.entries["toggle_ndpi_timeseries_creation"].description,
				    l7_rrd_labels, l7_rrd_values,
				    "per_protocol",
				    "primary",
				    "interfaces_ndpi_timeseries_creation",
				    "ntopng.prefs.interface_ndpi_timeseries_creation", nil,
				    elementToSwitch, showElementArray, nil, showElement)


  print('<thead class="table-primary"><tr><th colspan=2 class="info">'..i18n('prefs.local_hosts_timeseries')..'</th></tr></thead>')

  local hosts_rrd_labels = {i18n("off"), i18n("light"), i18n("full")}
  local hosts_rrd_values = {"off", "light", "full"}
  local hostElemsToSwitch = { "row_hosts_ndpi_timeseries_creation", "row_toggle_local_hosts_one_way_ts" }
  local hostShowElementArray = {{false, false, true} --[[ ndpi ]], {false, true, true} --[[ one-way traffic ]]}

  multipleTableButtonPrefs(subpage_active.entries["toggle_local_hosts_ts_creation"].title,
				    subpage_active.entries["toggle_local_hosts_ts_creation"].description,
				    hosts_rrd_labels, hosts_rrd_values,
				    "light",
				    "primary",
				    "hosts_ts_creation",
				    "ntopng.prefs.hosts_ts_creation", nil,
				    hostElemsToSwitch, hostShowElementArray, nil, true)

  local hosts_ts_creation = ntop.getPref("ntopng.prefs.hosts_ts_creation")
  local show_host_l7 = (hosts_ts_creation == "full")

  prefsToggleButton(subpage_active, {
    field = "toggle_local_hosts_one_way_ts",
    default = "0",
    pref = "hosts_one_way_traffic_rrd_creation",
    hidden = (hosts_ts_creation == "off"),
  })

  retVal = multipleTableButtonPrefs(subpage_active.entries["toggle_ndpi_timeseries_creation"].title,
				    subpage_active.entries["toggle_ndpi_timeseries_creation"].description,
				    l7_rrd_labels, l7_rrd_values,
				    "none",
				    "primary",
				    "hosts_ndpi_timeseries_creation",
				    "ntopng.prefs.host_ndpi_timeseries_creation", nil,
				    elementToSwitch, showElementArray, nil, show_host_l7)

  print('<thead class="table-primary"><tr><th colspan=2 class="info">'..i18n('prefs.l2_devices_timeseries')..'</th></tr></thead>')

  prefsToggleButton(subpage_active, {
    field = "toggle_l2_devices_traffic_rrd_creation",
    default = "0",
    pref = "l2_device_rrd_creation",
    to_switch = {"row_l2_devices_ndpi_timeseries_creation"},
  })

  local l7_rrd_labels = {i18n("prefs.none"),
			 i18n("prefs.per_category")}
  local l7_rrd_values = {"none",
			 "per_category"}

  local showElement = ntop.getPref("ntopng.prefs.l2_device_rrd_creation") == "1"

  retVal = multipleTableButtonPrefs(subpage_active.entries["toggle_ndpi_timeseries_creation"].title,
				    subpage_active.entries["toggle_ndpi_timeseries_creation"].description,
				    l7_rrd_labels, l7_rrd_values,
				    "none",
				    "primary",
				    "l2_devices_ndpi_timeseries_creation",
				    "ntopng.prefs.l2_device_ndpi_timeseries_creation", nil,
				    elementToSwitch, showElementArray, nil, showElement)

  print('<thead class="table-primary"><tr><th colspan=2 class="info">'..i18n('prefs.observation_points')..'</th></tr></thead>')

  prefsToggleButton(subpage_active, {
    field = "toggle_observation_points_rrd_creation",
    default = "0",
    pref = "observation_points_rrd_creation",
  })

  print('<thead class="table-primary"><tr><th colspan=2 class="info">'..i18n('prefs.system_probes_timeseries')..'</th></tr></thead>')

  prefsToggleButton(subpage_active, {
    field = "toggle_system_probes_timeseries",
    default = "1",
    pref = "system_probes_timeseries",
  })

  print('<thead class="table-primary"><tr><th colspan=2 class="info">'..i18n('prefs.other_timeseries')..'</th></tr></thead>')

  if ntop.isPro() then
    prefsToggleButton(subpage_active, {
      field = "toggle_flow_rrds",
      default = "0",
      pref = "flow_device_port_rrd_creation",
      disabled = not info["version.enterprise_edition"],
    })

    prefsToggleButton(subpage_active, {
      field = "toggle_pools_rrds",
      default = "0",
      pref = "host_pools_rrd_creation",
    })
  end

  prefsToggleButton(subpage_active, {
    field = "toggle_vlan_rrds",
    default = "0",
    pref = "vlan_rrd_creation",
  })

  prefsToggleButton(subpage_active, {
    field = "toggle_asn_rrds",
    default = "0",
    pref = "asn_rrd_creation",
  })

  prefsToggleButton(subpage_active, {
    field = "toggle_country_rrds",
    default = "0",
    pref = "country_rrd_creation",
  })

  prefsToggleButton(subpage_active, {
    field = "toggle_os_rrds",
    default = "0",
    pref = "os_rrd_creation",
  })

  if ntop.isPro() then
    prefsToggleButton(subpage_active, {
      field = "toggle_ndpi_flows_rrds",
      default = "0",
      pref = "ndpi_flows_rrd_creation",
    })
  end

  if info["version.enterprise_edition"] then
    prefsInformativeField("SNMP", i18n("prefs.snmp_timeseries_config_link", {url="?tab=snmp&show_advanced_prefs=1"}))
  end

  prefsToggleButton(subpage_active, {
    field = "toggle_internals_rrds",
    default = "0",
    pref = "internals_rrd_creation",
  })

  print('</table>')

  print('<table class="table">')
if show_advanced_prefs and false --[[ hide these settings for now ]] then
  print('<thead class="table-primary"><tr><th colspan=2 class="info">Network Interface Timeseries</th></tr></thead>')
  prefsInputFieldPrefs("Days for raw stats", "Number of days for which raw stats are kept. Default: 1.", "ntopng.prefs.", "intf_rrd_raw_days", prefs.intf_rrd_raw_days, "number", nil, nil, nil, {min=1, max=365*5, --[[ TODO check min/max ]]})
  prefsInputFieldPrefs("Days for 1 min resolution stats", "Number of days for which stats are kept in 1 min resolution. Default: 30.", "ntopng.prefs.", "intf_rrd_1min_days", prefs.intf_rrd_1min_days, "number", nil, nil, nil, {min=1, max=365*5, --[[ TODO check min/max ]]})
  prefsInputFieldPrefs("Days for 1 hour resolution stats", "Number of days for which stats are kept in 1 hour resolution. Default: 100.", "ntopng.prefs.", "intf_rrd_1h_days", prefs.intf_rrd_1h_days, "number", nil, nil, nil, {min=1, max=365*5, --[[ TODO check min/max ]]})
  prefsInputFieldPrefs("Days for 1 day resolution stats", "Number of days for which stats are kept in 1 day resolution. Default: 365.", "ntopng.prefs.", "intf_rrd_1d_days", prefs.intf_rrd_1d_days, "number", nil, nil, nil, {min=1, max=365*5, --[[ TODO check min/max ]]})

  print('<thead class="table-primary"><tr><th colspan=2 class="info">Protocol/Networks Timeseries</th></tr></thead>')
  prefsInputFieldPrefs("Days for raw stats", "Number of days for which raw stats are kept. Default: 1.", "ntopng.prefs.", "other_rrd_raw_days", prefs.other_rrd_raw_days, "number", nil, nil, nil, {min=1, max=365*5, --[[ TODO check min/max ]]})
  --prefsInputFieldPrefs("Days for 1 min resolution stats", "Number of days for which stats are kept in 1 min resolution. Default: 30.", "ntopng.prefs.", "other_rrd_1min_days", prefs.other_rrd_1min_days)
  prefsInputFieldPrefs("Days for 1 hour resolution stats", "Number of days for which stats are kept in 1 hour resolution. Default: 100.", "ntopng.prefs.", "other_rrd_1h_days", prefs.other_rrd_1h_days, "number", nil, nil, nil, {min=1, max=365*5, --[[ TODO check min/max ]]})
  prefsInputFieldPrefs("Days for 1 day resolution stats", "Number of days for which stats are kept in 1 day resolution. Default: 365.", "ntopng.prefs.", "other_rrd_1d_days", prefs.other_rrd_1d_days, "number", nil, nil, nil, {min=1, max=365*5, --[[ TODO check min/max ]]})
end
  print('<tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px" disabled="disabled">'..i18n("save")..'</button></th></tr>')
  print('</table>')

  print [[<input name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />
  </form> ]]
end

-- ================================================================================

function printLogging()
  if prefs.has_cmdl_trace_lvl then return end
  print('<form method="post">')
  print('<table class="table">')
  print('<thead class="table-primary"><tr><th colspan=2 class="info">'..i18n("prefs.logging")..'</th></tr></thead>')

  loggingSelector(subpage_active.entries["toggle_logging_level"].title,
     subpage_active.entries["toggle_logging_level"].description,
     "toggle_logging_level", "ntopng.prefs.logging_level")

  prefsToggleButton(subpage_active, {
    field = "toggle_log_to_file",
    default = "0",
    pref = "log_to_file",
  })

  prefsToggleButton(subpage_active, {
    field = "toggle_access_log",
    default = "0",
    pref = "enable_access_log",
  })

  prefsToggleButton(subpage_active, {
    field = "toggle_host_pools_log",
    default = "0",
    pref = "enable_host_pools_log",
  })

  print('<tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px" disabled="disabled">'..i18n("save")..'</button></th></tr>')

  print [[<input name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />
  </form>
  </table>]]
end

function printSnmp()
  if not ntop.isPro() then return end

  print('<form method="post">')
  print('<table class="table">')
  print('<thead class="table-primary"><tr><th colspan=2 class="info">SNMP</th></tr></thead>')
  local disabled = not info["version.enterprise_edition"]

  prefsToggleButton(subpage_active, {
    field = "toggle_snmp_rrds",
    default = "0",
    pref = "snmp_devices_rrd_creation",
    disabled = disabled,
  })

  local t_labels = {"v1", "v2c"}
  local t_values = {"0", "1"}

  multipleTableButtonPrefs(subpage_active.entries["default_snmp_proto_version"].title, subpage_active.entries["default_snmp_proto_version"].description,
			   t_labels, t_values, "1", "primary", "default_snmp_version", "ntopng.prefs.default_snmp_version", disabled)

  prefsInputFieldPrefs(subpage_active.entries["default_snmp_community"].title, subpage_active.entries["default_snmp_community"].description,
		       "ntopng.prefs.",
		       "default_snmp_community",
		       "public", false, nil, nil, nil,  {attributes={spellcheck="false", maxlength=64}, disabled=disabled})

  prefsInputFieldPrefs(subpage_active.entries["default_snmp_timeout"].title,
		       subpage_active.entries["default_snmp_timeout"].description,
		       "ntopng.prefs.", "snmp_timeout_sec", 3,  -- default 3 sec
		       "number", nil, nil, nil, { min=1, max=10 })

  prefsToggleButton(subpage_active, {
    field = "toggle_snmp_debug",
    default = "0",
    pref = "snmp_debug",
  })

  if(disabled) then
    prefsInformativeField(i18n("notes"), i18n("enterpriseOnly"))
  end

  print('<tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px" disabled="disabled">'..i18n("save")..'</button></th></tr>')

  print [[<input name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />
  </form>
  </table>]]
end

function printDumpSettings()
   print('<form method="post">')
   print('<table class="table">')
   print('<thead class="table-primary"><tr><th colspan=2 class="info">'..i18n("prefs.flows_dump")..'</th></tr></thead>')

   prefsToggleButton(subpage_active, {
    field = "toggle_enable_runtime_flows_dump",
    default = "1",
    pref = "enable_runtime_flows_dump",
    to_switch = {
       "row_toggle_tiny_flows_dump",
       "max_num_packets_per_tiny_flow",
       "max_num_bytes_per_tiny_flow",
    },
    -- Similar to "to_switch" but for nested items (e.g. "local hosts cache" only
    -- enabled when both "host cache" and "cache" are enabled).
    -- The following inputs will be shown/hidden when this preference changes.
    nested_to_switch = {
      -- input: the input ID to toggle (e.g. the "local hosts cache")
      -- parent: the parent of the input which affects the input logic (e.g. "host cache")
      -- parent_enabled_value: the parent input value that should make the child input visible
      -- pref_enabled_value: this preference value that should make the child input visible (e.g. "1" when "cache" is enabled)
      {input="max_num_packets_per_tiny_flow", parent="input-toggle_tiny_flows_dump", parent_enabled_value="1", pref_enabled_value="1"},
      {input="max_num_bytes_per_tiny_flow", parent="input-toggle_tiny_flows_dump", parent_enabled_value="1", pref_enabled_value="1"},
    },
   })

   local showAllElements = ntop.getPref("ntopng.prefs.enable_runtime_flows_dump") ~= "0"

   prefsToggleButton(subpage_active, {
			field = "toggle_tiny_flows_dump",
			default = "1",
			pref = "tiny_flows_export_enabled",
			to_switch = {
			   "max_num_packets_per_tiny_flow",
			   "max_num_bytes_per_tiny_flow"
			},
			hidden = not showAllElements,
   })

   local showTinyElements = showAllElements and ntop.getPref("ntopng.prefs.tiny_flows_export_enabled") ~= "0"

   prefsInputFieldPrefs(subpage_active.entries["max_num_packets_per_tiny_flow"].title,
			subpage_active.entries["max_num_packets_per_tiny_flow"].description,
			"ntopng.prefs.", "max_num_packets_per_tiny_flow",
			prefs.max_num_packets_per_tiny_flow, "number",
			showTinyElements,
			false, nil, {min=1, max=2^32-1})

   prefsInputFieldPrefs(subpage_active.entries["max_num_bytes_per_tiny_flow"].title,
			subpage_active.entries["max_num_bytes_per_tiny_flow"].description,
			"ntopng.prefs.", "max_num_bytes_per_tiny_flow",
			prefs.max_num_bytes_per_tiny_flow, "number",
			showTinyElements,
			false, nil, {min=1, max=2^32-1})

   print('<tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px" disabled="disabled">'..i18n("save")..'</button></th></tr>')

   print [[<input name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />
  </form>
  </table>]]
end

print[[
       <table class="table">
         <col width="20%">
         <col width="80%">
         <tr><td style="padding-right: 20px;">]]

print(
   template.gen("typeahead_input.html", {
		   typeahead={
		      base_id     = "prefs_search",
		      action      = ntop.getHttpPrefix() .. "/lua/admin/prefs.lua",
		      json_key    = "tab",
		      query_field = "tab",
		      query_url   = ntop.getHttpPrefix() .. "/lua/find_prefs.lua",
		      query_title = i18n("prefs.search_preferences"),
		      style       = "width:20em; margin:auto; margin-top: 0.4em; margin-bottom: 1.5em;",
		   }
   })
)

print[[
           <div class="list-group">]]

printMenuSubpages(tab)

local simple_view_class = (show_advanced_prefs and 'btn-secondary' or 'btn-primary active')
local expert_view_class = (show_advanced_prefs and 'btn-primary active' or 'btn-secondary')

print([[
           </div>
           <div class="text-center">

            <div id="prefs_toggle" class="btn-group">
              <form method='post'>
                <input name="csrf" type="hidden" value="]].. ntop.getRandomCSRFValue() ..[[" />
                <div class="btn-group btn-toggle mt-2">
                  <button class='btn btn-sm ]].. expert_view_class ..[[' name='show_advanced_prefs' value='true'>]].. i18n("prefs.expert_view") ..[[</button>
                  <button class='btn btn-sm ]].. simple_view_class ..[[' name='show_advanced_prefs' value='false'>]].. i18n("prefs.simple_view") ..[[</button>
                </div>
              </form>

            </div>

           </div>
]])
print[[
        </td><td colspan=2>]]

if(tab == "report") then
   printReportVisualization()
end

if(tab == "in_memory") then
   printInMemory()
end

if(tab == "dump_settings") then
   printDumpSettings()
end

if(tab == "on_disk_ts") then
   printStatsTimeseries()
end

if(tab == "alerts") then
   printAlerts()
end

if(tab == "protocols") then
   printProtocolPrefs()
end

if(tab == "discovery") then
   printNetworkDiscovery()
end

if(tab == "telemetry") then
   printTelemetry()
end

if(tab == "recording") then
   printRecording()
end

if(tab == "traffic_behaviour") then
  printNetworkBehaviour()
end

if(tab == "retention") then
   printDataRetention()
end

if(tab == "misc") then
   printMisc()
end

if(tab == "gui") then
   printGUI()
end

if(tab == "updates") then
   printUpdates()
end

if(tab == "auth") then
   printAuthentication()
end
if(tab == "ifaces") then
   printInterfaces()
end
if(tab == "logging") then
   printLogging()
end
if(tab == "snmp") then
   printSnmp()
end

print[[
        </td></tr>
      </table>
]]

   dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")

   print([[<script>
aysHandleForm("form", {
  disable_on_dirty: '.disable-on-dirty',
});

/* Use the validator plugin to override default chrome bubble, which is displayed out of window */
$("form[id!='search-host-form']").validator({disable:true});
</script>]])

end --[[ isAdministratorOrPrintErr ]]
