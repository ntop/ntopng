--
-- (C) 2013-15 - ntop.org
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

   ntop.loadPrefsDefaults()
   prefs = ntop.getPrefs()

   print [[
	    <h2>Runtime Preferences</h2>
	    <table class="table">
      ]]

   -- ================================================================================
   print('<tr><th colspan=2 class="info">Report Visualization</th></tr>')

   toggleTableButton("Throughput Unit",
		     "Select the throughput unit to be displayed in traffic reports.",
		     "Bytes", "bps", "primary","Packets", "pps", "primary","toggle_thpt_content", "ntopng.prefs.thpt_content")

   -- ================================================================================
   print('<tr><th colspan=2 class="info">Traffic Metrics Storage (RRD)</th></tr>')

   toggleTableButton("RRDs For Local Hosts",
		     "Toggle the creation of RRDs for local hosts. Turn it off to save storage space.",
		     "On", "1", "success", "Off", "0", "danger", "toggle_local", "ntopng.prefs.host_rrd_creation")

   toggleTableButton("nDPI RRDs For Local Hosts and Networks",
		     "Toggle the creation of nDPI RRDs for local hosts and defined networks. Enable their creation allows you "..
		     "to keep application protocol statistics at the cost of using more disk space.",
		     "On", "1", "success", "Off", "0", "danger", "toggle_local_ndpi", "ntopng.prefs.host_ndpi_rrd_creation")

   toggleTableButton("Category RRDs For Local Hosts and Networks",
           "Toggle the creation of Category RRDs for local hosts and defined networks. Enabling their creation allows you "..
           "to keep persistent traffic category statistics (e.g., social networks, news) at the cost of using more disk space.<br>"..
           "Creation is only possible if the ntopng instance has been launched with option -k flashstart:&lt;user&gt;:&lt;password&gt;.",
          "On", "1", "success", "Off", "0", "danger", "toggle_local_categorization", "ntopng.prefs.host_categories_rrd_creation", not prefs.is_categorization_enabled)

   -- ================================================================================
   print('<tr><th colspan=2 class="info">MySQL Database</th></tr>')

   mysql_retention = ntop.getCache("ntopng.prefs.mysql_retention")
   if((mysql_retention == nil) or (mysql_retention == "")) then mysql_retention = "30" end
   prefsInputField("Data Retention", "Duration in days of data retention in the MySQL database. Default: 30 days", "mysql_retention", mysql_retention)

   -- ================================================================================
   print('<tr><th colspan=2 class="info">Alerts</th></tr>')

   toggleTableButton("Alerts On Syslog",
		     "Enable alerts logging on system syslog.",
		     "On", "1", "success", "Off", "0", "danger", "toggle_alert_syslog", "ntopng.prefs.alerts_syslog")

