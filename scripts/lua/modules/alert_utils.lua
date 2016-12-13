--
-- (C) 2014-16 - ntop.org
--

-- This file contains the description of all functions
-- used to trigger host alerts

local verbose = false

alerts_granularity = {
    { "min", "Every Minute", 60 },
    { "5mins", "Every 5 Minutes", 300 },
    { "hour", "Hourly", 3600 },
    { "day", "Daily", 86400 }
}

alarmable_metrics = {'bytes', 'dns', 'idle', 'packets', 'p2p', 'throughput', 'ingress', 'egress', 'inner'}

default_re_arm_minutes = 5

alert_functions_description = {
    ["bytes"]   = "Bytes delta (sent + received)",
    ["dns"]     = "DNS traffic delta bytes (sent + received)",
    ["idle"]    = "Idle time since last packet sent (seconds)",	
    ["packets"] = "Packets delta (sent + received)",
    ["p2p"]     = "Peer-to-peer traffic delta bytes (sent + received)",
    ["throughput"]   = "Avergage throughput (sent + received) [Mbps]",
}

network_alert_functions_description = {
    ["ingress"] = "Ingress Bytes delta",
    ["egress"]  = "Egress Bytes delta",
    ["inner"]   = "Inner Bytes delta",
}

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

function get_re_arm_alerts_hash_name()
   return "ntopng.prefs.alerts_re_arm_minutes"
end

