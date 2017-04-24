--
-- (C) 2013-17 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
if((dirs.scriptdir ~= nil) and (dirs.scriptdir ~= "")) then package.path = dirs.scriptdir .. "/lua/modules/?.lua;" .. package.path end
require "lua_utils"
require "prefs_utils"
require "blacklist_utils"
local template = require "template_utils"

if(ntop.isPro()) then
  package.path = dirs.installdir .. "/scripts/lua/pro/?.lua;" .. package.path
end

sendHTTPHeader('text/html; charset=iso-8859-1')

local show_advanced_prefs = false
local alerts_disabled = false

if(haveAdminPrivileges()) then
   ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")

   active_page = "admin"
   dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

   prefs = ntop.getPrefs()

   print [[
	    <h2>Runtime Preferences</h2>
      ]]

   if(false) then
      io.write("------- SERVER ----------------\n")
      tprint(_SERVER)
      io.write("-------- GET ---------------\n")
      tprint(_GET)
      io.write("-------- POST ---------------\n")
      tprint(_POST)
      io.write("-----------------------\n")
   end

   tab = _GET["tab"]
   

   if toboolean(_POST["show_advanced_prefs"]) ~= nil then
      ntop.setPref(show_advanced_prefs_key, _POST["show_advanced_prefs"])
      show_advanced_prefs = toboolean(_POST["show_advanced_prefs"])
      notifyNtopng(show_advanced_prefs_key, _POST["show_advanced_prefs"])
   else
      show_advanced_prefs = toboolean(ntop.getPref(show_advanced_prefs_key))
      if isEmptyString(show_advanced_prefs) then show_advanced_prefs = false end
   end

   if ((prefs.has_cmdl_disable_alerts == true) or
      ((_POST["disable_alerts_generation"] ~= nil) and (_POST["disable_alerts_generation"] == "1")) or
      ((_POST["disable_alerts_generation"] == nil) and (ntop.getPref("ntopng.prefs.disable_alerts_generation") == "1"))) then
    alerts_disabled = true
   end

local subpage_active = nil

for _, subpage in ipairs(menu_subpages) do
  if not isSubpageAvailable(subpage, show_advanced_prefs) and subpage.id ~= tab then
    subpage.disabled = true
    
    if subpage.id == tab then
      -- will set to default
      tab = nil
    end
  elseif subpage.id == tab then
    subpage_active = subpage
  end
end

-- default subpage
if isEmptyString(tab) then
  -- Pick the first available subpage
  for _, subpage in ipairs(menu_subpages) do
    if isSubpageAvailable(subpage, show_advanced_prefs) then
      subpage_active = subpage
      tab = subpage.id
      break
    end
  end
end

-- ================================================================================

function printInterfaces()
  print('<form method="post">')
  print('<table class="table">')
  print('<tr><th colspan=2 class="info">'..i18n("prefs.dynamic_network_interfaces")..'</th></tr>')

  toggleTableButtonPrefs(subpage_active.entries["dynamic_iface_vlan_creation"].title,
			    subpage_active.entries["dynamic_iface_vlan_creation"].description .. "<p><b>"..i18n("shaping.notes")..":</b><ul>"..
			    "<li>"..i18n("prefs.dynamic_iface_vlan_creation_note_1").."</li>"..
			    "<li>"..i18n("prefs.dynamic_iface_vlan_creation_note_2").."</li>"..
			    "</ul>",
			    "On", "1", "success", "Off", "0", "danger", "dynamic_iface_vlan_creation", "ntopng.prefs.dynamic_iface_vlan_creation", "0")
  
  local labels = {i18n("prefs.none"), i18n("prefs.probe_ip_address"), i18n("prefs.ingress_flow_interface")}
  local values = {"none","probe_ip","ingress_iface_idx"}
  local elementToSwitch = {}
  local showElementArray = { true, false, false }
  local javascriptAfterSwitch = "";

  retVal = multipleTableButtonPrefs(subpage_active.entries["dynamic_flow_collection"].title,
				    subpage_active.entries["dynamic_flow_collection"].description.."<p><b>NOTE:</b><ul>"..
				    "<li>"..i18n("prefs.dynamic_flow_collection_note_1").."</li>"..
				    "<li>"..i18n("prefs.dynamic_flow_collection_note_2").."</ul>",
				    labels, values, "none", "primary", "multiple_flow_collection", "ntopng.prefs.dynamic_flow_collection_mode", nil,
				    elementToSwitch, showElementArray, javascriptAfterSwitch)

  print('<tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px">'..i18n("save")..'</button></th></tr>')
  print('</table>')
  print [[<input id="csrf" name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />
  </form> ]]
end

-- ================================================================================

