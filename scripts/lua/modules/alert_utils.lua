--
-- (C) 2014-16 - ntop.org
--

-- This file contains the description of all functions
-- used to trigger host alerts

local verbose = false

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

function get_re_arm_alerts_hash_name(timespan)
   if not is_allowed_timespan(timespan) then
      return nil
   end
   return "ntopng.prefs.alerts_"..timespan.."_re_arm_minutes"
end

function get_re_arm_alerts_temporary_key(timespan, ifname, alarmed_source, alarmed_metric)
   local ifid = getInterfaceId(ifname)
   if not is_allowed_timespan(timespan) or tonumber(ifid) == nil or not is_allowed_alarmable_metric(alarmed_metric) then
      return nil
   end
   local alarm_string = alarmed_source.."_"..timespan.."_"..alarmed_metric
   return "ntopng.alerts.ifid_"..tostring(ifid).."_re_arming_"..alarm_string
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

function bytes(old, new)
    if(new["sent"] ~= nil) then
        -- Host
        return((new["sent"]["bytes"]+new["rcvd"]["bytes"])-(old["sent"]["bytes"]+old["rcvd"]["bytes"]))
    else
       -- Interface
        return(new.stats.bytes - old.stats.bytes)
    end
end

function packets(old, new)
    if(new["sent"] ~= nil) then
        -- Host
        return((new["sent"]["packets"]+new["rcvd"]["packets"])-(old["sent"]["packets"]+old["rcvd"]["packets"]))
    else
        -- Interface
        return(new.stats.packets - old.stats.packets)
    end
end

function idle(old, new)
      local diff = os.time()-new["seen.last"]
      return(diff)
end

function dns(old, new)   return(proto_bytes(old, new, "DNS")) end
function p2p(old, new)   return(proto_bytes(old, new, "eDonkey")+proto_bytes(old, new, "BitTorrent")+proto_bytes(old, new, "Skype")) end

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

alerts_granularity = {
    { "min", "Every Minute" },
    { "5mins", "Every 5 Minutes" },
    { "hour", "Hourly" },
    { "day", "Daily" }
}

alarmable_metrics = {'bytes', 'packets', 'dns', 'p2p', 'idle', 'ingress', 'egress', 'inner'}

default_re_arm_minutes = {
    ["min"]  = 1    ,
    ["5mins"]= 5    ,
    ["hour"] = 60   ,
    ["day"]  = 3600
}

alert_functions_description = {
    ["bytes"]   = "Bytes delta (sent + received)",
    ["packets"] = "Packets delta (sent + received)",
    ["dns"]     = "DNS traffic delta bytes (sent + received)",
    ["p2p"]     = "Peer-to-peer traffic delta bytes (sent + received)",
    ["idle"]    = "Idle time since last packet sent (seconds)",
}

network_alert_functions_description = {
    ["ingress"] = "Ingress Bytes delta",
    ["egress"]  = "Egress Bytes delta",
    ["inner"]   = "Inner Bytes delta",
}


function re_arm_alert(alarm_source, timespan, alarmed_metric, ifname)
   local ifid = getInterfaceId(ifname)
   local re_arm_key = get_re_arm_alerts_temporary_key(timespan, ifname, alarm_source, alarmed_metric)
   local re_arm_minutes = ntop.getHashCache(get_re_arm_alerts_hash_name(timespan),
					    "ifid_"..tostring(ifid).."_"..alarm_source)
   if re_arm_minutes ~= "" then
      re_arm_minutes = tonumber(re_arm_minutes)
   else
      re_arm_minutes = default_re_arm_minutes[timespan]
   end
   if verbose then io.write('re_arm_minutes: '..re_arm_minutes..'\n') end
   -- we don't care about key contents, we just care about its exsistance
   if re_arm_minutes == 0 then
      return  -- don't want to re arm the alert
   end
   ntop.setCache(re_arm_key, "dummy",
		 re_arm_minutes * 60 - 5 --[[ subtract 5 seconds to make sure the limit is obeyed --]])
end

function is_alert_re_arming(alarm_source, timespan, alarmed_metric, ifname)
   local re_arm_key = get_re_arm_alerts_temporary_key(timespan, ifname, alarm_source, alarmed_metric)
   local is_rearming = ntop.getCache(re_arm_key)
   if is_rearming ~= "" then
      if verbose then io.write('re_arm_key: '..re_arm_key..' -> ' ..is_rearming..'-- \n') end
      return true
   end
   return false
