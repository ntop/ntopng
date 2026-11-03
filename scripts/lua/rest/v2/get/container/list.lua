--
-- (C) 2013-26 - ntop.org
--
-- Containers seen in the flows of the interface (?pod= only the containers of that pod), raw values
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "ntop_utils"
require "http_lint"
local rest_utils = require "rest_utils"

-- ?ifid= selects the interface; interface.select silently falls back to an allowed one: check it
local ifid = _GET["ifid"]
if not isEmptyString(ifid) then
   interface.select(tostring(ifid))
   if tostring(interface.getId()) ~= tostring(ifid) then
      rest_utils.answer(rest_utils.consts.err.invalid_interface)
      return
   end
end

local data = {}

for id, c in pairs(interface.getContainersStats(_GET["pod"]) or {}) do
   local info = c.info or {}

   data[#data + 1] = {
      id = id,
      -- As format_utils.formatContainer
      name = info["k8s.name"] or info["docker.name"] or info["id"] or id,
      pod = info["k8s.pod"],
      flows_as_client = c["num_flows.as_client"],
      flows_as_server = c["num_flows.as_server"],
      -- ms
      rtt_as_client = c["rtt_as_client"],
      rtt_as_server = c["rtt_as_server"],
      rtt_variance_as_client = c["rtt_variance_as_client"],
      rtt_variance_as_server = c["rtt_variance_as_server"],
   }
end

rest_utils.answer(rest_utils.consts.success.ok, data)
