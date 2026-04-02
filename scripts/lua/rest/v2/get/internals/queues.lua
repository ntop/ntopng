--
-- (C) 2019-26 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local format_utils = require "format_utils"
local rest_utils   = require "rest_utils"

-- ################################################

local ifid = _GET["ifid"]
if isEmptyString(ifid) then ifid = getSystemInterfaceId() end

-- ################################################

local ifaces_queues_stats = {}

for _, iface in pairs(interface.getIfNames()) do
   if ifid ~= tostring(getSystemInterfaceId()) and ifid ~= tostring(getInterfaceId(iface)) then
      goto continue
   end

   interface.select(iface)
   local queues_stats = interface.getQueuesStats()

   for queue, stats in pairs(queues_stats) do
      ifaces_queues_stats[#ifaces_queues_stats + 1] = {
         iface_name          = getHumanReadableInterfaceName(getInterfaceName(getInterfaceId(iface))),
         iface_id            = getInterfaceId(iface),
         queue               = queue,
         num_failed_enqueues = stats.num_failed_enqueues or 0,
      }
   end

   ::continue::
end

-- ################################################

rest_utils.extended_answer(rest_utils.consts.success.ok, ifaces_queues_stats, {
   recordsTotal    = #ifaces_queues_stats,
   recordsFiltered = #ifaces_queues_stats,
})