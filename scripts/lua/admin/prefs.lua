--
-- (C) 2013-16 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
if ( (dirs.scriptdir ~= nil) and (dirs.scriptdir ~= "")) then package.path = dirs.scriptdir .. "/lua/modules/?.lua;" .. package.path end
require "lua_utils"
require "prefs_utils"

if (ntop.isPro()) then
  package.path = dirs.installdir .. "/scripts/lua/pro/?.lua;" .. package.path
  require "report_utils"
end

sendHTTPHeader('text/html; charset=iso-8859-1')

if(haveAdminPrivileges()) then
   ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")

   active_page = "admin"
   dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

   prefs = ntop.getPrefs()

   print [[
	    <h2>Runtime Preferences</h2>
      ]]

subpage_active = _GET["subpage_active"]

report_active = ""
in_memory_active = ""
on_disk_rrds_active = ""
on_disk_dbs_active = ""
nbox_active = ""
alerts_active = ""
users_active = ""
logging_active = ""

if (subpage_active == nil or subpage_active == "") then
  subpage_active = "users"
end

if (subpage_active == "report") then
   report_active = "active"
end
if (subpage_active == "in_memory") then
   in_memory_active = "active"
end
if (subpage_active == "on_disk_rrds") then
   on_disk_rrds_active = "active"
end
if (subpage_active == "on_disk_dbs") then
   on_disk_dbs_active = "active"
end
if (subpage_active == "nbox") then
   nbox_active = "active"
end
if (subpage_active == "alerts") then
   if not prefs.has_cmdl_disable_alerts then
      alerts_active = "active"
   else
      report_active = "active" -- default
   end
end
if (subpage_active == "users") then
   users_active = "active"
end
if (subpage_active == "logging") then
   if not prefs.has_cmdl_trace_lvl then
      logging_active = "active"
   else
      -- cannot change logging level when it has been specified from the command line
      report_active = "active" -- default
   end
end


-- ================================================================================
function printReportVisualization()
  print('<form>')
  print('<input type=hidden name="subpage_active" value="report"/>\n')
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
function printTopTalkers()
  print('<form>')
  print('<input type=hidden name="subpage_active" value="top_talkers"/>\n')
  print('<table class="table">')
  print('<tr><th colspan=2 class="info">Top Talkers Storage</th></tr>')

  --default value
  minute_top_talkers_retention = 365
  prefsInputFieldPrefs("Data Retention", "Duration in days of minute top talkers data retention. Default: 365 days", "ntopng.prefs.", "minute_top_talkers_retention", minute_top_talkers_retention)

  print('<tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px">Save</button></th></tr>')
  print('</table>')
  print [[<input id="csrf" name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />
  </form> ]]
end

-- ================================================================================
function printStatsDatabases()
  print('<form>')
  print('<input type=hidden name="subpage_active" value="on_disk_dbs"/>\n')
  print('<table class="table">')
  print('<tr><th colspan=2 class="info">MySQL Database</th></tr>')

  mysql_retention = 30
  prefsInputFieldPrefs("Data Retention", "Duration in days of data retention in the MySQL database. Default: 30 days", "ntopng.prefs.", "mysql_retention", mysql_retention)

  print('</table>')
  print('<table class="table">')
  print('<tr><th colspan=2 class="info">Top Talkers Storage</th></tr>')

  --default value
  minute_top_talkers_retention = 365
  prefsInputFieldPrefs("Data Retention", "Duration in days of minute top talkers data retention. Default: 365 days", "ntopng.prefs.", "minute_top_talkers_retention", minute_top_talkers_retention)

  print('<tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px">Save</button></th></tr>')
  print('</table>')
  print [[<input id="csrf" name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />
  </form> ]]
end

