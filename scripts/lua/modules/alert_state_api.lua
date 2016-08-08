--
-- (C) 2014-16 - ntop.org
--

--[[

This file contains the set of API functions used to deal with stateful alerts.

--]]

-- dirs = ntop.getDirs()
-- package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "alert_state_utils"
require "lua_utils"

function refresh_threshold_alert_configuration(alert_source, ifname, timespan, alerts_string)
   if tostring(alerts_string) == nil then return nil end
   if is_allowed_timespan(timespan) == false then return nil end
   local ifid = getInterfaceId(ifname)
   -- check if we are processing a pair ip-vlan such as 192.168.1.0@0
   if string.match(alert_source, "@") then
      local host_info = hostkey2hostinfo(alert_source)
      local host_ip   = host_info["host"]
      local host_vlan = host_info["vlan"]
      local ongoing_hname = get_host_ongoing_hash_name(ifid, host_ip, host_vlan)
      local ongoing_alerts = ntop.getHashKeysCache(ongoing_hname)
      if ongoing_alerts == nil then return true --[[ nothing to do --]] end
      local new_alerts = {}

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
	    new_alerts[get_threshold_alert_id(timespan, metric)] = "dummy" -- just a placeholder
	 end
	 ::continue::
      end

      -- check if there are some ongoing alerts that no longer exist in new_alerts
      -- we want to close those alerts
      for oa, _ in pairs(ongoing_alerts) do
	 if new_alerts[oa] == nil then
	    alert_move_ongoing_to_closed(ifid, ongoing_hname, oa)
	 end
      end

   else
      local check = "TODO"
      -- check if is an interface or a network
   end
end

function fire_threshold_host_alert(ifid, host, timespan, metric, alert_severity, msg)
   local host_info = hostkey2hostinfo(host)
   local host_ip   = host_info["host"]
   local host_vlan = host_info["vlan"]
   local ongoing_hname = get_host_ongoing_hash_name(ifid, host_ip, host_vlan)
   local ongoing_hkey  = get_threshold_alert_id(timespan, metric)
   local ongoing_value = ntop.getHashCache(ongoing_hname, ongoing_hkey)
   local alert = {}
   if ongoing_value == "" or ongoing_value == nil then
      -- there was no ongoing alert on the given alert_id
      alert = {} -- empty
   else
      alert = ongoing_value
   end

   alert = forge_alert(alert, alert_severity,
		       2 --[[ see alert_type_keys in lua_utils.lua for the alert type --]],
		       msg)
   alert = j.encode(alert, nil) -- convert the table to a json string

   ntop.setHashCache(ongoing_hname, ongoing_hkey, alert)
   return true
end

function withdraw_threshold_host_alert(ifid, host, timespan, metric, alert_severity, msg)
   local host_info = hostkey2hostinfo(host)
   local host_ip   = host_info["host"]
   local host_vlan = host_info["vlan"]
   
   local ongoing_hname = get_host_ongoing_hash_name(ifid, host_ip, host_vlan)
   local ongoing_hkey  = get_threshold_alert_id(timespan, metric)

   return alert_move_ongoing_to_closed(ifid, ongoing_hname, ongoing_hkey)
end


function retrieve_host_alerts_histogram(ifid, hosts, epoch_begin, epoch_end)
   if tonumber(epoch_begin) == nil then return nil else epoch_begin = tonumber(epoch_begin) end
   if tonumber(epoch_end)   == nil then return nil else epoch_end   = tonumber(epoch_end)   end

   if epoch_end < epoch_begin then epoch_end = epoch_begin end

   -- align epochs to the minute
   epoch_begin = epoch_begin - (epoch_begin % 60)
   epoch_end   = epoch_end   - (epoch_end   % 60)

   local tokens
   if hosts == '*' or hosts == '*@*' then
      tokens = {"*@*"}
   else
      tokens = split(hosts, ",")
      if tokens == nil then tokens = {} end
   end

   local histogram = {}
   for when = epoch_begin, epoch_end, 60 do

      for _, host in pairs(tokens) do
	 local host_info = hostkey2hostinfo(host)
	 local host_ip   = host_info["host"]
	 local host_vlan = host_info["vlan"]
	 if host_vlan == nil then host_vlan = '*' end
	 -- TODO: retrieve ongoing alerts and attach information to the histogram
      end
   end
   -- tprint(histogram)
   return histogram
end

--retrieve_host_alerts_histogram(1, "192.168.2.2@0,127.0.0.1@5", 333333, 333334)
--retrieve_host_alerts_histogram(0, "*@*", 1470242400, 1470242520)