function printAlerts()
   if prefs.has_cmdl_disable_alerts then return end
  print('<form method="post">')
  print('<table class="table">')
  print('<tr><th colspan=2 class="info">'..i18n("show_alerts.alerts")..'</th></tr>')

 if ntop.getPref("ntopng.prefs.disable_alerts_generation") == "1" then
      showElements = true
  else
      showElements = false
  end

 local elementToSwitch = { "max_num_alerts_per_entity", "max_num_flow_alerts", "row_toggle_alert_probing",
  "row_toggle_malware_probing", "row_toggle_alert_syslog", "row_toggle_mysql_check_open_files_limit",
  "row_toggle_flow_alerts_iface", "row_alerts_retention_header", "row_alerts_security_header"}

  toggleTableButtonPrefs(subpage_active.entries["disable_alerts_generation"].title, subpage_active.entries["disable_alerts_generation"].description,
                    "On", "0", "success", -- On  means alerts enabled and thus disable_alerts_generation == 0
		    "Off", "1", "danger", -- Off for enabled alerts implies 1 for disable_alerts_generation
		    "disable_alerts_generation", "ntopng.prefs.disable_alerts_generation", "0",
                    false,
                    elementToSwitch)

  if ntop.getPrefs().are_alerts_enabled == true then
     showElements = true
  else
     showElements = false
  end

  toggleTableButtonPrefs(subpage_active.entries["toggle_flow_alerts_iface"].title, subpage_active.entries["toggle_flow_alerts_iface"].description,
                    "On", "1", "success",
		    "Off","0", "danger",
		    "toggle_flow_alerts_iface", "ntopng.alerts.dump_alerts_when_iface_is_alerted", "0",
		    false, nil, nil, showElements)

  toggleTableButtonPrefs(subpage_active.entries["toggle_mysql_check_open_files_limit"].title, subpage_active.entries["toggle_mysql_check_open_files_limit"].description,
			 "On", "1", "success", "Off", "0", "danger", "toggle_mysql_check_open_files_limit", "ntopng.prefs.mysql_check_open_files_limit", "1", nil, nil, nil, not (subpage_active.entries["toggle_mysql_check_open_files_limit"].hidden))

  print('<tr id="row_alerts_security_header" ')
  if (showElements == false) then print(' style="display:none;"') end
  print('><th colspan=2 class="info">'..i18n("prefs.security_alerts")..'</th></tr>')

  toggleTableButtonPrefs(subpage_active.entries["toggle_alert_probing"].title, subpage_active.entries["toggle_alert_probing"].description,
                    "On", "1", "success",
		    "Off","0", "danger",
		    "toggle_alert_probing", "ntopng.prefs.probing_alerts", "0",
		    false, nil, nil, showElements)

  toggleTableButtonPrefs(subpage_active.entries["toggle_malware_probing"].title, subpage_active.entries["toggle_malware_probing"].description,
                    "On", "1", "success",
		    "Off", "0", "danger",
		    "toggle_malware_probing", "ntopng.prefs.host_blacklist", "1",
		    false, nil, nil, showElements)

  print('<tr id="row_alerts_retention_header" ')
  if (showElements == false) then print(' style="display:none;"') end
  print('><th colspan=2 class="info">'..i18n("prefs.alerts_retention")..'</th></tr>')

  prefsInputFieldPrefs(subpage_active.entries["max_num_alerts_per_entity"].title, subpage_active.entries["max_num_alerts_per_entity"].description,
        "ntopng.prefs.", "max_num_alerts_per_entity", prefs.max_num_alerts_per_entity, "number", showElements, false, nil, {min=1, --[[ TODO check min/max ]]})

  prefsInputFieldPrefs(subpage_active.entries["max_num_flow_alerts"].title, subpage_active.entries["max_num_flow_alerts"].description,
        "ntopng.prefs.", "max_num_flow_alerts", prefs.max_num_flow_alerts, "number", showElements, false, nil, {min=1, --[[ TODO check min/max ]]})

  print('<tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px">'..i18n("save")..'</button></th></tr>')
  print('</table>')
  print [[<input id="csrf" name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />
  </form> ]]
end

-- ================================================================================