-- ================================================================================
function printAlerts()
   if prefs.has_cmdl_disable_alerts then return end
  print('<form>')
  print('<input type=hidden name="subpage_active" value="alerts"/>\n')
  print('<table class="table">')
  print('<tr><th colspan=2 class="info">Alerts</th></tr>')

  toggleTableButtonPrefs("Enable Alerts",
                    "Toggle the overall generation of alerts.",
                    "On", "0", "success", -- On  means alerts enabled and thus disable_alerts_generation == 0
		    "Off", "1", "danger", -- Off for enabled alerts implies 1 for disable_alerts_generation
		    "disable_alerts_generation", "ntopng.prefs.disable_alerts_generation", "0")

  if ntop.getPrefs().are_alerts_enabled == true then
     showElements = false
  else
     showElements = true
  end

  toggleTableButtonPrefs("Enable Probing Alerts",
                    "Enable alerts generated when probing attempts are detected.",
                    "On", "1", "success",
		    "Off","0", "danger",
		    "toggle_alert_probing", "ntopng.prefs.probing_alerts", "1",
		    showElements)

  toggleTableButtonPrefs("Alerts On Syslog",
                    "Enable alerts logging on system syslog.",
                    "On", "1", "success",
		    "Off", "0", "danger",
		    "toggle_alert_syslog", "ntopng.prefs.alerts_syslog", "1",
		    showElements)

  if (ntop.isPro()) then
    print('<tr><th colspan=2 class="info">Nagios Integration</th></tr>')

    local elementToSwitch = {"nagios_nsca_host","nagios_nsca_port","nagios_send_nsca_executable","nagios_send_nsca_config","nagios_host_name","nagios_service_name"}

    toggleTableButtonPrefs("Alerts To Nagios",
                    "Enable sending ntopng alerts to Nagios NSCA (Nagios Service Check Acceptor).",
                    "On", "1", "success",
		    "Off", "0", "danger",
		    "toggle_alert_nagios", "ntopng.prefs.alerts_nagios", "0",
		    showElements,
		    elementToSwitch)

    if ntop.getPref("ntopng.prefs.alerts_nagios") == "1" then
      showElements = true
    else
      showElements = false
    end

    prefsInputFieldPrefs("Nagios NSCA Host", "Address of the host where the Nagios NSCA daemon is running. Default: localhost.", "ntopng.prefs.", "nagios_nsca_host", prefs.nagios_nsca_host, nil, showElements)
    prefsInputFieldPrefs("Nagios NSCA Port", "Port where the Nagios daemon's NSCA is listening. Default: 5667.", "ntopng.prefs.", "nagios_nsca_port", prefs.nagios_nsca_port, nil, showElements)
    prefsInputFieldPrefs("Nagios send_nsca executable", "Absolute path to the Nagios NSCA send_nsca utility. Default: /usr/local/nagios/bin/send_nsca", "ntopng.prefs.", "nagios_send_nsca_executable", prefs.nagios_send_nsca_executable, nil, showElements)
    prefsInputFieldPrefs("Nagios send_nsca configuration", "Absolute path to the Nagios NSCA send_nsca utility configuration file. Default: /usr/local/nagios/etc/send_nsca.cfg", "ntopng.prefs.", "nagios_send_nsca_config", prefs.nagios_send_nsca_conf, nil, showElements)
    prefsInputFieldPrefs("Nagios host_name", "The host_name exactly as specified in Nagios host definition for the ntopng host. Default: ntopng-host", "ntopng.prefs.", "nagios_host_name", prefs.nagios_host_name, nil, showElements)
    prefsInputFieldPrefs("Nagios service_description", "The service description exactly as specified in Nagios passive service definition for the ntopng host. Default: NtopngAlert", "ntopng.prefs.", "nagios_service_name", prefs.nagios_service_name, nil, showElements)
  end

  print('<tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px">Save</button></th></tr>')
  print('</table>')
  print [[<input id="csrf" name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />
  </form> ]]
end

-- ================================================================================
function printNbox()
  print('<form>')
  print('<input type=hidden name="subpage_active" value="nbox"/>\n')
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

  prefsInputFieldPrefs("nBox User", "User that has privileges to access the nBox. Default: nbox", "ntopng.prefs.", "nbox_user", "nbox", nil, showElements)
  prefsInputFieldPrefs("nBox Password", "Password associated to the nBox user. Default: nbox", "ntopng.prefs.", "nbox_password", "nbox", "password", showElements)

  print('<tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px">Save</button></th></tr>')

  print('</table>')
  print [[<input id="csrf" name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />
  </form> ]]
end

