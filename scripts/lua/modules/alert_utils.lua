--
-- (C) 2014-17 - ntop.org
--

-- This file contains the description of all functions
-- used to trigger host alerts

local verbose = false
local callback_utils = require "callback_utils"

alerts_granularity = {
   { "min", "Every Minute", 60 },
   { "5mins", "Every 5 Minutes", 300 },
   { "hour", "Hourly", 3600 },
   { "day", "Daily", 86400 }
}

alarmable_metrics = {'bytes', 'dns', 'active', 'idle', 'packets', 'p2p', 'throughput', 'ingress', 'egress', 'inner'}

-- ##############################################################################

function bytes(old, new, interval)
   -- io.write(debug.traceback().."\n")
   if(verbose) then print("bytes("..interval..")") end

   if(new["sent"] ~= nil) then
      -- Host
      return((new["sent"]["bytes"]+new["rcvd"]["bytes"])-(old["sent"]["bytes"]+old["rcvd"]["bytes"]))
   else
      -- Interface
      return(new.stats.bytes - old.stats.bytes)
   end
end

function packets(old, new, interval)
   if(verbose) then print("packets("..interval..")") end
   if(new["sent"] ~= nil) then
      -- Host
      return((new["sent"]["packets"]+new["rcvd"]["packets"])-(old["sent"]["packets"]+old["rcvd"]["packets"]))
   else
      -- Interface
      return(new.stats.packets - old.stats.packets)
   end
end

function active(old, new, interval)
   if(verbose) then print("active("..interval..")") end
   local diff = new["duration"] - old["duration"]
   return(diff)
end

function idle(old, new, interval)
   if(verbose) then print("idle("..interval..")") end
   local diff = os.time()-new["seen.last"]
   return(diff)
end

function dns(old, new, interval)
   if(verbose) then print("dns("..interval..")") end
   return(proto_bytes(old, new, "DNS"))
end

function p2p(old, new, interval)
   if(verbose) then print("p2p("..interval..")") end
   return(proto_bytes(old, new, "eDonkey")+proto_bytes(old, new, "BitTorrent")+proto_bytes(old, new, "Skype"))
end

function throughput(old, new, interval)
   if(verbose) then print("throughput("..interval..")") end

   return((bytes(old, new, interval) * 8)/ (interval*1000000))
end

function ingress(old, new, interval)
   return new["ingress"] - old["ingress"]
end

function egress(old, new, interval)
   return new["egress"] - old["egress"]
end

function inner(old, new, interval)
   return new["inner"] - old["inner"]
end

-- ##############################################################################

if ntop.isEnterprise() then
   local dirs = ntop.getDirs()
   package.path = dirs.installdir .. "/pro/scripts/lua/enterprise/modules/?.lua;" .. package.path
   require "enterprise_alert_utils"
end

j = require("dkjson")
require "persistence"

function is_allowed_timespan(timespan)
   for _, granularity in pairs(alerts_granularity) do
      granularity = granularity[1]
      if timespan == granularity then
	 return true
      end
   end
   return false
end

function is_allowed_alarmable_metric(metric)
   for _, allowed_metric in pairs(alarmable_metrics) do
      if metric == allowed_metric then
	 return true
      end
   end
   return false
end

function get_alerts_hash_name(timespan, ifname)
   local ifid = getInterfaceId(ifname)
   if not is_allowed_timespan(timespan) or tonumber(ifid) == nil then
      return nil
   end
   return "ntopng.prefs.alerts_"..timespan..".ifid_"..tostring(ifid)
end

function get_housekeeping_set_name(ifId)
   return "ntopng.alerts.ifid_"..ifId..".make_room"
end

function ndpival_bytes(json, protoname)
   key = "ndpiStats"

   -- Host
   if((json[key] == nil) or (json[key][protoname] == nil)) then
      if(verbose) then print("## ("..protoname..") Empty<br>\n") end
      return(0)
   else
      local v = json[key][protoname]["bytes"]["sent"]+json[key][protoname]["bytes"]["rcvd"]
      if(verbose) then print("##  ("..protoname..") "..v.."<br>\n") end
      return(v)
   end
end

function proto_bytes(old, new, protoname)
   return(ndpival_bytes(new, protoname)-ndpival_bytes(old, protoname))
end
-- =====================================================

function get_alerts_suppressed_hash_name(ifname)
   local hash_name = "ntopng.prefs.alerts.ifid_"..tostring(getInterfaceId(ifname))
   return hash_name
end

function are_alerts_suppressed(observed, ifname)
   local suppressAlerts = ntop.getHashCache(get_alerts_suppressed_hash_name(ifname), observed)
   --[[
      tprint("are_alerts_suppressed ".. suppressAlerts)
      tprint("are_alerts_suppressed observed: ".. observed)
      tprint("are_alerts_suppressed ifname: "..ifname)
   --]]
   if((suppressAlerts == "") or (suppressAlerts == nil) or (suppressAlerts == "true")) then
      return false  -- alerts are not suppressed
   else
      if(verbose) then print("Skipping alert check for("..address.."): disabled in preferences<br>\n") end
      return true -- alerts are suppressed
   end
end

-- #################################################################

function delete_alert_configuration(alert_source, ifname)
   local ifid = getInterfaceId(ifname)
   local alert_level  = 2 -- alert_level_error
   local alert_type   = 2 -- alert_threshold_exceeded
   local is_host = false

   for k1,timespan in pairs(alerts_granularity) do
      timespan = timespan[1]
      local key = get_alerts_hash_name(timespan, ifname)
      local alarms = ntop.getHashCache(key, alert_source)
      if alarms ~= "" then
	 for k1, metric in pairs(alarmable_metrics) do
	    if ntop.isPro() then
	       ntop.withdrawNagiosAlert(alert_source, timespan, metric, "OK, alarm deactivated")
	    end
	    -- check if we are processing a pair ip-vlan such as 192.168.1.0@0
	    if string.match(alert_source, "@") then
	       interface.releaseHostAlert(alert_source, timespan.."_"..metric, alert_type, alert_level, "Alarm released.")
	       is_host = true
	       -- check if this is a subnet
	    elseif string.match(alert_source, "/") then
	       interface.releaseNetworkAlert(alert_source, timespan.."_"..metric, alert_type, alert_level, "Alarm released.")
	       -- finally assume it's an interface alert
	    else
	       interface.releaseInterfaceAlert(timespan.."_"..metric, alert_type, alert_level, "Alarm released.")
	    end
	 end
	 ntop.delHashCache(key, alert_source)
      end
   end

   if is_host == true then
      interface.refreshNumAlerts(alert_source)
   end
   interface.refreshNumAlerts()
end

function refresh_alert_configuration(alert_source, ifname, timespan, alerts_string)
   if tostring(alerts_string) == nil then return nil end
   if is_allowed_timespan(timespan) == false then return nil end
   local ifid = getInterfaceId(ifname)
   local alert_level  = 2 -- alert_level_error
   local alert_type   = 2 -- alert_threshold_exceeded
   local is_host = false
   -- check if we are processing a pair ip-vlan such as 192.168.1.0@0

   local new_alert_ids = {}

   -- alerts_string is a string such as dns;gt;23,bytes;gt;1,p2p;gt;3
   -- that string comes directly from the web interface and is a comma-separated
   -- list of threshold alerts configured.
   -- since formerly configured alerts may have been deleted, we need to check
   -- the ongoing_alerts against alerts_string and move to the closed list
   -- any ongoing alert that is no longer part of the alerts_string
   local tokens = split(alerts_string, ",")
   if tokens == nil then tokens = {} end
   for _, s in pairs(tokens) do
      if tostring(s) == nil then goto continue end
      local metric = string.split(s, ";")--[1]
      if metric == nil or metric[1] == nil then goto continue end
      metric = metric[1]

      if is_allowed_alarmable_metric(metric) == true then
	 new_alert_ids[timespan.."_"..metric] = true
      end
      ::continue::
   end

   -- check if there are some ongoing alerts that no longer exist in new_alerts
   -- we want to close those alerts
   for k1, timespan in pairs(alerts_granularity) do
      timespan = timespan[1]
      for k2, metric in pairs(alarmable_metrics) do
	 if new_alert_ids[timespan.."_"..metric] ~= true then
	    if string.match(alert_source, "@") then
	       interface.releaseHostAlert(alert_source, timespan.."_"..metric, alert_type, alert_level, "released.")
	       is_host = true
	    elseif string.match(alert_source, "/") then
	       interface.releaseNetworkAlert(alert_source, timespan.."_"..metric, alert_type, alert_level, "released.")
	    else
	       interface.releaseInterfaceAlert(timespan.."_"..metric, alert_type, alert_level, "Alarm released.")
	    end
	 end
      end
   end

   if is_host == true then
      interface.refreshNumAlerts(alert_source)
   end
   interface.refreshNumAlerts()