end

-- #################################################################
function delete_re_arming_alerts(alert_source, ifid)
   for k1, timespan in pairs(alerts_granularity) do
        timespan = timespan[1]
        local alarm_string = alert_source.."_"..timespan
        for k2, alarmed_metric in pairs(alarmable_metrics) do
            local alarm_string_2 = alarm_string.."_"..alarmed_metric
            local re_arm_key = "ntopng.alerts.ifid_"..tostring(ifid).."_re_arming_"..alarm_string_2
            ntop.delCache(re_arm_key)
        end
    end
end

function delete_alert_configuration(alert_source, ifname)
   local ifid = getInterfaceId(ifname)
   local alert_level  = 1 -- alert_level_warning
   local alert_type   = 2 -- alert_threshold_exceeded
   delete_re_arming_alerts(alert_source, ifid)
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
      ntop.delHashCache(get_re_arm_alerts_hash_name(timespan),
			"ifid_"..tostring(ifid).."_"..alert_source)
   end
end

function refresh_alert_configuration(alert_source, ifname, timespan, alerts_string)
   if tostring(alerts_string) == nil then return nil end
   if is_allowed_timespan(timespan) == false then return nil end
   local ifid = getInterfaceId(ifname)
   local alert_level  = 1 -- alert_level_warning
   local alert_type   = 2 -- alert_threshold_exceeded
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
	    elseif string.match(alert_source, "/") then
	       interface.releaseNetworkAlert(alert_source, timespan.."_"..metric, alert_type, alert_level, "released.")
	    else
	       interface.releaseInterfaceAlert(timespan.."_"..metric, alert_type, alert_level, "Alarm released.")
	    end
	 end
      end
   end
end

function check_host_alert(ifname, hostname, mode, key, old_json, new_json)
   if(verbose) then
        print("check_host_alert("..ifname..", "..hostname..", "..mode..", "..key..")<br>\n")

        print("<p>--------------------------------------------<p>\n")
        print("NEW<br>"..new_json.."<br>\n")
        print("<p>--------------------------------------------<p>\n")
        print("OLD<br>"..old_json.."<br>\n")
        print("<p>--------------------------------------------<p>\n")
    end

   local alert_level  = 1 -- alert_level_warning
   local alert_type   = 2 -- alert_threshold_exceeded
   local alert_status     -- to be set later

    old = j.decode(old_json, 1, nil)
    new = j.decode(new_json, 1, nil)

    -- str = "bytes;>;123,packets;>;12"
    hkey = get_alerts_hash_name(mode, ifname)
    str = ntop.getHashCache(hkey, hostname)

    -- if(verbose) then ("--"..hkey.."="..str.."--<br>") end
    if((str ~= nil) and (str ~= "")) then
        tokens = split(str, ",")

        for _,s in pairs(tokens) do
            -- if(verbose) then ("<b>"..s.."</b><br>\n") end
            t = string.split(s, ";")

            if(t[2] == "gt") then
                op = ">"
            else
                if(t[2] == "lt") then
                    op = "<"
                else
                    op = "=="
                end
            end

            local what = "val = "..t[1].."(old, new); if(val ".. op .. " " .. t[3] .. ") then return(true) else return(false) end"
            local f = loadstring(what)
            local rc = f()
	    local alert_id = mode.."_"..t[1] -- the alert identifies is the concat. of time granularity and condition, e.g., min_bytes

            if(rc) then
	       alert_status = 1 -- alert on
	       local alert_msg = "Threshold <b>"..t[1].."</b> crossed by host <A HREF="..ntop.getHttpPrefix().."/lua/host_details.lua?host="..key..">"..key:gsub("@0","").."</A> [".. val .." ".. op .. " " .. t[3].."]"

	       -- only if the alert is not in its re-arming period...
	       if not is_alert_re_arming(key, mode, t[1], ifname) then
		  if verbose then io.write("queuing alert\n") end
		  -- re-arm the alert
		  re_arm_alert(key, mode, t[1], ifname)
		  -- and send it to ntopng
		  interface.engageHostAlert(key, alert_id, alert_type, alert_level, alert_msg)
		  if ntop.isPro() then
		     -- possibly send the alert to nagios as well
		     ntop.sendNagiosAlert(string.gsub(key, "@0", "") --[[ vlan 0 is implicit for hosts --]],
					  mode, t[1], alert_msg)
		  end
	       else
		  if verbose then io.write("alarm silenced, re-arm in progress\n") end
	       end
	       if(verbose) then print("<font color=red>".. alert_msg .."</font><br>\n") end
            else  -- alert has not been triggered
	       alert_status = 2 -- alert off
	       if(verbose) then print("<p><font color=green><b>Threshold "..t[1].."@"..key.." not crossed</b> [value="..val.."]["..op.." "..t[3].."]</font><p>\n") end
	       if not is_alert_re_arming(key, mode, t[1], ifname) then
		  interface.releaseHostAlert(key, alert_id, alert_type, alert_level, "released!")
		  if ntop.isPro() then
		     ntop.withdrawNagiosAlert(string.gsub(key, "@0", "") --[[ vlan 0 is implicit for hosts --]],
					      mode, t[1], "service OK")
		  end
                end
            end
        end
    end
