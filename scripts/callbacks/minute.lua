--
-- (C) 2013-17 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "alert_utils"
if (ntop.isPro()) then
   package.path = dirs.installdir .. "/pro/scripts/callbacks/?.lua;" .. package.path
end

require "lua_utils"
require "graph_utils"
require "top_structure"
local host_pools_utils = require "host_pools_utils"

prefs = ntop.getPrefs()
-- ########################################################

function foreachHost(ifname, callback)
   local hostbase
   
   interface.select(ifname)
   -- ifstats = interface.getStats()
   
   hosts_stats = interface.getLocalHostsInfo(false)
   hosts_stats = hosts_stats["hosts"]
   for hostname, hoststats in pairs(hosts_stats) do
      local host = interface.getHostInfo(hostname)

      if(host == nil) then
         if(verbose) then print("\n["..__FILE__()..":"..__LINE__().."] NULL host "..hostname.." !!!!\n") end
      else
         if(verbose) then
            print ("["..__FILE__()..":"..__LINE__().."] [" .. hostname .. "][local: ")
            print(tostring(host["localhost"]))
            print("]" .. (hoststats["bytes.sent"]+hoststats["bytes.rcvd"]) .. "]\n")
         end
	 
         if(host.localhost) then
            local keypath = getPathFromKey(hostname)
            hostbase = fixPath(dirs.workingdir .. "/" .. ifstats.id .. "/rrd/" .. keypath)

            if(not(ntop.exists(hostbase))) then
               if(verbose) then print("\n["..__FILE__()..":"..__LINE__().."] Creating base directory ", hostbase, '\n') end
               ntop.mkdir(hostbase)
            end
         else
            hostbase = nil
         end
         
         callback(hostname, host, hoststats, hostbase)
      end
   end
end

-- ########################################################

function saveLocalHostsActivity(hostname, host, hoststats, hostbase)
   if host.localhost then
      local actStats = interface.getHostActivity(hostname)
      if actStats then
         local hostsbase = fixPath(hostbase .. "/activity")
         if(not(ntop.exists(hostsbase))) then
            if(verbose) then print("\n["..__FILE__()..":"..__LINE__().."] Creating host activity directory ", hostsbase, '\n') end
            ntop.mkdir(hostsbase)
         end

         for act, val in pairs(actStats) do
            name = fixPath(hostsbase .. "/" .. act .. ".rrd")

            -- up, down, background bytes
            createActivityRRDCounter(name, verbose)
            ntop.rrd_update(name, "N:"..tolongint(val.up) .. ":" .. tolongint(val.down) .. ":" .. tolongint(val.background))

            if(verbose) then
               print("["..__FILE__()..":"..__LINE__().."] Updating RRD [".. ifstats.name .."] "..name..' ['..val.up.."/"..val.down.."/"..val.background..']\n')
            end
         end
      end
   end
end

-- ########################################################

when = os.time()

local verbose = ntop.verboseTrace()

-- Scan "minute" alerts
for _, ifname in pairs(interface.getIfNames()) do
   scanAlerts("min", ifname)
end

ifnames = interface.getIfNames()
num_ifaces = 0
verbose = false

if((_GET ~= nil) and (_GET["verbose"] ~= nil)) then
   verbose = true
end

if(verbose) then
   sendHTTPHeader('text/plain')
end

host_rrd_creation = ntop.getCache("ntopng.prefs.host_rrd_creation")
host_ndpi_rrd_creation = ntop.getCache("ntopng.prefs.host_ndpi_rrd_creation")
host_categories_rrd_creation = ntop.getCache("ntopng.prefs.host_categories_rrd_creation")
flow_devices_rrd_creation = ntop.getCache("ntopng.prefs.flow_devices_rrd_creation")

if(tostring(flow_devices_rrd_creation) == "1") then
   local info = ntop.getInfo()

   if(info["version.enterprise_edition"] ~= true) then
      flow_devices_rrd_creation = "0"
   end
end


