--
-- (C) 2013-15 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

if (ntop.isPro()) then
  package.path = dirs.installdir .. "/pro/scripts/callbacks/?.lua;" .. package.path
end

require "lua_utils"
require "alert_utils"
require "graph_utils"
require "influx_utils"
require "top_structure"

when = os.time()

local verbose = ntop.verboseTrace()

if(use_influx) then
   cache_key = "minute.lua.cache"
   load_last_influx(cache_key)
   host_header = '[\n  {\n "name" : "hosts",\n "columns" : ["time", "interface", "host", "proto", "sent", "rcvd"],\n "points" : [\n'
   if_header = '[\n  {\n "name" : "interfaces.l7",\n "columns" : ["time", "interface", "proto", "sent", "rcvd"],\n "points" : [\n'
   num_host_points = 0
   num_if_points = 0
end

function influx_add_interface_point(ifname, key, sent, rcvd)
   local k = ifname.."."..key

   local s = diff_value_influx(k, "sent", sent)
   local r = diff_value_influx(k, "rcvd", rcvd)
   
   if((s > 0) or (r > 0)) then
      if(num_if_points > 0) then if_header = if_header .. ',\n' end
      if_header = if_header .. '\t['.. when .. '000, "' .. ifname .. '","' .. key .. '",' .. s .. ',' .. r .. ']'
      num_if_points = num_if_points + 1
   end
end

function influx_add_host_point(ifname, host, key, sent, rcvd)
   local k = ifname.."."..host.."."..key

   if((sent == 0) and (rcvd == 0)) then return end

   -- io.write(k.." [sent: "..sent.."][rcvd: "..rcvd.."]\n")

   local s = diff_value_influx(k, "sent", sent)
   local r = diff_value_influx(k, "rcvd", rcvd)

   if((s > 0) or (r > 0)) then
      if(num_host_points > 0) then host_header = host_header .. ',\n' end
      host_header = host_header .. '\t['.. when .. '000, "' .. ifname .. '","' .. host .. '","' .. key .. '",' .. s .. ',' .. r .. ']'
      -- io.write(ifname.."|"..host.."|"..key.."|"..s.."|"..r.."\n")
      num_host_points = num_host_points + 1
   end
end


-- Scan "minute" alerts
scanAlerts("min")

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

