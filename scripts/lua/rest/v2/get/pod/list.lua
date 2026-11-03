--
-- (C) 2013-26 - ntop.org
--
-- Kubernetes pods seen in the flows of the interface, raw values
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

for pod, p in pairs(interface.getPodsStats() or {}) do
   data[#data + 1] = {
      pod = pod,
      num_containers = p["num_containers"],
      flows_as_client = p["num_flows.as_client"],
      flows_as_server = p["num_flows.as_server"],
      -- ms
      rtt_as_client = p["rtt_as_client"],
      rtt_as_server = p["rtt_as_server"],
      rtt_variance_as_client = p["rtt_variance_as_client"],
      rtt_variance_as_server = p["rtt_variance_as_server"],
   }
end

rest_utils.answer(rest_utils.consts.success.ok, data)