function printExternalAlertsReport()
  if alerts_disabled then return end

  print('<form method="post">')
  print('<table class="table">')
  print('<tr><th colspan=2 class="info">'..i18n("prefs.internal_log")..'</th></tr>')

  local showElements = true

  toggleTableButtonPrefs(subpage_active.entries["toggle_alert_syslog"].title, subpage_active.entries["toggle_alert_syslog"].description,
                    "On", "1", "success",
		    "Off", "0", "danger",
		    "toggle_alert_syslog", "ntopng.prefs.alerts_syslog", "0",
		    false, nil, nil, showElements)

   print('<tr><th colspan=2 class="info"><i class="fa fa-slack" aria-hidden="true"></i> '..i18n('prefs.slack_integration')..'</th></tr>')

   local elementToSwitchSlack = {"row_slack_notification_severity_preference", "sender_username", "slack_webhook"}

   toggleTableButtonPrefs(subpage_active.entries["toggle_slack_notification"].title, subpage_active.entries["toggle_slack_notification"].description,
                    "On", "1", "success", -- On  means alerts enabled and thus disable_alerts_generation == 0
		    "Off", "0", "danger", -- Off for enabled alerts implies 1 for disable_alerts_generation
		    "toggle_slack_notification", "ntopng.alerts.notification_enabled", "0", showElements==false, elementToSwitchSlack)

  local showSlackNotificationPrefs = false
  if ntop.getPref("ntopng.alerts.notification_enabled") == "1" then
     showSlackNotificationPrefs = true
  else
     showSlackNotificationPrefs = false
  end

  local labels = {i18n("prefs.errors"), i18n("prefs.errors_and_warnings"), i18n("prefs.all")}
  local values = {"only_errors","errors_and_warnings","all_alerts"}

  local retVal = multipleTableButtonPrefs(subpage_active.entries["slack_notification_severity_preference"].title, subpage_active.entries["slack_notification_severity_preference"].description,
               labels, values, "only_errors", "primary", "slack_notification_severity_preference",
	       "ntopng.alerts.slack_alert_severity", nil, nil, nil,  nil, showElements and showSlackNotificationPrefs)

  prefsInputFieldPrefs(subpage_active.entries["sender_username"].title, subpage_active.entries["sender_username"].description,
           "ntopng.alerts.", "sender_username",
		       "ntopng Webhook", nil, showElements and showSlackNotificationPrefs, false, nil, {attributes={spellcheck="false"}})

  prefsInputFieldPrefs(subpage_active.entries["slack_webhook"].title, subpage_active.entries["slack_webhook"].description,
		       "ntopng.alerts.", "slack_webhook",
		       "", nil, showElements and showSlackNotificationPrefs, true, true, {attributes={spellcheck="false"}})


  if(ntop.isPro()) then
    print('<tr><th colspan=2 class="info">'..i18n("prefs.nagios_integration")..'</th></tr>')

    local alertsEnabled = showElements

    local elementToSwitch = {"nagios_nsca_host","nagios_nsca_port","nagios_send_nsca_executable","nagios_send_nsca_config","nagios_host_name","nagios_service_name"}

    toggleTableButtonPrefs(subpage_active.entries["toggle_alert_nagios"].title, subpage_active.entries["toggle_alert_nagios"].description,
                    "On", "1", "success",
		    "Off", "0", "danger",
		    "toggle_alert_nagios", "ntopng.prefs.alerts_nagios", "0",
                    alertsEnabled==false,
		    elementToSwitch)

    if ntop.getPref("ntopng.prefs.alerts_nagios") == "0" then
      showElements = false
    end
    showElements = alertsEnabled and showElements

    prefsInputFieldPrefs(subpage_active.entries["nagios_nsca_host"].title, subpage_active.entries["nagios_nsca_host"].description, "ntopng.prefs.", "nagios_nsca_host", prefs.nagios_nsca_host, nil, showElements, false)
    prefsInputFieldPrefs(subpage_active.entries["nagios_nsca_port"].title, subpage_active.entries["nagios_nsca_port"].description, "ntopng.prefs.", "nagios_nsca_port", prefs.nagios_nsca_port, "number", showElements, false, nil, {min=1, max=65535})
    prefsInputFieldPrefs(subpage_active.entries["nagios_send_nsca_executable"].title, subpage_active.entries["nagios_send_nsca_executable"].description, "ntopng.prefs.", "nagios_send_nsca_executable", prefs.nagios_send_nsca_executable, nil, showElements, false)
    prefsInputFieldPrefs(subpage_active.entries["nagios_send_nsca_config"].title, subpage_active.entries["nagios_send_nsca_config"].description, "ntopng.prefs.", "nagios_send_nsca_config", prefs.nagios_send_nsca_conf, nil, showElements, false)
    prefsInputFieldPrefs(subpage_active.entries["nagios_host_name"].title, subpage_active.entries["nagios_host_name"].description, "ntopng.prefs.", "nagios_host_name", prefs.nagios_host_name, nil, showElements, false)
    prefsInputFieldPrefs(subpage_active.entries["nagios_service_name"].title, subpage_active.entries["nagios_service_name"].description, "ntopng.prefs.", "nagios_service_name", prefs.nagios_service_name, nil, showElements)
  end
  
  print('<tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px">'..i18n("save")..'</button></th></tr>')
  print('</table>')
  print [[<input id="csrf" name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />
  </form> ]]
end

-- ================================================================================

function printProtocolPrefs()
  print('<form method="post">')

  print('<table class="table">')

  print('<tr><th colspan=2 class="info">HTTP</th></tr>')

  toggleTableButtonPrefs(subpage_active.entries["toggle_top_sites"].title, subpage_active.entries["toggle_top_sites"].description,
        "On", "1", "success",
        "Off", "0", "danger",
        "toggle_top_sites", "ntopng.prefs.host_top_sites_creation", "0")

  print('<tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px">'..i18n("save")..'</button></th></tr>')

  print('</table>')
  print [[<input id="csrf" name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />
  </form> ]]
end

-- ================================================================================

function printBridgingPrefs()
  local show
  local label

  if((prefs["http.port"] == 80) and (prefs["http.alt_port"] ~= 0)) then
     show = true
     label = ""
  else
     show = false
     label = "<p>"..i18n("prefs.captive_portal_disabled_message").."</p>"
  end

  print('<form method="post">')

  print('<table class="table">')

  print('<tr><th colspan=2 class="info">'..i18n("prefs.traffic_shaping")..'</th></tr>')
  toggleTableButtonPrefs(subpage_active.entries["toggle_shaping_directions"].title, subpage_active.entries["toggle_shaping_directions"].description,
       "On", "1", "success",
       "Off", "0", "danger",
       "toggle_shaping_directions", "ntopng.prefs.split_shaping_directions", "0")

  print('<tr><th colspan=2 class="info">'..i18n("prefs.user_authentication")..'</th></tr>')

  toggleTableButtonPrefs(subpage_active.entries["toggle_captive_portal"].title, subpage_active.entries["toggle_captive_portal"].description .. label,
			 "On", "1", "success",
			 "Off", "0", "danger",
			 "toggle_captive_portal", "ntopng.prefs.enable_captive_portal", "0",
			 not(show))
  
  print('<tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px">'..i18n("save")..'</button></th></tr>')

  print('</table>')
  print [[<input id="csrf" name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />
  </form> ]]
end

-- ================================================================================

function printNbox()
  print('<form method="post">')
  print('<table class="table">')

  print('<tr><th colspan=2 class="info">'..i18n("prefs.nbox_integration")..'</th></tr>')

  local elementToSwitch = {"nbox_user","nbox_password"}

  toggleTableButtonPrefs(subpage_active.entries["toggle_nbox_integration"].title, subpage_active.entries["toggle_nbox_integration"].description,
        "On", "1", "success", "Off", "0", "danger", "toggle_nbox_integration", "ntopng.prefs.nbox_integration", "0", nil, elementToSwitch)

  if ntop.getPref("ntopng.prefs.nbox_integration") == "1" then
    showElements = true
  else
    showElements = false
  end

  prefsInputFieldPrefs(subpage_active.entries["nbox_user"].title, subpage_active.entries["nbox_user"].description, "ntopng.prefs.", "nbox_user", "nbox", nil, showElements, false)
  prefsInputFieldPrefs(subpage_active.entries["nbox_password"].title, subpage_active.entries["nbox_password"].description, "ntopng.prefs.", "nbox_password", "nbox", "password", showElements, false)

  print('<tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px">'..i18n("save")..'</button></th></tr>')

  print('</table>')
  print [[<input id="csrf" name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />
  </form> ]]
