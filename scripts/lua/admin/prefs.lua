--
-- (C) 2013-17 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
if((dirs.scriptdir ~= nil) and (dirs.scriptdir ~= "")) then package.path = dirs.scriptdir .. "/lua/modules/?.lua;" .. package.path end
require "lua_utils"
require "prefs_utils"
require "blacklist_utils"

if(ntop.isPro()) then
  package.path = dirs.installdir .. "/scripts/lua/pro/?.lua;" .. package.path
  require "report_utils"
end

sendHTTPHeader('text/html; charset=iso-8859-1')

local show_advanced_prefs = false
local show_advanced_prefs_key = "ntopng.prefs.show_advanced_prefs"

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

   subpage_active = _GET["subpage_active"]
   

   if toboolean(_POST["show_advanced_prefs"]) ~= nil then
      ntop.setPref(show_advanced_prefs_key, _POST["show_advanced_prefs"])
      show_advanced_prefs = toboolean(_POST["show_advanced_prefs"])
      notifyNtopng(show_advanced_prefs_key, _POST["show_advanced_prefs"])
   else
      show_advanced_prefs = toboolean(ntop.getPref(show_advanced_prefs_key))
      if isEmptyString(show_advanced_prefs) then show_advanced_prefs = false end
   end
   
   local menu_subpages = {
      {id="users",         label="Users",                advanced=false, pro_only=false,  disabled=false},
      {id="ifaces",        label="Network Interfaces",   advanced=true,  pro_only=false,  disabled=false},
      {id="in_memory",     label="In-Memory Data",       advanced=true,  pro_only=false,  disabled=false},
      {id="on_disk_rrds",  label="On-Disk Timeseries",   advanced=false, pro_only=false,  disabled=false},
      {id="on_disk_dbs",   label="On-Disk Databases",    advanced=true,  pro_only=false,  disabled=false},
      {id="alerts",        label="Alerts",               advanced=false, pro_only=false,  disabled=(prefs.has_cmdl_disable_alerts == true)},
      {id="protocols",     label="Protocols",            advanced=false, pro_only=false,  disabled=false},
      {id="report",        label="Units of Measurement", advanced=false, pro_only=false,  disabled=false},
      {id="logging",       label="Log Level",            advanced=false, pro_only=false,  disabled=(prefs.has_cmdl_trace_lvl == true)},
      {id="nbox",          label="nBox Integration",     advanced=true,  pro_only=true,   disabled=false},
   }

if(info["version.enterprise_edition"]) then
   table.insert(menu_subpages, {id="bridging",          label="Traffic Bridging",     advanced=false,  pro_only=true,   disabled=false})
end

for _, subpage in ipairs(menu_subpages) do
  if((subpage.disabled) or
     ((subpage.advanced) and (not show_advanced_prefs)) or  -- restore default in case of simple preferences
     ((subpage.pro_only) and (not ntop.isPro()))) then      -- restore default in case of non pro

    subpage.disabled = true
    
    if subpage.id == subpage_active then
      -- will set to default
      subpage_active = nil
    end
  end
end

-- default subpage
if isEmptyString(subpage_active) then
  subpage_active = "users"
end

-- ================================================================================

function printReportVisualization()
  print('<form method="post">')
  print('<table class="table">')
  print('<tr><th colspan=2 class="info">Report Visualization</th></tr>')

  toggleTableButtonPrefs("Throughput Unit",
              "Select the throughput unit to be displayed in traffic reports.",
              "Bytes", "bps", "primary","Packets", "pps", "primary","toggle_thpt_content", "ntopng.prefs.thpt_content", "bps")
  print('<tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px">Save</button></th></tr>')
  print('</table>')
  print [[<input id="csrf" name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />
  </form> ]]
end

-- ================================================================================

