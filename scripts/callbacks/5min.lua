--
-- (C) 2013-17 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

if (ntop.isPro()) then
  package.path = dirs.installdir .. "/pro/scripts/callbacks/?.lua;" .. package.path
  require("5min")

  package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
  require "snmp_utils"
end

require "lua_utils"
require "graph_utils"
require "alert_utils"
require "rrd_utils"
local host_pools_utils = require "host_pools_utils"
local callback_utils = require "callback_utils"

local when = os.time()
local verbose = ntop.verboseTrace()

-- We must complete within the 5 minutes
local time_threshold = when - (when % 300) + 300 - 10 -- safe margin

-- ########################################################

local interface_rrd_creation = ntop.getPref("ntopng.prefs.interface_rrd_creation")
local interface_ndpi_timeseries_creation = ntop.getPref("ntopng.prefs.interface_ndpi_timeseries_creation")
local host_rrd_creation = ntop.getPref("ntopng.prefs.host_rrd_creation")
local host_ndpi_timeseries_creation = ntop.getPref("ntopng.prefs.host_ndpi_timeseries_creation")
local l2_device_rrd_creation = ntop.getPref("ntopng.prefs.l2_device_rrd_creation")
local l2_device_ndpi_timeseries_creation = ntop.getPref("ntopng.prefs.l2_device_ndpi_timeseries_creation")
local host_categories_rrd_creation = ntop.getPref("ntopng.prefs.host_categories_rrd_creation")
local flow_devices_rrd_creation = ntop.getPref("ntopng.prefs.flow_device_port_rrd_creation")
local host_pools_rrd_creation = ntop.getPref("ntopng.prefs.host_pools_rrd_creation")
local snmp_devices_rrd_creation = ntop.getPref("ntopng.prefs.snmp_devices_rrd_creation")
local asn_rrd_creation = ntop.getPref("ntopng.prefs.asn_rrd_creation")
local vlan_rrd_creation = ntop.getPref("ntopng.prefs.vlan_rrd_creation")
local tcp_retr_ooo_lost_rrd_creation = ntop.getPref("ntopng.prefs.tcp_retr_ooo_lost_rrd_creation")

-- ########################################################
-- Populate some defaults
if(tostring(flow_devices_rrd_creation) == "1" and ntop.isEnterprise() == false) then
   flow_devices_rrd_creation = "0"
end

if(tostring(snmp_devices_rrd_creation) == "1" and ntop.isEnterprise() == false) then
   snmp_devices_rrd_creation = "0"
end

-- Interface RRD creation is on, with per-protocol nDPI
if isEmptyString(interface_rrd_creation) then interface_rrd_creation = "1" end
if isEmptyString(interface_ndpi_timeseries_creation) then interface_ndpi_timeseries_creation = "per_protocol" end

-- Local hosts RRD creation is on, with no nDPI rrd creation
if isEmptyString(host_rrd_creation) then host_rrd_creation = "1" end
if isEmptyString(host_ndpi_timeseries_creation) then host_ndpi_timeseries_creation = "none" end

-- Devices RRD creation is OFF, as OFF is the nDPI rrd creation
if isEmptyString(l2_device_rrd_creation) then l2_device_rrd_creation = "0" end
if isEmptyString(l2_device_ndpi_timeseries_creation) then l2_device_ndpi_timeseries_creation = "none" end

-- tprint({interface_rrd_creation=interface_rrd_creation, interface_ndpi_timeseries_creation=interface_ndpi_timeseries_creation,host_rrd_creation=host_rrd_creation,host_ndpi_timeseries_creation=host_ndpi_timeseries_creation})

local ifnames = interface.getIfNames()
local prefs = ntop.getPrefs()

-- Scan "5 minute" alerts
callback_utils.foreachInterface(ifnames, nil, function(ifname, ifstats)
   scanAlerts("5mins", ifname)
   housekeepingAlertsMakeRoom(getInterfaceId(ifname))
end)