end

-- ================================================================================

function printMisc()
  print('<form method="post">')
  print('<table class="table">')

  print('<tr><th colspan=2 class="info">'..i18n("prefs.web_user_interface")..'</th></tr>')
  if prefs.is_autologout_enabled == true then
     toggleTableButtonPrefs(subpage_active.entries["toggle_autologout"].title, subpage_active.entries["toggle_autologout"].description,
			    "On", "1", "success", "Off", "0", "danger", "toggle_autologout", "ntopng.prefs.is_autologon_enabled", "1")
  end
  prefsInputFieldPrefs(subpage_active.entries["google_apis_browser_key"].title, subpage_active.entries["google_apis_browser_key"].description,
		       "ntopng.prefs.",
		       "google_apis_browser_key",
		       "", false, nil, nil, nil, {style={width="25em;"}, attributes={spellcheck="false"} --[[ Note: Google API keys can vary in format ]] })

  print('<tr><th colspan=2 class="info">'..i18n("prefs.report_units")..'</th></tr>')

  local t_labels = {i18n("bytes"), i18n("packets")}
  local t_values = {"bps", "pps"}

  multipleTableButtonPrefs(subpage_active.entries["toggle_thpt_content"].title, subpage_active.entries["toggle_thpt_content"].description,
			   t_labels, t_values, "bps", "primary", "toggle_thpt_content", "ntopng.prefs.thpt_content")

  -- ######################

  if(haveAdminPrivileges()) then
     print('<tr><th colspan=2 class="info">'..i18n("prefs.host_mask")..'</th></tr>')
     
     local h_labels = {i18n("prefs.no_host_mask"), i18n("prefs.local_host_mask"), i18n("prefs.remote_host_mask")}
     local h_values = {"0", "1", "2"}
     
     multipleTableButtonPrefs(subpage_active.entries["toggle_host_mask"].title,
			      subpage_active.entries["toggle_host_mask"].description,
			      h_labels, h_values, "0", "primary", "toggle_host_mask", "ntopng.prefs.host_mask")
  end

  -- #####################

  print('<tr><th colspan=2 style="text-align:right;"><button type="submit" onclick="return save_button_users();" class="btn btn-primary" style="width:115px">'..i18n("save")..'</button></th></tr>')
  print('</table>')
  print [[<input id="csrf" name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />
    </form>]]

end

-- ================================================================================