end

function check_network_alert(ifname, network_name, mode, key, old_table, new_table)
   if(verbose) then
        io.write("check_newtowrk_alert("..ifname..", "..network_name..", "..mode..", "..key..")\n")
        io.write("new:\n")
        tprint(new_table)
        io.write("old:\n")
        tprint(old_table)
    end

   local alert_level = 1 -- alert_level_warning
   local alert_status = 1 -- alert_on
   local alert_type = 2 -- alert_threshold_exceeded

    deltas = {}
    local delta_names = {'ingress', 'egress', 'inner'}
    for i = 1, 3 do
        local delta_name = delta_names[i]
        deltas[delta_name] = 0
        if old_table[delta_name] and new_table[delta_name] then
            deltas[delta_name] = new_table[delta_name] - old_table[delta_name]
        end
    end
    -- str = "bytes;>;123,packets;>;12"
    hkey = get_alerts_hash_name(mode, ifname)

    local str = ntop.getHashCache(hkey, network_name)

    -- if(verbose) then ("--"..hkey.."="..str.."--<br>") end
    if((str ~= nil) and (str ~= "")) then
        local tokens = split(str, ",")

        for _,s in pairs(tokens) do
            -- if(verbose) then ("<b>"..s.."</b><br>\n") end
            local t = string.split(s, ";")

            if(t[2] == "gt") then
                op = ">"
            else
                if(t[2] == "lt") then
                    op = "<"
                else
                    op = "=="
                end
            end

            local what = "val = deltas['"..t[1].."']; if(val ".. op .. " " .. t[3] .. ") then return(true) else return(false) end"
            local f = loadstring(what)
            local rc = f()

	    local alert_id = mode.."_"..t[1] -- the alert identifies is the concat. of time granularity and condition, e.g., min_bytes
            if(rc) then
                local alert_msg = "Threshold <b>"..t[1].."</b> crossed by network <A HREF="..ntop.getHttpPrefix().."/lua/network_details.lua?network="..key.."&page=historical>"..network_name.."</A> [".. val .." ".. op .. " " .. t[3].."]"

                if not is_alert_re_arming(network_name, mode, t[1], ifname) then
                    if verbose then io.write("queuing alert\n") end
                    re_arm_alert(network_name, mode, t[1], ifname)
		    interface.engageNetworkAlert(network_name, alert_id, alert_type, alert_level, alert_msg)
                    if ntop.isPro() then
                        -- possibly send the alert to nagios as well
		       ntop.sendNagiosAlert(network_name, mode, t[1], alert_msg)
                    end
                else
                    if verbose then io.write("alarm silenced, re-arm in progress\n") end
                end
                if(verbose) then print("<font color=red>".. alert_msg .."</font><br>\n") end
            else
                if(verbose) then print("<p><font color=green><b>Network threshold "..t[1].."@"..network_name.." not crossed</b> [value="..val.."]["..op.." "..t[3].."]</font><p>\n") end
                if not is_alert_re_arming(network_name, mode, t[1], ifname) then
		   interface.releaseNetworkAlert(network_name, alert_id, alert_type, alert_level, "released!")
		   if ntop.isPro() then
		      ntop.withdrawNagiosAlert(network_name, mode, t[1], "service OK")
		   end
                end
            end
        end
    end
end

-- #################################