-- ########################################################

callback_utils.foreachInterface(ifnames, interface_rrd_creation_enabled, function(_ifname, ifstats)
  basedir = fixPath(dirs.workingdir .. "/" .. ifstats.id .. "/rrd")

  if interface_rrd_creation == "1" then

     if interface_ndpi_timeseries_creation == "per_protocol" or interface_ndpi_timeseries_creation == "both" then
	for k in pairs(ifstats["ndpi"]) do
	   local v = ifstats["ndpi"][k]["bytes.sent"]+ifstats["ndpi"][k]["bytes.rcvd"]
	   if(verbose) then print("["..__FILE__()..":"..__LINE__().."] ".._ifname..": "..k.."="..v.."\n") end

	   local name = fixPath(basedir .. "/"..k..".rrd")
	   createSingleRRDcounter(name, 300, verbose)
	   ntop.rrd_update(name, "N:".. tolongint(v))
	end
     end

     if interface_ndpi_timeseries_creation == "per_category" or interface_ndpi_timeseries_creation == "both" then
	for k, v in pairs(ifstats["ndpi_categories"]) do
	   v = v["bytes"]
	   if(verbose) then print("["..__FILE__()..":"..__LINE__().."] ".._ifname..": "..k.."="..v.."\n") end

	   local name = fixPath(basedir .. "/"..k..".rrd")
	   createSingleRRDcounter(name, 300, verbose)
	   ntop.rrd_update(name, "N:".. tolongint(v))
	end
     end

     if (not ntop.exists(fixPath(basedir.."/localstats/"))) then
	if(verbose) then print("\n["..__FILE__()..":"..__LINE__().."] Creating localstats directory ", fixPath(basedir.."/localstats"), '\n') end
	ntop.mkdir(fixPath(basedir.."/localstats/"))
     end

     -- IN/OUT counters
     if (ifstats["localstats"]["bytes"]["local2remote"] > 0) then
	name = fixPath(basedir .. "/localstats/local2remote.rrd")
	createSingleRRDcounter(name, 300, verbose)
	ntop.rrd_update(name, "N:"..tolongint(ifstats["localstats"]["bytes"]["local2remote"]))
	if (verbose) then print("\n["..__FILE__()..":"..__LINE__().."] Updating RRD [".. ifstats.name .."] "..name..'\n') end
     end

     if (ifstats["localstats"]["bytes"]["remote2local"] > 0) then
	name = fixPath(basedir .. "/localstats/remote2local.rrd")
	createSingleRRDcounter(name, 300, verbose)
	ntop.rrd_update(name, "N:"..tolongint(ifstats["localstats"]["bytes"]["remote2local"]))
	if (verbose) then print("\n["..__FILE__()..":"..__LINE__().."] Updating RRD [".. ifstats.name .."] "..name..'\n') end
     end
  end

  -- Save hosts stats (if enabled from the preferences)
  if host_rrd_creation ~= "0" or host_categories_rrd_creation ~= "0" then

   local in_time = callback_utils.foreachLocalHost(_ifname, time_threshold, function (hostname, host, hostbase)
     -- Crunch additional stats for local hosts only
     if(host.localhost) then
       -- Traffic stats
       if(host_rrd_creation == "1") then
	  local name = fixPath(hostbase .. "/bytes.rrd")
	  createRRDcounter(name, 300, verbose)
	  ntop.rrd_update(name, "N:"..tolongint(host["bytes.sent"]) .. ":" .. tolongint(host["bytes.rcvd"]))
	  if(verbose) then
	     print("\n["..__FILE__()..":"..__LINE__().."] Updating RRD [".. ifstats.name .."] "..name..'\n')
	  end

	  -- Number of flows
	  makeRRD(hostbase, ifstats.name, "num_flows", 300, host["active_flows.as_client"] + host["active_flows.as_server"])

	  -- L4 Protocols
	  for id, _ in ipairs(l4_keys) do
	     k = l4_keys[id][2]
	     if((host[k..".bytes.sent"] ~= nil) and (host[k..".bytes.rcvd"] ~= nil)) then
		if(verbose) then print("["..__FILE__()..":"..__LINE__().."]\t"..k.."\n") end

		name = fixPath(hostbase .. "/".. k .. ".rrd")
		createRRDcounter(name, 300, verbose)
		-- io.write(name.."="..host[k..".bytes.sent"].."|".. host[k..".bytes.rcvd"] .. "\n")
		ntop.rrd_update(name, "N:".. tolongint(host[k..".bytes.sent"]) .. ":" .. tolongint(host[k..".bytes.rcvd"]))
		if(verbose) then print("\n["..__FILE__()..":"..__LINE__().."] Updating RRD [".. ifstats.name .."] "..name..'\n') end
	     else
		-- L2 host
		--io.write("Discarding "..k.."@"..hostname.."\n")
	     end
	  end
       end

       if(host_ndpi_timeseries_creation == "per_protocol" or host_ndpi_timeseries_creation == "both") then
	  -- nDPI Protocols
	  for k in pairs(host["ndpi"] or {}) do
	     name = fixPath(hostbase .. "/".. k .. ".rrd")
	     createRRDcounter(name, 300, verbose)
	     ntop.rrd_update(name, "N:".. tolongint(host["ndpi"][k]["bytes.sent"]) .. ":" .. tolongint(host["ndpi"][k]["bytes.rcvd"]))

	     if(verbose) then print("\n["..__FILE__()..":"..__LINE__().."] Updating RRD [".. ifstats.name .."] "..name..'\n') end
	  end
       end

       if(host_ndpi_timeseries_creation == "per_category" or host_ndpi_timeseries_creation == "both") then
	  -- nDPI Protocol CATEGORIES
	  for k, cat in pairs(host["ndpi_categories"] or {}) do
	     name = fixPath(hostbase .. "/".. k .. ".rrd")
	     createSingleRRDcounter(name, 300, verbose)
	     ntop.rrd_update(name, "N:".. tolongint(cat["bytes"]))

	     if(verbose) then print("\n["..__FILE__()..":"..__LINE__().."] Updating RRD [".. ifstats.name .."] "..name..'\n') end
	  end
       end

       if(host_categories_rrd_creation ~= "0") then
	  if not ntop.exists(fixPath(hostbase.."/categories")) then
	     ntop.mkdir(fixPath(hostbase.."/categories"))
	  end

	  if host["categories"] ~= nil then
	     for _cat_name, cat_bytes in pairs(host["categories"]) do
                cat_name = getCategoryLabel(_cat_name)
                -- io.write('cat_name: '..cat_name..' cat_bytes:'..tostring(cat_bytes)..'\n')
                name = fixPath(hostbase.."/categories/"..cat_name..".rrd")
                createSingleRRDcounter(name, 300, verbose)
                ntop.rrd_update(name, "N:".. tolongint(cat_bytes))
	     end
	  end
       end
     end -- ends if host.localhost
   end) -- end foreeachHost
   if not in_time then
      callback_utils.print(__FILE__(), __LINE__(), "ERROR: Cannot complete local hosts RRD dump in 5 minutes. Please check your RRD configuration.")
      return false
   end

   if l2_device_rrd_creation ~= "0" then
     local in_time = callback_utils.foreachDevice(_ifname, time_threshold, function (devicename, device, devicebase)
       local name = fixPath(devicebase .. "/bytes.rrd")

       createRRDcounter(name, 300, verbose)
       ntop.rrd_update(name, "N:"..tolongint(device["bytes.sent"]) .. ":" .. tolongint(device["bytes.rcvd"]))

       if l2_device_ndpi_timeseries_creation == "per_category" then
	  -- nDPI Protocol CATEGORIES
	  for k, cat in pairs(device["ndpi_categories"] or {}) do
	     name = fixPath(devicebase .. "/".. k .. ".rrd")
	     createSingleRRDcounter(name, 300, verbose)
	     ntop.rrd_update(name, "N:".. tolongint(cat["bytes"]))

	     if(verbose) then print("\n["..__FILE__()..":"..__LINE__().."] Updating RRD [".. ifstats.name .."] "..name..'\n') end
	  end
       end

     end)

     if not in_time then
      callback_utils.print(__FILE__(), __LINE__(), "ERROR: Cannot devices RRD dump in 5 minutes. Please check your RRD configuration.")
      return false
   end
  end

  end

  -- create RRD for ASN
  if asn_rrd_creation == "1" then
     local basedir = fixPath(dirs.workingdir .. "/" .. ifstats.id..'/asnstats')

     local asn_info = interface.getASesInfo({detailsLevel = "higher"})
     for _, asn_stats in ipairs(asn_info["ASes"]) do
	local asn = asn_stats["asn"]

	local asnpath = fixPath(basedir.. "/" .. asn)
        if not ntop.exists(asnpath) then
	   ntop.mkdir(asnpath)
        end

        -- Save ASN bytes
        local asn_bytes_rrd = fixPath(asnpath .. "/bytes.rrd")
        createRRDcounter(asn_bytes_rrd, 300, false)
        ntop.rrd_update(asn_bytes_rrd, "N:"..tolongint(asn_stats["bytes.sent"]) .. ":" .. tolongint(asn_stats["bytes.rcvd"]))

        -- Save ASN ndpi stats
        if asn_stats["ndpi"] ~= nil then
	   for proto_name, proto_stats in pairs(asn_stats["ndpi"]) do
	      local asn_ndpi_rrd = fixPath(asnpath.."/"..proto_name..".rrd")
	      createRRDcounter(asn_ndpi_rrd, 300, verbose)
	      ntop.rrd_update(asn_ndpi_rrd, "N:"..tolongint(proto_stats["bytes.sent"])..":"..tolongint(proto_stats["bytes.rcvd"]))
	   end
        end

	if tcp_retr_ooo_lost_rrd_creation == "1" then
	   --[[ TODO: implement for ASes
	   local anoms = (asn_stats["tcp.packets.out_of_order"] or 0)
	   anoms = anoms + (asn_stats["tcp.packets.retransmissions"] or 0) + (asn_stats["tcp.packets.lost"] or 0)
	   if(anoms > 0) then
	      makeRRD(asnpath, ifstats.id, "tcp_retr_ooo_lost", 300, anoms)
	   end
	   --]]
	end
     end
  end

  -- Create RRD for vlans
  if vlan_rrd_creation == "1" then
    local basedir = fixPath(dirs.workingdir .. "/" .. ifstats.id..'/vlanstats')
    local vlan_info = interface.getVLANsInfo()

    if (vlan_info ~= nil) and (vlan_info["VLANs"] ~= nil) then
      for _, vlan_stats in pairs(vlan_info["VLANs"]) do
        local vlan_id = vlan_stats["vlan_id"]

        local vlanpath = getPathFromKey(vlan_id)
        vlanpath = fixPath(basedir.. "/" .. vlanpath)
        if not ntop.exists(vlanpath) then
          ntop.mkdir(vlanpath)
        end

        local vlanbytes = fixPath(vlanpath .. "/bytes.rrd")
        createRRDcounter(vlanbytes, 300, false)
        ntop.rrd_update(vlanbytes, "N:"..tolongint(vlan_stats["bytes.sent"]) .. ":" .. tolongint(vlan_stats["bytes.rcvd"]))

        -- Save VLAN ndpi stats
        if vlan_stats["ndpi"] ~= nil then
          for proto_name, proto_stats in pairs(vlan_stats["ndpi"]) do
            local vlan_ndpi_rrd = fixPath(vlanpath.."/"..proto_name..".rrd")
            createRRDcounter(vlan_ndpi_rrd, 300, verbose)
            ntop.rrd_update(vlan_ndpi_rrd, "N:"..tolongint(proto_stats["bytes.sent"])..":"..tolongint(proto_stats["bytes.rcvd"]))
          end
        end

        if tcp_retr_ooo_lost_rrd_creation == "1" then
          --[[ TODO: implement for VLANs
          local anoms = (vlan_stats["tcp.packets.out_of_order"] or 0)
          anoms = anoms + (vlan_stats["tcp.packets.retransmissions"] or 0) + (vlan_stats["tcp.packets.lost"] or 0)
          if(anoms > 0) then
             makeRRD(vlanpath, ifstats.id, "tcp_retr_ooo_lost", 300, anoms)
          end
          --]]
        end
      end
    end
  end

  -- Create RRDs for flow and sFlow devices
  if(flow_devices_rrd_creation == "1" and ntop.isEnterprise()) then
     local flowdevs = interface.getSFlowDevices()

     for flow_device_ip,_ in pairs(flowdevs) do
        local ports = interface.getSFlowDeviceInfo(flow_device_ip)

        if(verbose) then
	   print ("["..__FILE__()..":"..__LINE__().."] Processing sFlow device "..flow_device_ip.."\n")
        end

        for port_idx,port_value in pairs(ports) do
	   local base = getRRDName(ifstats.id, "sflow:"..flow_device_ip, port_idx)
	   if(not(ntop.exists(base))) then ntop.mkdir(base) end

	   local name = getRRDName(ifstats.id, "sflow:"..flow_device_ip, port_idx.."/bytes.rrd")

	   createRRDcounter(name, 300, verbose)
	   str = "N:".. tolongint(port_value.ifOutOctets) .. ":" .. tolongint(port_value.ifInOctets)
	   ntop.rrd_update(name, str)

	   if(verbose) then
	      print ("["..__FILE__()..":"..__LINE__().."]  Processing sFlow device "..flow_device_ip.." / port "..port_idx.." ["..name.."]\n")
	   end
        end
     end

     local flowdevs = interface.getFlowDevices() -- Flow, not sFlow here

     for flow_device_ip,_ in pairs(flowdevs) do
	local ports = interface.getFlowDeviceInfo(flow_device_ip)

	if(verbose) then
	   print ("["..__FILE__()..":"..__LINE__().."] Processing flow device "..flow_device_ip.."\n")
	end

	for port_idx,port_value in pairs(ports) do
	   local base = getRRDName(ifstats.id, "flow_device:"..flow_device_ip, port_idx)
	   if(not(ntop.exists(base))) then ntop.mkdir(base) end

	   local name = getRRDName(ifstats.id, "flow_device:"..flow_device_ip, port_idx.."/bytes.rrd")

	   createRRDcounter(name, 300, verbose)
	   str = "N:".. tolongint(port_value["bytes.out_bytes"]) .. ":" .. tolongint(port_value["bytes.in_bytes"])
	   ntop.rrd_update(name, str)

	   if(verbose) then
	      print ("["..__FILE__()..":"..__LINE__().."]  Processing flow device "..flow_device_ip.." / port "..port_idx.." ["..name.."]\n")
	   end
	end
     end

  end

  -- Save Host Pools stats every 5 minutes
  if((ntop.isPro()) and (tostring(host_pools_rrd_creation) == "1") and (not ifstats.isView)) then
    host_pools_utils.updateRRDs(ifstats.id, true --[[ also dump nDPI data ]], verbose)
  end
end)

-- ########################################################

-- This must be placed at the end of the script
if(tostring(snmp_devices_rrd_creation) == "1") then
   snmp_update_rrds(time_threshold, verbose)
end
