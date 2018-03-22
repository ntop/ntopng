--
-- (C) 2013-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
require "db_utils"
local json = require ("dkjson")

sendHTTPContentTypeHeader('text/html')

local ifid = _GET["ifid"]
if ifid == nil or ifid == "" then
   ifid = getInterfaceId(ifname)
end

-- use this two params to see statistics of a single host
-- or for a pair of them
local host = _GET["peer1"]
local peer = _GET["peer2"]
if peer and not host then
   host = peer
   peer = nil
end

-- this is to retrieve L7 application data
local l7_proto_id = _GET["l7_proto_id"]

-- specify the type of stats
local action = _GET["fav_action"]
if action == nil or (action ~= "set" and action ~= "get" and action ~= "del" and action ~= "del_all") then
   -- default to get
   stats_type = "get"
end

local stats_type = _GET["stats_type"]
if stats_type == nil or (stats_type ~= "top_talkers" and stats_type ~= "top_applications") then
   -- default to top traffic
   stats_type = "top_talkers"
end

local favourite_type = _GET["favourite_type"]
if favourite_type == nil or
   (favourite_type ~= "talker" and favourite_type ~= "apps_per_host_pair" and
    favourite_type ~= "app" and favourite_type ~= "host_peers_by_app") then
   -- default to talkers
   -- infer the favourite type by looking at peers
   favourite_type = "talker"
end

-- start building the response
local res = {["status"] = "unable to parse the request, please check input parameters."}

-- prepare the redis key
local k = getRedisPrefix("ntopng.prefs")..'.'..tostring(ifid)..'.historical_favourites.'..stats_type..'.'..favourite_type

if action == "get" then
   -- retrieve all the elements set for this kind of preference
   res = ntop.getHashKeysCache(k)
   if res == nil then res = {} end
   -- now it's time to retrieve has values that contain resolved addresses
   -- and are a more-user friendly way to represent hosts
   for h, _ in pairs(res) do
      res[h] = ntop.getHashCache(k, h)
      if res[h] == "" or res[h] == nil then res[h] = h end
   end
elseif action == "set" or action == "del" then
   local entry = ""
   local resolved = ""

   -- TOP TALKERS favourites
   if favourite_type == "talker" or favourite_type == "apps_per_host_pair" then
      if host ~= "" and host ~= nil then
	 entry = host
	 resolved = getResolvedAddress(hostkey2hostinfo(host))

	 if peer ~= "" and peer ~= nil then
	    entry = entry..','..peer
	    resolved = resolved..','..getResolvedAddress(hostkey2hostinfo(peer))
	 end
      end

   -- TOP APPLICATIONS favourites
   elseif favourite_type == "app" or favourite_type == "host_peers_by_app" then
      if l7_proto_id ~= "" and l7_proto_id ~= nil then
	 entry = l7_proto_id
	 resolved = interface.getnDPIProtoName(tonumber(l7_proto_id))
	 if host ~= "" and host ~= nil then
	    entry = entry..','..host
	    resolved = resolved..','..getResolvedAddress(hostkey2hostinfo(host))
	 end
      end
   end

   if entry ~= "" then
      if action == "set" then
	 ntop.setHashCache(k, entry, resolved)
      elseif action == "del" then
	 ntop.delHashCache(k, entry)
      end
   end
   res = {}
elseif action == "del_all" then
   ntop.delCache(k)
   res = {}
else
   -- should never be reached

end

print(json.encode(res, nil))