if (ntop.isPro()) then
   -- ================================================================================
   print('<tr><th colspan=2 class="info">Nagios Alerts</th></tr>')

   toggleTableButton("Alerts To Nagios",
		     "Enable sending ntopng alerts to Nagios NSCA (Nagios Service Check Acceptor).",
		     "On", "1", "success", "Off", "0", "danger", "toggle_alert_nagios", "ntopng.prefs.alerts_nagios")

   if ntop.getCache("ntopng.prefs.alerts_nagios") == "1" then
    prefsInputField("Nagios NSCA Host", "Address of the host where the Nagios NSCA daemon is running. Default: localhost.", "nagios_nsca_host", prefs.nagios_nsca_host)
    prefsInputField("Nagios NSCA Port", "Port where the Nagios daemon's NSCA is listening. Default: 5667.", "nagios_nsca_port", prefs.nagios_nsca_port)
    prefsInputField("Nagios send_nsca executable", "Absolute path to the Nagios NSCA send_nsca utility. Default: /usr/local/nagios/bin/send_nsca", "nagios_send_nsca_executable", prefs.nagios_send_nsca_executable)
    prefsInputField("Nagios send_nsca configuration", "Absolute path to the Nagios NSCA send_nsca utility configuration file. Default: /usr/local/nagios/etc/send_nsca.cfg", "nagios_send_nsca_config", prefs.nagios_send_nsca_conf)
    prefsInputField("Nagios host_name", "The host_name exactly as specified in Nagios host definition for the ntopng host. Default: ntopng-host", "nagios_host_name", prefs.nagios_host_name)
    prefsInputField("Nagios service_description", "The service description exactly as specified in Nagios passive service definition for the ntopng host. Default: NtopngAlert", "nagios_service_name", prefs.nagios_service_name)
   end
   -- ================================================================================
   print('<tr><th colspan=2 class="info">nBox integration</th></tr>')

   local nbox_integration = ntop.getCache("ntopng.prefs.nbox_integration")
   local nbox_host = ntop.getCache("ntopng.prefs.nbox_host")
   local nbox_user = ntop.getCache("ntopng.prefs.nbox_user")
   local nbox_password = ntop.getCache("ntopng.prefs.nbox_password")
   if((nbox_integration == nil) or (nbox_integration == "")) then ntop.setCache("ntopng.prefs.nbox_integration", "0") end
   if((nbox_host == nil) or (nbox_host == "")) then nbox_host = "localhost" end
   if((nbox_user == nil) or (nbox_user == "")) then nbox_user = "nbox" end
   if((nbox_password == nil) or (nbox_password == "")) then nbox_password = "nbox" end

   toggleTableButton("Integrate with nBox",
         "Enable sending ntopng requests (e.g., to download pcap files) to an nBox.",
         "On", "1", "success", "Off", "0", "danger", "toggle_nbox_integration", "ntopng.prefs.nbox_integration")
   if ntop.getCache("ntopng.prefs.nbox_integration") == "1" then
    prefsInputField("nBox Host", "Address of the nBox host. Default: localhost", "nbox_host", nbox_host)
    prefsInputField("nBox User", "User that has privileges to access the nBox. Default: nbox", "nbox_user", nbox_user)
    prefsInputField("nBox Password", "Passowrd associated to the nBox user. Default: nbox", "nbox_password", nbox_password, "password")
   end

   print('<tr><th colspan=2 class="info">User Authentication</th></tr>')

   local js_body_funtion_script = "";

   js_body_funtion_script = js_body_funtion_script.."  if ((field.substring(0, 7) != \"ldap://\") && (field.substring(0, 8) != \"ldaps://\")) {\n"
   js_body_funtion_script = js_body_funtion_script.."    return \"Invalid Value: missing \\\"ldap://\\\" or \\\"ldaps://\\\" at beginning.\";"
   js_body_funtion_script = js_body_funtion_script.."  }\n"

   js_body_funtion_script = js_body_funtion_script.."  var new_field = field.replace(\'ldaps://\', \'\');\n"
   js_body_funtion_script = js_body_funtion_script.."  new_field = new_field.replace(\'ldap://\', \'\');\n"
   js_body_funtion_script = js_body_funtion_script.."  var res = new_field.split(\":\");\n"
   js_body_funtion_script = js_body_funtion_script.."  if(res.length != 2){\n"
   js_body_funtion_script = js_body_funtion_script.."     return \"Invalid Value: missing ldap server address or port number.\";\n"
   js_body_funtion_script = js_body_funtion_script.."  }\n"
   js_body_funtion_script = js_body_funtion_script.."  return \"\";\n"

   local labels = {"Local","LDAP","LDAP/Local"}
   local values = {"local","ldap","ldap_local"}
   local retVal = multipleTableButton("LDAP Authentication",
         "Local (Local only), LDAP (LDAP server only), LDAP/Local (Authenticate with LDAP server, if fails it uses local authentication).",
         labels, values, "local", "primary", "multiple_ldap_authentication", "ntopng.prefs.auth_type")
    if ((retVal == "ldap") or (retVal == "ldap_local")) then
      local ldap_server = ntop.getCache("ntopng.prefs.ldap.server")
      if((ldap_server == nil) or (ldap_server == "")) then
        ldap_server = "ldap://localhost:389"
        ntop.setCache("ntopng.prefs.ldap.server", ldap_server)
      end
      prefsInputFieldWithParamCheck("LDAP Server Address", "IP address of LDAP server. Default: \"ldap://localhost:389\".", "ntopng.prefs.ldap", "server", ldap_server, "text", js_body_funtion_script)
      local ldap_bind_dn = ntop.getCache("ntopng.prefs.ldap.bind_dn")
      if(ldap_bind_dn == nil) then ldap_bind_dn = "" end
      prefsInputFieldWithParamCheck("LDAP Bind DN", "Bind Distinguished Name of LDAP server. Example: \"CN=ntop_users,DC=ntop,DC=org,DC=local\".", "ntopng.prefs.ldap", "bind_dn", ldap_bind_dn, "text", nil)
      local ldap_bind_pwd = ntop.getCache("ntopng.prefs.ldap.bind_pwd")
      if(ldap_bind_pwd == nil) then ldap_bind_pwd = "" end
      prefsInputFieldWithParamCheck("LDAP Authentication Password", "Password used for authenticating with the LDAP server.", "ntopng.prefs.ldap", "bind_pwd", ldap_bind_pwd, "password", nil)
      local ldap_user_group = ntop.getCache("ntopng.prefs.ldap.user_group")
      if(ldap_user_group == nil) then ldap_user_group = "" end
      prefsInputFieldWithParamCheck("LDAP User Group", "Group name to which user has to belong in order to authenticate as unprivileged user.", "ntopng.prefs.ldap", "user_group", ldap_user_group, "text", nil)
      local ldap_admin_group = ntop.getCache("ntopng.prefs.ldap.admin_group")
      if(ldap_admin_group == nil) then ldap_admin_group = "" end
      prefsInputFieldWithParamCheck("LDAP Admin Group", "Group name to which user has to belong in order to authenticate as an administrator.", "ntopng.prefs.ldap", "admin_group", ldap_admin_group, "text", nil)
    end