-- ================================================================================
function printUsers()
  print('<form id="form_ldap">')
  print('<input type=hidden name="subpage_active" value="users"/>\n')
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
		       "<a href=\"https://googlegeodevelopers.blogspot.it/2016/06/building-for-scale-updates-to-google.html\">can be found here</a>. "..
                       "Once obtained, the API key can be placed in this field."
		       ,
		       "ntopng.prefs.",
		       "google_apis_browser_key",
		       "")

  if ntop.isPro() then

     print('<tr><th colspan=2 class="info">Authentication</th></tr>')
     local labels = {"Local","LDAP","LDAP/Local"}
     local values = {"local","ldap","ldap_local"}
     local elementToSwitch = {"row_multiple_ldap_account_type", "row_toggle_ldap_anonymous_bind","server","bind_dn", "bind_pwd", "search_path", "user_group", "admin_group"}
     local showElementArray = {false, true, true}
     local javascriptAfterSwitch = "";
     javascriptAfterSwitch = javascriptAfterSwitch.."  if ($(\"#id-toggle-multiple_ldap_authentication\").val() != \"local\"  ) {\n"
     javascriptAfterSwitch = javascriptAfterSwitch.."    if ($(\"#toggle_ldap_anonymous_bind_input\").val() == \"0\") {\n"
     javascriptAfterSwitch = javascriptAfterSwitch.."      $(\"#bind_dn\").css(\"display\",\"table-row\");\n"
     javascriptAfterSwitch = javascriptAfterSwitch.."      $(\"#bind_pwd\").css(\"display\",\"table-row\");\n"
     javascriptAfterSwitch = javascriptAfterSwitch.."    } else {\n"
     javascriptAfterSwitch = javascriptAfterSwitch.."      $(\"#bind_dn\").css(\"display\",\"none\");\n"
     javascriptAfterSwitch = javascriptAfterSwitch.."      $(\"#bind_pwd\").css(\"display\",\"none\");\n"
     javascriptAfterSwitch = javascriptAfterSwitch.."    }\n"
     javascriptAfterSwitch = javascriptAfterSwitch.."  }\n"
     local retVal = multipleTableButtonPrefs("Authentication Method",
					     "Local (Local only), LDAP (LDAP server only), LDAP/Local (Authenticate with LDAP server, if fails it uses local authentication).",
					     labels, values, "local", "primary", "multiple_ldap_authentication", "ntopng.prefs.auth_type", nil,  elementToSwitch, showElementArray, javascriptAfterSwitch)

     local showElements = true;
     if ntop.getPref("ntopng.prefs.auth_type") == "local" then
	showElements = false
     end

     local labels_account = {"Posix","sAMAccount"}
     local values_account = {"posix","samaccount"}
     multipleTableButtonPrefs("LDAP Accounts Type",
			      "Choose your account type",
			      labels_account, values_account, "posix", "primary", "multiple_ldap_account_type", "ntopng.prefs.ldap.account_type", nil, nil, nil, nil, showElements)

     prefsInputFieldPrefs("LDAP Server Address", "IP address and port of LDAP server (e.g. ldaps://localhost:636). Default: \"ldap://localhost:389\".", "ntopng.prefs.ldap", "server", "ldap://localhost:389", nil, showElements)

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
     prefsInputFieldPrefs("LDAP Bind DN", "Bind Distinguished Name of LDAP server. Example: \"CN=ntop_users,DC=ntop,DC=org,DC=local\".", "ntopng.prefs.ldap", "bind_dn", "", nil, showElementsBind)
     prefsInputFieldPrefs("LDAP Bind Authentication Password", "Bind password used for authenticating with the LDAP server.", "ntopng.prefs.ldap", "bind_pwd", "", "password", showElementsBind)

     prefsInputFieldPrefs("LDAP Search Path", "Root path used to search the users.", "ntopng.prefs.ldap", "search_path", "", "text", showElements)
     prefsInputFieldPrefs("LDAP User Group", "Group name to which user has to belong in order to authenticate as unprivileged user.", "ntopng.prefs.ldap", "user_group", "", "text", showElements)
     prefsInputFieldPrefs("LDAP Admin Group", "Group name to which user has to belong in order to authenticate as an administrator.", "ntopng.prefs.ldap", "admin_group", "", "text", showElements)

  end
  print('<tr><th colspan=2 style="text-align:right;"><button type="button" onclick="save_button_users()" class="btn btn-primary" style="width:115px">Save</button></th></tr>')
  print('</table>')

  print [[<input id="csrf" name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />
  </form>
  <script>
    function save_button_users(){
      if (typeof $("#id-toggle-multiple_ldap_authentication").val() !== 'undefined'
          && $("#id-toggle-multiple_ldap_authentication").val() != "local") {
        var field = $("#id_input_server").val();

        if ((field.substring(0, 7) != "ldap://") && (field.substring(0, 8) != "ldaps://")) {
          alert("Invalid LDAP Server Address Value: missing \"ldap://\" or \"ldaps://\" at beginning.");
          return;
        }

        var new_field = field.replace('ldaps://', '');
        new_field = new_field.replace('ldap://', '');
        var res = new_field.split(":");
        if(res.length != 2){
          alert("Invalid LDAP Server Address Value: missing ldap server address or port number.");
          return;
        }
      }

      $("#form_ldap").submit();
    }
  </script>
  ]]