function get_re_arm_alerts_hash_key(ifid, ifname_or_network)
   local parts = {"ifid", tostring(ifid)}
   if ifname_or_network ~= nil then
      parts[#parts+1] = ifname_or_network
   end

   return table.concat(parts, "_")
end

function get_re_arm_alerts_temporary_key(ifname, alarmed_source, alarmed_metric)
   local ifid = getInterfaceId(ifname)
   if(tonumber(ifid) == nil) or (not is_allowed_alarmable_metric(alarmed_metric)) then
      return nil
   end
   local alarm_string = alarmed_source.."_"..alarmed_metric
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

function re_arm_alert(alarm_source, alarmed_metric, ifname)
   local ifid = getInterfaceId(ifname)
   local re_arm_key = get_re_arm_alerts_temporary_key(ifname, alarm_source, alarmed_metric)
   local re_arm_minutes = ntop.getHashCache(get_re_arm_alerts_hash_name(), get_re_arm_alerts_hash_key(ifid, alarm_source))
   if re_arm_minutes ~= "" then
      re_arm_minutes = tonumber(re_arm_minutes)
   else
      re_arm_minutes = default_re_arm_minutes
   end
   if verbose then io.write('re_arm_minutes: '..re_arm_minutes..'\n') end
   -- we don't care about key contents, we just care about its exsistance
   if re_arm_minutes == 0 then
      return  -- don't want to re arm the alert
   end
   ntop.setCache(re_arm_key, "dummy",
		 re_arm_minutes * 60 - 5 --[[ subtract 5 seconds to make sure the limit is obeyed --]])
end

function is_alert_re_arming(alarm_source, alarmed_metric, ifname)
   local re_arm_key = get_re_arm_alerts_temporary_key(ifname, alarm_source, alarmed_metric)
   local is_rearming = ntop.getCache(re_arm_key)
   if is_rearming ~= "" then
      if verbose then io.write('re_arm_key: '..re_arm_key..' -> ' ..is_rearming..'-- \n') end
      return true
   end
   return false
end

-- #################################################################

function delete_re_arming_alerts(alert_source, ifid)
     for k2, alarmed_metric in pairs(alarmable_metrics) do
	 local re_arm_key = get_re_arm_alerts_temporary_key(ifid, alert_source, alarmed_metric)
	 ntop.delCache(re_arm_key)
     end
end

function delete_alert_configuration(alert_source, ifname)
   local ifid = getInterfaceId(ifname)
   local alert_level  = 1 -- alert_level_warning
   local alert_type   = 2 -- alert_threshold_exceeded
   local is_host = false
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
      ntop.delHashCache(get_re_arm_alerts_hash_name(), get_re_arm_alerts_hash_key(ifid, alert_source))
   end

   if is_host == true then
      interface.refreshNumAlerts(alert_source)
   else
      interface.refreshNumAlerts()
   end
end

function refresh_alert_configuration(alert_source, ifname, timespan, alerts_string)
   if tostring(alerts_string) == nil then return nil end
   if is_allowed_timespan(timespan) == false then return nil end
   local ifid = getInterfaceId(ifname)
   local alert_level  = 1 -- alert_level_warning
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
   else
      interface.refreshNumAlerts()
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
    duration = granularity2sec(mode)
    
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

	    -- This is where magic happens: loadstring() evaluates the string
            local what = "val = "..t[1].."(old, new, duration); if(val ".. op .. " " .. t[3] .. ") then return(true) else return(false) end"
            local f = loadstring(what)
            local rc = f()
	    local alert_id = mode.."_"..t[1] -- the alert identifies is the concat. of time granularity and condition, e.g., min_bytes

            if(rc) then
	       alert_status = 1 -- alert on
	       local alert_msg = "Threshold <b>"..t[1].."</b> crossed by host <A HREF="..ntop.getHttpPrefix().."/lua/host_details.lua?host="..key..">"..key:gsub("@0","").."</A> [".. val .." ".. op .. " " .. t[3].."]"

	       -- only if the alert is not in its re-arming period...
	       if not is_alert_re_arming(key, t[1], ifname) then
		  if verbose then io.write("queuing alert\n") end
		  -- re-arm the alert
		  re_arm_alert(key, t[1], ifname)
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
	       if not is_alert_re_arming(key, t[1], ifname) then
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

	    -- This is where magic happens: loadstring() evaluates the string
            local what = "val = deltas['"..t[1].."']; if(val ".. op .. " " .. t[3] .. ") then return(true) else return(false) end"
            local f = loadstring(what)
            local rc = f()

	    local alert_id = mode.."_"..t[1] -- the alert identifies is the concat. of time granularity and condition, e.g., min_bytes
            if(rc) then
                local alert_msg = "Threshold <b>"..t[1].."</b> crossed by network <A HREF="..ntop.getHttpPrefix().."/lua/network_details.lua?network="..key.."&page=historical>"..network_name.."</A> [".. val .." ".. op .. " " .. t[3].."]"

                if not is_alert_re_arming(network_name, t[1], ifname) then
                    if verbose then io.write("queuing alert\n") end
                    re_arm_alert(network_name, t[1], ifname)
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
                if not is_alert_re_arming(network_name, t[1], ifname) then
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

    local alert_level  = 1 -- alert_level_warning
    local alert_status = 1 -- alert_on
    local alert_type   = 2 -- alert_threshold_exceeded

    -- Needed because Lua. loadstring() won't work otherwise.
    old = old_table
    new = new_table

    -- str = "bytes;>;123,packets;>;12"
    hkey = get_alerts_hash_name(mode, ifname)
    duration = granularity2sec(mode)
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

	    -- This is where magic happens: loadstring() evaluates the string
            local what = "val = "..t[1].."(old, new, duration); if(val ".. op .. " " .. t[3] .. ") then return(true) else return(false) end"
            local f = loadstring(what)
            local rc = f()
	    local alert_id = mode.."_"..t[1] -- the alert identifies is the concat. of time granularity and condition, e.g., min_bytes

            if(rc) then
	       local alert_msg = "Threshold <b>"..t[1].."</b> crossed by interface <A HREF="..ntop.getHttpPrefix().."/lua/if_stats.lua?ifId="..tostring(getInterfaceId(ifname))..
                ">"..ifname.."</A> [".. val .." ".. op .. " " .. t[3].."]"

                if not is_alert_re_arming(ifname_clean, t[1], ifname) then
                    if verbose then io.write("queuing alert\n") end
                    re_arm_alert(ifname_clean, t[1], ifname)
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
                if not is_alert_re_arming(ifname_clean, t[1], ifname) then
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

function granularity2sec(g)
   for _, granularity in pairs(alerts_granularity) do
       if(granularity[1] == g) then
       	   return(granularity[3])
       end
   end

   return(0)
end

-- #################################

function check_interface_threshold(ifname, mode)
    interface.select(ifname)
    local ifstats = interface.getStats()
    ifname_id = ifstats.id

    if are_alerts_suppressed("iface_"..ifname_id, ifname) then return end

    if(verbose) then print("check_interface_threshold(ifaceId="..ifname_id..", timePeriod="..mode..")<br>\n") end
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

function getExtraParameters(url_params)
   local params = {}
   -- Note: entity and entity_val are used to perform queries, so cannot apper here
   local exclude = {csrf=1, id_to_delete=1, older_than_seconds=1, tab_id=1,
      id_to_delete=1, status=1}

   if type(url_params) == "table" then
      for k, v in pairs(url_params) do
        if not exclude[k] then
           params[k] = v
        end
      end
   end

   return params
end

-- #################################

function performAlertsQuery(statement, what, options)
   local opts = {
      row_id=nil,
      entity_type=nil,
      entity_value=nil,
      period_begin=nil,
      period_end=nil,
      alert_type=nil,
      alert_severity=nil,
      origin=nil,
      target=nil,
      hosts_type=nil,

   -- pagination parameters
      current_page=nil,
      per_page=nil,
      sort_column=nil,
      sort_order=nil,
   }
   for k,v in pairs(options) do opts[k] = v end
   --~ tprint(opts)

   local wargs = {"WHERE", "1=1"}

   if opts.row_id ~= nil then
      wargs[#wargs+1] = 'AND rowid = '..(opts.row_id)
   end

   if (opts.entity_type ~= nil) and (opts.entity_value ~= nil) then
      if((what == "historical-flows") and (alertEntityRaw(opts.entity_type) == "host")) then
         -- need to handle differently for flows table
         local info = hostkey2hostinfo(opts.entity_value)
         wargs[#wargs+1] = 'AND (cli_addr="'..(info.host)..'" OR srv_addr="'..(info.host)..'")'
         wargs[#wargs+1] = 'AND vlan_id='..(info.vlan)
      else
         wargs[#wargs+1] = 'AND alert_entity = "'..(opts.entity_type)..'"'
         wargs[#wargs+1] = 'AND alert_entity_val = "'..(opts.entity_value)..'"'
      end
   end

   if opts.origin ~= nil then
      local info = hostkey2hostinfo(opts.origin)
      wargs[#wargs+1] = 'AND cli_addr="'..(info.host)..'"'
      wargs[#wargs+1] = 'AND vlan_id='..(info.vlan)
   end

   if opts.target ~= nil then
      local info = hostkey2hostinfo(opts.target)
      wargs[#wargs+1] = 'AND srv_addr="'..(info.host)..'"'
      wargs[#wargs+1] = 'AND vlan_id='..(info.vlan)
   end

   if opts.period_begin ~= nil then
      wargs[#wargs+1] = 'AND alert_tstamp >= '..(opts.period_begin)
   end

   if opts.period_end ~= nil then
      wargs[#wargs+1] = 'AND alert_tstamp <= '..(opts.period_end)
   end

   if opts.hosts_type ~= nil then
      if opts.hosts_type ~= "all_hosts" then
         local cli_local, srv_local = 0, 0

         if opts.hosts_type == "local_only" then cli_local, srv_local = 1, 1
         elseif opts.hosts_type == "remote_only" then cli_local, srv_local = 0, 0
         elseif opts.hosts_type == "local_origin_remote_target" then cli_local, srv_local = 1, 0
         elseif opts.hosts_type == "remote_origin_local_target" then cli_local, srv_local = 0, 1
         end

         if what == "historical-flows" then
            wargs[#wargs+1] = "AND cli_localhost = "..cli_local
            wargs[#wargs+1] = "AND srv_localhost = "..srv_local
         end
         -- TODO cannot apply it to other tables right now
      end
   end

   if opts.alert_type ~= nil then
      wargs[#wargs+1] = "AND alert_type = "..(opts.alert_type)
   end

   if opts.alert_severity ~= nil then
      wargs[#wargs+1] = "AND alert_severity = "..(opts.alert_severity)
   end

   if((opts.sort_column ~= nil) and (opts.sort_order ~= nil)) then      
      local order_by
      
      if opts.sort_column == "column_date" then
         order_by = "alert_tstamp"
      elseif opts.sort_column == "column_severity" then
         order_by = "alert_severity"
      elseif opts.sort_column == "column_type" then
         order_by = "alert_type"
      elseif((opts.sort_column == "column_duration") and (what == "historical")) then
         order_by = "(alert_tstamp_end - alert_tstamp)"
      else
         -- default
         order_by = "alert_tstamp"
      end

      wargs[#wargs+1] = "ORDER BY "..order_by
      wargs[#wargs+1] = string.upper(opts.sort_order)
   end

   -- pagination
   if((opts.per_page ~= nil) and (opts.current_page ~= nil)) then
      local to_skip = (opts.current_page-1) * opts.per_page
      wargs[#wargs+1] = "LIMIT"
      wargs[#wargs+1] = to_skip..","..(opts.per_page)
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
      error("Invald alert subject: "..what)
   end

   -- trigger counters refresh
   if trimSpace(statement:lower()) == "delete" then
      interface.refreshNumAlerts(true)
   end

   return res
end

-- #################################

function getNumAlerts(what, options)
   local num = 0
   local opts = getUnpagedAlertOptions(options or {})
   checkFilterOptions(opts)
   local res = performAlertsQuery("SELECT COUNT(*) AS count", what, opts)
   if((res ~= nil) and (#res == 1) and (res[1].count ~= nil)) then num = tonumber(res[1].count) end

   return num
end

-- #################################

function getAlerts(what, options)
   local opts = checkFilterOptions(options, true)
   return performAlertsQuery("SELECT rowid, *", what, opts)
end

-- #################################

function deleteAlerts(what, options)
   local opts = getUnpagedAlertOptions(options or {})
   performAlertsQuery("DELETE", what, opts)
   _GET["older_than_seconds"] = nil
end

-- #################################

-- builds an URL query string from an options object (performAlertsQuery parameters)
function alertsQueryParametersToUrl(opts)
   local res = ""

   if opts.alert_severity ~= nil then res = res.."&severity="..alertSeverityRaw(opts.alert_severity) end
   if opts.alert_type ~= nil then res = res.."&type="..alertTypeRaw(opts.alert_type) end
   if ((opts.entity_type ~= nil) and (opts.entity_value ~= nil)) then res = res .."&entity="..alertEntityRaw(opts.entity_type).."&entity_val="..opts.entity_value end
   if opts.origin ~= nil then res = res.."&origin="..opts.origin end
   if opts.target ~= nil then res = res.."&target="..opts.target end
   if opts.hosts_type ~= nil then res = res.."&hosts_type="..opts.hosts_type end
   if opts.period_begin ~= nil then res = res.."&period_begin="..opts.period_begin end
   if opts.period_end ~= nil then res = res.."&period_end="..opts.period_end end
   if opts.current_page ~= nil then res = res.."&currentPage="..opts.current_page end
   if opts.per_page ~= nil then res = res.."&perPage="..opts.per_page end
   if opts.sort_column ~= nil then res = res.."&sortColumn="..opts.sort_column end
   if opts.sort_order ~= nil then res = res.."&sortOrder="..opts.sort_order end

   return res
end

-- builds an options object suitable to be passed to performAlertsQuery from GET parameters
function UrlToalertsQueryParameters(_GET)
   local opts = {}
   
   if not isEmptyString(_GET["severity"]) then opts.alert_severity = alertSeverity(_GET["severity"]) end
   if not isEmptyString(_GET["type"]) then opts.alert_type = alertType(_GET["type"]) end
   if((not isEmptyString(_GET["entity"])) and (not isEmptyString(_GET["entity_val"]))) then opts.entity_type = alertEntity(_GET["entity"]); opts.entity_value = _GET["entity_val"] end
   if not isEmptyString(_GET["origin"]) then opts.origin = _GET["origin"] end
   if not isEmptyString(_GET["target"]) then opts.target = _GET["target"] end
   if not isEmptyString(_GET["hosts_type"]) then opts.hosts_type = _GET["hosts_type"] end

   -- TODO unify
   if((tonumber(_GET["older_than_seconds"]) ~= nil) and (tonumber(_GET["older_than_seconds"]) > 0)) then opts.period_end = os.time() - tonumber(_GET["older_than_seconds"]) end
   if((tonumber(_GET["period_end"]) ~= nil) and (tonumber(_GET["period_end"]) > 0)) then opts.period_end = tonumber(_GET["period_end"]) end
   
   if((tonumber(_GET["period_begin"]) ~= nil) and (tonumber(_GET["period_begin"]) > 0)) then opts.period_begin = tonumber(_GET["period_begin"]) end

   -- Pagination
   if((tonumber(_GET["currentPage"]) ~= nil) and (tonumber(_GET["perPage"]) ~= nil)) then opts.current_page = tonumber(_GET["currentPage"]); opts.per_page = tonumber(_GET["perPage"]) end
   if((not isEmptyString(_GET["sortColumn"])) and (not isEmptyString(_GET["sortOrder"]))) then
      opts.sort_column = _GET["sortColumn"]
      opts.sort_order = _GET["sortOrder"]
   end

   return opts
end

-- #################################

-- Remove pagination options from the options
function getUnpagedAlertOptions(options)
   local res = {}

   local paged_option = { current_page=1, per_page=1, sort_column=1, sort_order=1 }

   for k,v in pairs(options) do
      if not paged_option[k] then
         res[k] = v
      end
   end

   return res
end

-- #################################

-- this removes filter options for tabs which are not the active one
function checkFilterOptions(opts, clone)
   local res

   if clone then
      res = {}
      for k,v in pairs(opts) do res[k] = v end
   else
      res = opts
   end

   if not isEmptyString(_GET["status"]) then
      if _GET["status"] ~= what then
         res.alert_severity = nil
         res.alert_type = nil
      end
   end

   return res
end

-- #################################

function checkDeleteStoredAlerts()
   if((_GET["csrf"] ~= nil) and (_GET["status"] ~= nil)) then
      local delete_params = UrlToalertsQueryParameters(_GET)

      if(_GET["id_to_delete"] ~= "__all__") then
         delete_params.row_id = tonumber(_GET["id_to_delete"])
      end

      deleteAlerts(_GET["status"], delete_params)
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
      local label = id_to_label[id]

      class_active = ""
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

function drawAlertSourceSettings(alert_source, delete_button_msg, delete_confirm_msg, page_name, page_params, alt_name, show_entity)
   local num_engaged_alerts, num_past_alerts, num_flow_alerts = 0,0,0
   local tab = _GET["tab"]

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
      -- these fields will be used to perfom queries
      _GET["entity"] = show_entity
      _GET["entity_val"] = alert_source
   end

   if(show_entity) then
      -- possibly process pending delete arguments
      checkDeleteStoredAlerts()
      
      -- possibly add a tab if there are alerts configured for the host
      local alert_opts = UrlToalertsQueryParameters(_GET)
      num_engaged_alerts = getNumAlerts("engaged", alert_opts)
      num_past_alerts = getNumAlerts("historical", alert_opts)
      num_flow_alerts = getNumAlerts("historical-flows", alert_opts)

      if num_past_alerts > 0 or num_engaged_alerts > 0 or num_flow_alerts > 0 then
         if(tab == nil) then
            -- if no tab is selected and there are alerts, we show them by default
            tab = "alert_list"
         end

         printTab("alert_list", "Detected Alerts", tab)
      else
         -- if there are no alerts, we show the first alert granularity configuration page
         if(tab=="alert_list") then tab = nil end
      end
   end

   if(tab == nil) then tab = alerts_granularity[1][1] end

   for _,e in pairs(alerts_granularity) do
      local k = e[1]
      local l = e[2]
      l = '<i class="fa fa-cog" aria-hidden="true"></i>&nbsp;'..l
      printTab(k, l, tab)
   end

   print('</ul>')

   if((show_entity) and (tab == "alert_list")) then
      drawAlertTables(num_past_alerts, num_engaged_alerts, num_flow_alerts, _GET, true)
   else
      -- Before doing anything we need to check if we need to save values

      vals = { }
      alerts = ""
      to_save = false

      if((_GET["to_delete"] ~= nil) and (_GET["SaveAlerts"] == nil)) then
         delete_alert_configuration(alert_source, ifname)
         alerts = nil
      else
         for k,_ in pairs(alert_functions_description) do
       value    = _GET["value_"..k]
       operator = _GET["operator_"..k]

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

      <form>
       <input type=hidden name=page value=alerts>
      ]]
      print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')
      print('<input type=hidden name=tab value="'..tab..'" />\n')

      for param,value in pairs(page_params) do
         print('<input type=hidden name="'..param..'" value="'..value..'">\n')
      end

      for k,v in pairsByKeys(alert_functions_description, asc) do
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

      <input type="submit" class="btn btn-primary" name="SaveAlerts" value="Save Configuration">

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
          <form class=form-inline style="margin-bottom: 0px;" method=get action="#"><input type=hidden name=to_delete value="__all__">
      ]]
      print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')
      print [[    <button class="btn btn-default" data-dismiss="modal" aria-hidden="true">Close</button>
          <button class="btn btn-primary" type="submit">Delete All</button>

        </div>
      </form>
      </div>
      </div>

      </th> </tr>



      </tbody> </table>
      ]]
   end
end

-- #################################

function drawAlertTables(num_past_alerts, num_engaged_alerts, num_flow_alerts, url_params, hide_extended_title, alt_nav_tabs)
   local entity = nil
   local entity_val = nil
   if _GET["entity"] ~= nil and _GET["entity"] ~= "" then entity = _GET["entity"] end
   if _GET["entity_val"] ~= nil and _GET["entity_val"] ~= "" then entity_val = _GET["entity_val"] end
   local alert_items = {}

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
if entity ~= nil and entity ~= "" then print(firstToUpper(entity).." ") end
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
   $("#modalDeleteAlertsStatus").val(getCurrentStatus());
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
      alert_items[#alert_items +1] = {["label"] = i18n("show_alerts.past_flow_alerts"),
	 ["div-id"] = "table-flow-alerts-history",  ["status"] = "historical-flows"}
   elseif status == "historical-flows" then
      status = nil; status_reset = 1
   end

   -- This possibly passes some parameters to the search query
   local url_extra_params = ""
   for k, v in pairs(getExtraParameters(url_params)) do
      url_extra_params = url_extra_params.."&"..k.."="..v
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
			url: "]]
      print (ntop.getHttpPrefix())
      print [[/lua/get_alerts_data.lua?&status=]] print(t["status"]..url_extra_params) print[[",
               showFilter: true,
	       showPagination: true,
               buttons: [']]

      local title = t["label"]

      -- TODO this condition should be removed and page integration support implemented
      if((entity == nil) and isEmptyString(_GET["period_begin"]) and isEmptyString(_GET["period_end"])) then
	 -- alert_level_keys and alert_type_keys are defined in lua_utils
	 local alert_severities = {}
	 for _, s in pairs(alert_level_keys) do alert_severities[#alert_severities +1 ] = s[3] end
	 local alert_types = {}
	 for _, s in pairs(alert_type_keys) do alert_types[#alert_types +1 ] = s[3] end

    local a_type, a_severity
    if clicked == "1" then
      a_type = _GET["type"]
      a_severity = _GET["severity"]
   else
      a_type = nil
      a_severity = nil
    end

	 print(drawDropdown(t["status"], "type", a_type, alert_types))
	 print(drawDropdown(t["status"], "severity", a_severity, alert_severities))
      elseif((entity_val ~= nil) and (not hide_extended_title)) then
	 if entity == "host" then
	    local host_ip = entity_val
	    local sp = split(host_ip, "@")
	    if #sp == 2 then
	       host_ip = ntop.resolveAddress(sp[1])
	    end
	    
	    title = title .. " - Host " .. host_ip
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
            var status_reset = ]] print(status_reset) --[[ this is necessary because of status parameter inconsinstency after tab switch ]] print[[;
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
local has_fixed_period = ((_GET["period_begin"] ~= nil) or (_GET["period_end"] ~= nil))

print('<div id="alertsActionsPanel">')
print('<br>Alerts to Purge: ')
print[[<select id="deleteZoomSelector" class="form-control" style="display:]] if has_fixed_period then print("none") else print("inline") end print[[; width:14em; margin:0 1em;">]]
   local all_msg = ""

   if not has_fixed_period then
      print('<optgroup label="older than">')
      for k,v in ipairs(zoom_vals) do
         print('<option data-older="'..zoom_vals[k][2]..'" data-msg="'.." "..zoom_vals[k][3].. '">'..zoom_vals[k][1]..'</option>\n')
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

    <form class=form-inline style="margin-bottom: 0px;" method=get action="#"><input type=hidden name=id_to_delete value="__all__">
      <input type="hidden" id="modalDeleteAlertsOlderThan" name="older_than_seconds" value="-1">
      <input type="hidden" id="modalDeleteAlertsStatus" name="status">
      ]]

      print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')

      -- This is required because of drawAlertTables integration in other complex pages
      for k, v in pairs(getExtraParameters(url_params)) do
	 print('<input name="'..k..'" type="hidden" value="'..v..'"/>\n')
      end
      
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
var cur_alert_num_req = null;

/* This acts before shown.bs.modal event, avoiding visual fields substitution glitch */
$('#buttonOpenDeleteModal').on('click', function() {
   var lb = $("#purgeBtnLabel");
   var zoomsel = $("#deleteZoomSelector").find(":selected");

   $(".modal-body #modalDeleteAlertsMsg").html(zoomsel.data('msg') + ']]
   if _GET["severity"] ~= nil then
      print(' with severity "'..firstToUpper(_GET["severity"])..'" ')
   elseif _GET["type"] ~= nil then
      print(' with type "'..firstToUpper(_GET["type"])..'" ')
   end
   print[[');
   if (lb.length == 1)
      $(".modal-body #modalDeleteContext").html(" " + lb.html());
   $(".modal-footer #modalDeleteAlertsOlderThan").val(zoomsel.data('older'));

   cur_alert_num_req = $.ajax({
      type: 'GET',
      ]] print("url: '"..ntop.getHttpPrefix().."/lua/get_num_alerts.lua?older_than_seconds=' + $(\"#modalDeleteAlertsOlderThan\").val() + '&status=' + getCurrentStatus() + '")
      print(alertsQueryParametersToUrl(UrlToalertsQueryParameters(url_params)))
      print[[',
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
