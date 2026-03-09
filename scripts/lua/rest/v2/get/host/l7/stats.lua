--
-- (C) 2013-26 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local rest_utils  = require "rest_utils"
local stats_utils = require "stats_utils"

local ifid           = _GET["ifid"]
local host_info      = url2hostinfo(_GET)
local breed          = _GET["breed"]
local ndpi_category  = _GET["ndpi_category"]
local collapse_stats = _GET["collapse_stats"] or "true"

if isEmptyString(ifid) then
  rest_utils.answer(rest_utils.consts.err.invalid_interface)
  return
end

interface.select(ifid)

local stats = interface.getHostInfo(host_info["host"], host_info["vlan"])

if stats == nil then
  rest_utils.answer(rest_utils.consts.err.not_found)
  return
end

local ndpi_protos      = interface.getnDPIProtocols()
local show_breed       = (breed == "true")
local show_ndpi_category = (ndpi_category == "true")

local function getAppUrl(app)
  if ndpi_protos[app] ~= nil then
    return ntop.getHttpPrefix() .. "/lua/flows_stats.lua?application=" .. app
  end
  return nil
end

local _ifstats = computeL7Stats(stats, show_breed, show_ndpi_category)
local data = {}

for key, value in pairsByValues(_ifstats, rev) do
  local duration = 0
  if stats["ndpi"][key] ~= nil then
    duration = stats["ndpi"][key]["duration"]
  end

  data[#data + 1] = {
    label    = key,
    value    = value,
    duration = duration,
    url      = getAppUrl(key),
  }
end

if collapse_stats == "true" then
  data = stats_utils.collapse_stats(data, 1, 3)
end

rest_utils.answer(rest_utils.consts.success.ok, data)