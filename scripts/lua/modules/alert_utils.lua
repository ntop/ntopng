--
-- (C) 2014-15 - ntop.org
--

-- This file contains the description of all functions
-- used to trigger host alerts

local verbose = false

j = require("dkjson")
require "persistence"

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
      return(new["stats.bytes"]-old["stats.bytes"])
   end
end
function packets(old, new)
   if(new["sent"] ~= nil) then
      -- Host
      return((new["sent"]["packets"]+new["rcvd"]["packets"])-(old["sent"]["packets"]+old["rcvd"]["packets"]))
   else
      -- Interface
      return(new["stats.packets"]-old["stats.packets"])
   end
end
function dns(old, new)   return(proto_bytes(old, new, "DNS")) end
function p2p(old, new)   return(proto_bytes(old, new, "eDonkey")+proto_bytes(old, new, "BitTorrent")+proto_bytes(old, new, "Skype")) end


alerts_granularity = {
   { "min", "Every Minute" },
   { "5mins", "Every 5 Minutes" },
   { "hour", "Hourly" },
   { "day", "Daily" }
}

alert_functions_description = {
   ["bytes"]   = "Bytes delta (sent + received)",
   ["packets"] = "Packets delta (sent + received)",
   ["dns"]     = "DNS traffic delta bytes (sent + received)",
   ["p2p"]     = "Peer-to-peer traffic delta bytes (sent + received)",
}

-- #################################################################

function delete_host_alert_configuration(host_ip)
for k,v in pairs(alerts_granularity) do
   key = "ntopng.prefs.alerts_"..v[1]
   -- print(key.."<br>\n")
   ntop.delHashCache(key, host_ip)
end
end

function delete_interface_alert_configuration(if_name)
for k,v in pairs(alerts_granularity) do
   key = "ntopng.prefs.alerts_"..v[1]
   -- print(key.."<br>\n")
   ntop.delHashCache(key, if_name)
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

   old = j.decode(old_json, 1, nil)
   new = j.decode(new_json, 1, nil)

   -- str = "bytes;>;123,packets;>;12"
   hkey = "ntopng.prefs.alerts_"..mode

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


	 if(rc) then
	    local alert_msg = "Threshold <b>"..t[1].."</b> crossed by host <A HREF="..ntop.getHttpPrefix().."/lua/host_details.lua?host="..key..">"..key.."</A> [".. val .." ".. op .. " " .. t[3].."]"
	    local alert_level = 1 -- alert_level_warning
	    local alert_type = 2 -- alert_threshold_exceeded

	    ntop.queueAlert(alert_level, alert_type, alert_msg)
	    if(verbose) then print("<font color=red>".. alert_msg .."</font><br>\n") end
	 else
	    if(verbose) then print("<p><font color=green><b>Threshold "..t[1].."@"..key.." not crossed</b> [value="..val.."]["..op.." "..t[3].."]</font><p>\n") end
	 end
      end
   end
end

-- #################################

function check_interface_alert(ifname, mode, old_table, new_table)
   local ifname_clean = string.gsub(ifname, "/", "_")
   if(verbose) then
      print("check_interface_alert("..ifname..", "..mode..", "..key..")<br>\n")
   end

   -- Needed because Lua. loadstring() won't work otherwise.
   old = old_table
   new = new_table

   -- str = "bytes;>;123,packets;>;12"
   hkey = "ntopng.prefs.alerts_"..mode

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

	 if(rc) then
	    local alert_msg = "Threshold <b>"..t[1].."</b> crossed by interface <A HREF="..ntop.getHttpPrefix().."/lua/if_stats.lua?if_name="..ifname..
                              ">"..ifname.."</A> [".. val .." ".. op .. " " .. t[3].."]"
	    local alert_level = 1 -- alert_level_warning
	    local alert_type = 2 -- alert_threshold_exceeded

	    ntop.queueAlert(alert_level, alert_type, alert_msg)
	    if(verbose) then print("<font color=red>".. alert_msg .."</font><br>\n") end
	 else
	    if(verbose) then print("<p><font color=green><b>Threshold "..t[1].."@"..ifname.." not crossed</b> [value="..val.."]["..op.." "..t[3].."]</font><p>\n") end
	 end
      end
   end
end

-- #################################

function check_interface_threshold(ifname, mode)
   local ifname_clean = string.gsub(ifname, "/", "_")

   suppressAlerts = ntop.getHashCache("ntopng.prefs.alerts", "iface_"..ifname_clean)
   if((suppressAlerts == "") or (suppressAlerts == nil) or (suppressAlerts == "true")) then
      if(verbose) then print("Alert check for ("..ifname_clean..", "..mode..")<br>\n") end
   else
      if(verbose) then print("Skipping alert check for("..ifname_clean..", "..mode.."): disabled in preferences<br>\n") end
      return
   end

   if(verbose) then print("check_interface_threshold("..ifname_clean..", "..host_ip..", "..mode..")<br>\n") end
   basedir = fixPath(dirs.workingdir .. "/" .. ifname_clean .. "/json/" .. mode)
   if(not(ntop.exists(basedir))) then
      ntop.mkdir(basedir)
   end

   --if(verbose) then print(basedir.."<br>\n") end
   interface.select(ifname)
   ifstats = interface.getStats()

   if (ifstats ~= nil) then
     fname = fixPath(basedir.."/iface_"..ifname_clean.."_lastdump")

     if(verbose) then print(fname.."<p>\n") end
     if (ntop.exists(fname)) then
       -- Read old version
       old_dump = persistence.load(fname)
       if (old_dump ~= nil) then
         check_interface_alert(ifname, mode, old_dump, ifstats)
       end
     end

     -- Write new version
     persistence.store(fname, ifstats)
   end
end

-- #################################

function check_host_threshold(ifname, host_ip, mode)
   suppressAlerts = ntop.getHashCache("ntopng.prefs.alerts", host_ip)
   if((suppressAlerts == "") or (suppressAlerts == nil) or (suppressAlerts == "true")) then
      if(verbose) then print("Alert check for ("..ifname..", "..host_ip..", "..mode..")<br>\n") end
   else
      if(verbose) then print("Skipping alert check for("..ifname..", "..host_ip..", "..mode.."): disabled in preferences<br>\n") end
      return
   end

   if(verbose) then print("check_host_threshold("..ifname..", "..host_ip..", "..mode..")<br>\n") end
   basedir = fixPath(dirs.workingdir .. "/" .. ifname .. "/json/" .. mode)
   if(not(ntop.exists(basedir))) then
      ntop.mkdir(basedir)
   end

   --if(verbose) then print(basedir.."<br>\n") end
   interface.select(ifname)
   json = interface.getHostInfo(host_ip)

   if(json ~= nil) then
      fname = fixPath(basedir.."/".. host_ip ..".json")

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

function scanAlerts(granularity)
   ifnames = interface.getIfNames()
   for _,_ifname in pairs(ifnames) do
      ifname = purifyInterfaceName(_ifname)
      if(verbose) then print("[minute.lua] Processing interface " .. ifname.."<p>\n") end

      check_interface_threshold(ifname, granularity)

      hash_key = "ntopng.prefs.alerts_"..granularity
      hosts = ntop.getHashKeysCache(hash_key)

      if(hosts ~= nil) then
	 for h in pairs(hosts) do
	    if(verbose) then print("[minute.lua] Checking host " .. h.." alerts<p>\n") end
	    check_host_threshold(ifname, h, granularity)
	 end
      end
   end -- interfaces
end