function check_interface_alert(ifname, mode, old_table, new_table)
   local ifname_clean = "iface_"..tostring(getInterfaceId(ifname))
    if(verbose) then
        print("check_interface_alert("..ifname..", "..mode..")<br>\n")
    end

    local alert_level = 1 -- alert_level_warning
    local alert_status = 1 -- alert_on
    local alert_type = 2 -- alert_threshold_exceeded

    -- Needed because Lua. loadstring() won't work otherwise.
    old = old_table
    new = new_table

    -- str = "bytes;>;123,packets;>;12"
    hkey = get_alerts_hash_name(mode, ifname)

    str = ntop.getHashCache(hkey, ifname_clean)

    -- if(verbose) then ("--"..hkey.."="..str.."--<br>") end
    if((str ~= nil) and (str ~= "")) then
        tokens = split(str, ",")

        for _,s in pairs(tokens) do
            -- if(verbose) then ("<b>"..s.."</b><br>\n") end
            t = string.split(s, ";")

            if(t[2] == "gt") then
                op = ">"
            else
                if(t[2] == "lt") then
                    op = "<"
                else
                    op = "=="
                end
            end

            local what = "val = "..t[1].."(old, new); if(val ".. op .. " " .. t[3] .. ") then return(true) else return(false) end"
            local f = loadstring(what)
            local rc = f()
	    local alert_id = mode.."_"..t[1] -- the alert identifies is the concat. of time granularity and condition, e.g., min_bytes

            if(rc) then
	       local alert_msg = "Threshold <b>"..t[1].."</b> crossed by interface <A HREF="..ntop.getHttpPrefix().."/lua/if_stats.lua?ifId="..tostring(getInterfaceId(ifname))..
                ">"..ifname.."</A> [".. val .." ".. op .. " " .. t[3].."]"

                if not is_alert_re_arming(ifname_clean, mode, t[1], ifname) then
                    if verbose then io.write("queuing alert\n") end
                    re_arm_alert(ifname_clean, mode, t[1], ifname)
		    interface.engageInterfaceAlert(alert_id, alert_type, alert_level, alert_msg)
                    if ntop.isPro() then
                        -- possibly send the alert to nagios as well
		       ntop.sendNagiosAlert(ifname_clean, mode, t[1], alert_msg)
                    end
                else
                    if verbose then io.write("alarm silenced, re-arm in progress\n") end
                end

                if(verbose) then print("<font color=red>".. alert_msg .."</font><br>\n") end
            else
                if(verbose) then print("<p><font color=green><b>Threshold "..t[1].."@"..ifname.." not crossed</b> [value="..val.."]["..op.." "..t[3].."]</font><p>\n") end
                if not is_alert_re_arming(ifname_clean, mode, t[1], ifname) then
		   interface.releaseInterfaceAlert(alert_id, alert_type, alert_level, "released!")
		   if ntop.isPro() then
		      ntop.withdrawNagiosAlert(ifname_clean, mode, t[1], "service OK")
		   end
                end
            end
        end
    end
end


-- #################################

function check_interface_threshold(ifname, mode)
    interface.select(ifname)
    local ifstats = interface.getStats()
    ifname_id = ifstats.id

    if are_alerts_suppressed("iface_"..ifname_id, ifname) then return end

    if(verbose) then print("check_interface_threshold("..ifname_id..", "..mode..")<br>\n") end
    basedir = fixPath(dirs.workingdir .. "/" .. ifname_id .. "/json/" .. mode)
    if(not(ntop.exists(basedir))) then
        ntop.mkdir(basedir)
    end

    if (ifstats ~= nil) then
        fname = fixPath(basedir.."/iface_"..ifname_id.."_lastdump")

        if(verbose) then print(fname.."<p>\n") end
        if (ntop.exists(fname)) then
            -- Read old version
	   old_dump = persistence.load(fname)
            if old_dump ~= nil and old_dump.stats ~= nil then
                check_interface_alert(ifname, mode, old_dump, ifstats)
            end
        end

        -- Write new version
        persistence.store(fname, ifstats)
    end
end


