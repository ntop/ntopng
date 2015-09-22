--
-- (C) 2013-15 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
if ( (dirs.scriptdir ~= nil) and (dirs.scriptdir ~= "")) then package.path = dirs.scriptdir .. "/lua/modules/?.lua;" .. package.path end
require "lua_utils"

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
   print('<tr><th colspan=2 class="info">Nagios Alerts Configuration</th></tr>')

   toggleTableButton("Send Alerts To Nagios",
		     "Enable/disable sending ntopng alerts to Nagios in addition to storing them into ntopng.",
		     "On", "1", "success", "Off", "0", "danger", "toggle_alert_nagios", "ntopng.prefs.alerts_nagios")

   prefsInputField("Nagios Daemon Host", "Address of the host where the Nagios daemon is running. Default: localhost.", "nagios_host", prefs.nagios_host)
   prefsInputField("Nagios Daemon Port", "Port where the Nagios daemon is listening. Default: 5667.", "nagios_port", prefs.nagios_port)
   prefsInputField("Nagios Daemon Configuration", "Path of the Nagios configuration file used by the <A HREF=\"http://exchange.nagios.org/directory/Addons/Passive-Checks\" target=\"_blank\">send_nsca</A> utility to send events to the Nagios damon. Default: /etc/nagios/send_nsca.cfg.", "nagios_config", prefs.nagios_config)

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
