--
-- (C) 2019-26 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local rest_utils = require "rest_utils"
local checks = require "checks"

-- ################################################

local ifid = _GET["ifid"]
if isEmptyString(ifid) then ifid = getSystemInterfaceId() end

interface.select(tostring(ifid))

-- ################################################

local filter_target = _GET["check_target"]

local flow_checks_stats = ntop.getFlowChecksStats() or {}
local data = {}

for _, info in ipairs(checks.listSubdirs()) do
   if not isEmptyString(filter_target) and info["label"] ~= filter_target then goto continue end

   local ok, scripts = pcall(function()
      return checks.load(ifid, checks.getScriptType(info["id"]), info["id"], { return_all = true })
   end)
   if not ok or not scripts then goto continue end

   for name, script in pairsByKeys(scripts.modules, asc) do
      if name == "my_custom_script" then goto next_script end

      -- Edition / availability
      local availability
      if     script.edition == "enterprise_m" then availability = "Enterprise M"
      elseif script.edition == "enterprise_l" then availability = "Enterprise L"
      elseif script.edition == "pro"          then availability = "Pro"
      else                                         availability = "Community"
      end

      -- Hooks (comma-joined, one row per script)
      local hooks = {}
      for hook in pairsByKeys(script.hooks or {}) do
         hooks[#hooks + 1] = hook
      end

      -- Filters
      local filters = {}
      if script.l4_proto              then filters[#filters + 1] = "l4_proto=" .. script.l4_proto end
      if script.l7_proto              then filters[#filters + 1] = "l7_proto=" .. script.l7_proto end
      if script.packet_interface_only then filters[#filters + 1] = "packet_interface" end
      if script.three_way_handshake_ok then filters[#filters + 1] = "3wh_completed" end
      if script.local_only            then filters[#filters + 1] = "local_only" end
      if script.nedge_only            then filters[#filters + 1] = "nedge=true" end
      if script.nedge_exclude         then filters[#filters + 1] = "nedge=false" end

      -- Execution time (flow checks only)
      local exec_time_ms
      if info["id"] == "flow"
         and flow_checks_stats[name]
         and flow_checks_stats[name].stats
         and flow_checks_stats[name].stats.execution_time then
         exec_time_ms = flow_checks_stats[name].stats.execution_time / 1000000
      end

      data[#data + 1] = {
         name         = name,
         type         = info["label"],
         availability = availability,
         hooks        = table.concat(hooks,   ", "),
         filters      = table.concat(filters, ", "),
         num_filtered = script.num_filtered or 0,
         exec_time_ms = exec_time_ms,
      }

      ::next_script::
   end

   ::continue::
end

rest_utils.extended_answer(rest_utils.consts.success.ok, data, {
   recordsTotal    = #data,
   recordsFiltered = #data,
})
