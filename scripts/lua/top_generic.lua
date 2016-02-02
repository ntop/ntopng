--
-- (C) 2013-15 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
require "top_talkers"
require "db_utils"
local json = require ("dkjson")

sendHTTPHeader('text/html; charset=iso-8859-1')

ifid = getInterfaceId(ifname)

-- make epoch and epoch_start synonims, that is, one can specify
-- either epoch or the more meningful epoch_start
epoch = _GET["epoch"]
epoch_start = _GET["epoch_start"]
if epoch_start == nil or epoch_start == "" then epoch_start = epoch end

-- epoch end is optional and is used to retrieve intervals different from 1 min
epoch_end = _GET["epoch_end"]

module = _GET["m"]
param = _GET["param"]
mode = _GET["mode"]
add_vlan = _GET["addvlan"]

-- use this two params to see statistics of a single host
-- or for a pair of them
local peer1 = _GET["peer1"]
local peer2 = _GET["peer2"]
if peer2 and not peer1 then
        peer1 = peer2
        peer2 = nil
end
-- specify the type of stats
local stats_type = _GET["stats_type"]
if stats_type == nil or (stats_type ~= "top_talkers" and stats_type ~= "top_applications" and stats_type ~= "peers_traffic_histogram") then
        -- default to top traffic
        stats_type = "top_talkers"
end

if (module == nil) then
  print("[ ]\n")
else
  if (param == nil) then param = "" end
  mod = require("top_scripts."..module)
  if (type(mod) == type(true)) then
    print("[ ]\n")
  else
     if(epoch_start == nil) then
	top = mod.getTopClean(ifid, ifname, mode)
        print(top)
     elseif epoch_end == nil or epoch_end == "" then
	epoch_start = epoch_start+60 -- we return the minute before the event as epochs are stored in the DB 'past' the time period
	top = mod.getHistoricalTop(ifid, ifname, epoch_start, add_vlan)
        print(top)
     else
        local res = {}
        if stats_type == "top_talkers" then
                if not peer1 and not peer2 then
                        -- compute the top-talkers for the selected time interval
                        res = mod.getHistoricalTopInInterval(ifid, ifname, epoch_start + 60, epoch_end + 60, add_vlan)
                else
                        res = getHostTopTalkers(ifid, peer1, nil, epoch_start + 60, epoch_end + 60)

                        for _, record in pairs(res) do
                                record["peer_label"] = ntop.getResolvedAddress(record["peer_addr"])  -- TODO: resolve names
                        end
                        -- tprint(res)
                end
        elseif stats_type =="top_applications" then
                res = getHostTopApplications(ifid, peer1, peer2, nil, epoch_start + 60, epoch_end + 60)

                -- add protocol labels
                for _, record in pairs(res) do
                        record["application_label"] = getApplicationLabel(interface.getnDPIProtoName(tonumber(record["application"])))
                end
                -- tprint(res)
        elseif stats_type =="peers_traffic_histogram" and peer1 and peer2 then
                res = getPeersTrafficHistogram(ifid, peer1, peer2, nil, epoch_start + 60, epoch_end + 60)

                for _, record in pairs(res) do
                        record["peer1_label"] = ntop.getResolvedAddress(record["peer1_addr"])
                        record["peer2_label"] = ntop.getResolvedAddress(record["peer2_addr"])

                end
                -- tprint(res)
        end
        print(json.encode(res, nil))
     end
  end
end
