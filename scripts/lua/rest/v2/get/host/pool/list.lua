--
-- (C) 2013-26 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path

require "ntop_utils"
require "http_lint"
local rest_utils = require "rest_utils"
local auth = require "auth"
local host_pools = require "host_pools"
local pools = require "pools"

-- ?ifid= selects the interface; interface.select silently falls back to an allowed one: check it
local ifid = _GET["ifid"]
if not isEmptyString(ifid) then
   interface.select(tostring(ifid))
   if tostring(interface.getId()) ~= tostring(ifid) then
      rest_utils.answer(rest_utils.consts.err.invalid_interface)
      return
   end
end

local host_pools_instance = host_pools:create()
local pools_stats = interface.getHostPoolsStats() or {}
local now = os.time()
local data = {}

for pool_id, pool_stats in pairs(pools_stats) do
   -- Only the pools the user is allowed to see
   if auth.is_allowed_host_pool(pool_id) then
      local pool = host_pools_instance:get_pool(pool_id)
      local name = (pool_id == pools.DEFAULT_POOL_ID) and pools.DEFAULT_POOL_NAME or (pool and pool["name"])

      -- Pools deleted while their stats are still in memory have no name: skipped
      if name then
         local sent = pool_stats["bytes.sent"] or 0
         local rcvd = pool_stats["bytes.rcvd"] or 0
         -- "<host>@<vlan>": members for the edit dialog, the address only for the table
         local members = (pool and pool["members"]) or {}
         local members_labels = {}

         for i, member in ipairs(members) do
            members_labels[i] = member:match("^[^@]+") or member
         end

         data[#data + 1] = {
            pool_id = pool_id,
            pool_name = name,
            hosts = pool_stats["num_hosts"] or 0,
            -- Seconds since the first packet
            seen_since = pool_stats["seen.first"] and (now - pool_stats["seen.first"] + 1) or 0,
            bytes_sent = sent,
            bytes_rcvd = rcvd,
            throughput = pool_stats["throughput_bps"] or 0,
            traffic = sent + rcvd,
            members = members,
            members_labels = members_labels,
         }
      end
   end
end

rest_utils.extended_answer(rest_utils.consts.success.ok, data, {
   recordsTotal = #data,
   recordsFiltered = #data,
})