end

-- ================================================================================
function printInMemory()
  print('<form>')
  print('<input type=hidden name="subpage_active" value="in_memory"/>\n')
  print('<table class="table">')

  print('<tr><th colspan=2 class="info">Idle Timeout Settings</th></tr>')
  prefsInputFieldPrefs("Local Host Idle Timeout", "Inactivity time after which a local host is considered idle (sec). "..
		          "Idle local hosts are dumped to a cache so their counters can be restored in case they become active again. "..
			  "Counters include, but are not limited to, packets and bytes total and per Layer-7 application. "..
			  "Default: 300.", "ntopng.prefs.","local_host_max_idle", prefs.local_host_max_idle)
  prefsInputFieldPrefs("Remote Host Idle Timeout", "Inactivity time after which a remote host is considered idle (sec). Default: 60.", "ntopng.prefs.", "non_local_host_max_idle", prefs.non_local_host_max_idle)
  prefsInputFieldPrefs("Flow Idle Timeout", "Inactivity time after which a flow is considered idle (sec). Default: 60.", "ntopng.prefs.", "flow_max_idle", prefs.flow_max_idle)

  print('<tr><th colspan=2 class="info">Idle Local Hosts Cache Settings</th></tr>')
  toggleTableButtonPrefs("Local Host Cache",
			 "Toggle the creation of cache entries for idle local hosts. "..
			 "Cached local hosts counters are restored automatically to their previous values "..
			    " upon detection of additional host traffic.",
			 "On", "1", "success", "Off", "0", "danger",
			 "toggle_local_host_cache_enabled",
			 "ntopng.prefs.is_local_host_cache_enabled", "1")
  prefsInputFieldPrefs("Local Host Cache Duration", "Time after which an idle local host is deleted from the cache (sec). "..
		       "Default: 3600.", "ntopng.prefs.","local_host_cache_duration", prefs.local_host_cache_duration)
  
  print('<tr><th colspan=2 class="info">Hosts Statistics Update Frequency</th></tr>')
  prefsInputFieldPrefs("Update frequency in seconds",
		       "Some host statistics such as throughputs are updated periodically. "..
			  "This value regulates how often ntopng will update these statistics. "..
			  "Larger values are less computationally intensive and tend to average out minor variations. "..
			  "Smaller values are more computationally intensive and tend to highlight minor variations. "..
			  "Values in the order of few secods are safe. " ..
			  "Default: 5 seconds.",
		       "ntopng.prefs.", "housekeeping_frequency", prefs.housekeeping_frequency)

  print('<tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px">Save</button></th></tr>')
  print('</table>')
  print [[<input id="csrf" name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />
  </form> ]]
end

-- ================================================================================
function printStatsRrds()
  print('<form>')
  print('<input type=hidden name="subpage_active" value="on_disk_rrds"/>\n')
  print('<table class="table">')
  print('<tr><th colspan=2 class="info">Local Hosts and Networks Timeseries</th></tr>')

  toggleTableButtonPrefs("Traffic Timeseries",
			 "Toggle the creation of traffic timeseries for local hosts and networks. Turn it off to save storage space.",
			 "On", "1", "success", "Off", "0", "danger", "toggle_local", "ntopng.prefs.host_rrd_creation", "1")
  
  toggleTableButtonPrefs("Layer-7 Application Timeseries",
			 "Toggle the creation of nDPI timeseries for local hosts and defined networks. Enable their creation allows you "..
			    "to keep application protocol statistics at the cost of using more disk space.",
			 "On", "1", "success", "Off", "0", "danger", "toggle_local_ndpi", "ntopng.prefs.host_ndpi_rrd_creation", "0")
  
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
  print('<tr><th colspan=2 class="info">Network Interface Timeseries</th></tr>')
  prefsInputFieldPrefs("Days for raw stats", "Number of days for which raw stats are kept. Default: 1.", "ntopng.prefs.", "intf_rrd_raw_days", prefs.intf_rrd_raw_days)
  prefsInputFieldPrefs("Days for 1 min resolution stats", "Number of days for which stats are kept in 1 min resolution. Default: 30.", "ntopng.prefs.", "intf_rrd_1min_days", prefs.intf_rrd_1min_days)
  prefsInputFieldPrefs("Days for 1 hour resolution stats", "Number of days for which stats are kept in 1 hour resolution. Default: 100.", "ntopng.prefs.", "intf_rrd_1h_days", prefs.intf_rrd_1h_days)
  prefsInputFieldPrefs("Days for 1 day resolution stats", "Number of days for which stats are kept in 1 day resolution. Default: 365.", "ntopng.prefs.", "intf_rrd_1d_days", prefs.intf_rrd_1d_days)

  print('<tr><th colspan=2 class="info">Protocol/Networks Timeseries</th></tr>')
  prefsInputFieldPrefs("Days for raw stats", "Number of days for which raw stats are kept. Default: 1.", "ntopng.prefs.", "other_rrd_raw_days", prefs.other_rrd_raw_days)
  --prefsInputFieldPrefs("Days for 1 min resolution stats", "Number of days for which stats are kept in 1 min resolution. Default: 30.", "ntopng.prefs.", "other_rrd_1min_days", prefs.other_rrd_1min_days)
  prefsInputFieldPrefs("Days for 1 hour resolution stats", "Number of days for which stats are kept in 1 hour resolution. Default: 100.", "ntopng.prefs.", "other_rrd_1h_days", prefs.other_rrd_1h_days)
  prefsInputFieldPrefs("Days for 1 day resolution stats", "Number of days for which stats are kept in 1 day resolution. Default: 365.", "ntopng.prefs.", "other_rrd_1d_days", prefs.other_rrd_1d_days)

  print('<tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px">Save</button></th></tr>')
  print('</table>')
  print [[<input id="csrf" name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />
  </form> ]]