function check_networks_threshold(ifname, mode)
   interface.select(ifname)
   local subnet_stats = interface.getNetworksStats()
   local alarmed_subnets = ntop.getHashKeysCache(get_alerts_hash_name(mode, ifname))

   local ifname_id = interface.getStats().id

   local basedir = fixPath(dirs.workingdir .. "/" .. ifname_id .. "/json/" .. mode)
   if not ntop.exists(basedir) then
      ntop.mkdir(basedir)
   end

   for subnet,sstats in pairs(subnet_stats) do
      if sstats == nil or type(alarmed_subnets) ~= "table" or alarmed_subnets[subnet] == nil or are_alerts_suppressed(subnet, ifname) then goto continue end

      local statspath = getPathFromKey(subnet)
      statspath = fixPath(basedir.. "/" .. statspath)
      if not ntop.exists(statspath) then
	 ntop.mkdir(statspath)
      end
      statspath = fixPath(statspath .. "/alarmed_subnet_stats_lastdump")

      if ntop.exists(statspath) then
	 -- Read old version
	 old_dump = persistence.load(statspath)
	 if (old_dump ~= nil) then
	    -- (ifname, network_name, mode, key, old_table, new_table)
	    check_network_alert(ifname, subnet, mode, sstats['network_id'], old_dump, subnet_stats[subnet])
	 end
      end
      persistence.store(statspath, subnet_stats[subnet])
      ::continue::
   end
end

-- #################################

function check_host_threshold(ifname, host_ip, mode)
    interface.select(ifname)
    local ifstats = interface.getStats()
    ifname_id = ifstats.id
    local host_ip_fsname = host_ip

    if are_alerts_suppressed(host_ip, ifname) then return end

    if string.ends(host_ip, "@0") then
       host_ip_fsname = string.split(host_ip, "@")
       host_ip_fsname = host_ip_fsname[1]
    end
    
    if(verbose) then print("check_host_threshold("..ifname_id..", "..host_ip..", "..mode..")<br>\n") end
    basedir = fixPath(dirs.workingdir .. "/" .. ifname_id .. "/json/" .. mode)
    if(not(ntop.exists(basedir))) then
        ntop.mkdir(basedir)
    end

    json = interface.getHostInfo(host_ip)

    if(json ~= nil) then
        fname = fixPath(basedir.."/".. host_ip_fsname ..".json")
        if(verbose) then print(fname.."<p>\n") end
        -- Read old version
        f = io.open(fname, "r")
        if(f ~= nil) then
            old_json = f:read("*all")
            f:close()
            check_host_alert(ifname, host_ip, mode, host_ip, old_json, json["json"])
        end

        -- Write new version
        f = io.open(fname, "w")

        if(f ~= nil) then
            f:write(json["json"])
            f:close()
        end
    end
end

-- #################################

function scanAlerts(granularity, ifname)
   if(verbose) then print("[minute.lua] Scanning ".. granularity .." alerts for interface " .. ifname.."<p>\n") end

   check_interface_threshold(ifname, granularity)
   check_networks_threshold(ifname, granularity)
   -- host alerts checks
   local hash_key = get_alerts_hash_name(granularity, ifname)
   local hosts = ntop.getHashKeysCache(hash_key)
   if(hosts ~= nil) then
      for h in pairs(hosts) do
	 if(verbose) then print("[minute.lua] Checking host " .. h.." alerts<p>\n") end
	 check_host_threshold(ifname, h, granularity)
      end
   end
end

-- #################################

function checkDeleteStoredAlerts()
   if(_GET["csrf"] ~= nil) then
      if(_GET["id_to_delete"] ~= nil) then
	 if(_GET["id_to_delete"] == "__all__") then
	    if _GET["entity"] ~= nil and _GET["entity"] ~= "" then
	       -- delete all alerts of a given entity (e.g., a given host)
	       interface.deleteAlerts(true --[[ engaged --]],
				      _GET["entity"], _GET["entity_val"])
	       interface.deleteAlerts(false --[[ and not engaged --]],
				      _GET["entity"], _GET["entity_val"])
	    else
	       -- delete all existing alerts
	       interface.deleteAlerts(true --[[ engaged --]])
	       interface.deleteAlerts(false --[[ and not engaged --]])
	       interface.deleteFlowAlerts()
	    end
	 else
	    local id_to_delete = tonumber(_GET["id_to_delete"])
	    if id_to_delete ~= nil then
	       if _GET["status"] == "engaged" then
		  interface.deleteAlerts(true, id_to_delete)
	       elseif _GET["status"] == "historical" then
		  interface.deleteAlerts(false, id_to_delete)
	       elseif _GET["status"] == "historical-flows" then
		  interface.deleteFlowAlerts(id_to_delete)
	       end
	    end
	 end
      end
   end