end

-- #################################

-- TODO use this information to generate the alerts
local function not_used()
  local ifname_clean = "iface_"..tostring(getInterfaceId(ifname))
  local alert_level  = 2 -- alert_level_error
  local alert_status = 1 -- alert_on
  local alert_type   = 2 -- alert_threshold_exceeded

  local alert_id = threshold.key

  	 if(rc) then
	    local alert_msg = "Threshold <b>"..threshold.metric.."</b> crossed by interface <A HREF='"..ntop.getHttpPrefix().."/lua/if_stats.lua?ifid="..tostring(getInterfaceId(ifname))..
	       "'>"..ifname.."</A> [".. val .." ".. op .. " " .. threshold.edge.."]"

	    if verbose then io.write("queuing alert\n") end
	    interface.engageInterfaceAlert(alert_id, alert_type, alert_level, alert_msg)
	    if ntop.isPro() then
	       -- possibly send the alert to nagios as well
	       ntop.sendNagiosAlert(ifname_clean, granularity, threshold.metric, alert_msg)
	    end
	    if(verbose) then print("<font color=red>".. alert_msg .."</font><br>\n") end
	 else
	    if(verbose) then print("<p><font color=green><b>Threshold "..threshold.metric.."@"..ifname.." not crossed</b> [value="..val.."]["..op.." "..threshold.edge.."]</font><p>\n") end
	    interface.releaseInterfaceAlert(alert_id, alert_type, alert_level, "released!")
	    if ntop.isPro() then
	       ntop.withdrawNagiosAlert(ifname_clean, granularity, threshold.metric, "service OK")
	    end
	 end

    if(rc) then
	    alert_status = 1 -- alert on
	    local alert_msg = "Threshold <b>"..t[1].."</b> crossed by host <A HREF='"..ntop.getHttpPrefix().."/lua/host_details.lua?host="..key.."'>"..key:gsub("@0","").."</A> [".. val .." ".. op .. " " .. t[3].."]"

	    if verbose then io.write("queuing alert\n") end
	    interface.engageHostAlert(key, alert_id, alert_type, alert_level, alert_msg)
	    if ntop.isPro() then
	       -- possibly send the alert to nagios as well
	       ntop.sendNagiosAlert(string.gsub(key, "@0", ""), --[[ vlan 0 is implicit for hosts --]]
				    mode, t[1], alert_msg)
	    end
	    if(verbose) then print("<font color=red>".. alert_msg .."</font><br>\n") end
	 else  -- alert has not been triggered
	    alert_status = 2 -- alert off
	    if(verbose) then print("<p><font color=green><b>Threshold "..t[1].."@"..key.." not crossed</b> [value="..val.."]["..op.." "..t[3].."]</font><p>\n") end
	    interface.releaseHostAlert(key, alert_id, alert_type, alert_level, "released!")
	    if ntop.isPro() then
	       ntop.withdrawNagiosAlert(string.gsub(key, "@0", "") --[[ vlan 0 is implicit for hosts --]],
					mode, t[1], "service OK")
	    end
	 end

    if(rc) then
	    local alert_msg = "Threshold <b>"..t[1].."</b> crossed by network <A HREF='"..ntop.getHttpPrefix().."/lua/network_details.lua?network="..key.."&page=historical'>"..network_name.."</A> [".. val .." ".. op .. " " .. t[3].."]"

	    if verbose then io.write("queuing alert\n") end
	    interface.engageNetworkAlert(network_name, alert_id, alert_type, alert_level, alert_msg)
	    if ntop.isPro() then
	       -- possibly send the alert to nagios as well
	       ntop.sendNagiosAlert(network_name, mode, t[1], alert_msg)
	    end
	    if(verbose) then print("<font color=red>".. alert_msg .."</font><br>\n") end
	 else
	    if(verbose) then print("<p><font color=green><b>Network threshold "..t[1].."@"..network_name.." not crossed</b> [value="..val.."]["..op.." "..t[3].."]</font><p>\n") end
	    interface.releaseNetworkAlert(network_name, alert_id, alert_type, alert_level, "released!")
	    if ntop.isPro() then
	       ntop.withdrawNagiosAlert(network_name, mode, t[1], "service OK")
	    end
	 end
end

-- #################################

-- Note: see getConfiguredAlertsThresholds for threshold object format
local function entity_threshold_crossed(ifname, granularity, old_table, new_table, threshold)
   -- Needed because Lua. loadstring() won't work otherwise.
   old = old_table
   new = new_table
   duration = granularity2sec(granularity)

   local op = op2jsop(threshold.operator)

   -- This is where magic happens: loadstring() evaluates the string
   local what = "val = "..threshold.metric.."(old, new, duration); if(val ".. op .. " " .. threshold.edge .. ") then return(true) else return(false) end"

   local f = loadstring(what)
   local rc = f()

   return rc
end

-- #################################

function granularity2sec(g)
   for _, granularity in pairs(alerts_granularity) do
      if(granularity[1] == g) then
	 return(granularity[3])
      end
   end

   return(0)
end

function op2jsop(op)
   if op == "gt" then
      return ">"
   elseif op "lt" then
      return "<"
   else
      return "=="
   end
end

