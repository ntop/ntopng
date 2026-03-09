--
-- (C) 2013-26 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local rest_utils  = require "rest_utils"
local stats_utils = require "stats_utils"

local ifid           = _GET["ifid"]
local collapse_stats = toboolean(_GET["collapse_stats"])

if isEmptyString(ifid) then
  rest_utils.answer(rest_utils.consts.err.invalid_interface)
  return
end

interface.select(ifid)

local stats = interface.getActiveFlowsStats()

if not stats or not stats.qoe then
  rest_utils.answer(rest_utils.consts.err.internal_error)
  return
end

local data = {}

for key, value in pairsByField(stats.qoe, "num", rev) do
  data[#data + 1] = {
    label = i18n("flow_details.qoe_" .. key .. "_label") or "",
    value = value.num
  }
end

if collapse_stats then
  data = stats_utils.collapse_stats(data, 1, 3)
end

rest_utils.answer(rest_utils.consts.success.ok, data)