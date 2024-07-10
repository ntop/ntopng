--
-- (C) 2013-24 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local format_utils = require "format_utils"
local rest_utils = require "rest_utils"
local json = require("dkjson")
require "lua_utils"

-- Get from redis the throughput type bps or pps
local ts_enabled = areASTimeseriesEnabled(interface.getId())
local throughput_type = getThroughputType()
local now = os.time()

interface.select(ifname)

local asn = tonumber(_GET["asn"])
local as_info;

if (asn ~= nil) then
  as_info = interface.getASInfo(asn)

   if (as_info) then
      as_info = { as_info }
   end
else
   as_info = interface.getASesInfo({detailsLevel = "high"})
   as_info = as_info["ASes"]
end

local res = {}


if as_info ~= nil then
   for key, value in pairs(as_info) do
      local record = {} 

      local bytes_sent = value["bytes.sent"]
      local bytes_rcvd = value["bytes.rcvd"]

      record["asn"] = value["asn"]
      record["avg_host_score"] = math.floor(value["score"] / value["num_hosts"])
      record["bytes_sent"] = bytes_sent
      record["bytes_rcvd"] = bytes_rcvd
      record["alerted_flows"] = value["alerted_flows"]["total"]
      record["traffic"] = bytes_sent + bytes_rcvd
      record["ts_enabled"] = ts_enabled
      record["seen_since"] = value["seen.first"]
      record["score"] = value["score"]
      record["num_hosts"] = value["num_hosts"]
      record["throughput"] = value["throughput_bps"]
      record["asname"] = value["asname"]

      record["breakdown"] = { 
         bytes_sent = bytes_sent, 
         bytes_rcvd = bytes_rcvd 
      }
      
      table.insert(res, record)
   end
end


rest_utils.answer(rest_utils.consts.success.ok, res)
