--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local rest_utils = require("rest_utils")
local stats_utils = require("stats_utils")

--
-- Read statistics about nDPI application protocols on an interface
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{"ifid": "1", "ndpistats_mode": "count"}' http://localhost:3000/lua/rest/v2/get/interface/l7/stats.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

local rc = rest_utils.consts.success.ok
local res = {}

local ifid = _GET["ifid"]
local ndpistats_mode = _GET["ndpistats_mode"]
local breed = _GET["breed"]
local ndpi_category = _GET["ndpi_category"]
local get_all_values = (_GET["all_values"] or "false")
local collapse_stats = (_GET["collapse_stats"] or "true")
local max_values = tonumber(_GET["max_values"] or 5)

if isEmptyString(ifid) then
   rc = rest_utils.consts.err.invalid_interface
   rest_utils.answer(rc)
   return
end

local show_breed = false
if breed == "true" then
   show_breed = true
end

local show_ndpi_category = false
if ndpi_category == "true" then
   show_ndpi_category = true
end

interface.select(ifid)

local ndpi_protos = interface.getnDPIProtocols()

local function getAppUrl(app)
   if ndpi_protos[app] ~= nil then
      return ntop.getHttpPrefix().."/lua/flows_stats.lua?application="..app
   end
   return nil
end

local stats
local tot = 0

if ndpistats_mode == "sinceStartup" then
   stats = interface.getStats()
   tot = stats.stats.bytes
elseif ndpistats_mode == "count" then
   stats = interface.getnDPIFlowsCount()
else
   rest_utils.answer(rest_utils.consts.err.invalid_args)
   return
end

if stats == nil then
   rest_utils.answer(rest_utils.consts.err.internal_error)
   return
end

if(ndpistats_mode == "count") then
  tot = 0

  for k, v in pairs(stats) do
    tot = tot + v
    stats[k] = tonumber(v)
  end

  local threshold = (tot * 3) / 100
  local num = 0

  if(get_all_values == "true") then
    max_values = 65535 -- ndpi protocols are u_int16_t, so the max numeric value is 65535
  end

  for k, v in pairsByValues(stats, rev) do
    if((num < max_values) and (v > threshold)) then
      res[#res + 1] = {
        label = k,
        value = v,
        url = getAppUrl(k),
      }
      num = num + 1
      tot = tot - v
    else
      break
    end
  end

  if(tot > 0) then
    res[#res + 1] = {
        label = i18n("other"),
        value = tot,
    }
  elseif(num == 0) then
    res[#res + 1] = {
        label = i18n("no_flows"),
        value = 0,
    }
  end

  rest_utils.answer(rc, res)
  return
end

local _ifstats = computeL7Stats(stats, show_breed, show_ndpi_category)

for key, value in pairsByValues(_ifstats, rev) do

   res[#res + 1] = {
      label = key,
      value = value,
      url = getAppUrl(key),
   }
end

if collapse_stats == "true" then
  res = stats_utils.collapse_stats(res, 1, 3 --[[ threshold ]])
end

rest_utils.answer(rc, res)
