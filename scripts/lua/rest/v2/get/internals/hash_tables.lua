--
-- (C) 2019-26 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local rest_utils = require "rest_utils"

-- ################################################

local ifid = _GET["ifid"]
if isEmptyString(ifid) then ifid = getSystemInterfaceId() end

local filter_ht = _GET["hash_table"]

-- ################################################
-- Build the list of interfaces to collect from.
-- When ifid is the system interface (-1) iterate all interfaces,
-- matching the original get_internals_hash_tables_stats.lua behaviour.

local ifaces = {}
if tostring(ifid) == getSystemInterfaceId() then
   for _, iface in pairs(interface.getIfNames()) do
      ifaces[#ifaces + 1] = { iface = iface, id = tostring(getInterfaceId(iface)) }
   end
else
   ifaces[1] = { iface = getInterfaceName(ifid), id = tostring(ifid) }
end

-- ################################################

local data = {}

for _, entry in ipairs(ifaces) do
   interface.select(entry.iface)
   local ht_stats = interface.getHashTablesStats() or {}

   for ht, stats in pairsByKeys(ht_stats, asc) do
      if not isEmptyString(filter_ht) and ht ~= filter_ht then goto continue end

      local active = stats.hash_entry_states.hash_entry_state_active or 0
      local idle   = stats.hash_entry_states.hash_entry_state_idle   or 0
      local max_sz = stats.max_hash_size or 1

      local active_pct = round(active / max_sz * 100, 2)
      local idle_pct   = round(idle   / max_sz * 100, 2)
      local free_pct   = math.max(0, 100 - active_pct - idle_pct)
      local idle_ratio = idle * 100 / (idle + active + 1)

      data[#data + 1] = {
         iface_name   = getHumanReadableInterfaceName(entry.iface),
         iface_id     = tonumber(entry.id),
         hash_table   = ht,
         active       = active,
         idle         = idle,
         max_size     = max_sz,
         active_pct   = active_pct,
         idle_pct     = idle_pct,
         free_pct     = free_pct,
         high_idle    = (idle_ratio >= 50),
      }
      ::continue::
   end
end

rest_utils.extended_answer(rest_utils.consts.success.ok, data, {
   recordsTotal    = #data,
   recordsFiltered = #data,
})