end

-- TODO
if(false) then
   if(ntop.isPro()) then
   -- ================================================================================
      print('<tr><th colspan=2 class="info">Periodic Activities</th></tr>')
      local message = "Toggle generation of daily reports in PDF format."
      local disable = false
      if (not havePDFRenderer(getUsedPDFRenderer())) then
        disable = true
        message = message.." Install "..getUsedPDFRenderer().." to enable this."
      elseif (not ntop.isLoginDisabled()) then
        disable = true
        message = message..' Start ntopng with the "-l" option to enable this.'
      end
      toggleTableButton("Generate Reports Daily",
                        message, "On", "1", "success", "Off", "0", "danger",
                        "toggle_daily_reports", "ntopng.prefs.daily_reports", disable)
   end
end

   -- ================================================================================
   print('<tr><th colspan=2 class="info">Data Purge</th></tr>')
   prefsInputField("Local Host Idle Timeout", "Inactivity time after which a local host is considered idle (sec). Default: 300.", "local_host_max_idle", prefs.local_host_max_idle)
   prefsInputField("Remote Host Idle Timeout", "Inactivity time after which a remote host is considered idle (sec). Default: 60.", "non_local_host_max_idle", prefs.non_local_host_max_idle)
   prefsInputField("Flow Idle Timeout", "Inactivity time after which a flow is considered idle (sec). Default: 60.", "flow_max_idle", prefs.flow_max_idle)

   -- ================================================================================

   -- ================================================================================
   print('<tr><th colspan=2 class="info">Network Interface Stats RRDs</th></tr>')
   prefsInputField("Days for raw stats", "Number of days for which raw stats are kept. Default: 1.", "intf_rrd_raw_days", prefs.intf_rrd_raw_days)
   prefsInputField("Days for 1 min resolution stats", "Number of days for which stats are kept in 1 min resolution. Default: 30.", "intf_rrd_1min_days", prefs.intf_rrd_1min_days)
   prefsInputField("Days for 1 hour resolution stats", "Number of days for which stats are kept in 1 hour resolution. Default: 100.", "intf_rrd_1h_days", prefs.intf_rrd_1h_days)
   prefsInputField("Days for 1 day resolution stats", "Number of days for which stats are kept in 1 day resolution. Default: 365.", "intf_rrd_1d_days", prefs.intf_rrd_1d_days)

   -- ================================================================================

   -- ================================================================================
   print('<tr><th colspan=2 class="info">Protocol/Networks Stats RRDs</th></tr>')
   prefsInputField("Days for raw stats", "Number of days for which raw stats are kept. Default: 1.", "other_rrd_raw_days", prefs.other_rrd_raw_days)
   --prefsInputField("Days for 1 min resolution stats", "Number of days for which stats are kept in 1 min resolution. Default: 30.", "other_rrd_1min_days", prefs.other_rrd_1min_days)
   prefsInputField("Days for 1 hour resolution stats", "Number of days for which stats are kept in 1 hour resolution. Default: 100.", "other_rrd_1h_days", prefs.other_rrd_1h_days)
   prefsInputField("Days for 1 day resolution stats", "Number of days for which stats are kept in 1 day resolution. Default: 365.", "other_rrd_1d_days", prefs.other_rrd_1d_days)

   -- ================================================================================

   print [[
	 </table>
      ]]

   dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
end
