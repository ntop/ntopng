--
-- (C) 2013-26 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local rest_utils  = require "rest_utils"
local stats_utils = require "stats_utils"

local ifid           = _GET["ifid"]
local ndpistats_mode = _GET["ndpistats_mode"]
local breed          = _GET["breed"]
local ndpi_category  = _GET["ndpi_category"]
local get_all_values = _GET["all_values"] or "false"
local collapse_stats = _GET["collapse_stats"] or "true"
local show_top       = _GET["show_top"] or "false"
local max_values     = tonumber(_GET["max_values"] or 5)

if isEmptyString(ifid) then
  rest_utils.answer(rest_utils.consts.err.invalid_interface)
  return
end

interface.select(ifid)

local ndpi_protos       = interface.getnDPIProtocols()
local show_breed        = (breed == "true")
local show_ndpi_category = (ndpi_category == "true")

local function getAppUrl(app)
  if ndpi_protos[app] ~= nil then
    return ntop.getHttpPrefix() .. "/lua/flows_stats.lua?application=" .. app
  end
  return nil
end

local stats
local data = {}

if ndpistats_mode == "sinceStartup" then
  stats = interface.getStats()
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

-- ##################################

if ndpistats_mode == "count" then
  local tot = 0

  for k, v in pairs(stats) do
    tot = tot + v
    stats[k] = tonumber(v)
  end

  local threshold = (tot * 3) / 100
  local num = 0

  if get_all_values == "true" then
    max_values = 65535
  end

  for k, v in pairsByValues(stats, rev) do
    if num < max_values and v > threshold then
      data[#data + 1] = {
        label = k,
        value = v,
        url   = getAppUrl(k),
      }
      num = num + 1
      tot = tot - v
    else
      break
    end
  end

  if tot > 0 then
    data[#data + 1] = {
      label = i18n("other"),
      value = tot,
    }
  elseif num == 0 then
    data[#data + 1] = {
      label = i18n("no_flows"),
      value = 0,
    }
  end

  rest_utils.answer(rest_utils.consts.success.ok, data)
  return
end

-- ##################################

local _ifstats = computeL7Stats(stats, show_breed, show_ndpi_category)

for key, value in pairsByValues(_ifstats, rev) do
  data[#data + 1] = {
    label = key,
    value = value,
    url   = getAppUrl(key),
  }
end

if show_top == "true" then
  data = stats_utils.collapse_top_stats(data, max_values)
elseif collapse_stats == "true" then
  data = stats_utils.collapse_stats(data, 1, 3)
end

rest_utils.answer(rest_utils.consts.success.ok, data)