function printInterfaces()
  print('<form method="post">')
  print('<table class="table">')
  print('<tr><th colspan=2 class="info">Dynamic Network Interfaces</th></tr>')

  toggleTableButtonPrefs("VLAN Disaggregation",
			    "Toggle the automatic creation of virtual interfaces based on VLAN tags.<p><b>NOTE:</b><ul><li>Value changes will not be effective for existing interfaces.<li>This setting is valid only for packet-based interfaces (no flow collection).</ul>",
			    "On", "1", "success", "Off", "0", "danger", "dynamic_iface_vlan_creation", "ntopng.prefs.dynamic_iface_vlan_creation", "0")
  
  local labels = {"None","Probe IP Address","Ingress Flow Interface"}
  local values = {"none","probe_ip","ingress_iface_idx"}
  local elementToSwitch = {}
  local showElementArray = { true, false, false }
  local javascriptAfterSwitch = "";

  retVal = multipleTableButtonPrefs("Dynamic Flow Collection Interfaces",
				    "When ntopng is used in flow collection mode (e.g. -i tcp://127.0.0.1:1234c), "..
				       "flows can be collected on dynamic sub-interfaces based on the specified criteria.<p><b>NOTE:</b><ul>"..
				    "<li>Value changes will not be effective for existing interfaces.<li>This setting is valid only for based-based interfaces (no packet collection).</ul>",
				    labels, values, "none", "primary", "multiple_flow_collection", "ntopng.prefs.dynamic_flow_collection_mode", nil,
				    elementToSwitch, showElementArray, javascriptAfterSwitch)

  print('<tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px">Save</button></th></tr>')
  print('</table>')
  print [[<input id="csrf" name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />
  </form> ]]
end

-- ================================================================================

function printTopTalkers()
  print('<form method="post">')
  print('<table class="table">')
  print('<tr><th colspan=2 class="info">Top Talkers Storage</th></tr>')

  --default value
  minute_top_talkers_retention = 365
  prefsInputFieldPrefs("Data Retention", "Duration in days of minute top talkers data retention. Default: 365 days", "ntopng.prefs.", "minute_top_talkers_retention", minute_top_talkers_retention, "number", nil, nil, nil, {min=1, max=365*10, --[[ TODO check min/max ]]})

  print('<tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px">Save</button></th></tr>')
  print('</table>')
  print [[<input id="csrf" name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />
  </form> ]]
end

-- ================================================================================

function printStatsDatabases()
  print('<form method="post">')
  print('<table class="table">')
  print('<tr><th colspan=2 class="info">MySQL Database</th></tr>')

  mysql_retention = 30
  prefsInputFieldPrefs("Data Retention", "Duration in days of data retention in the MySQL database. Default: 30 days", "ntopng.prefs.", "mysql_retention", mysql_retention, "number", nil, nil, nil, {min=1, max=365*5, --[[ TODO check min/max ]]})

  toggleTableButtonPrefs("Check open_files_limit",
			 "Toggle the periodic check of MySQL open_files_limit.",
			 "On", "1", "success", "Off", "0", "danger", "toggle_mysql_check_open_files_limit", "ntopng.prefs.mysql_check_open_files_limit", "1")

  print('</table>')
  print('<table class="table">')
  print('<tr><th colspan=2 class="info">Top Talkers Storage</th></tr>')

  --default value
  minute_top_talkers_retention = 365
  prefsInputFieldPrefs("Data Retention", "Duration in days of minute top talkers data retention. Default: 365 days", "ntopng.prefs.", "minute_top_talkers_retention", minute_top_talkers_retention, "number", nil, nil, nil, {min=1, max=365*10, --[[ TODO check min/max ]]})

  print('<tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px">Save</button></th></tr>')
  print('</table>')
  print [[<input id="csrf" name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />
  </form> ]]
end

-- ================================================================================