function printAuthentication()
  if not ntop.isPro() then return end

  print('<form method="post">')
  print('<table class="table">')

  print('<tr><th colspan=2 class="info">'..i18n("prefs.authentication")..'</th></tr>')
  local labels = {i18n("prefs.local"), i18n("prefs.ldap"), i18n("prefs.ldap_local")}
  local values = {"local","ldap","ldap_local"}
  local elementToSwitch = {"row_multiple_ldap_account_type", "row_toggle_ldap_anonymous_bind","server","bind_dn", "bind_pwd", "ldap_server_address", "search_path", "user_group", "admin_group"}
  local showElementArray = {false, true, true}
  local javascriptAfterSwitch = "";
  javascriptAfterSwitch = javascriptAfterSwitch.."  if($(\"#id-toggle-multiple_ldap_authentication\").val() != \"local\"  ) {\n"
  javascriptAfterSwitch = javascriptAfterSwitch.."    if($(\"#toggle_ldap_anonymous_bind_input\").val() == \"0\") {\n"
  javascriptAfterSwitch = javascriptAfterSwitch.."      $(\"#bind_dn\").css(\"display\",\"table-row\");\n"
  javascriptAfterSwitch = javascriptAfterSwitch.."      $(\"#bind_pwd\").css(\"display\",\"table-row\");\n"
  javascriptAfterSwitch = javascriptAfterSwitch.."    } else {\n"
  javascriptAfterSwitch = javascriptAfterSwitch.."      $(\"#bind_dn\").css(\"display\",\"none\");\n"
  javascriptAfterSwitch = javascriptAfterSwitch.."      $(\"#bind_pwd\").css(\"display\",\"none\");\n"
  javascriptAfterSwitch = javascriptAfterSwitch.."    }\n"
  javascriptAfterSwitch = javascriptAfterSwitch.."  }\n"
  local retVal = multipleTableButtonPrefs(subpage_active.entries["multiple_ldap_authentication"].title,
           subpage_active.entries["multiple_ldap_authentication"].description,
           labels, values, "local", "primary", "multiple_ldap_authentication", "ntopng.prefs.auth_type", nil,
           elementToSwitch, showElementArray, javascriptAfterSwitch)

  local showElements = true;
  if ntop.getPref("ntopng.prefs.auth_type") == "local" then
  showElements = false
  end

  local labels_account = {i18n("prefs.posix"), i18n("prefs.samaccount")}
  local values_account = {"posix","samaccount"}
  multipleTableButtonPrefs(subpage_active.entries["multiple_ldap_account_type"].title, subpage_active.entries["multiple_ldap_account_type"].description,
        labels_account, values_account, "posix", "primary", "multiple_ldap_account_type", "ntopng.prefs.ldap.account_type", nil, nil, nil, nil, showElements)

  prefsInputFieldPrefs(subpage_active.entries["ldap_server_address"].title, subpage_active.entries["ldap_server_address"].description,
        "ntopng.prefs.ldap", "ldap_server_address", "ldap://localhost:389", nil, showElements, true, true, {attributes={pattern="ldap(s)?://[0-9.\\-A-Za-z]+(:[0-9]+)?", spellcheck="false", required="required"}})

  local elementToSwitchBind = {"bind_dn","bind_pwd"}
  toggleTableButtonPrefs(subpage_active.entries["toggle_ldap_anonymous_bind"].title, subpage_active.entries["toggle_ldap_anonymous_bind"].description, "On", "1", "success", "Off", "0", "danger", "toggle_ldap_anonymous_bind", "ntopng.prefs.ldap.anonymous_bind", "0", nil, elementToSwitchBind, true, showElements)

  local showEnabledAnonymousBind = false
    if ntop.getPref("ntopng.prefs.ldap.anonymous_bind") == "0" then
  showEnabledAnonymousBind = true
  end
  local showElementsBind = showElements
  if showElements == true then
    showElementsBind = showEnabledAnonymousBind
  end
  -- These two fields are necessary to prevent chrome from filling in LDAP username and password with saved credentials
  -- Chrome, in fact, ignores the autocomplete=off on the input field. The input fill-in triggers un-necessary are-you-sure leave message
  print('<input style="display:none;" type="text" name="_" data-ays-ignore="true" />')
  print('<input style="display:none;" type="password" name="_" data-ays-ignore="true" />')
  --
  prefsInputFieldPrefs(subpage_active.entries["bind_dn"].title, subpage_active.entries["bind_dn"].description .. "\"CN=ntop_users,DC=ntop,DC=org,DC=local\".", "ntopng.prefs.ldap", "bind_dn", "", nil, showElementsBind, true, false, {attributes={spellcheck="false"}})
  prefsInputFieldPrefs(subpage_active.entries["bind_pwd"].title, subpage_active.entries["bind_pwd"].description, "ntopng.prefs.ldap", "bind_pwd", "", "password", showElementsBind, true, false)

  prefsInputFieldPrefs(subpage_active.entries["search_path"].title, subpage_active.entries["search_path"].description, "ntopng.prefs.ldap", "search_path", "", "text", showElements, nil, nil, {attributes={spellcheck="false"}})
  prefsInputFieldPrefs(subpage_active.entries["user_group"].title, subpage_active.entries["user_group"].description, "ntopng.prefs.ldap", "user_group", "", "text", showElements, nil, nil, {attributes={spellcheck="false"}})
  prefsInputFieldPrefs(subpage_active.entries["admin_group"].title, subpage_active.entries["admin_group"].description, "ntopng.prefs.ldap", "admin_group", "", "text", showElements, nil, nil, {attributes={spellcheck="false"}})

  print('<tr><th colspan=2 style="text-align:right;"><button type="submit" onclick="return save_button_users();" class="btn btn-primary" style="width:115px">'..i18n("save")..'</button></th></tr>')
  print('</table>')
  print [[<input id="csrf" name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />]]
  print('</form>')
end

-- ================================================================================

