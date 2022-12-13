--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require "dkjson"
local rest_utils = require "rest_utils"

--
-- Read all the  L4 protocols
-- Example: curl -u admin:admin -H "Content-Type: application/json" http://localhost:3000/lua/rest/v2/get/l4/protocol/consts.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

local ifid = _GET["ifid"]
local asn = tonumber(_GET["asn"])

if not ifid then
  rest_utils.answer(rest_utils.consts.err.invalid_interface)
  return
end

local function format_asn_data(stats)
  return {
    id = stats["asn"],
    name = stats["name"],
    first_seen = stats["seen.first"],
    last_seen = stats["seen.last"],
    num_hosts = stats["num_hosts"],
    alerted_flows = stats["alerted_flows"]["total"],
    score = stats["score"],
    rtt = stats["round_trip_time"],
    bytes_sent = stats["bytes.sent"],
    bytes_rcvd = stats["bytes.rcvd"],
    packets_sent = stats["packets.sent"],
    packets_rcvd = stats["packets.rcvd"],
  }
end

interface.select(ifid)

local rc = rest_utils.consts.success.ok
local res = {}

if asn then
  local as = interface.getASInfo(asn)

  res[#res + 1] = format_asn_data(as)
else
  local asn_stats = interface.getASesInfo({ detailsLevel = "high" }) or {}
  local num_data = asn_stats.numASes or 0
  
  if num_data and num_data > 0 then
    for _, stats in pairs(asn_stats['ASes']) do
      res[#res + 1] = format_asn_data(stats)
    end
  end
end

rest_utils.answer(rc, res)