-- id = 0
for _,_ifname in pairs(ifnames) do
   interface.select(_ifname)
   ifstats = interface.getStats()

   if(verbose) then print("\n["..__FILE__()..":"..__LINE__().."]===============================\n["..__FILE__()..":"..__LINE__().."] Processing interface " .. _ifname .. " ["..ifstats.id.."]") end
   -- Dump topTalkers every minute

   if((ifstats.type ~= "pcap dump") and (ifstats.type ~= "unknown")) then
      talkers = makeTopJSON(ifstats.id, _ifname)      
      ntop.insertMinuteSampling(ifstats.id, talkers)

      --if(verbose) then print(talkers); end
      -- Run RRD update every 5 minutes
      -- Use 30 just to avoid rounding issues
      diff = when % 300

      -- print('\n["..__FILE__()..":"..__LINE__().."] Diff: '..diff..'\n')

      if(verbose or (diff < 60)) then
	 -- Scan "5 minute" alerts
	 scanAlerts("5mins")

	 basedir = fixPath(dirs.workingdir .. "/" .. ifstats.id .. "/rrd")
	 for k in pairs(ifstats["ndpi"]) do
	    v = ifstats["ndpi"][k]["bytes.sent"]+ifstats["ndpi"][k]["bytes.rcvd"]
	    if(verbose) then print("["..__FILE__()..":"..__LINE__().."] ".._ifname..": "..k.."="..v.."\n") end

	    name = fixPath(basedir .. "/"..k..".rrd")
	    createSingleRRDcounter(name, verbose)
	    influx_add_interface_point(_ifname, "l7."..k, ifstats["ndpi"][k]["bytes.sent"], ifstats["ndpi"][k]["bytes.rcvd"])
	    ntop.rrd_update(name, "N:".. v)
	 end

         if (not ntop.exists(fixPath(basedir.."/localstats/"))) then
           if(verbose) then print("\n["..__FILE__()..":"..__LINE__().."] Creating localstats directory ", fixPath(basedir.."/localstats"), '\n') end
           ntop.mkdir(fixPath(basedir.."/localstats/"))
         end
         -- IN/OUT counters
         if (ifstats["localstats"]["bytes"]["local2remote"] > 0) then
           name = fixPath(basedir .. "/localstats/local2remote.rrd")
           createSingleRRDcounter(name, verbose)
           ntop.rrd_update(name, "N:"..ifstats["localstats"]["bytes"]["local2remote"])
           if (verbose) then print("\n["..__FILE__()..":"..__LINE__().."] Updating RRD [".. ifstats.name .."] "..name..'\n') end
         end
         if (ifstats["localstats"]["bytes"]["remote2local"] > 0) then
           name = fixPath(basedir .. "/localstats/remote2local.rrd")
           createSingleRRDcounter(name, verbose)
           ntop.rrd_update(name, "N:"..ifstats["localstats"]["bytes"]["remote2local"])
           if (verbose) then print("\n["..__FILE__()..":"..__LINE__().."] Updating RRD [".. ifstats.name .."] "..name..'\n') end
         end

	 -- Save hosts stats
	 if(host_rrd_creation ~= "0") then
	    hosts_stats = interface.getLocalHostsInfo()
            local networks_aggr = {}
            local communities_aggr = {}
	    for key, value in pairs(hosts_stats) do
	       host = interface.getHostInfo(key)

	       if(host == nil) then
		  if(verbose) then print("\n["..__FILE__()..":"..__LINE__().."] NULL host "..key.." !!!!\n") end
	       else
		  if(verbose) then
		     print ("["..__FILE__()..":"..__LINE__().."] [" .. key .. "][local: ")
		     print(tostring(host["localhost"]))
		     print("]" .. (hosts_stats[key]["bytes.sent"]+hosts_stats[key]["bytes.rcvd"]) .. "]\n")
		  end

		  if(host.localhost) then
                     local keypath = getPathFromKey(key)
		     basedir = fixPath(dirs.workingdir .. "/" .. ifstats.id .. "/rrd/" .. keypath)

		     if(not(ntop.exists(basedir))) then
			if(verbose) then print("\n["..__FILE__()..":"..__LINE__().."] Creating base directory ", basedir, '\n') end
			ntop.mkdir(basedir)
		     end

                     -- Aggregate communities
                     communities = interface.getHostCommunities(0, hosts_stats[key]["ip"])
                     if (communities ~= nil) then
                        for ckey,cvalue in pairs(communities) do
                          if (communities_aggr[cvalue] == nil) then
                            communities_aggr[cvalue] = {}
                          end
                          if (communities_aggr[cvalue]["bytes.sent"] == nil) then
                            communities_aggr[cvalue]["bytes.sent"] = hosts_stats[key]["bytes.sent"]
                            communities_aggr[cvalue]["bytes.rcvd"] = hosts_stats[key]["bytes.rcvd"]
                          else
                            communities_aggr[cvalue]["bytes.sent"] = communities_aggr[cvalue]["bytes.sent"] +
                                                                     hosts_stats[key]["bytes.sent"]
                            communities_aggr[cvalue]["bytes.rcvd"] = communities_aggr[cvalue]["bytes.rcvd"] +
                                                                     hosts_stats[key]["bytes.rcvd"]
                          end
                        end
                     end

                     -- Aggregate network stats
                     if (networks_aggr[hosts_stats[key]["local_network_name"]] == nil) then
                       networks_aggr[hosts_stats[key]["local_network_name"]] = {}
                     end
                     if (networks_aggr[hosts_stats[key]["local_network_name"]]["bytes.sent"] == nil) then
                       networks_aggr[hosts_stats[key]["local_network_name"]]["bytes.sent"] = hosts_stats[key]["bytes.sent"]
                       networks_aggr[hosts_stats[key]["local_network_name"]]["bytes.rcvd"] = hosts_stats[key]["bytes.rcvd"]
                     else
                       networks_aggr[hosts_stats[key]["local_network_name"]]["bytes.sent"] =
                           networks_aggr[hosts_stats[key]["local_network_name"]]["bytes.sent"] +
                           hosts_stats[key]["bytes.sent"]
                       networks_aggr[hosts_stats[key]["local_network_name"]]["bytes.rcvd"] =
                           networks_aggr[hosts_stats[key]["local_network_name"]]["bytes.rcvd"] +
                           hosts_stats[key]["bytes.rcvd"]
                     end

		     -- Traffic stats
		     name = fixPath(basedir .. "/bytes.rrd")
		     createRRDcounter(name, 300, verbose)
		     ntop.rrd_update(name, "N:"..hosts_stats[key]["bytes.sent"] .. ":" .. hosts_stats[key]["bytes.rcvd"])
		     if(verbose) then print("\n["..__FILE__()..":"..__LINE__().."] Updating RRD [".. ifstats.name .."] "..name..'\n') end
		     influx_add_host_point(_ifname, key, "l3.traffic", hosts_stats[key]["bytes.sent"], hosts_stats[key]["bytes.rcvd"])

		     -- L4 Protocols
		     for id, _ in ipairs(l4_keys) do
			k = l4_keys[id][2]
			if((host[k..".bytes.sent"] ~= nil) and (host[k..".bytes.rcvd"] ~= nil)) then
			   if(verbose) then print("["..__FILE__()..":"..__LINE__().."]\t"..k.."\n") end

			   name = fixPath(basedir .. "/".. k .. ".rrd")
			   createRRDcounter(name, 300, verbose)
			   -- io.write(name.."="..host[k..".bytes.sent"].."|".. host[k..".bytes.rcvd"] .. "\n")
			   ntop.rrd_update(name, "N:".. host[k..".bytes.sent"] .. ":" .. host[k..".bytes.rcvd"])
			   if(verbose) then print("\n["..__FILE__()..":"..__LINE__().."] Updating RRD [".. ifstats.name .."] "..name..'\n') end
			   influx_add_host_point(_ifname, key, "l4."..k, host[k..".bytes.sent"], host[k..".bytes.rcvd"])
			else
			   -- L2 host
			   --io.write("Discarding "..k.."@"..key.."\n")
			end
		     end

		     if(host_ndpi_rrd_creation ~= "0") then
			-- nDPI Protocols
			for k in pairs(host["ndpi"]) do
			   name = fixPath(basedir .. "/".. k .. ".rrd")
			   createRRDcounter(name, 300, verbose)
			   ntop.rrd_update(name, "N:".. host["ndpi"][k]["bytes.sent"] .. ":" .. host["ndpi"][k]["bytes.rcvd"])

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
			   influx_add_host_point(_ifname, key, "l7."..k, host["ndpi"][k]["bytes.sent"], host["ndpi"][k]["bytes.rcvd"])
			end

			if(host["epp"]) then dumpSingleTreeCounters(basedir, "epp", host, verbose) end
			if(host["dns"]) then dumpSingleTreeCounters(basedir, "dns", host, verbose) end
		     end
		  else
		     -- print("ERROR: ["..__FILE__()..":"..__LINE__().."] Skipping non local host "..key.."\n")
		  end
	       end -- if
	    end -- for

            --- Create RRD for networks
            for n,m in pairs(networks_aggr) do
              local netname = getPathFromKey(n)
              local base = dirs.workingdir .. "/" .. ifstats.id .. "/rrd/".. netname
              base = fixPath(base)
              if(not(ntop.exists(base))) then ntop.mkdir(base) end
              name = fixPath(base .. "/bytes.rrd")
              createRRDcounter(name, 300, verbose)
              ntop.rrd_update(name, "N:".. m["bytes.sent"] .. ":" .. m["bytes.rcvd"])
              if (m["ndpi"]) then -- nDPI data could be disabled
                for k in pairs(m["ndpi"]) do
                  ndpiname = fixPath(base.."/"..k..".rrd")
                  createRRDcounter(ndpiname, 300, verbose)
                  ntop.rrd_update(ndpiname, "N:"..m["ndpi"][k]["bytes.sent"]..":"..m["ndpi"][k]["bytes.rcvd"])
                end
              end
            end
            --- Create RRD for communities
            for n,m in pairs(communities_aggr) do
              local base = dirs.workingdir .. "/" .. ifstats.id .. "/rrd/community-".. n
              base = fixPath(base)
              if(not(ntop.exists(base))) then ntop.mkdir(base) end
              name = fixPath(base .. "/bytes.rrd")
              createRRDcounter(name, 300, verbose)
              ntop.rrd_update(name, "N:".. m["bytes.sent"] .. ":" .. m["bytes.rcvd"])
            end
	 end -- if rrd
      end -- if(diff
   end -- if(good interface type
end -- for ifname,_ in pairs(ifnames) do

if(use_influx) then
   if_header = if_header .. "\n]\n }\n]\n"
   -- io.write(if_header.."\n")
   ntop.postHTTPJsonData(influx_user, influx_pwd, influx_url, if_header)

   host_header = host_header .. "\n]\n }\n]\n"
   -- io.write(host_header.."\n")
   ntop.postHTTPJsonData(influx_user, influx_pwd, influx_url, host_header)

   save_curr_influx(cache_key)
end