function printInMemory()
  print('<form id="localRemoteTimeoutForm" method="post">')

  print('<table class="table">')
  print('<tr><th colspan=2 class="info">'..i18n("prefs.local_hosts_cache_settings")..'</th></tr>')
  toggleTableButtonPrefs(subpage_active.entries["toggle_local_host_cache_enabled"].title, subpage_active.entries["toggle_local_host_cache_enabled"].description,
			 "On", "1", "success", "Off", "0", "danger",
			 "toggle_local_host_cache_enabled",
			 "ntopng.prefs.is_local_host_cache_enabled", "1")

  local elementToSwitchLocalCache = {"active_local_host_cache_interval"}

  toggleTableButtonPrefs(subpage_active.entries["toggle_active_local_host_cache_enabled"].title, subpage_active.entries["toggle_active_local_host_cache_enabled"].description,
			 "On", "1", "success", "Off", "0", "danger",
			 "toggle_active_local_host_cache_enabled",
			 "ntopng.prefs.is_active_local_host_cache_enabled", "0", nil, elementToSwitchLocalCache)

  local showActiveLocalHostCacheInterval = false
  if ntop.getPref("ntopng.prefs.is_active_local_host_cache_enabled") == "1" then
    showActiveLocalHostCacheInterval = true
  end

  prefsInputFieldPrefs(subpage_active.entries["active_local_host_cache_interval"].title, subpage_active.entries["active_local_host_cache_interval"].description,
    "ntopng.prefs.", "active_local_host_cache_interval", prefs.active_local_host_cache_interval, "number", showActiveLocalHostCacheInterval, nil, nil, {min=60, tformat="mhd"})

  prefsInputFieldPrefs(subpage_active.entries["local_host_cache_duration"].title, subpage_active.entries["local_host_cache_duration"].description,
    "ntopng.prefs.","local_host_cache_duration", prefs.local_host_cache_duration, "number", nil, nil, nil, {min=60, tformat="mhd"})
  print('</table>')
  
  print('<table class="table">')
  print('<tr><th colspan=2 class="info">'..i18n("prefs.idle_timeout_settings")..'</th></tr>')
  prefsInputFieldPrefs(subpage_active.entries["local_host_max_idle"].title, subpage_active.entries["local_host_max_idle"].description,
      "ntopng.prefs.","local_host_max_idle", prefs.local_host_max_idle, "number", nil, nil, nil, {min=1, max=1800, tformat="sm", attributes={["data-localremotetimeout"]="localremotetimeout"}})
  prefsInputFieldPrefs(subpage_active.entries["non_local_host_max_idle"].title, subpage_active.entries["non_local_host_max_idle"].description,
      "ntopng.prefs.", "non_local_host_max_idle", prefs.non_local_host_max_idle, "number", nil, nil, nil, {min=1, max=1800, tformat="sm"})
  prefsInputFieldPrefs(subpage_active.entries["flow_max_idle"].title, subpage_active.entries["flow_max_idle"].description,
      "ntopng.prefs.", "flow_max_idle", prefs.flow_max_idle, "number", nil, nil, nil, {min=1, max=1800, tformat="sm"})

  prefsInputFieldPrefs(subpage_active.entries["housekeeping_frequency"].title, subpage_active.entries["housekeeping_frequency"].description,
      "ntopng.prefs.", "housekeeping_frequency", prefs.housekeeping_frequency, "number", nil, nil, nil, {min=1, max=60})

  print('<tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px">'..i18n("save")..'</button></th></tr>')
  print('</table>')
  print [[<input id="csrf" name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />
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
  print('<tr><th colspan=2 class="info">'..i18n('prefs.timeseries')..'</th></tr>')

  toggleTableButtonPrefs(subpage_active.entries["toggle_local"].title, subpage_active.entries["toggle_local"].description,
			 "On", "1", "success", "Off", "0", "danger", "toggle_local", "ntopng.prefs.host_rrd_creation", "1")

  toggleTableButtonPrefs(subpage_active.entries["toggle_local_ndpi"].title, subpage_active.entries["toggle_local_ndpi"].description,
			 "On", "1", "success", "Off", "0", "danger", "toggle_local_ndpi", "ntopng.prefs.host_ndpi_rrd_creation", "0")

  local activityPrefsToSwitch = {"local_activity_prefs",
    "host_activity_rrd_raw_hours", "id_input_host_activity_rrd_raw_hours",
    "host_activity_rrd_1h_days", "id_input_host_activity_rrd_1h_days",
    "host_activity_rrd_1d_days", "id_input_host_activity_rrd_1d_days"}

  if prefs.is_flow_activity_enabled then
    toggleTableButtonPrefs(subpage_active.entries["toggle_local_activity"].title, subpage_active.entries["toggle_local_activity"].description,
  	 	         "On", "1", "success", "Off", "0", "danger", "toggle_local_activity", "ntopng.prefs.host_activity_rrd_creation", "0",
                         not prefs.is_flow_activity_enabled, activityPrefsToSwitch, false)
  end

  local info = ntop.getInfo()

  if ntop.isPro() then
     toggleTableButtonPrefs(subpage_active.entries["toggle_flow_rrds"].title, subpage_active.entries["toggle_flow_rrds"].description,
                            "On", "1", "success", "Off", "0", "danger", "toggle_flow_rrds", "ntopng.prefs.flow_device_port_rrd_creation", "0", not info["version.enterprise_edition"])

    toggleTableButtonPrefs(subpage_active.entries["toggle_pools_rrds"].title, subpage_active.entries["toggle_pools_rrds"].description,
			 "On", "1", "success", "Off", "0", "danger", "toggle_pools_rrds", "ntopng.prefs.host_pools_rrd_creation", "0")
  end

  toggleTableButtonPrefs(subpage_active.entries["toggle_tcp_flags_rrds"].title, subpage_active.entries["toggle_tcp_flags_rrds"].description.."<br>",
			 "On", "1", "success", "Off", "0", "danger", "toggle_tcp_flags_rrds",
			 "ntopng.prefs.tcp_flags_rrd_creation", "0")

  toggleTableButtonPrefs(subpage_active.entries["toggle_tcp_retr_ooo_lost_rrds"].title, subpage_active.entries["toggle_tcp_retr_ooo_lost_rrds"].description.."<br>",
			 "On", "1", "success", "Off", "0", "danger", "toggle_tcp_retr_ooo_lost_rrds",
			 "ntopng.prefs.tcp_retr_ooo_lost_rrd_creation", "0")

  toggleTableButtonPrefs(subpage_active.entries["toggle_vlan_rrds"].title, subpage_active.entries["toggle_vlan_rrds"].description.."<br>",
			 "On", "1", "success", "Off", "0", "danger", "toggle_vlan_rrds",
			 "ntopng.prefs.vlan_rrd_creation", "0")

  toggleTableButtonPrefs(subpage_active.entries["toggle_asn_rrds"].title, subpage_active.entries["toggle_asn_rrds"].description.."<br>",
			 "On", "1", "success", "Off", "0", "danger", "toggle_asn_rrds",
			 "ntopng.prefs.asn_rrd_creation", "0")

  toggleTableButtonPrefs(subpage_active.entries["toggle_local_categorization"].title, subpage_active.entries["toggle_local_categorization"].description.."-k flashstart:&lt;user&gt;:&lt;password&gt;.",
			 "On", "1", "success", "Off", "0", "danger", "toggle_local_categorization",
			 "ntopng.prefs.host_categories_rrd_creation", "0", not prefs.is_categorization_enabled)
  print('</table>')

  print('<table class="table">')
  print('<tr><th colspan=2 class="info">'..i18n("prefs.databases")..'</th></tr>')

  mysql_retention = 7
  prefsInputFieldPrefs(subpage_active.entries["mysql_retention"].title, subpage_active.entries["mysql_retention"].description .. "-F mysql;&lt;host|socket&gt;;&lt;dbname&gt;;&lt;table name&gt;;&lt;user&gt;;&lt;pw&gt;.",
    "ntopng.prefs.", "mysql_retention", mysql_retention, "number", not subpage_active.entries["mysql_retention"].hidden, nil, nil, {min=1, max=365*5, --[[ TODO check min/max ]]})
  
  --default value
  minute_top_talkers_retention = 365
  prefsInputFieldPrefs(subpage_active.entries["minute_top_talkers_retention"].title, subpage_active.entries["minute_top_talkers_retention"].description,
      "ntopng.prefs.", "minute_top_talkers_retention", minute_top_talkers_retention, "number", nil, nil, nil, {min=1, max=365*10, --[[ TODO check min/max ]]})
  print('</table>')

  print('<table class="table">')
if show_advanced_prefs and false --[[ hide these settings for now ]] then
  print('<tr><th colspan=2 class="info">Network Interface Timeseries</th></tr>')
  prefsInputFieldPrefs("Days for raw stats", "Number of days for which raw stats are kept. Default: 1.", "ntopng.prefs.", "intf_rrd_raw_days", prefs.intf_rrd_raw_days, "number", nil, nil, nil, {min=1, max=365*5, --[[ TODO check min/max ]]})
  prefsInputFieldPrefs("Days for 1 min resolution stats", "Number of days for which stats are kept in 1 min resolution. Default: 30.", "ntopng.prefs.", "intf_rrd_1min_days", prefs.intf_rrd_1min_days, "number", nil, nil, nil, {min=1, max=365*5, --[[ TODO check min/max ]]})
  prefsInputFieldPrefs("Days for 1 hour resolution stats", "Number of days for which stats are kept in 1 hour resolution. Default: 100.", "ntopng.prefs.", "intf_rrd_1h_days", prefs.intf_rrd_1h_days, "number", nil, nil, nil, {min=1, max=365*5, --[[ TODO check min/max ]]})
  prefsInputFieldPrefs("Days for 1 day resolution stats", "Number of days for which stats are kept in 1 day resolution. Default: 365.", "ntopng.prefs.", "intf_rrd_1d_days", prefs.intf_rrd_1d_days, "number", nil, nil, nil, {min=1, max=365*5, --[[ TODO check min/max ]]})

  print('<tr><th colspan=2 class="info">Protocol/Networks Timeseries</th></tr>')
  prefsInputFieldPrefs("Days for raw stats", "Number of days for which raw stats are kept. Default: 1.", "ntopng.prefs.", "other_rrd_raw_days", prefs.other_rrd_raw_days, "number", nil, nil, nil, {min=1, max=365*5, --[[ TODO check min/max ]]})
  --prefsInputFieldPrefs("Days for 1 min resolution stats", "Number of days for which stats are kept in 1 min resolution. Default: 30.", "ntopng.prefs.", "other_rrd_1min_days", prefs.other_rrd_1min_days)
  prefsInputFieldPrefs("Days for 1 hour resolution stats", "Number of days for which stats are kept in 1 hour resolution. Default: 100.", "ntopng.prefs.", "other_rrd_1h_days", prefs.other_rrd_1h_days, "number", nil, nil, nil, {min=1, max=365*5, --[[ TODO check min/max ]]})
  prefsInputFieldPrefs("Days for 1 day resolution stats", "Number of days for which stats are kept in 1 day resolution. Default: 365.", "ntopng.prefs.", "other_rrd_1d_days", prefs.other_rrd_1d_days, "number", nil, nil, nil, {min=1, max=365*5, --[[ TODO check min/max ]]})

  -- Only shown when toggle_local_activity switch is on
  if prefs.is_flow_activity_enabled then
     print('<tr id="local_activity_prefs"><th colspan=2 class="info">Local Activity Timeseries</th></tr>')
     prefsInputFieldPrefs("Hours for raw stats", "Number of hours for which raw stats are kept. Default: 48.", "ntopng.prefs.", "host_activity_rrd_raw_hours", prefs.host_activity_rrd_raw_hours, "number", nil, nil, nil, {min=1, max=24*7, --[[ TODO check min/max ]]})
     prefsInputFieldPrefs("Days for 1 hour resolution stats", "Number of days for which stats are kept in 1 hour resolution. Default: 15.", "ntopng.prefs.", "host_activity_rrd_1h_days", prefs.host_activity_rrd_1h_days, "number", nil, nil, nil, {min=1, max=365*5, --[[ TODO check min/max ]]})
     prefsInputFieldPrefs("Days for 1 day resolution stats", "Number of days for which stats are kept in 1 day resolution. Default: 90.", "ntopng.prefs.", "host_activity_rrd_1d_days", prefs.host_activity_rrd_1d_days, "number", nil, nil, nil, {min=1, max=365*5, --[[ TODO check min/max ]]})
  end
end
  print('<tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px">'..i18n("save")..'</button></th></tr>')
  print('</table>')

  print [[<input id="csrf" name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />
  </form> ]]
end

-- ================================================================================

function printLogging()
  if prefs.has_cmdl_trace_lvl then return end
  print('<form method="post">')
  print('<table class="table">')
  print('<tr><th colspan=2 class="info">'..i18n("prefs.logging")..'</th></tr>')

  loggingSelector(subpage_active.entries["toggle_logging_level"].title, subpage_active.entries["toggle_logging_level"].description,
        "toggle_logging_level", "ntopng.prefs.logging_level")

  toggleTableButtonPrefs(subpage_active.entries["toggle_access_log"].title, subpage_active.entries["toggle_access_log"].description,
        "On", "1", "success",
        "Off", "0", "danger",
        "toggle_access_log", "ntopng.prefs.enable_access_log", "0")


  print('<tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px">'..i18n("save")..'</button></th></tr>')

  print [[<input id="csrf" name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />
  </form>
  </table>]]
end

function printSnmp()
  if not ntop.isEnterprise() then return end

  print('<form method="post">')
  print('<table class="table">')
  print('<tr><th colspan=2 class="info">SNMP</th></tr>')

  toggleTableButtonPrefs(subpage_active.entries["toggle_snmp_rrds"].title, subpage_active.entries["toggle_snmp_rrds"].description,
			 "On", "1", "success", "Off", "0", "danger", "toggle_snmp_rrds", "ntopng.prefs.snmp_devices_rrd_creation", "0",
			    not info["version.enterprise_edition"])

  prefsInputFieldPrefs(subpage_active.entries["default_snmp_community"].title, subpage_active.entries["default_snmp_community"].description,
		       "ntopng.prefs.",
		       "default_snmp_community",
		       "public", false, nil, nil, nil,  {attributes={spellcheck="false", maxlength=64}})

  print('<tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px">'..i18n("save")..'</button></th></tr>')

  print [[<input id="csrf" name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />
  </form>
  </table>]]
end

function printFlowDBDump()
  print('<form method="post">')
  print('<table class="table">')
  print('<tr><th colspan=2 class="info">'..i18n("prefs.tiny_flows")..'</th></tr>')

  toggleTableButtonPrefs(subpage_active.entries["toggle_flow_db_dump_export"].title, subpage_active.entries["toggle_flow_db_dump_export"].description,
			 "On", "1", "success", "Off", "0", "danger", "toggle_flow_db_dump_export", "ntopng.prefs.flow_db_dump_export_enabled", "1")

  prefsInputFieldPrefs(subpage_active.entries["max_num_packets_per_tiny_flow"].title, subpage_active.entries["max_num_packets_per_tiny_flow"].description,
        "ntopng.prefs.", "max_num_packets_per_tiny_flow", prefs.max_num_packets_per_tiny_flow, "number", true, false, nil, {min=1, max=2^32-1})

  prefsInputFieldPrefs(subpage_active.entries["max_num_bytes_per_tiny_flow"].title, subpage_active.entries["max_num_bytes_per_tiny_flow"].description,
        "ntopng.prefs.", "max_num_bytes_per_tiny_flow", prefs.max_num_bytes_per_tiny_flow, "number", true, false, nil, {min=1, max=2^32-1})

  print('<tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px">'..i18n("save")..'</button></th></tr>')

  print [[<input id="csrf" name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />
  </form>
  </table>]]
end

   print[[
       <table class="table table-bordered">
         <col width="20%">
         <col width="80%">
         <tr><td style="padding-right: 20px;">]]

   print(
      template.gen("typeahead_input.html", {
        typeahead={
          base_id     = "prefs_search",
          action      = "/lua/admin/prefs.lua",
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

for _, subpage in ipairs(menu_subpages) do
  if not subpage.disabled then
    print[[<a href="]] print(ntop.getHttpPrefix()) print[[/lua/admin/prefs.lua?tab=]] print(subpage.id) print[[" class="list-group-item]] if(tab == subpage.id) then print(" active") end print[[">]] print(subpage.label) print[[</a>]]
  end
end

print[[
           </div>
           <br>
           <div align="center">

            <div id="prefs_toggle" class="btn-group">
              <form method="post">
<input id="csrf" name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />
<input type=hidden name="show_advanced_prefs" value="]]if show_advanced_prefs then print("false") else print("true") end print[["/>


<br>
<div class="btn-group btn-toggle">
]]

local cls_on      = "btn btn-sm"
local onclick_on  = ""
local cls_off     = cls_on
local onclick_off = onclick_on
if show_advanced_prefs then
   cls_on  = cls_on..' btn-primary active'
   cls_off = cls_off..' btn-default'
   onclick_off = "this.form.submit();"
else
   cls_on = cls_on..' btn-default'
   cls_off = cls_off..' btn-primary active'
   onclick_on = "this.form.submit();"
end
print('<button type="button" class="'..cls_on..'" onclick="'..onclick_on..'">'..i18n("prefs.expert_view")..'</button>')
print('<button type="button" class="'..cls_off..'" onclick="'..onclick_off..'">'..i18n("prefs.simple_view")..'</button>')

print[[
</div>
              </form>

            </div>

           </div>

        </td><td colspan=2 style="padding-left: 14px;border-left-style: groove; border-width:1px; border-color: #e0e0e0;">]]

if(tab == "report") then
   printReportVisualization()
end

if(tab == "in_memory") then
   printInMemory()
end

if(tab == "on_disk_ts") then
   printStatsTimeseries()
end

if(tab == "alerts") then
   printAlerts()
end

if(tab == "ext_alerts") then
   printExternalAlertsReport()
end

if(tab == "protocols") then
   printProtocolPrefs()
end

if(tab == "nbox") then
  if(ntop.isPro()) then
     printNbox()
  end
end

if(tab == "bridging") then
  if(info["version.enterprise_edition"]) then
     printBridgingPrefs()
  end
end

if(tab == "misc") then
   printMisc()
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
if(tab == "flow_db_dump") then
   printFlowDBDump()
end

print[[
        </td></tr>
      </table>
]]

   dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")

   print([[<script>
aysHandleForm("form");

/* Use the validator plugin to override default chrome bubble, which is displayed out of window */
$("form[id!='search-host-form']").validator({disable:true});
</script>]])

if(_SERVER["REQUEST_METHOD"] == "POST") then
   -- Something has changed
  ntop.reloadPreferences()
end

if(_POST["toggle_malware_probing"] ~= nil) then
  loadHostBlackList(true --[[ force the reload of the list ]])
end

end --[[ haveAdminPrivileges ]]