function performAlertsQuery(statement, what, opts)
   local wargs = {"WHERE", "1=1"}

   if tonumber(opts.row_id) ~= nil then
      wargs[#wargs+1] = 'AND rowid = '..(opts.row_id)
   end

   if (not isEmptyString(opts.entity)) and (not isEmptyString(opts.entity_val)) then
      if((what == "historical-flows") and (alertEntityRaw(opts.entity) == "host")) then
         -- need to handle differently for flows table
         local info = hostkey2hostinfo(opts.entity_val)
         wargs[#wargs+1] = 'AND (cli_addr="'..(info.host)..'" OR srv_addr="'..(info.host)..'")'
         wargs[#wargs+1] = 'AND vlan_id='..(info.vlan)
      else
         wargs[#wargs+1] = 'AND alert_entity = "'..(opts.entity)..'"'
         wargs[#wargs+1] = 'AND alert_entity_val = "'..(opts.entity_val)..'"'
      end
   end

   if not isEmptyString(opts.origin) then
      local info = hostkey2hostinfo(opts.origin)
      wargs[#wargs+1] = 'AND cli_addr="'..(info.host)..'"'
      wargs[#wargs+1] = 'AND vlan_id='..(info.vlan)
   end

   if not isEmptyString(opts.target) then
      local info = hostkey2hostinfo(opts.target)
      wargs[#wargs+1] = 'AND srv_addr="'..(info.host)..'"'
      wargs[#wargs+1] = 'AND vlan_id='..(info.vlan)
   end

   if tonumber(opts.epoch_begin) ~= nil then
      wargs[#wargs+1] = 'AND alert_tstamp >= '..(opts.epoch_begin)
   end

   if tonumber(opts.epoch_end) ~= nil then
      wargs[#wargs+1] = 'AND alert_tstamp <= '..(opts.epoch_end)
   end

   if not isEmptyString(opts.flowhosts_type) then
      if opts.flowhosts_type ~= "all_hosts" then
         local cli_local, srv_local = 0, 0

         if opts.flowhosts_type == "local_only" then cli_local, srv_local = 1, 1
         elseif opts.flowhosts_type == "remote_only" then cli_local, srv_local = 0, 0
         elseif opts.flowhosts_type == "local_origin_remote_target" then cli_local, srv_local = 1, 0
         elseif opts.flowhosts_type == "remote_origin_local_target" then cli_local, srv_local = 0, 1
         end

         if what == "historical-flows" then
            wargs[#wargs+1] = "AND cli_localhost = "..cli_local
            wargs[#wargs+1] = "AND srv_localhost = "..srv_local
         end
         -- TODO cannot apply it to other tables right now
      end
   end

   if tonumber(opts.alert_type) ~= nil then
      wargs[#wargs+1] = "AND alert_type = "..(opts.alert_type)
   end

   if tonumber(opts.alert_severity) ~= nil then
      wargs[#wargs+1] = "AND alert_severity = "..(opts.alert_severity)
   end

   if((not isEmptyString(opts.sortColumn)) and (not isEmptyString(opts.sortOrder))) then
      local order_by

      if opts.sortColumn == "column_date" then
         order_by = "alert_tstamp"
      elseif opts.sortColumn == "column_severity" then
         order_by = "alert_severity"
      elseif opts.sortColumn == "column_type" then
         order_by = "alert_type"
      elseif((opts.sortColumn == "column_duration") and (what == "historical")) then
         order_by = "(alert_tstamp_end - alert_tstamp)"
      else
         -- default
         order_by = "alert_tstamp"
      end

      wargs[#wargs+1] = "ORDER BY "..order_by
      wargs[#wargs+1] = string.upper(opts.sortOrder)
   end

   -- pagination
   if((tonumber(opts.perPage) ~= nil) and (tonumber(opts.currentPage) ~= nil)) then
      local to_skip = (tonumber(opts.currentPage)-1) * tonumber(opts.perPage)
      wargs[#wargs+1] = "LIMIT"
      wargs[#wargs+1] = to_skip..","..(opts.perPage)
   end

   local query = table.concat(wargs, " ")
   local res

   -- Uncomment to debug the queries
   --~ tprint(statement.." (from "..what..") "..query)

   if what == "engaged" then
      res = interface.queryAlertsRaw(true, statement, query)

   elseif what == "historical" then
      res = interface.queryAlertsRaw(false, statement, query)
   elseif what == "historical-flows" then
      res = interface.queryFlowAlertsRaw(statement, query)
   else
      error("Invalid alert subject: "..what)
   end

   -- trigger counters refresh
   if trimSpace(statement:lower()) == "delete" then
      -- keep counters in sync only for engaged alerts
      if what == "engaged" then
	 refreshHostsEngagedAlertsCounters()
      end
      interface.refreshNumAlerts()
   end

   return res
end

-- #################################
function refreshHostsEngagedAlertsCounters(host_vlan)
   local hosts

   if isEmptyString(host_vlan) == false then
      hosts[host_vlan:gsub("@0","")] = {updated = false}
   else
      hosts = interface.getHostsInfo(false --[[ no details --]])
      hosts = hosts["hosts"]
   end

   for k, v in pairs(hosts) do
      if v["num_alerts"] > 0 then
	 hosts[k] = {updated = false}
      else
	 hosts[k] = nil
      end
   end

   local res = interface.queryAlertsRaw(true, "select alert_entity_val, count(*) cnt",
					"where alert_entity="..alertEntity("host")
					   .. " group by alert_entity_val having cnt > 0")

   if res == nil then res = {} end

   -- update the hosts that actually have engaged alerts
   for _, k in pairs(res) do
      local entity_val = k["alert_entity_val"]
      local sp = split(entity_val, "@")
      local host = sp[1]
      local vlan = tonumber(sp[2])
      if vlan == 0 then
	 entity_val = host -- no vlan in the key if vlan is zero
      end

      interface.refreshNumAlerts(host, vlan, tonumber(k["cnt"]))

      if hosts[entity_val] ~= nil then
	 hosts[entity_val]["updated"] = true
      end
   end

   -- finally update the hosts that no longer have engaged alerts
   for k, v in pairs(hosts) do
      if v["updated"] == false then
	 interface.refreshNumAlerts(k, nil, 0);
      end
   end
end

-- #################################

function getNumAlerts(what, options)
   local num = 0
   local opts = getUnpagedAlertOptions(options or {})
   local res = performAlertsQuery("SELECT COUNT(*) AS count", what, opts)
   if((res ~= nil) and (#res == 1) and (res[1].count ~= nil)) then num = tonumber(res[1].count) end

   return num
end

-- #################################

function getAlerts(what, options)
   return performAlertsQuery("SELECT rowid, *", what, options)
end

-- #################################

function deleteAlerts(what, options)
   local opts = getUnpagedAlertOptions(options or {})
   performAlertsQuery("DELETE", what, opts)
end

-- #################################

-- this function returns an object with parameters specific for one tab
function getTabParameters(_get, what)
   local opts = {}
   for k,v in pairs(_get) do opts[k] = v end

   -- these options are contextual to the current tab (status)
   if _get.status ~= what then
      opts.alert_type = nil
      opts.alert_severity = nil
   end
   if not isEmptyString(what) then opts.status = what end
   return opts
end

-- #################################

-- Remove pagination options from the options
function getUnpagedAlertOptions(options)
   local res = {}

   local paged_option = { currentPage=1, perPage=1, sortColumn=1, sortOrder=1 }

   for k,v in pairs(options) do
      if not paged_option[k] then
         res[k] = v
      end
   end

   return res
end

-- #################################

function checkDeleteStoredAlerts()
   if((_POST["id_to_delete"] ~= nil) and (_GET["status"] ~= nil)) then
      if(_POST["id_to_delete"] ~= "__all__") then
         _GET["row_id"] = tonumber(_POST["id_to_delete"])
      end

      deleteAlerts(_GET["status"], _GET)
      -- to avoid performing the delete again
      _POST["id_to_delete"] = nil
      -- to avoid filtering by id
      _GET["row_id"] = nil
      -- in case of delete "older than" button, resets the time period after the delete took place
      if isEmptyString(_GET["epoch_begin"]) then _GET["epoch_end"] = nil end

      local new_num = getNumAlerts(_GET["status"], _GET)
      if new_num == 0 then
         -- reset the filter to avoid hiding the tab
         _GET["alert_severity"] = nil
         _GET["alert_type"] = nil
      end
   end
end

-- #################################

local function drawDropdown(status, selection_name, active_entry, entries_table)
   -- alert_level_keys and alert_type_keys are defined in lua_utils
   local id_to_label
   if selection_name == "severity" then
      id_to_label = alertSeverityLabel
   elseif selection_name == "type" then
      id_to_label = alertTypeLabel
   end

   -- compute counters to avoid printing items that have zero entries in the database
   local actual_entries = {}
   if status == "historical-flows" then

      if selection_name == "severity" then
	 actual_entries = interface.queryFlowAlertsRaw("select alert_severity id, count(*) count", "group by alert_severity")
      elseif selection_name == "type" then
	 actual_entries = interface.queryFlowAlertsRaw("select alert_type id, count(*) count", "group by alert_type")
      end

   else -- dealing with non flow alerts (engaged and closed)
      local engaged
      if status == "engaged" then
	 engaged = true
      elseif status == "historical" then
	 engaged = false
      end

      if selection_name == "severity" then
	 actual_entries = interface.queryAlertsRaw(engaged, "select alert_severity id, count(*) count", "group by alert_severity")
      elseif selection_name == "type" then
	 actual_entries = interface.queryAlertsRaw(engaged, "select alert_type id, count(*) count", "group by alert_type")
      end

   end

   local buttons = '<div class="btn-group">'

   local button_label = firstToUpper(selection_name)
   if active_entry ~= nil and active_entry ~= "" then
      button_label = firstToUpper(active_entry)..'<span class="glyphicon glyphicon-filter"></span>'
   end

   buttons = buttons..'<button class="btn btn-link dropdown-toggle" data-toggle="dropdown">'..button_label
   buttons = buttons..'<span class="caret"></span></button>'

   buttons = buttons..'<ul class="dropdown-menu dropdown-menu-right" role="menu">'

   local class_active = ""
   if active_entry == nil then class_active = ' class="active"' end
   buttons = buttons..'<li'..class_active..'><a href="?status='..status..'">All</a></i>'

   for _, entry in pairs(actual_entries) do
      local id = tonumber(entry["id"])
      local count = entry["count"]
      local label = id_to_label(id, true)

      class_active = ""
      if label == active_entry then class_active = ' class="active"' end
      -- buttons = buttons..'<li'..class_active..'><a href="'..ntop.getHttpPrefix()..'/lua/show_alerts.lua?status='..status
      buttons = buttons..'<li'..class_active..'><a href="?status='..status
      buttons = buttons..'&alert_'..selection_name..'='..id..'">'
      buttons = buttons..firstToUpper(label)..' ('..count..')</a></li>'
   end

   buttons = buttons..'</ul></div>'

   return buttons
end

-- #################################

-- This function makes a consistent abstraction on entities
function getAlertSource(entity, entity_value, alt_name)
   if entity == "host" then
      local host_name

      if alt_name then
         host_name = alt_name
      else
         local hostInfo = hostkey2hostinfo(entity_value)
         host_name = ntop.resolveAddress(hostInfo["host"])
      end

      return {
         source = "host",
         title = "Host",
         label = "Host " .. host_name,
         friendly_value = host_name,
      }
   else
      if string.find(entity_value, "/") ~= nil then
         local network_name
         if alt_name then
            network_name = alt_name
         else
            local hostInfo = hostkey2hostinfo(entity_value)
            network_name = hostInfo["host"]
         end

         return {
            source = "network",
            title = "Network",
            label = "Network " .. network_name,
            friendly_value = network_name,
         }
      else
         local interface_name
         if alt_name then
            interface_name = alt_name
         else
            -- TODO
            interface_name = ""
         end

         return {
            source = "interface",
            title = "Interface",
            label = "Interface " .. interface_name,
            friendly_value = interface_name,
         }
      end
   end
end

-- #################################

function drawAlertSettings(alert_source, alert_val)
   local alerts_enabled
   local host_or_network = ((alert_source.source == "host") or (alert_source.source == "network"))

   -- host specific
   local flow_rate_alert_thresh
   local syn_alert_thresh
   local flows_alert_thresh

   if not isAdministrator() then
      return
   end

   -- handle settings change
   local config_changed = false

   local trigger_alerts = _POST["trigger_alerts"]
   if(trigger_alerts ~= nil) then
      if(trigger_alerts == "true") then
         ntop.delHashCache(get_alerts_suppressed_hash_name(ifname), alert_val)
         alerts_enabled = true
      else
         ntop.setHashCache(get_alerts_suppressed_hash_name(ifname), alert_val, trigger_alerts)
         alerts_enabled = false
      end
      config_changed = true
   else
      if are_alerts_suppressed(alert_val, ifname) then
         alerts_enabled = false
      else
         alerts_enabled = true
      end
   end

   if host_or_network then
      local hostInfo = hostkey2hostinfo(alert_val)
      local host_ip = hostInfo["host"]
      local host_vlan = hostInfo["vlan"]

      flow_rate_alert_thresh = 'ntopng.prefs.'..host_ip..':'..tostring(host_vlan)..'.flow_rate_alert_threshold'
      syn_alert_thresh = 'ntopng.prefs.'..host_ip..':'..tostring(host_vlan)..'.syn_alert_threshold'
      flows_alert_thresh = 'ntopng.prefs.'..host_ip..':'..tostring(host_vlan)..'.flows_alert_threshold'

      if _POST["flow_rate_alert_threshold"] ~= nil and _POST["flow_rate_alert_threshold"] ~= "" then
         ntop.setPref(flow_rate_alert_thresh, _POST["flow_rate_alert_threshold"])
         flow_rate_alert_thresh = _POST["flow_rate_alert_threshold"]
         config_changed = true
      else
         local v = nil
         if _POST["flow_rate_alert_threshold"] == nil then
            v = ntop.getPref(flow_rate_alert_thresh)
         end

         if v ~= nil and v ~= "" then
            flow_rate_alert_thresh = v
         else
            flow_rate_alert_thresh = 25
         end
      end

      if _POST["syn_alert_threshold"] ~= nil and _POST["syn_alert_threshold"] ~= "" then
         ntop.setPref(syn_alert_thresh, _POST["syn_alert_threshold"])
         syn_alert_thresh = _POST["syn_alert_threshold"]
         config_changed = true
      else
         local v = nil
         if _POST["syn_alert_threshold"] == nil then
            v = ntop.getPref(syn_alert_thresh)
         end

         if v ~= nil and v ~= "" then
            syn_alert_thresh = v
         else
            syn_alert_thresh = 10
         end
      end
      if _POST["flows_alert_threshold"] ~= nil and _POST["flows_alert_threshold"] ~= "" then
         ntop.setPref(flows_alert_thresh, _POST["flows_alert_threshold"])
         flows_alert_thresh = _POST["flows_alert_threshold"]
         config_changed = true
      else
         local v = nil
         if _POST["flows_alert_threshold"] == nil then
            v = ntop.getPref(flows_alert_thresh)
         end

         if v ~= nil and v ~= "" then
            flows_alert_thresh = v
         else
            flows_alert_thresh = 32768
         end
      end
   end

   if config_changed then
      if alert_source.source == "host" then
         local hostInfo = hostkey2hostinfo(alert_val)
         local host_ip = hostInfo["host"]
         local host_vlan = hostInfo["vlan"]

         -- io.write("Reloading host '"..host_ip.."' alerts configuration...\n")
         interface.refreshHostAlertsConfiguration(host_ip, host_vlan)
      end
   end

   print("<table class=\"table table-striped table-bordered\">\n")

   -- Source agnostic settings

   local alerts_checked
   local alerts_value
   if alerts_enabled then
      alerts_checked = 'checked="checked"'
      alerts_value = "false" -- Opposite
   else
      alerts_checked = ""
      alerts_value = "true" -- Opposite
   end

   print [[
         <tr><th>]] print(alert_source.title) print[[ Alerts</th><td nowrap>
         <form id="alert_prefs" class="form-inline" style="margin-bottom: 0px;" method="post">]]
   print[[<input type="hidden" name="tab" value="alerts_preferences">]]
   print('<input type="hidden" name="trigger_alerts" value="'..alerts_value..'"><input type="checkbox" value="1" '..alerts_checked..' onclick="this.form.submit();"> <i class="fa fa-exclamation-triangle fa-lg"></i> Trigger alerts for '.. alert_source.label ..'</input>')
   print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')
   print('</form>')
   print('</td>')
   print [[</tr>]]

   -- Source specific settings
   if host_or_network then
      print("<tr><th width=250>" .. alert_source.title .. " Flow Alert Threshold</th>\n")
      print [[<td>]]
      print[[<form class="form-inline" style="margin-bottom: 0px;" method="post">]]
      print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')
      print('<input type="number" name="flow_rate_alert_threshold" style="width:7em;" placeholder="" min="0" step="1" max="100000" value="')
      print(tostring(flow_rate_alert_thresh))
      print [["></input>
      &nbsp;<button type="submit" style="position: absolute; margin-top: 0; height: 26px" class="btn btn-default btn-xs">Save</button>
       </form>
   <small>
       Max number of new flows/sec over which a host is considered a flooder. Default: 25.<br>
   </small>]]
	 print[[
       </td></tr>
          ]]

      print("<tr><th width=250>" .. alert_source.title .. " SYN Alert Threshold</th>\n")
      print [[<td>]]
      print[[<form class="form-inline" style="margin-bottom: 0px;" method="post">]]
      print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')
      print [[<input type="number" name="syn_alert_threshold" style="width:7em;" placeholder="" min="0" step="5" max="100000" value="]]
      print(tostring(syn_alert_thresh))
      print [["></input>
         &nbsp;<button type="submit" style="position: absolute; margin-top: 0; height: 26px" class="btn btn-default btn-xs">Save</button>
       </form>
   <small>
       Max number of sent TCP SYN packets/sec over which a host is considered a flooder. Default: 10.<br>
   </small>]]
	 print[[
       </td></tr>
          ]]

      print("<tr><th width=250>" .. alert_source.title .. " Flows Threshold</th>\n")
      print [[<td>]]
      print[[<form class="form-inline" style="margin-bottom: 0px;" method="post">]]
      print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')
      print [[<input type="number" name="flows_alert_threshold" style="width:7em;" placeholder="" min="0" step="1" max="100000" value="]]
      print(tostring(flows_alert_thresh))
      print [["></input>
         &nbsp;<button type="submit" style="position: absolute; margin-top: 0; height: 26px" class="btn btn-default btn-xs">Save</button>
       </form>
   <small>
       Max number of flows over which a host is considered a flooder. Default: 32768.<br>
   </small>]]
	 print[[
       </td></tr>
          ]]
   end

   print("</table>")
end

function drawAlertSourceSettings(alert_source, delete_button_msg, delete_confirm_msg, page_name, page_params, alt_name, show_entity)
   local num_engaged_alerts, num_past_alerts, num_flow_alerts = 0,0,0
   local tab = _GET["tab"]

   local descr
   if alert_source:match("/") then
      descr = network_alert_functions_description
   elseif not alert_source:match("%.") then
      -- interface
      descr = table.clone(alert_functions_description)
      descr["active"] = nil
   else
      descr = alert_functions_description
   end

   print('<ul class="nav nav-tabs">')

   local function printTab(tab, content, sel_tab)
      if(tab == sel_tab) then print("\t<li class=active>") else print("\t<li>") end
      print("<a href=\""..ntop.getHttpPrefix().."/lua/"..page_name.."?page=alerts&tab="..tab)
      for param, value in pairs(page_params) do
         print("&"..param.."="..value)
      end
      print("\">"..content.."</a></li>\n")
   end

   if(show_entity) then
      -- these fields will be used to perform queries
      _GET["entity"] = alertEntity(show_entity)
      _GET["entity_val"] = alert_source
   end

   if(show_entity) then
      -- possibly process pending delete arguments
      checkDeleteStoredAlerts()

      -- possibly add a tab if there are alerts configured for the host
      num_engaged_alerts = getNumAlerts("engaged", getTabParameters(_GET, "engaged"))
      num_past_alerts = getNumAlerts("historical", getTabParameters(_GET, "historical"))
      num_flow_alerts = getNumAlerts("historical-flows", getTabParameters(_GET, "historical-flows"))

      if num_past_alerts > 0 or num_engaged_alerts > 0 or num_flow_alerts > 0 then
         if(tab == nil) then
            -- if no tab is selected and there are alerts, we show them by default
            tab = "alert_list"
         end

         printTab("alert_list", "Detected Alerts", tab)
      else
         -- if there are no alerts, we show the alert settings
         if(tab=="alert_list") then tab = nil end
      end
   end

   if(tab == nil) then tab = "alert_settings" end

   printTab("alert_settings", '<i class="fa fa-cog" aria-hidden="true"></i>&nbsp;General Settings', tab)

   for _,e in pairs(alerts_granularity) do
      local k = e[1]
      local l = e[2]
      l = '<i class="fa fa-cog" aria-hidden="true"></i>&nbsp;'..l
      printTab(k, l, tab)
   end

   print('</ul>')

   if((show_entity) and (tab == "alert_list")) then
      drawAlertTables(num_past_alerts, num_engaged_alerts, num_flow_alerts, _GET, true)
   elseif(tab == "alert_settings") then
      drawAlertSettings(getAlertSource(show_entity, alert_source, alt_name), alert_source)
   else
      -- Before doing anything we need to check if we need to save values

      vals = { }
      alerts = ""
      to_save = false

      if((_POST["to_delete"] ~= nil) and (_POST["SaveAlerts"] == nil)) then
         delete_alert_configuration(alert_source, ifname)
         alerts = nil
      else
         for k,_ in pairs(descr) do
	    value    = _POST["value_"..k]
	    operator = _POST["operator_"..k]

	    if((value ~= nil) and (operator ~= nil)) then
	       --io.write("\t"..k.."\n")
	       to_save = true
	       value = tonumber(value)
	       if(value ~= nil) then
		  if(alerts ~= "") then alerts = alerts .. "," end
		  alerts = alerts .. k .. ";" .. operator .. ";" .. value
	       else
		  if ntop.isPro() then ntop.withdrawNagiosAlert(alert_source, tab, k, "alarm not installed") end
	       end
	    end
         end

         --print(alerts)

         if(to_save) then
            refresh_alert_configuration(alert_source, ifname, tab, alerts)
            if(alerts == "") then
               ntop.delHashCache(get_alerts_hash_name(tab, ifname), alert_source)
            else
               ntop.setHashCache(get_alerts_hash_name(tab, ifname), alert_source, alerts)
            end
         else
            alerts = ntop.getHashCache(get_alerts_hash_name(tab, ifname), alert_source)
         end
      end

      if(alerts ~= nil) then
         --print(alerts)
         --tokens = string.split(alerts, ",")
         tokens = split(alerts, ",")

         --print(tokens)
         if(tokens ~= nil) then
	    for _,s in pairs(tokens) do
	       t = string.split(s, ";")
	       --print("-"..t[1].."-")
	       if(t ~= nil) then vals[t[1]] = { t[2], t[3] } end
	    end
         end
      end


      print [[
       </ul>
       <table id="user" class="table table-bordered table-striped" style="clear: both"> <tbody>
       <tr><th width=20%>Alert Function</th><th>Threshold</th></tr>

      <form method="post">
      ]]
      print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')

      for k,v in pairsByKeys(descr, asc) do
         print("<tr><th>"..k.."</th><td>\n")
         print("<select name=operator_".. k ..">\n")
         if((vals[k] ~= nil) and (vals[k][1] == "gt")) then print("<option selected=\"selected\"") else print("<option ") end
         print("value=\"gt\">&gt;</option>\n")

         if((vals[k] ~= nil) and (vals[k][1] == "eq")) then print("<option selected=\"selected\"") else print("<option ") end
         print("value=\"eq\">=</option>\n")

         if((vals[k] ~= nil) and (vals[k][1] == "lt")) then print("<option selected=\"selected\"") else print("<option ") end
         print("value=\"lt\">&lt;</option>\n")
         print("</select>\n")
         print("<input type=text name=\"value_"..k.."\" value=\"")
         if(vals[k] ~= nil) then print(vals[k][2]) end
         print("\">\n\n")
         print("<br><small>"..v.."</small>\n")
         print("</td></tr>\n")
      end

      print [[
      <tr><th colspan=2  style="text-align: center; white-space: nowrap;" >

         <input type="hidden" name="SaveAlerts" value="">
         <input type="submit" class="btn btn-primary" value="Save Configuration">
      </form>

      <a href="#myModal" role="button" class="btn" data-toggle="modal">[ <i type="submit" class="fa fa-trash-o"></i> ]] print(delete_button_msg) print[[ ]</button></a>
      <!-- Modal -->
      <div class="modal fade" id="myModal" tabindex="-1" role="dialog" aria-labelledby="myModalLabel" aria-hidden="true">
        <div class="modal-dialog">
          <div class="modal-content">
       <div class="modal-header">
          <button type="button" class="close" data-dismiss="modal" aria-hidden="true">X</button>
          <h3 id="myModalLabel">Confirm Action</h3>
        </div>
        <div class="modal-body">
       <p>]] print(delete_confirm_msg) print(" ") if alt_name ~= nil then print(alt_name) else print(alert_source) end print[[?</p>
        </div>
        <div class="modal-footer">
          <form class=form-inline style="margin-bottom: 0px;" method="post">
          <input type=hidden name=to_delete value="">
      ]]
      print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')
      print [[    <button class="btn btn-default" data-dismiss="modal" aria-hidden="true">Close</button>
          <button class="btn btn-primary" type="submit">Delete All</button>
         </form>
        </div>
      </div>
      </div>

      </th> </tr>



      </tbody> </table>
      ]]
   end
end

-- #################################

function housekeepingAlertsMakeRoom()
   local ifnames = interface.getIfNames()
   for id, n in pairs(ifnames) do
      interface.select(n)

      local ifId = getInterfaceId(n)

      if interface.makeRoomRequested() then
	 local k = get_housekeeping_set_name(ifId)

	 local members = ntop.getMembersCache(k)
	 for _, m in pairs(members) do
	    ntop.delMembersCache(k, m)
	    m = m:split("|")

	    local alert_entity = tonumber(m[1])
	    local alert_entity_value = m[2]
	    local table_name = m[3]

	    interface.makeRoomAlerts(alert_entity, alert_entity_value, table_name)
	 end
      end
   end
end

-- #################################

function drawAlertTables(num_past_alerts, num_engaged_alerts, num_flow_alerts, get_params, hide_extended_title, alt_nav_tabs)
   local alert_items = {}
   local url_params = {}
   for k,v in pairs(get_params) do if k ~= "csrf" then url_params[k] = v end end

      print [[
     <div align=right><i id="PageRefresh" class="fa fa-refresh" aria-hidden="true"></i></div>

        <script type="text/javascript">
            $('#PageRefresh').click(function() {
                document.location = "]] print(ntop.getHttpPrefix().."/lua/show_alerts.lua") print [[";
            });
        </script>
]]


      if not alt_nav_tabs then
	 print[[
<br>
<ul class="nav nav-tabs" role="tablist" id="alert-tabs">
<!-- will be populated later with javascript -->
</ul>
]]
	 nav_tab_id = "alert-tabs"
      else
	 nav_tab_id = alt_nav_tabs
      end

      print[[
<script>

function checkAlertActionsPanel() {
   /* check if this tab is handled by this script */
   if(getCurrentStatus() == "")
      $("#alertsActionsPanel").css("display", "none");
   else
      $("#alertsActionsPanel").css("display", "");
}

function setActiveHashTab(hash) {
   $('#]] print(nav_tab_id) --[[ see "clicked" below for the other part of this logic ]] print[[ a[href="' + hash + '"]').tab('show');
}

/* Handle the current tab */
$(function() {
 $("ul.nav-tabs > li > a").on("shown.bs.tab", function(e) {
      var id = $(e.target).attr("href").substr(1);
      history.replaceState(null, null, "#"+id);
      updateDeleteLabel(id);
      updateDeleteContext(id);
      checkAlertActionsPanel();
   });

  var hash = window.location.hash;
  if (! hash && ]] if(isEmptyString(status) and not isEmptyString(_GET["tab"])) then print("true") else print("false") end print[[)
    hash = "#]] print(_GET["tab"] or "") print[[";

  if (hash)
    setActiveHashTab(hash)

  $(function() { checkAlertActionsPanel(); });
});

function getActiveTabId() {
   return $("#]] print(nav_tab_id) print[[ > li.active > a").attr('href').substr(1);
}

function updateDeleteLabel(tabid) {
   var label = $("#purgeBtnLabel");
   var prefix = "]]
      if not isEmptyString(_GET["entity"]) then print(alertEntityLabel(_GET["entity"], true).." ") end
      print [[";
   var val = "";

   if (tabid == "tab-table-engaged-alerts")
      val = "Engaged ";
   else if (tabid == "tab-table-alerts-history")
      val = "Past ";
   else if (tabid == "tab-table-flow-alerts-history")
      val = "Past Flow ";

   label.html(prefix + val);
}

function updateDeleteContext(tabid) {
   $("#modalDeleteForm input[name='status']").val(getCurrentStatus());
}

function getCurrentStatus() {
   var tabid = getActiveTabId();

   if (tabid == "tab-table-engaged-alerts")
      val = "engaged";
   else if (tabid == "tab-table-alerts-history")
      val = "historical";
   else if (tabid == "tab-table-flow-alerts-history")
      val = "historical-flows";
   else
      val = "";

   return val;
}
</script>
]]
      if not alt_nav_tabs then print [[<div class="tab-content">]] end

      local status = _GET["status"]
      local status_reset = 0

      if num_engaged_alerts > 0 then
	 alert_items[#alert_items + 1] = {["label"] = i18n("show_alerts.engaged_alerts"),
	    ["div-id"] = "table-engaged-alerts",  ["status"] = "engaged"}
      elseif status == "engaged" then
	 status = nil; status_reset = 1
      end

      if num_past_alerts > 0 then
	 alert_items[#alert_items +1] = {["label"] = i18n("show_alerts.past_alerts"),
	    ["div-id"] = "table-alerts-history",  ["status"] = "historical"}
      elseif status == "historical" then
	 status = nil; status_reset = 1
      end

      if num_flow_alerts > 0 then
	 alert_items[#alert_items +1] = {["label"] = i18n("show_alerts.flow_alerts"),
	    ["div-id"] = "table-flow-alerts-history",  ["status"] = "historical-flows"}
      elseif status == "historical-flows" then
	 status = nil; status_reset = 1
      end

      for k, t in ipairs(alert_items) do
	 local clicked = "0"
	 if((not alt_nav_tabs) and ((k == 1 and status == nil) or (status ~= nil and status == t["status"]))) then
	    clicked = "1"
	 end
	 print [[
      <div class="tab-pane fade in" id="tab-]] print(t["div-id"]) print[[">
        <div id="]] print(t["div-id"]) print[["></div>
      </div>

      <script type="text/javascript">

         $("#]] print(nav_tab_id) print[[").append('<li><a href="#tab-]] print(t["div-id"]) print[[" clicked="]] print(clicked) print[[" role="tab" data-toggle="tab">]] print(t["label"]) print[[</a></li>')

         $('a[href="#tab-]] print(t["div-id"]) print[["]').on('shown.bs.tab', function (e) {
         // append the li to the tabs

	 $("#]] print(t["div-id"]) print[[").datatable({
			url: "]] print(ntop.getHttpPrefix()) print [[/lua/get_alerts_data.lua?" + $.param(]] print(tableToJsObject(getTabParameters(url_params, t["status"]))) print [[),
               showFilter: true,
	       showPagination: true,
               buttons: [']]

	 local title = t["label"]

	 -- TODO this condition should be removed and page integration support implemented
	 if((isEmptyString(_GET["entity"])) and isEmptyString(_GET["epoch_begin"]) and isEmptyString(_GET["epoch_end"])) then
	    -- alert_level_keys and alert_type_keys are defined in lua_utils
	    local alert_severities = {}
	    for _, s in pairs(alert_level_keys) do alert_severities[#alert_severities +1 ] = s[3] end
	    local alert_types = {}
	    for _, s in pairs(alert_type_keys) do alert_types[#alert_types +1 ] = s[3] end

	    local a_type, a_severity = nil, nil
	    if clicked == "1" then
	       if tonumber(_GET["alert_type"]) ~= nil then a_type = alertTypeLabel(_GET["alert_type"], true) end
	       if tonumber(_GET["alert_severity"]) ~= nil then a_severity = alertSeverityLabel(_GET["alert_severity"], true) end
	    end

	    print(drawDropdown(t["status"], "type", a_type, alert_types))
	    print(drawDropdown(t["status"], "severity", a_severity, alert_severities))
	 elseif((not isEmptyString(_GET["entity_val"])) and (not hide_extended_title)) then
	    if entity == "host" then
	       title = title .. " - " .. getAlertSource(entity, _GET["entity_val"]).label
	    end
	 end

	 print[['],
/*
               buttons: ['<div class="btn-group"><button class="btn btn-link dropdown-toggle" data-toggle="dropdown">Severity<span class="caret"></span></button><ul class="dropdown-menu" role="menu"><li>test severity</li></ul></div><div class="btn-group"><button class="btn btn-link dropdown-toggle" data-toggle="dropdown">Type<span class="caret"></span></button><ul class="dropdown-menu" role="menu"><li>test type</li></ul></div>'],
*/
]]

	 if(_GET["currentPage"] ~= nil and _GET["status"] == t["status"]) then
	    print("currentPage: ".._GET["currentPage"]..",\n")
	 end
	 if(_GET["perPage"] ~= nil and _GET["status"] == t["status"]) then
	    print("perPage: ".._GET["perPage"]..",\n")
	 end
	 print ('sort: [ ["' .. getDefaultTableSort("alerts") ..'","' .. getDefaultTableSortOrder("alerts").. '"] ],\n')
	 print [[
	        title: "]] print(title) print[[",
      columns: [
	 {
	    title: "]]print(i18n("show_alerts.alert_actions"))print[[",
	    field: "column_key",
	    css: {
	       textAlign: 'center', width: '100px'
	    }
	 },

	 {
	    title: "]]print(i18n("show_alerts.alert_datetime"))print[[",
	    field: "column_date",
            sortable: true,
	    css: {
	       textAlign: 'center'
	    }
	 },
]]

	 if t["status"] ~= "historical-flows" then
	    print[[
	 {
	    title: "]]print(i18n("show_alerts.alert_duration"))print[[",
	    field: "column_duration",
            sortable: true,
	    css: {
	       textAlign: 'center'
	    }
	 },
	 ]]
	 end

	 print[[
	 {
	    title: "]]print(i18n("show_alerts.alert_severity"))print[[",
	    field: "column_severity",
            sortable: true,
	    css: {
	       textAlign: 'center'
	    }
	 },

	 {
	    title: "]]print(i18n("show_alerts.alert_type"))print[[",
	    field: "column_type",
            sortable: true,
	    css: {
	       textAlign: 'center'
	    }
	 },

	 {
	    title: "]]print(i18n("show_alerts.alert_description"))print[[",
	    field: "column_msg",
	    css: {
	       textAlign: 'left'
	    }
	 }
      ]
   });
   });
   ]]
	 if (clicked == "1") then
	    print[[
         // must wait for modalDeleteAlertsStatus to be created
         $(function() {
            var status_reset = ]] print(status_reset) --[[ this is necessary because of status parameter inconsistency after tab switch ]] print[[;
            var tabid;

            if ((status_reset) || (getCurrentStatus() == "")) {
               tabid = "]] print("tab-"..t["div-id"]) print[[";
               history.replaceState(null, null, "#"+tabid);
            } else {
               tabid = getActiveTabId();
            }

            updateDeleteLabel(tabid);
            updateDeleteContext(tabid);
         });
      ]]
	 end
	 print[[
   </script>
	      ]]

      end

      local zoom_vals = {
	 { "5 min",  5*60*1, i18n("show_alerts.older_5_minutes_ago") },
	 { "30 min", 30*60*1, i18n("show_alerts.older_30_minutes_ago") },
	 { "1 hour",  60*60*1, i18n("show_alerts.older_1_hour_ago") },
	 { "1 day",  60*60*24, i18n("show_alerts.older_1_day_ago") },
	 { "1 week",  60*60*24*7, i18n("show_alerts.older_1_week_ago") },
	 { "1 month",  60*60*24*31, i18n("show_alerts.older_1_month_ago") },
	 { "6 months",  60*60*24*31*6, i18n("show_alerts.older_6_months_ago") },
	 { "1 year",  60*60*24*366 , i18n("show_alerts.older_1_year_ago") }
      }

      if (num_past_alerts > 0 or num_flow_alerts > 0 or num_engaged_alerts > 0) then
	 -- trigger the click on the right tab to force table load
	 print[[
<script type="text/javascript">
$("[clicked=1]").trigger("click");
</script>
]]

	 if not alt_nav_tabs then print [[</div> <!-- closes tab-content -->]] end
	 local has_fixed_period = ((not isEmptyString(_GET["epoch_begin"])) or (not isEmptyString(_GET["epoch_end"])))

	 print('<div id="alertsActionsPanel">')
	 print('<br>Alerts to Purge: ')
	 print[[<select id="deleteZoomSelector" class="form-control" style="display:]] if has_fixed_period then print("none") else print("inline") end print[[; width:14em; margin:0 1em;">]]
	 local all_msg = ""

	 if not has_fixed_period then
	    print('<optgroup label="older than">')
	    for k,v in ipairs(zoom_vals) do
	       print('<option data-older="'..(os.time() - zoom_vals[k][2])..'" data-msg="'.." "..zoom_vals[k][3].. '">'..zoom_vals[k][1]..'</option>\n')
	    end
	    print('</optgroup>')
	 else
	    all_msg = " in the selected time period"
	 end

	 print('<option selected="selected" data-older="0" data-msg="') print(all_msg) print('">All</option>\n')


	 print[[</select>]]
	 print[[<button id="buttonOpenDeleteModal" data-toggle="modal" data-target="#myModal" class="btn btn-default"><i type="submit" class="fa fa-trash-o"></i> Purge <span id="purgeBtnLabel"></span>Alerts</button>
<!-- Modal -->
<div class="modal fade" id="myModal" tabindex="-1" role="dialog" aria-labelledby="myModalLabel" aria-hidden="true">
  <div class="modal-dialog">
    <div class="modal-content">
      <div class="modal-header">
    <button type="button" class="close" data-dismiss="modal" aria-hidden="true">X</button>
    <h3 id="myModalLabel">Confirm Action</h3>
  </div>
  <div class="modal-body">
    <p>Do you really want to purge all the<span id="modalDeleteContext"></span> alerts<span id="modalDeleteAlertsMsg"></span>?</p>
  </div>
  <div class="modal-footer">

    <form id="modalDeleteForm" class=form-inline style="margin-bottom: 0px;" method="post" onsubmit="return checkModalDelete();">
         <input type="hidden" id="modalDeleteAlertsOlderThan" value="-1" />
      ]]
	    print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')

	 -- we need to dynamically modify parameters at js-time because we switch tab
	 local delete_params = getTabParameters(url_params, nil)
	 delete_params.epoch_end = -1

	 print [[
    <button class="btn btn-default" data-dismiss="modal" aria-hidden="true">Close</button>
    <button class="btn btn-primary" type="submit">Purge [<img id="alerts-summary-wait" src="]] print(ntop.getHttpPrefix()) print[[/img/loading.gif"\><span id="alerts-summary-body"></span> alerts]</button>
</form>
  </div>
  </div>
</div>
</div>
</div> <!-- closes alertsActionsPanel -->

<script>

paramsToForm('#modalDeleteForm', ]] print(tableToJsObject(delete_params)) print[[);

function getTabSpecificParams() {
   var tab_specific = {status:getCurrentStatus()};
   var period_end = $('#modalDeleteAlertsOlderThan').val();
   if (parseInt(period_end) > 0)
      tab_specific.epoch_end = period_end;

   if (tab_specific.status == "]] print(_GET["status"]) print[[") {
      tab_specific.alert_severity = ]] if tonumber(_GET["alert_severity"]) ~= nil then print(_GET["alert_severity"]) else print('""') end print[[;
      tab_specific.alert_type = ]] if tonumber(_GET["alert_type"]) ~= nil then print(_GET["alert_type"]) else print('""') end print[[;
   }

   // merge the general parameters to the tab specific ones
   return paramsExtend(]] print(tableToJsObject(getTabParameters(url_params, nil))) print[[, tab_specific);
}

function checkModalDelete() {
   var get_params = getTabSpecificParams();
   var post_params = {};
   post_params.csrf = "]] print(ntop.getRandomCSRFValue()) print[[";
   post_params.id_to_delete = "__all__";

   // this actually performs the request
   var form = paramsToForm('<form method="post"></form>', post_params);
   form.attr("action", "?" + $.param(get_params));
   form.appendTo('body').submit();
   return false;
}

var cur_alert_num_req = null;

/* This acts before shown.bs.modal event, avoiding visual fields substitution glitch */
$('#buttonOpenDeleteModal').on('click', function() {
   var lb = $("#purgeBtnLabel");
   var zoomsel = $("#deleteZoomSelector").find(":selected");

   $(".modal-body #modalDeleteAlertsMsg").html(zoomsel.data('msg') + ']]
	 if tonumber(_GET["alert_severity"]) ~= nil then
	    print(' with severity "'..alertSeverityLabel(_GET["alert_severity"], true)..'" ')
	 elseif tonumber(_GET["alert_type"]) ~= nil then
	    print(' with type "'..alertTypeLabel(_GET["alert_type"], true)..'" ')
	 end
	 print[[');
   if (lb.length == 1)
      $(".modal-body #modalDeleteContext").html(" " + lb.html());

   $('#modalDeleteAlertsOlderThan').val(zoomsel.data('older'));

   cur_alert_num_req = $.ajax({
      type: 'GET',
      ]] print("url: '"..ntop.getHttpPrefix().."/lua/get_num_alerts.lua'") print[[,
       data: getTabSpecificParams(),
       complete: function() {
         $("#alerts-summary-wait").hide();
       }, error: function() {
         $("#alerts-summary-body").html("?");
       }, success: function(count){
         $("#alerts-summary-body").html(count);
         if (count == 0)
            $('#myModal button[type="submit"]').attr("disabled", "disabled");
       }
    });
});

$('#myModal').on('hidden.bs.modal', function () {
   if(cur_alert_num_req) {
      cur_alert_num_req.abort();
      cur_alert_num_req = null;
   }

   $("#alerts-summary-wait").show();
   $("#alerts-summary-body").html("");
   $('#myModal button[type="submit"]').removeAttr("disabled");
})
</script>]]
      end

end

function alertAnomalousHosts()
   local ifnames = interface.getIfNames()
   local cb = function(_ifname, ifstats)
      local ha = interface.getHostsWithAnomalies()

      for host_key, host_stats in pairs(ha) do
	 local anomalies = host_stats["anomalies"]

	 if type(anomalies) == "table" then
	    for anom_key, anom_stats in pairs(anomalies) do
	       -- TODO: engage alert for anom_key if alert has not yet been engaged
	    end
	 end
      end

      --TODO: check, among the currently engaged alerts, those that are no longed engaged
      -- by checking in ha retrieved above. If an alert is engaged, but the corresponding host
      -- is no longer in ha, then the alert must be released.
   end

   callback_utils.foreachInterface(ifnames, enable_second_debug, cb)
end

-- #################################

local function getEngagedAlertsCacheKey(granularity)
   return "ntopng.cache.engaged_alerts_cache_" .. granularity
end

local function getConfiguredAlertsThresholds(ifname, granularity)
  local thresholds_key = get_alerts_hash_name(granularity, ifname)
  local res = {}

  for entity_val, thresholds_str in pairs(ntop.getHashAllCache(thresholds_key) or {}) do
    local thresholds = split(thresholds_str, ",")
    res[entity_val] = {}

    for _, threshold in pairs(thresholds) do
      local parts = string.split(threshold, ";")
      if #parts == 3 then
        local alert_key = granularity .. "_" .. parts[1] -- the alert key is the concatenation of the granularity and the metric
        res[entity_val][parts[1]] = {metric=parts[1], operator=parts[2], edge=parts[3], key=alert_key}
      end
    end
  end

  return res
end

local function engageAlert(entity_type, entity_value, atype, akey, message)
  -- TOOD engage based on the entity_type
  if(verbose) then io.write("Engage Alert: "..entity_value.." "..atype.." "..akey..": "..message.."\n") end
end

local function releaseAlert(entity_type, entity_value, atype, message)
  -- TOOD release based on the entity_type
  if(verbose) then io.write("Release Alert: "..entity_value.." "..alert.atype.." "..alert.akey..": "..message.."\n") end
end

local function getEngagedAlertsCache(granularity)
   -- TODO: this function should return the engaged alerts for the given granularity, from redis or from SQLite
   return {}
end

function invalidateEngagedAlertsCache()
  local keys = ntop.getKeysCache(getEngagedAlertsCacheKey("*")) or {}

  for key in pairs(keys) do
    ntop.delCache(key)
  end

  if(verbose) then io.write("Engaged Alerts Cache invalidated\n") end
end

-- #################################

local function check_entity_alerts(ifname, entity_type, entity_value, working_status, old_entity_info, entity_info)
  if are_alerts_suppressed(entity_value, ifname) then return end

  local granularity = working_status.granularity
  local engaged_cache = working_status.engaged_cache
  local current_alerts = {}
  local invalidate = false

  if (granularity == "min") and (entity_type == "host") then
    -- Populate current_alerts with host anomalies
    for anomal_name, anomaly in pairs(entity_info.anomalies or {}) do
      if starts(anomal_name, "syn_flood") then
        current_alerts["tcp_syn_flood"] = current_alerts["tcp_syn_flood"] or {}
        current_alerts["tcp_syn_flood"][anomaly] = true
      end
    end
  end

  -- Populate current_alerts with threshold crosses
  for _, threshold in pairs(working_status.configured_thresholds[entity_value] or {}) do
    local exceeded = entity_threshold_crossed(ifname, granularity, old_entity_info, entity_info, threshold)

    if exceeded then
      current_alerts["threshold_cross"] = current_alerts["threshold_cross"] or {}
      current_alerts["threshold_cross"][threshold.key] = true
    end
  end

  -- Process current_alerts to detect Engage / Release
  for atype, akeys in pairs(current_alerts) do
    for akey in pairs(akeys) do
      if ((engaged_cache[entity_type] == nil)
          or (engaged_cache[entity_type][entity_value] == nil)
          or (engaged_cache[entity_type][entity_value][atype] == nil)
          or (engaged_cache[entity_type][entity_value][atype][akey] == nil)) then
        engageAlert(entity_type, entity_value, atype, akey, "")
        working_status.dirty_cache = true
      end
    end
  end

  if (engaged_cache[entity_type] ~= nil) and (engaged_cache[entity_type][entity_value] ~= nil) then
    for atype, akey in pairs(engaged_cache[entity_type][entity_value]) do
      if (current_alerts[atype] ~= nil) and (current_alerts[atype][akey] ~= nil) then
        releaseAlert(entity_type, entity_value, atype, akey, "")
        working_status.dirty_cache = true
      end
    end
  end
end

-- #################################

local function entity_threshold_status_rw(granularity, ifname_id, fname, use_persistance, to_write --[[nil if it's a read]])
   local basedir = fixPath(dirs.workingdir .. "/" .. ifname_id .. "/json/" .. granularity)
   local fpath = fixPath(basedir.."/"..fname)

   if to_write ~= nil then
      local path = string.match(fpath, ".*/")
      if not(ntop.exists(path)) then
         ntop.mkdir(path)
      end

      -- Write new version
      if use_persistance then
         persistence.store(fpath, to_write)
      else
         local f = io.open(fpath, "w")
         if f ~= nil then
            f:write(to_write)
            f:close()
         end
      end
   elseif ntop.exists(fpath) then
      -- Read old version
      local old_dump = nil

      if use_persistance then
         old_dump = persistence.load(fpath)
      else
         local f = io.open(fpath, "r")
         if(f ~= nil) then
            old_dump = f:read("*all")
            f:close()
            if not isEmptyString(old_dump) then
               old_dump = j.decode(old_dump, 1, nil)
            end
         end
      end

      if old_dump ~= nil then
         return old_dump
      end
   end
end

local function interface_threshold_status_rw(granularity, ifid,  to_write)
   return entity_threshold_status_rw(granularity, ifid, "iface_"..ifid.."_lastdump", true, to_write)
end

local function network_threshold_status_rw(granularity, ifid, network, to_write)
   return entity_threshold_status_rw(granularity, ifid, getPathFromKey(network) .. "/alarmed_subnet_stats_lastdump", true, to_write)
end

local function host_threshold_status_rw(granularity, ifid, hostinfo, to_write)
   return entity_threshold_status_rw(granularity, ifid, hostinfo.ip .. ".json", false, to_write)
end

-- #################################

local function check_interface_alerts(ifname, ifid, working_status)
   local ifstats = interface.getStats()
   local entity_value = "iface_"..ifid

   if working_status.configured_thresholds[entity_value] then
      local old_entity_info = interface_threshold_status_rw(working_status.granularity, ifid) -- read old json
      local new_entity_info = ifstats

      -- Check if there is any threshold configured for the interface
      if old_entity_info ~= nil then
         check_entity_alerts(ifname, "iface", entity_value, working_status, old_entity_info, new_entity_info)
      end

      interface_threshold_status_rw(working_status.granularity, ifid, new_entity_info) -- write new json
   end
end

local function check_networks_alerts(ifname, ifid, working_status)
   local subnet_stats = interface.getNetworksStats()

   for subnet, sstats in pairs(subnet_stats) do
      -- Check if there is any threshold configured for the network
      if working_status.configured_thresholds[subnet] then
         local old_entity_info = network_threshold_status_rw(working_status.granularity, ifid, subnet) -- read old json
         local new_entity_info = sstats

         if old_entity_info ~= nil then
            check_entity_alerts(ifname, "network", subnet, working_status, old_entity_info, new_entity_info)
         end

         network_threshold_status_rw(working_status.granularity, ifid, subnet, new_entity_info) -- write new json
      end
   end
end

local function check_hosts_alerts(ifname, ifid, working_status)
   local hosts = interface.getLocalHostsInfo(false)

   if hosts ~= nil then
      for host, hoststats in pairs(hosts["hosts"] or {}) do
         local hostinfo = interface.getHostInfo(host)
         local entity_value = hostinfo2hostkey({host=host, vlan=hostinfo.vlan}, nil, true --[[force vlan]])
         local old_entity_info = host_threshold_status_rw(working_status.granularity, ifid, hostinfo)  -- read old json
         local new_entity_info_json = hostinfo["json"]

         if old_entity_info ~= nil then
            check_entity_alerts(ifname, "host", entity_value, working_status, old_entity_info, j.decode(new_entity_info_json, 1, nil))
         end

         host_threshold_status_rw(working_status.granularity, ifid, hostinfo, new_entity_info_json) -- write new json
      end
   end
end

-- #################################

function scanAlerts(granularity, ifname)
   if(verbose) then print("[minute.lua] Scanning ".. granularity .." alerts for interface " .. ifname.."<p>\n") end
   local ifid = getInterfaceId(ifname)

   local working_status = {
      granularity = granularity,
      engaged_cache = getEngagedAlertsCache(granularity),
      configured_thresholds = getConfiguredAlertsThresholds(ifname, granularity),
      dirty_cache = false,
   }

   check_interface_alerts(ifname, ifid, working_status)
   check_networks_alerts(ifname, ifid, working_status)
   check_hosts_alerts(ifname, ifid, working_status)

   if working_status.dirty_cache then
      invalidateEngagedAlertsCache()
   end
end
