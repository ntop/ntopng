--
-- (C) 2013-26 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "flow_utils"
local rest_utils = require "rest_utils"
local as_utils = require "as_utils"

if not (ntop.hasGeoIP and ntop.hasGeoIP()) then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

local ip_version_or_host = _GET["flowhosts_type"]
local ifid = _GET["ifid"] or interface.getId()
local current_ifid = interface.getId()

interface.select(ifid)

if not isEmptyString(ip_version_or_host) then
   if string.starts(ip_version_or_host, "ip_version_") then
      local version = split(ip_version_or_host, "ip_version_")
      _GET["version"] = version[2]
      _GET["flowhosts_type"] = nil
   else
      local host = hostkey2hostinfo(ip_version_or_host)
      if isIPv4(host.host) or isIPv6(host.host) then
         _GET["host"] = ip_version_or_host
         _GET["flowhosts_type"] = nil
      end
   end
end

local flows_filter = getFlowsFilter()
flows_filter = as_utils.formatFilters(flows_filter, true)

-- Need client/server geo-coordinates and country (for the flag in the
-- tooltip), capped tightly since this powers a map view, not a paginated
-- table.
flows_filter.detailsLevel = "max"
flows_filter.maxHits = 512
flows_filter.perPage = 512
flows_filter.toSkip = 0

local flows_stats = interface.getFlowsInfo(flows_filter["hostFilter"], flows_filter, flows_filter["talkingWith"],
   flows_filter["client"], flows_filter["server"], flows_filter["flow_info"])

local nodes = {}
local nodes_seen = {}
local edges = {}

local function add_node(ip, lat, lng, country, protocol)
   if isEmptyString(ip) or (lat == 0 and lng == 0) then
      return
   end
   if not nodes_seen[ip] then
      nodes_seen[ip] = {
         lat = lat,
         lng = lng,
         label = ip,
         ip = ip,
         status = "Online",
         country = country,
         protocols = {},
         connectionCount = 0
      }
      nodes[#nodes + 1] = nodes_seen[ip]
   end
   nodes_seen[ip].connectionCount = nodes_seen[ip].connectionCount + 1
   if not isEmptyString(protocol) then
      nodes_seen[ip].protocols[protocol] = true
   end
end

if flows_stats and flows_stats.flows then
   for _, value in ipairs(flows_stats.flows) do
      local cli_ip = value["cli.ip"]
      local srv_ip = value["srv.ip"]
      local cli_lat, cli_lng = value["cli.latitude"], value["cli.longitude"]
      local srv_lat, srv_lng = value["srv.latitude"], value["srv.longitude"]
      local protocol = value["proto.ndpi"]

      add_node(cli_ip, cli_lat, cli_lng, value["cli.country"], protocol)
      add_node(srv_ip, srv_lat, srv_lng, value["srv.country"], protocol)

      if cli_lat and cli_lat ~= 0 and srv_lat and srv_lat ~= 0 then
         edges[#edges + 1] = {
            sourcePosition = { cli_lng, cli_lat },
            targetPosition = { srv_lng, srv_lat },
            sourceSiteId = cli_ip,
            targetSiteId = srv_ip,
            protocol = protocol,
            severity = (value["predominant_alert"] and "Warning") or "Normal"
         }
      end
   end
end

-- Flatten the protocol set into a sorted, comma-joined string for the tooltip
for _, node in ipairs(nodes) do
   local proto_list = {}
   for proto, _ in pairs(node.protocols) do
      proto_list[#proto_list + 1] = proto
   end
   table.sort(proto_list)
   node.protocols = table.concat(proto_list, ", ")
end

if tostring(current_ifid) ~= tostring(ifid) then
   interface.select(current_ifid)
end

rest_utils.answer(rest_utils.consts.success.ok, {
   nodes = nodes,
   edges = edges
})
