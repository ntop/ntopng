--
-- (C) 2013-26 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

-- Parses the JSON POST payload and validates/sanitizes _GET/_POST (normally
-- loaded by lua_utils): must be required before reading the parameters
require "http_lint"
require "ntop_utils" -- isEmptyString(), pairsByField(), rev()
require "lua_utils_generic" -- toboolean()
require "locales_utils" -- i18n()
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
  if value.num > 0 then
    data[#data + 1] = {
      label = i18n("flow_details.qoe_" .. key .. "_label") or "",
      value = value.num
    }
  end
end

if collapse_stats then
  data = stats_utils.collapse_stats(data, 1, 3)
end

rest_utils.answer(rest_utils.consts.success.ok, data)