function printAlerts()
   if prefs.has_cmdl_disable_alerts then return end
  print('<form method="post">')
  print('<table class="table">')
  print('<tr><th colspan=2 class="info">Alerts</th></tr>')

 if ntop.getPref("ntopng.prefs.disable_alerts_generation") == "1" then
      showElements = true
  else
      showElements = false
  end

 local elementToSwitch = { "max_num_alerts_per_entity", "max_num_flow_alerts", "row_toggle_alert_probing", "toggle_malware_probing", "row_toggle_alert_syslog" }

  toggleTableButtonPrefs("Enable Alerts",
                    "Toggle the overall generation of alerts.",
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


  prefsInputFieldPrefs("Maximum Number of Alerts per Entity",
		       "The maximum number of alerts per alarmable entity. Alarmable entities are hosts, networks, interfaces and flows. "..
		       "Once the maximum number of entity alerts is reached, oldest alerts will be overwritten. "..
			  "Default: 1024.", "ntopng.prefs.", "max_num_alerts_per_entity", prefs.max_num_alerts_per_entity, "number", showElements, false, nil, {min=1, --[[ TODO check min/max ]]})

  prefsInputFieldPrefs("Maximum Number of Flow Alerts",
		       "The maximum number of flow alerts. Once the maximum number of alerts is reached, oldest alerts will be overwritten. "..
			  "Default: 16384.", "ntopng.prefs.", "max_num_flow_alerts", prefs.max_num_flow_alerts, "number", showElements, false, nil, {min=1, --[[ TODO check min/max ]]})

  toggleTableButtonPrefs("Enable Probing Alerts",
                    "Enable alerts generated when probing attempts are detected.",
                    "On", "1", "success",
		    "Off","0", "danger",
		    "toggle_alert_probing", "ntopng.prefs.probing_alerts", "0",
		    false, nil, nil, showElements)

  toggleTableButtonPrefs("Dump Flow Alerts",
                    "Enable flow alert generation when the network interface is alerted.",
                    "On", "1", "success",
		    "Off","0", "danger",
		    "toggle_flow_alerts_iface", "ntopng.alerts.dump_alerts_when_iface_is_alerted", "0",
		    false, nil, nil, showElements)

  toggleTableButtonPrefs("Enable Hosts Malware Blacklists",
                    "Enable alerts generated by traffic sent/received by <A HREF=https://rules.emergingthreats.net/fwrules/emerging-Block-IPs.txt>malware-marked hosts</A>. Overnight new blacklist rules are refreshed.",
                    "On", "enabled", "success",
		    "Off","disabled", "danger",
		    "toggle_malware_probing", "ntopng.prefs.host_blacklist", "1",
		    false, nil, nil, showElements)

  toggleTableButtonPrefs("Alerts On Syslog",
                    "Enable alerts logging on system syslog.",
                    "On", "1", "success",
		    "Off", "0", "danger",
		    "toggle_alert_syslog", "ntopng.prefs.alerts_syslog", "0",
		    false, nil, nil, showElements)

   print('<tr><th colspan=2 class="info"><i class="fa fa-slack" aria-hidden="true"></i> Slack Integration</th></tr>')

   local elementToSwitchSlack = {"row_slack_notification_severity_preference", "sender_username", "slack_webhook"}

   toggleTableButtonPrefs("Enable <A HREF=http://www.slack.com>Slack</A> Notification",
                    "Toggle the alert notification via slack.",
                    "On", "1", "success", -- On  means alerts enabled and thus disable_alerts_generation == 0
		    "Off", "0", "danger", -- Off for enabled alerts implies 1 for disable_alerts_generation
		    "toggle_slack_notification", "ntopng.alerts.notification_enabled", "0", showElements==false, elementToSwitchSlack)

  local showSlackNotificationPrefs = false
  if ntop.getPref("ntopng.alerts.notification_enabled") == "1" then
     showSlackNotificationPrefs = true
  else
     showSlackNotificationPrefs = false
  end

  local labels = {"Errors","Errors and Warnings","All"}
  local values = {"only_errors","errors_and_warnings","all_alerts"}

  local retVal = multipleTableButtonPrefs("Notification Preference Based On Severity",
               "Errors (errors only), Errors and Warnings (errors and warnings, no info), All (every kind of alerts will be notified).",
               labels, values, "only_errors", "primary", "slack_notification_severity_preference",
	       "ntopng.alerts.slack_alert_severity", nil, nil, nil,  nil, showElements and showSlackNotificationPrefs)

  prefsInputFieldPrefs("Notification Sender Username",
		       "Set the username of the sender of slack notifications", "ntopng.alerts.", "sender_username",
		       "ntopng Webhook", nil, showElements and showSlackNotificationPrefs, false, nil, {attributes={spellcheck="false"}})

  prefsInputFieldPrefs("Notification Webhook",
		       "Send your notification to this slack URL", "ntopng.alerts.", "slack_webhook",
		       "", nil, showElements and showSlackNotificationPrefs, true, true, {attributes={spellcheck="false"}})


  if(ntop.isPro()) then
    print('<tr><th colspan=2 class="info">Nagios Integration</th></tr>')

    local alertsEnabled = showElements

    local elementToSwitch = {"nagios_nsca_host","nagios_nsca_port","nagios_send_nsca_executable","nagios_send_nsca_config","nagios_host_name","nagios_service_name"}

    toggleTableButtonPrefs("Send Alerts To Nagios",
                    "Enable sending ntopng alerts to Nagios NSCA (Nagios Service Check Acceptor).",
                    "On", "1", "success",
		    "Off", "0", "danger",
		    "toggle_alert_nagios", "ntopng.prefs.alerts_nagios", "0",
                    alertsEnabled==false,
		    elementToSwitch)

    if ntop.getPref("ntopng.prefs.alerts_nagios") == "0" then
      showElements = false
    end
    showElements = alertsEnabled and showElements

    prefsInputFieldPrefs("Nagios NSCA Host", "Address of the host where the Nagios NSCA daemon is running. Default: localhost.", "ntopng.prefs.", "nagios_nsca_host", prefs.nagios_nsca_host, nil, showElements, false)
    prefsInputFieldPrefs("Nagios NSCA Port", "Port where the Nagios daemon's NSCA is listening. Default: 5667.", "ntopng.prefs.", "nagios_nsca_port", prefs.nagios_nsca_port, "number", showElements, false, nil, {min=1, max=65535})
    prefsInputFieldPrefs("Nagios send_nsca executable", "Absolute path to the Nagios NSCA send_nsca utility. Default: /usr/local/nagios/bin/send_nsca", "ntopng.prefs.", "nagios_send_nsca_executable", prefs.nagios_send_nsca_executable, nil, showElements, false)
    prefsInputFieldPrefs("Nagios send_nsca configuration", "Absolute path to the Nagios NSCA send_nsca utility configuration file. Default: /usr/local/nagios/etc/send_nsca.cfg", "ntopng.prefs.", "nagios_send_nsca_config", prefs.nagios_send_nsca_conf, nil, showElements, false)
    prefsInputFieldPrefs("Nagios host_name", "The host_name exactly as specified in Nagios host definition for the ntopng host. Default: ntopng-host", "ntopng.prefs.", "nagios_host_name", prefs.nagios_host_name, nil, showElements, false)
    prefsInputFieldPrefs("Nagios service_description", "The service description exactly as specified in Nagios passive service definition for the ntopng host. Default: NtopngAlert", "ntopng.prefs.", "nagios_service_name", prefs.nagios_service_name, nil, showElements)
  end

  print('<tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px">Save</button></th></tr>')
  print('</table>')
  print [[<input id="csrf" name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />
  </form> ]]
end

-- ================================================================================

function printProtocolPrefs()
  print('<form method="post">')

  print('<table class="table">')

  print('<tr><th colspan=2 class="info">HTTP</th></tr>')

  toggleTableButtonPrefs("Top HTTP Sites",
        "Toggle the creation of top visited sites for local hosts. This may increase the disk usage.",
        "On", "1", "success",
        "Off", "0", "danger",
        "toggle_top_sites", "ntopng.prefs.host_top_sites_creation", "0")

  print('<tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px">Save</button></th></tr>')

  print('</table>')
  print [[<input id="csrf" name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />
  </form> ]]
end

-- ================================================================================

function printBridgingPrefs()
  print('<form method="post">')

  print('<table class="table">')

  print('<tr><th colspan=2 class="info">User Authentication</th></tr>')

  toggleTableButtonPrefs("Captive Portal",
        "Enable the web captive portal for authenticating network users.",
        "On", "1", "success",
        "Off", "0", "danger",
        "toggle_captive_portal", "ntopng.prefs.enable_captive_portal", "0")

  print('<tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px">Save</button></th></tr>')

  print('</table>')
  print [[<input id="csrf" name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />
  </form> ]]
end

-- ================================================================================

function printNbox()
  print('<form method="post">')
  print('<table class="table">')

  print('<tr><th colspan=2 class="info">nBox Integration</th></tr>')

  local elementToSwitch = {"nbox_user","nbox_password"}

  toggleTableButtonPrefs("Enable nBox Support",
        "Enable sending ntopng requests (e.g., to download pcap files) to an nBox. Pcap requests are issued from the historical data browser when browsing 'Talkers' and 'Protocols'. Each request carry information on the search criteria generated by the user when drilling-down historical data. Requests are queued and pcaps become available for download from a dedicated 'Pcaps' tab once generated.",
        "On", "1", "success", "Off", "0", "danger", "toggle_nbox_integration", "ntopng.prefs.nbox_integration", "0", nil, elementToSwitch)

  if ntop.getPref("ntopng.prefs.nbox_integration") == "1" then
    showElements = true
  else
    showElements = false
  end

  prefsInputFieldPrefs("nBox User", "User that has privileges to access the nBox. Default: nbox", "ntopng.prefs.", "nbox_user", "nbox", nil, showElements, false)
  prefsInputFieldPrefs("nBox Password", "Password associated to the nBox user. Default: nbox", "ntopng.prefs.", "nbox_password", "nbox", "password", showElements, false)

  print('<tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px">Save</button></th></tr>')

  print('</table>')
  print [[<input id="csrf" name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />
  </form> ]]
end

-- ================================================================================

function printUsers()
  print('<form method="post">')
  print('<table class="table">')

  print('<tr><th colspan=2 class="info">Web User Interface</th></tr>')
  if prefs.is_autologout_enabled == true then
     toggleTableButtonPrefs("Auto Logout",
			    "Toggle the automatic logout of web interface users with expired sessions.",
			    "On", "1", "success", "Off", "0", "danger", "toggle_autologout", "ntopng.prefs.is_autologon_enabled", "1")
  end
  prefsInputFieldPrefs("Google APIs Browser Key",
		       "Graphical hosts geomaps are based on Google Maps APIs. Google recently changed Maps API access policies "..
		       "and now requires a browser API key to be sumbitted for every request. Detailed information on how to obtain an API key "..
		       "<a href=\"https://googlegeodevelopers.blogspot.it/2016-17/06/building-for-scale-updates-to-google.html\">can be found here</a>. "..
                       "Once obtained, the API key can be placed in this field."
		       ,
		       "ntopng.prefs.",
		       "google_apis_browser_key",
		       "", false, nil, nil, nil, {style={width="25em;"}, attributes={spellcheck="false"} --[[ Note: Google API keys can vary in format ]] })

  if ntop.isPro() then
     print('<tr><th colspan=2 class="info">Authentication</th></tr>')
     local labels = {"Local","LDAP","LDAP/Local"}
     local values = {"local","ldap","ldap_local"}
     local elementToSwitch = {"row_multiple_ldap_account_type", "row_toggle_ldap_anonymous_bind","server","bind_dn", "bind_pwd", "search_path", "user_group", "admin_group"}
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
     local retVal = multipleTableButtonPrefs("Authentication Method",
					     "Local (Local only), LDAP (LDAP server only), LDAP/Local (Authenticate with LDAP server, if fails it uses local authentication).",
					     labels, values, "local", "primary", "multiple_ldap_authentication", "ntopng.prefs.auth_type", nil,
					     elementToSwitch, showElementArray, javascriptAfterSwitch)

     local showElements = true;
     if ntop.getPref("ntopng.prefs.auth_type") == "local" then
	showElements = false
     end

     local labels_account = {"Posix","sAMAccount"}
     local values_account = {"posix","samaccount"}
     multipleTableButtonPrefs("LDAP Accounts Type",
			      "Choose your account type",
			      labels_account, values_account, "posix", "primary", "multiple_ldap_account_type", "ntopng.prefs.ldap.account_type", nil, nil, nil, nil, showElements)

     prefsInputFieldPrefs("LDAP Server Address", "IP address and port of LDAP server (e.g. ldaps://localhost:636). Default: \"ldap://localhost:389\".", "ntopng.prefs.ldap", "server", "ldap://localhost:389", nil, showElements, true, true, {attributes={pattern="ldap(s)?://[0-9.\\-A-Za-z]+(:[0-9]+)?", spellcheck="false", required="required"}})

     local elementToSwitchBind = {"bind_dn","bind_pwd"}
     toggleTableButtonPrefs("LDAP Anonymous Binding","Enable anonymous binding.","On", "1", "success", "Off", "0", "danger", "toggle_ldap_anonymous_bind", "ntopng.prefs.ldap.anonymous_bind", "0", nil, elementToSwitchBind, true, showElements)

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
     print('<input style="display:none;" type="password" name="__" data-ays-ignore="true" />')
     --
     prefsInputFieldPrefs("LDAP Bind DN", "Bind Distinguished Name of LDAP server. Example: \"CN=ntop_users,DC=ntop,DC=org,DC=local\".", "ntopng.prefs.ldap", "bind_dn", "", nil, showElementsBind, true, false, {attributes={spellcheck="false"}})
     prefsInputFieldPrefs("LDAP Bind Authentication Password", "Bind password used for authenticating with the LDAP server.", "ntopng.prefs.ldap", "bind_pwd", "", "password", showElementsBind, true, false)

     prefsInputFieldPrefs("LDAP Search Path", "Root path used to search the users.", "ntopng.prefs.ldap", "search_path", "", "text", showElements, nil, nil, {attributes={spellcheck="false"}})
     prefsInputFieldPrefs("LDAP User Group", "Group name to which user has to belong in order to authenticate as unprivileged user.", "ntopng.prefs.ldap", "user_group", "", "text", showElements, nil, nil, {attributes={spellcheck="false"}})
     prefsInputFieldPrefs("LDAP Admin Group", "Group name to which user has to belong in order to authenticate as an administrator.", "ntopng.prefs.ldap", "admin_group", "", "text", showElements, nil, nil, {attributes={spellcheck="false"}})

  end
  print('<tr><th colspan=2 style="text-align:right;"><button type="submit" onclick="return save_button_users();" class="btn btn-primary" style="width:115px">Save</button></th></tr>')
  print('</table>')

  print [[<input id="csrf" name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />
  </form>
  <script>
    function save_button_users(){
      if(typeof $("#id-toggle-multiple_ldap_authentication").val() !== 'undefined'
          && $("#id-toggle-multiple_ldap_authentication").val() != "local") {
        var field = $("#id_input_server").val();

        if((field.substring(0, 7) != "ldap://") && (field.substring(0, 8) != "ldaps://")) {
          alert("Invalid LDAP Server Address Value: missing \"ldap://\" or \"ldaps://\" at beginning.");
          return false;
        }

        var new_field = field.replace('ldaps://', '');
        new_field = new_field.replace('ldap://', '');
        var res = new_field.split(":");
        if(res.length != 2){
          alert("Invalid LDAP Server Address Value: missing ldap server address or port number.");
          return false;
        }
      }

      /* do submit */
      return true;
    }
  </script>
  ]]
end

-- ================================================================================

function printInMemory()
  print('<form method="post">')
  print('<table class="table">')

  print('<tr><th colspan=2 class="info">Idle Timeout Settings</th></tr>')
  prefsInputFieldPrefs("Local Host Idle Timeout", "Inactivity time after which a local host is considered idle (sec). "..
		          "Idle local hosts are dumped to a cache so their counters can be restored in case they become active again. "..
			  "Counters include, but are not limited to, packets and bytes total and per Layer-7 application. "..
			  "Default: 5 min.", "ntopng.prefs.","local_host_max_idle", prefs.local_host_max_idle, "number", nil, nil, nil, {min=1, max=3600, tformat="smh" --[[ TODO check min/max ]]})
  prefsInputFieldPrefs("Remote Host Idle Timeout", "Inactivity time after which a remote host is considered idle. Default: 1 min.", "ntopng.prefs.", "non_local_host_max_idle", prefs.non_local_host_max_idle, "number", nil, nil, nil, {min=1, max=3600, tformat="smh" --[[ TODO check min/max ]]})
  prefsInputFieldPrefs("Flow Idle Timeout", "Inactivity time after which a flow is considered idle. Default: 1 min.", "ntopng.prefs.", "flow_max_idle", prefs.flow_max_idle, "number", nil, nil, nil, {min=1, max=3600, tformat="smh" --[[ TODO check min/max ]]})

  print('<tr><th colspan=2 class="info">Local Hosts Cache Settings</th></tr>')
  toggleTableButtonPrefs("Idle Local Hosts Cache",
			 "Toggle the creation of cache entries for idle local hosts. "..
			 "Cached local hosts counters are restored automatically to their previous values "..
			    " upon detection of additional host traffic.",
			 "On", "1", "success", "Off", "0", "danger",
			 "toggle_local_host_cache_enabled",
			 "ntopng.prefs.is_local_host_cache_enabled", "1")

  toggleTableButtonPrefs("Active Local Hosts Cache",
			 "Toggle the hourly creation of cache entries for active local hosts. "..
			 "Caching active local hosts on an hourly basis can be useful to protect host counters against "..
			 "failures (e.g., power losses). This is particularly important for local hosts that seldomly go idle "..
			 "as it guarantees that their counters will be cached at least once per hour.  ",
			 "On", "1", "success", "Off", "0", "danger",
			 "toggle_active_local_host_cache_enabled",
			 "ntopng.prefs.is_active_local_host_cache_enabled", "0")
  prefsInputFieldPrefs("Local Hosts Cache Duration", "Time after which a cached local host is deleted from the cache. "..
			 "Default: 1 hour.", "ntopng.prefs.","local_host_cache_duration", prefs.local_host_cache_duration, "number", nil, nil, nil, {min=60, max=60*60*24*60, tformat="smhd" --[[ TODO check min/max ]]})

  print('<tr><th colspan=2 class="info">Hosts Statistics Update Frequency</th></tr>')
  prefsInputFieldPrefs("Update frequency",
		       "Some host statistics such as throughputs are updated periodically. "..
			  "This value regulates how often ntopng will update these statistics. "..
			  "Larger values are less computationally intensive and tend to average out minor variations. "..
			  "Smaller values are more computationally intensive and tend to highlight minor variations. "..
			  "Values in the order of few secods are safe. " ..
			  "Default: 5 seconds.",
		       "ntopng.prefs.", "housekeeping_frequency", prefs.housekeeping_frequency, "number", nil, nil, nil, {min=1, max=3600, tformat="smh" --[[ TODO check min/max ]]})

  print('<tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px">Save</button></th></tr>')
  print('</table>')
  print [[<input id="csrf" name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />
  </form> ]]
end

-- ================================================================================

function printStatsRrds()
  print('<form method="post">')
  print('<table class="table">')
  print('<tr><th colspan=2 class="info">Local Hosts and Networks Timeseries</th></tr>')

  toggleTableButtonPrefs("Traffic Timeseries",
			 "Toggle the creation of traffic timeseries for local hosts and networks. Turn it off to save storage space.",
			 "On", "1", "success", "Off", "0", "danger", "toggle_local", "ntopng.prefs.host_rrd_creation", "1")

  toggleTableButtonPrefs("Layer-7 Application Timeseries",
			 "Toggle the creation of nDPI timeseries for local hosts and defined networks. Enable their creation allows you "..
			    "to keep application protocol statistics at the cost of using more disk space.",
			 "On", "1", "success", "Off", "0", "danger", "toggle_local_ndpi", "ntopng.prefs.host_ndpi_rrd_creation", "0")

 local toggle_local_activity = "toggle_local_activity"
  local activityPrefsToSwitch = {"local_activity_prefs",
    "host_activity_rrd_raw_hours", "id_input_host_activity_rrd_raw_hours",
    "host_activity_rrd_1h_days", "id_input_host_activity_rrd_1h_days",
    "host_activity_rrd_1d_days", "id_input_host_activity_rrd_1d_days"}

  if prefs.is_flow_activity_enabled then
    toggleTableButtonPrefs("Activities Timeseries",
			 "Toggle the creation of activities timeseries for local hosts and networks. Turn it off to save storage space.",
  	 	         "On", "1", "success", "Off", "0", "danger", toggle_local_activity, "ntopng.prefs.host_activity_rrd_creation", "0",
                         false, activityPrefsToSwitch, false)
  end

  local info = ntop.getInfo()
  toggleTableButtonPrefs("Flow Devices Timeseries",
			 "Toggle the creation of bytes timeseries for each port of the sFlow/NetFlow devices. For each device port" ..
			 " will be created an RRD with ingress/egress bytes.",
			 "On", "1", "success", "Off", "0", "danger", "toggle_flow_rrds", "ntopng.prefs.flow_devices_rrd_creation", "0",
			    not info["version.enterprise_edition"])

  toggleTableButtonPrefs("Category Timeseries",
			 "Toggle the creation of Category timeseries for local hosts and defined networks. Enabling their creation allows you "..
			    "to keep persistent traffic category statistics (e.g., social networks, news) at the cost of using more disk space.<br>"..
			 "Creation is only possible if the ntopng instance has been launched with option -k flashstart:&lt;user&gt;:&lt;password&gt;.",
			 "On", "1", "success", "Off", "0", "danger", "toggle_local_categorization",
			 "ntopng.prefs.host_categories_rrd_creation", "0", not prefs.is_categorization_enabled)
  print('</table>')

  print('<table class="table">')
if show_advanced_prefs then
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
  print('<tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px">Save</button></th></tr>')
  print('</table>')

  print [[<input id="csrf" name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />
  </form> ]]
end

-- ================================================================================

function printLogging()
  if prefs.has_cmdl_trace_lvl then return end
  print('<form method="post">')
  print('<table class="table">')
  print('<tr><th colspan=2 class="info">Logging</th></tr>')

  loggingSelector("Log level", "Choose the runtime logging level.", "toggle_logging_level", "ntopng.prefs.logging_level")

  print('<tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px">Save</button></th></tr>')

  print [[<input id="csrf" name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />
  </form>
  </table>]]
end

   print[[
       <table class="table table-bordered">
         <col width="20%">
         <col width="80%">
         <tr><td style="padding-right: 20px;">

           <div class="list-group">]]

for _, subpage in ipairs(menu_subpages) do
  if not subpage.disabled then
    print[[<a href="]] print(ntop.getHttpPrefix()) print[[/lua/admin/prefs.lua?subpage_active=]] print(subpage.id) print[[" class="list-group-item]] if(subpage_active == subpage.id) then print(" active") end print[[">]] print(subpage.label) print[[</a>]]
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
print('<button type="button" class="'..cls_on..'" onclick="'..onclick_on..'">Expert View</button>')
print('<button type="button" class="'..cls_off..'" onclick="'..onclick_off..'">Simple View</button>')

print[[
</div>
              </form>

            </div>

           </div>

        </td><td colspan=2 style="padding-left: 14px;border-left-style: groove; border-width:1px; border-color: #e0e0e0;">]]

if(subpage_active == "report") then
   printReportVisualization()
end

if(subpage_active == "in_memory") then
   printInMemory()
end

if(subpage_active == "on_disk_rrds") then
   printStatsRrds()
end

if(subpage_active == "on_disk_dbs") then
   printStatsDatabases()
end

if(subpage_active == "alerts") then
   printAlerts()
end

if(subpage_active == "protocols") then
   printProtocolPrefs()
end

if(subpage_active == "nbox") then
  if(ntop.isPro()) then
     printNbox()
  end
end

if(subpage_active == "bridging") then
  if(info["version.enterprise_edition"]) then
     printBridgingPrefs()
  end
end

if(subpage_active == "users") then
   printUsers()
end
if(subpage_active == "ifaces") then
   printInterfaces()
end
if(subpage_active == "logging") then
   printLogging()
end

print[[
        </td></tr>
      </table>
]]

   dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")

   print([[<script>
aysHandleForm("form[id!='search-host-form']");

/* Use the validator plugin to override default chrome bubble, which is displayed out of window */
$("form[id!='search-host-form']").validator({disable:true});
</script>]])

if(_SERVER["REQUEST_METHOD"] == "POST") then
   -- Something has changed
  ntop.reloadPreferences()
  io.write("$$$$$$$$$$$ RELOAD $$$$$$$$$$$")
end

if(_POST["toggle_malware_probing"] ~= nil) then
  loadHostBlackList(true --[[ force the reload of the list ]])
end

end --[[ haveAdminPrivileges ]]