end

-- ================================================================================
function printLogging()
  if prefs.has_cmdl_trace_lvl then return end
  print('<form>')
  print('<input type=hidden name="subpage_active" value="logging"/>\n')
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
           <div class="list-group ">
             <a href="]] print(ntop.getHttpPrefix()) print[[/lua/admin/prefs.lua?subpage_active=users" class="list-group-item ]] print(users_active) print[[">Users</a>
             <a href="]] print(ntop.getHttpPrefix()) print[[/lua/admin/prefs.lua?subpage_active=in_memory" class="list-group-item ]] print(in_memory_active) print[[">In-Memory Data</a>
             <a href="]] print(ntop.getHttpPrefix()) print[[/lua/admin/prefs.lua?subpage_active=on_disk_rrds" class="list-group-item ]] print(on_disk_rrds_active) print[[">On-Disk Timeseries</a>
             <a href="]] print(ntop.getHttpPrefix()) print[[/lua/admin/prefs.lua?subpage_active=on_disk_dbs" class="list-group-item ]] print(on_disk_dbs_active) print[[">On-Disk Databases</a>]]
   if not prefs.has_cmdl_disable_alerts then
      print[[<a href="]] print(ntop.getHttpPrefix()) print[[/lua/admin/prefs.lua?subpage_active=alerts" class="list-group-item ]] print(alerts_active) print[[">Alerts</a>]]
   end
      print[[<a href="]] print(ntop.getHttpPrefix()) print[[/lua/admin/prefs.lua?subpage_active=report" class="list-group-item ]] print(report_active) print[[">Units of Measurement</a>]]
   if not prefs.has_cmdl_trace_lvl then
      print [[<a href="]] print(ntop.getHttpPrefix()) print[[/lua/admin/prefs.lua?subpage_active=logging" class="list-group-item ]] print(logging_active) print[[">Log Level</a> ]]
   end

   if (ntop.isPro()) then
      print [[<a href="]] print(ntop.getHttpPrefix()) print[[/lua/admin/prefs.lua?subpage_active=nbox" class="list-group-item ]] print(nbox_active) print[[">nBox Integration</a> ]]
   end

print[[
           </div>
        </td><td colspan=2 style="padding-left: 14px;border-left-style: groove; border-width:1px; border-color: #e0e0e0;">]]

if (subpage_active == "report") then
   printReportVisualization()
end
if (subpage_active == "in_memory") then
   printInMemory()
end
if (subpage_active == "on_disk_rrds") then
   printStatsRrds()
end
if (subpage_active == "on_disk_dbs") then
   printStatsDatabases()
end
if (subpage_active == "alerts") then
   if not prefs.has_cmdl_disable_alerts then
      printAlerts()
   else
      printReportVisualization()
   end
end
if (subpage_active == "nbox") then
  if (ntop.isPro()) then
     printNbox()
  end
end
if (subpage_active == "users") then
   printUsers()
end
if (subpage_active == "logging") then
   if not prefs.has_cmdl_trace_lvl then
      printLogging()
   else
      printReportVisualization()
   end
end

print[[
        </td></tr>
      </table>
]]





   dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
end