end

-- #################################

local function drawDropdown(status, selection_name, active_entry, entries_table)
   -- alert_level_keys and alert_type_keys are defined in lua_utils
   local id_to_label = {}
   if selection_name == "severity" then
      for _, s in pairs(alert_level_keys) do id_to_label[s[2]] = s[3] end
   elseif selection_name == "type" then
      for _, s in pairs(alert_type_keys) do id_to_label[s[2]] = s[3] end
   end

   -- compute counters to avoid printing items that have zero entries in the database
   local actual_entries = {}
   if status == "historical-flows" then

      if selection_name == "severity" then
	 actual_entries = interface.selectFlowAlertsRaw("alert_severity id, count(*) count", "group by alert_severity")
      elseif selection_name == "type" then
	 actual_entries = interface.selectFlowAlertsRaw("alert_type id, count(*) count", "group by alert_type")
      end

   else -- dealing with non flow alerts (engaged and closed)
      local engaged
      if status == "engaged" then
	 engaged = true
      elseif status == "historical" then
	 engaged = false
      end

      if selection_name == "severity" then
	 actual_entries = interface.selectAlertsRaw(engaged, "alert_severity id, count(*) count", "group by alert_severity")
      elseif selection_name == "type" then
	 actual_entries = interface.selectAlertsRaw(engaged, "alert_type id, count(*) count", "group by alert_type")
      end

   end

   local buttons = '<div class="btn-group">'

   local button_label = firstToUpper(selection_name)
   if active_entry ~= nil and active_entry ~= "" then
      button_label = firstToUpper(active_entry)..'<span class="glyphicon glyphicon-filter"></span>'
   end
   
   buttons = buttons..'<button class="btn btn-link dropdown-toggle" data-toggle="dropdown">'..button_label
      buttons = buttons..'<span class="caret"></span></button>'
   
   buttons = buttons..'<ul class="dropdown-menu" role="menu">'

   for _, entry in pairs(actual_entries) do
      local id = tonumber(entry["id"])
      local count = entry["count"]
      local label = id_to_label[id]

      local class_active = ""
      if label == active_entry then class_active = ' class="active"' end
      -- buttons = buttons..'<li'..class_active..'><a href="'..ntop.getHttpPrefix()..'/lua/show_alerts.lua?status='..status
      buttons = buttons..'<li'..class_active..'><a href="?status='..status
      buttons = buttons..'&'..selection_name..'='..label..'">'
      buttons = buttons..firstToUpper(label)..' ('..count..')</a></li>'
   end

   buttons = buttons..'</ul></div>'
   
   return buttons
end

-- #################################