-- id = 0
for _,_ifname in pairs(ifnames) do
   interface.select(_ifname)
   ifstats = interface.getStats()

   if(verbose) then print("\n["..__FILE__()..":"..__LINE__().."]===============================\n["..__FILE__()..":"..__LINE__().."] Processing interface " .. _ifname .. " ["..ifstats.id.."]\n") end
   -- Dump topTalkers every minute

   if((ifstats.type ~= "pcap dump") and (ifstats.type ~= "unknown")) then
      talkers = makeTopJSON(ifstats.id, _ifname)
      if(verbose) then
         print("Computed talkers for interfaceId "..ifstats.id.."/"..ifstats.name.."\n")
	 print(talkers)
      end
      ntop.insertMinuteSampling(ifstats.id, talkers)

      -- TODO secondStats = interface.getLastMinuteTrafficStats()
      -- TODO send secondStats to collector

      -- Save local subnets stats every minute
      basedir = fixPath(dirs.workingdir .. "/" .. ifstats.id..'/subnetstats')
      local subnet_stats = interface.getNetworksStats()
      for subnet,sstats in pairs(subnet_stats) do
	 local rrdpath = getPathFromKey(subnet)
	 rrdpath = fixPath(basedir.. "/" .. rrdpath)
	 if(not(ntop.exists(rrdpath))) then
	    ntop.mkdir(rrdpath)
	 end
	 rrdpath = fixPath(rrdpath .. "/bytes.rrd")
	 createTripleRRDcounter(rrdpath, 60, false)  -- 60(s) == 1 minute step
	 ntop.rrd_update(rrdpath, "N:"..tolongint(sstats["ingress"]) .. ":" .. tolongint(sstats["egress"]) .. ":" .. tolongint(sstats["inner"]))
      end

      basedir = fixPath(dirs.workingdir .. "/" .. ifstats.id .. "/rrd")
      if not ntop.exists(basedir) then ntop.mkdir(basedir) end

      -- General stats
      makeRRD(basedir, _ifname, "num_hosts", 60, ifstats.stats.hosts)
      makeRRD(basedir, _ifname, "num_devices", 60, ifstats.stats.devices)
      makeRRD(basedir, _ifname, "num_flows", 60, ifstats.stats.flows)
      makeRRD(basedir, _ifname, "num_http_hosts", 60, ifstats.stats.http_hosts)

      -- TCP stats
      makeRRD(basedir, _ifname, "tcp_retransmissions", 60, ifstats.tcpPacketStats.retransmissions)
      makeRRD(basedir, _ifname, "tcp_ooo", 60, ifstats.tcpPacketStats.out_of_order)
      makeRRD(basedir, _ifname, "tcp_lost", 60, ifstats.tcpPacketStats.lost)

      -- Save Profile stats every minute
      if ntop.isPro() and ifstats.profiles then  -- profiles are only available in the Pro version
	 basedir = fixPath(dirs.workingdir .. "/" .. ifstats.id..'/profilestats')
	 for pname, ptraffic in pairs(ifstats.profiles) do
	    local rrdpath = fixPath(basedir.. "/" .. getPathFromKey(trimSpace(pname)))
	    if(not(ntop.exists(rrdpath))) then
	       ntop.mkdir(rrdpath)
	    end
	    rrdpath = fixPath(rrdpath .. "/bytes.rrd")
	    createSingleRRDcounter(rrdpath, 60, false)  -- 60(s) == 1 minute step
	    ntop.rrd_update(rrdpath, "N:"..tolongint(ptraffic))
	 end
      end

      -- Run RRD update every 5 minutes
      -- Use 30 just to avoid rounding issues
      diff = when % 300

      -- print('\n["..__FILE__()..":"..__LINE__().."] Diff: '..diff..'\n')
      if(verbose or (diff < 60)) then
	 -- Scan "5 minute" alerts
	 scanAlerts("5mins", _ifname)

	 basedir = fixPath(dirs.workingdir .. "/" .. ifstats.id .. "/rrd")
	 for k in pairs(ifstats["ndpi"]) do
	    v = ifstats["ndpi"][k]["bytes.sent"]+ifstats["ndpi"][k]["bytes.rcvd"]
	    if(verbose) then print("["..__FILE__()..":"..__LINE__().."] ".._ifname..": "..k.."="..v.."\n") end

	    name = fixPath(basedir .. "/"..k..".rrd")
	    createSingleRRDcounter(name, 300, verbose)
	    ntop.rrd_update(name, "N:".. tolongint(v))
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

	 -- Save hosts stats
	 if(host_rrd_creation ~= "0") then
            local networks_aggr = {}
	    local vlans_aggr    = {}

	    foreachHost(_ifname, function (hostname, host, hoststats, hostbase)
			   -- Aggregate VLAN stats
			   local host_vlan = hoststats["vlan"]
			   if host_vlan ~= nil and host_vlan ~= 0 then
			      if vlans_aggr[host_vlan] == nil then
				 vlans_aggr[host_vlan] = {}
			      elseif vlans_aggr[host_vlan]["bytes.sent"] == nil then
				 vlans_aggr[host_vlan]["bytes.sent"] = hoststats["bytes.sent"]
				 vlans_aggr[host_vlan]["bytes.rcvd"] = hoststats["bytes.rcvd"]
			      else
				 vlans_aggr[host_vlan]["bytes.sent"] = vlans_aggr[host_vlan]["bytes.sent"] + hoststats["bytes.sent"]
				 vlans_aggr[host_vlan]["bytes.rcvd"] = vlans_aggr[host_vlan]["bytes.rcvd"] + hoststats["bytes.rcvd"]
			      end
			   end

			   if(host.localhost) then
			      if host_categories_rrd_creation ~= "0" and not ntop.exists(fixPath(hostbase.."/categories")) then
				 ntop.mkdir(fixPath(hostbase.."/categories"))
			      end

			      -- Aggregate network stats
			      network_key = hoststats["local_network_name"]

			      --io.write("==> Adding "..network_key.."\n")
			      if (networks_aggr[network_key] == nil) then
				 networks_aggr[network_key] = {}
			      end
			      if (networks_aggr[network_key]["bytes.sent"] == nil) then
				 networks_aggr[network_key]["bytes.sent"] = hoststats["bytes.sent"]
				 networks_aggr[network_key]["bytes.rcvd"] = hoststats["bytes.rcvd"]
			      else
				 networks_aggr[network_key]["bytes.sent"] = networks_aggr[network_key]["bytes.sent"] + hoststats["bytes.sent"]
				 networks_aggr[network_key]["bytes.rcvd"] = networks_aggr[network_key]["bytes.rcvd"] + hoststats["bytes.rcvd"]
			      end

			      -- Traffic stats
			      name = fixPath(hostbase .. "/bytes.rrd")
			      createRRDcounter(name, 300, verbose)
			      ntop.rrd_update(name, "N:"..tolongint(hoststats["bytes.sent"]) .. ":" .. tolongint(hoststats["bytes.rcvd"]))
			      if(verbose) then
				 print("\n["..__FILE__()..":"..__LINE__().."] Updating RRD [".. ifstats.name .."] "..name..'\n')
			      end

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

			      if(host_ndpi_rrd_creation ~= "0") then
				 -- nDPI Protocols
				 for k in pairs(host["ndpi"]) do
				    name = fixPath(hostbase .. "/".. k .. ".rrd")
				    createRRDcounter(name, 300, verbose)
				    ntop.rrd_update(name, "N:".. tolongint(host["ndpi"][k]["bytes.sent"]) .. ":" .. tolongint(host["ndpi"][k]["bytes.rcvd"]))

				    -- Aggregate network NDPI stats
				    if (networks_aggr[host["local_network_name"]]["ndpi"] == nil) then
				       networks_aggr[host["local_network_name"]]["ndpi"] = {}
				    end
				    if (networks_aggr[host["local_network_name"]]["ndpi"][k] == nil) then
				       networks_aggr[host["local_network_name"]]["ndpi"][k] = {}
				    end
				    if (networks_aggr[host["local_network_name"]]["ndpi"][k]["bytes.sent"] == nil) then
				       networks_aggr[host["local_network_name"]]["ndpi"][k]["bytes.sent"] = host["ndpi"][k]["bytes.sent"]
				    else
				       networks_aggr[host["local_network_name"]]["ndpi"][k]["bytes.sent"] =
					  networks_aggr[host["local_network_name"]]["ndpi"][k]["bytes.sent"] +
					  host["ndpi"][k]["bytes.sent"]
				    end
				    if (networks_aggr[host["local_network_name"]]["ndpi"][k]["bytes.rcvd"] == nil) then
				       networks_aggr[host["local_network_name"]]["ndpi"][k]["bytes.rcvd"] = host["ndpi"][k]["bytes.rcvd"]
				    else
				       networks_aggr[host["local_network_name"]]["ndpi"][k]["bytes.rcvd"] =
					  networks_aggr[host["local_network_name"]]["ndpi"][k]["bytes.rcvd"] +
					  host["ndpi"][k]["bytes.rcvd"]
				    end

				    if(verbose) then print("\n["..__FILE__()..":"..__LINE__().."] Updating RRD [".. ifstats.name .."] "..name..'\n') end
				 end
				 if(host_categories_rrd_creation ~= "0" and host.localhost) then
				    if host["categories"] ~= nil then
				       if networks_aggr[host["local_network_name"]]["categories"] == nil then
					  networks_aggr[host["local_network_name"]]["categories"] = {}
				       end
				       for _cat_name, cat_bytes in pairs(host["categories"]) do
					  cat_name = getCategoryLabel(_cat_name)
					  -- io.write('cat_name: '..cat_name..' cat_bytes:'..tostring(cat_bytes)..'\n')
					  name = fixPath(hostbase.."/categories/"..cat_name..".rrd")
					  createSingleRRDcounter(name, 300, verbose)
					  ntop.rrd_update(name, "N:".. tolongint(cat_bytes))

					  if networks_aggr[host["local_network_name"]]["categories"][cat_name] == nil then
					     networks_aggr[host["local_network_name"]]["categories"][cat_name] = cat_bytes
					  else
					     networks_aggr[host["local_network_name"]]["categories"][cat_name] =
						networks_aggr[host["local_network_name"]]["categories"][cat_name] + cat_bytes
					  end
				       end
				    end
				 end

				 if(host["epp"]) then dumpSingleTreeCounters(hostbase, "epp", host, verbose) end
				 if(host["dns"]) then dumpSingleTreeCounters(hostbase, "dns", host, verbose) end
			      end
			   else
			      -- print("ERROR: ["..__FILE__()..":"..__LINE__().."] Skipping non local host "..hostname.."\n")
			   end
	    end) -- end foreachHost

	    -- create RRD for vlans
	    local basedir = fixPath(dirs.workingdir .. "/" .. ifstats.id..'/vlanstats')
	    for vlan_id, vlan_stats in pairs(vlans_aggr) do
	       local vlanpath = getPathFromKey(vlan_id)
	       vlanpath = fixPath(basedir.. "/" .. vlanpath)
	       if not ntop.exists(vlanpath) then
		  ntop.mkdir(vlanpath)
	       end
	       vlanpath = fixPath(vlanpath .. "/bytes.rrd")
	       createRRDcounter(vlanpath, 300, false)
	       ntop.rrd_update(vlanpath, "N:"..tolongint(vlan_stats["bytes.sent"]) .. ":" .. tolongint(vlan_stats["bytes.rcvd"]))
	    end

            --- Create RRD for networks
            for n,m in pairs(networks_aggr) do
	       local netname = getPathFromKey(n)
	       local base = dirs.workingdir .. "/" .. ifstats.id .. "/rrd/".. netname
	       base = fixPath(base)
	       --io.write("->"..n.."\n")
	       if(not(ntop.exists(base))) then ntop.mkdir(base) end
	       name = fixPath(base .. "/bytes.rrd")
	       createRRDcounter(name, 300, verbose)
	       str = "N:".. tolongint(m["bytes.sent"]) .. ":" .. tolongint(m["bytes.rcvd"])
	       --io.write(name.."="..str.."\n")
	       ntop.rrd_update(name, str)
	       if (m["ndpi"]) then -- nDPI data could be disabled
		  for k in pairs(m["ndpi"]) do
		     local ndpiname = fixPath(base.."/"..k..".rrd")
		     createRRDcounter(ndpiname, 300, verbose)
		     ntop.rrd_update(ndpiname, "N:"..tolongint(m["ndpi"][k]["bytes.sent"])..":"..tolongint(m["ndpi"][k]["bytes.rcvd"]))
		  end
	       end
	       if (m["categories"]) then
		  if not ntop.exists(fixPath(base.."/categories")) then ntop.mkdir(fixPath(base.."/categories")) end
		  for cat_name, cat_bytes in pairs(m["categories"]) do
		     local catrrdname = fixPath(base.."/categories/"..cat_name..".rrd")
		     createSingleRRDcounter(catrrdname, 300, verbose)
		     ntop.rrd_update(catrrdname, "N:"..tolongint(cat_bytes))
		  end
	       end
            end -- for

            -- Save Host Pools stats every 5 minutes
         for _,pool in ipairs(host_pools_utils.getPoolsList(ifstats.id, true --[[ without any additional pool info ]])) do
            local pool_base = host_pools_utils.getRRDBase(ifstats.id, pool.id)

            if(not(ntop.exists(pool_base))) then
               ntop.mkdir(pool_base)
            end

            local rrdpath = fixPath(pool_base .. "/bytes.rrd")
            createRRDcounter(rrdpath, 300, verbose)
            --TODO bytes and protocols
            ntop.rrd_update(rrdpath, "N:"..tolongint(0) .. ":" .. tolongint(0))
         end

	    -- Create RRDs for flow devices
	    if(tostring(flow_devices_rrd_creation) == "1") then
	       local flowdevs = interface.getFlowDevices()

	       for flow_device_ip,_ in pairs(flowdevs) do
		  local ports = interface.getFlowDeviceInfo(flow_device_ip)

		  if(verbose) then
		     print ("["..__FILE__()..":"..__LINE__().."] Processing flow device "..flow_device_ip.."\n")
		  end

		  for port_idx,port_value in pairs(ports) do
		     local base = dirs.workingdir .. "/" .. ifstats.id .. "/rrd/flowdevs/".. flow_device_ip

		     base = fixPath(base)
		     if(not(ntop.exists(base))) then ntop.mkdir(base) end
		     name = fixPath(base .. "/"..port_idx..".rrd")
		     createRRDcounter(name, 300, verbose)
		     str = "N:".. tolongint(port_value.ifInOctets) .. ":" .. tolongint(port_value.ifOutOctets)
		     ntop.rrd_update(name, str)

		     if(verbose) then
			print ("["..__FILE__()..":"..__LINE__().."]  Processing flow device "..flow_device_ip.." / port "..port_idx.." ["..name.."]\n")
		     end
		  end
	       end
	    end

	    -- Save host activity stats only if flow activities are actually enabled
	    if prefs.is_flow_activity_enabled == true then
	       foreachHost(_ifname, saveLocalHostsActivity)
	    end
	 end -- if rrd
      end -- if(diff
   end -- if(good interface type
end -- for ifname,_ in pairs(ifnames) do

-- check MySQL open files status
-- NOTE: performed on startup.lua
-- checkOpenFiles()

-- when the active local hosts cache is enabled, ntopng periodically dumps active local hosts statistics to redis
-- in order to protect from failures (e.g., power losses)
if prefs.is_active_local_hosts_cache_enabled then
   local interval = prefs.active_local_hosts_cache_interval
   local diff = when % tonumber((interval or 3600 --[[ default 1 h --]]))

   --[[
   tprint("interval: "..tostring(interval))
   tprint("when: "..tostring(when))
   tprint("diff: "..tostring(diff))
   --]]

   if diff < 60 then
      for _, ifname in pairs(ifnames) do
	 -- tprint("dumping ifname: "..ifname)

	 -- to protect from failures (e.g., power losses) it is possible to save
	 -- local hosts counters to redis once per hour
	 interface.select(ifname)
	 interface.dumpLocalHosts2redis()
      end

   end
end
