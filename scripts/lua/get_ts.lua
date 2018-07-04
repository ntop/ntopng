--
-- (C) 2013-18 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

if ntop.isPro() then
  package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
end

require "lua_utils"
local ts_utils = require("ts_utils")
local json = require("dkjson")

local schema_id = _GET["ts_schema"]
local query = _GET["ts_query"]
local tstart = tonumber(_GET["epoch_begin"]) or (os.time() - 3600)
local tend = tonumber(_GET["epoch_end"]) or os.time()

-- convert the query into fields
local tags = tsQueryToTags(_GET["ts_query"])

if tags.ifid then
  interface.select(tags.ifid)
end

sendHTTPHeader('application/json')

-- Load all the schemas
require("ts_second")
require("ts_minute")
require("ts_5min")

local res

if starts(schema_id, "top:") then
  local schema_id = split(schema_id, "top:")[2]

  res = ts_utils.queryTopk(schema_id, tags, tstart, tend)
else
  res = ts_utils.query(schema_id, tags, tstart, tend)
end

if res == nil then
  print("[]")
  return
end

-- TODO make a script parameter?
local extend_labels = true

if extend_labels then
  local tags = res.series and res.series[1] and res.series[1].tags

  if tags then
    if tags.if_index and tags.device then
      -- SNMP port name
      local snmp_device = require "snmp_device"
      snmp_device.init(tags.device)

      for _, serie in pairs(res.series) do
        local interfaces = snmp_device.get_device()["interfaces"]
        local label = shortenString(get_snmp_interface_label(interfaces[serie.tags.if_index]))

        serie.ext_label = label
      end
    end
  end
end

print(json.encode(res))