function drawAlertTables(num_alerts, num_engaged_alerts, num_flow_alerts, url_params)
   local entity = nil
   if _GET["entity"] ~= nil and _GET["entity"] ~= "" then entity = _GET["entity"] end   
   local alert_items = {}

   print[[
<br>
<ul class="nav nav-tabs" role="tablist" id="alert-tabs">
<!-- will be populated later with javascript -->
</ul>

<div class="tab-content">
]]

   local status = _GET["status"]
   if num_engaged_alerts > 0 then
      alert_items[#alert_items + 1] = {["label"] = "Engaged Alerts", ["div-id"] = "table-engaged-alerts",  ["status"] = "engaged"}
   end

   if num_alerts > 0 then
      alert_items[#alert_items +1] = {["label"] = "Alerts History", ["div-id"] = "table-alerts-history",  ["status"] = "historical"}
   end

   if num_flow_alerts > 0 then
      alert_items[#alert_items +1] = {["label"] = "Flow Alerts History", ["div-id"] = "table-flow-alerts-history",  ["status"] = "historical-flows"}
   end

   local url_extra_params = ""
   if type(url_params) == "table" then
      for k, v in pairs(url_params) do
	 if k ~= "csrf" then
	    url_extra_params = url_extra_params.."&"..k.."="..v
	 end
      end
   end


   for k, t in ipairs(alert_items) do
      local clicked = "0"
      if (k == 1 and status == nil) or (status ~= nil and status == t["status"]) then
	 clicked = "1"
      end
      print [[
      <div class="tab-pane fade in" id="tab-]] print(t["div-id"]) print[[">
        <div id="]] print(t["div-id"]) print[["></div>
      </div>

      <script type="text/javascript">

         $("#alert-tabs").append('<li><a href="#tab-]] print(t["div-id"]) print[[" clicked="]] print(clicked) print[[" role="tab" data-toggle="tab">]] print(t["label"]) print[[</a></li>')

         $('a[href="#tab-]] print(t["div-id"]) print[["]').on('shown.bs.tab', function (e) {
         // append the li to the tabs

	 $("#]] print(t["div-id"]) print[[").datatable({
			url: "]]
      print (ntop.getHttpPrefix())
      print [[/lua/get_alerts_data.lua?alerts_impl=new&alert_status=]] print(t["status"]..url_extra_params) print[[",
               showFilter: true,
	       showPagination: true,
               buttons: [']]

      if entity == nil then

	 -- alert_level_keys and alert_type_keys are defined in lua_utils
	 local alert_severities = {}
	 for _, s in pairs(alert_level_keys) do alert_severities[#alert_severities +1 ] = s[3] end
	 local alert_types = {}
	 for _, s in pairs(alert_type_keys) do alert_types[#alert_types +1 ] = s[3] end

	 print(drawDropdown(t["status"], "type", _GET["type"], alert_types))
	 print(drawDropdown(t["status"], "severity", _GET["severity"], alert_severities))

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
	        title: "]] print(t["label"]) print[[",
      columns: [
	 {
	    title: "Action",
	    field: "column_key",
	    css: { 
	       textAlign: 'center'
	    }
	 },

	 {
	    title: "First Seen",
	    field: "column_date",
            sortable: true,
	    css: { 
	       textAlign: 'center'
	    }
	 },
]]

      if t["status"] == "historical" then
      print[[
	 {
	    title: "Duration",
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
	    title: "Severity",
	    field: "column_severity",
            sortable: true,
	    css: { 
	       textAlign: 'center'
	    }
	 },

	 {
	    title: "Alert Type",
	    field: "column_type",
            sortable: true,
	    css: { 
	       textAlign: 'center'
	    }
	 },

	 {
	    title: "Description",
	    field: "column_msg",
	    css: { 
	       textAlign: 'left'
	    }
	 }
      ]
   });
   });
   </script>
	      ]]

   end



   if (num_alerts > 0 or num_flow_alerts > 0 or num_engaged_alerts > 0) then
      -- trigger the click on the right tab to force table load
      print[[
<script type="text/javascript">
$("[clicked=1]").trigger("click");
</script>
]]
      

      local purge_msg = " Purge All "
      if entity ~= nil and entity ~= "" then purge_msg = purge_msg..firstToUpper(entity).." " end
      purge_msg = purge_msg.."Alerts"
      print [[
</div> <!-- closes tab-content -->

<a href="#myModal" role="button" class="btn btn-default" data-toggle="modal"><i type="submit" class="fa fa-trash-o"></i>]] print(purge_msg) print[[</button></a>
 
<!-- Modal -->
<div class="modal fade" id="myModal" tabindex="-1" role="dialog" aria-labelledby="myModalLabel" aria-hidden="true">
  <div class="modal-dialog">
    <div class="modal-content">
      <div class="modal-header">
    <button type="button" class="close" data-dismiss="modal" aria-hidden="true">X</button>
    <h3 id="myModalLabel">Confirm Action</h3>
  </div>
  <div class="modal-body">
    <p>Do you really want to purge all alerts?</p>
  </div>
  <div class="modal-footer">

    <form class=form-inline style="margin-bottom: 0px;" method=get action="#"><input type=hidden name=id_to_delete value="__all__">
      ]]

      print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')

      if type(url_params) == "table" then
	 for k, v in pairs(url_params) do
	    if k ~= "csrf" then
	       print('<input name="'..k..'" type="hidden" value="'..v..'"/>\n')
	    end
	 end
      end
      if entity ~= nil and entity ~= "" then
	 print('<input name="entity" type="hidden" value="'..entity..'"/>\n')
      end
      
      print [[
    <button class="btn btn-default" data-dismiss="modal" aria-hidden="true">Close</button>
    <button class="btn btn-primary" type="submit">Purge All</button>
</form>
  </div>
  </div>
</div>
</div>

      ]]
   end

end
