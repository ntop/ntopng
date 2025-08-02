--
-- (C) 2013-24 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path

require "lua_utils"
local host_pools = require "host_pools"
local rest_utils = require "rest_utils"

-- to extract pool members, given pool id
local pools = require "pools"

-- Instantiate host pools
local host_pools_instance = host_pools:create()

local ifid = interface.getId()
local pools_stats = interface.getHostPoolsStats()

local result = {}

-- Create the pool instance
local s = pools:create()

for pool_id, pool_stats in pairs(pools_stats) do
  -- Try to convert pool to record (contains pool name and host info)
  local record = host_pools_instance:hostpool2record(ifid, pool_id, pool_stats)

  -- geet pool details to show in gui
  local pool_name = host_pools_instance:get_pool_name(pool_id)
  local hosts = record["hosts"] or pool_stats["num_hosts"] or 0
  local seen_since = pool_stats["seen.last"] or 0
  local bytes_rcvd = pool_stats["bytes.rcvd"] or 0
  local bytes_sent = pool_stats["bytes.sent"] or 0
  local throughput = pool_stats["throughput_bps"] or 0
  local traffic = bytes_sent + bytes_rcvd

  local cur_pool = host_pools_instance:get_pool(pool_id)

  -- extract members from cur_pool.members table
  -- clean_members is used to show in the ui
  -- members is used for the pool edit value
  local clean_members = {}
  local members = {}

  if cur_pool and cur_pool.members then
    for i, member in pairs(cur_pool.members) do
      -- remove '@' and everything after it (used for ntopng key)
      local clean_member = member:match("^[^@]+")
      table.insert(clean_members, clean_member)
      table.insert(members, member)
    end
  end
  table.insert(result, {
    ["pool_name"] = pool_name,
    ["pool_id"] = pool_id,
    ["hosts"] = hosts,
    ["seen_since"] = seen_since,
    ["breakdown"] = {
      ["bytes_rcvd"] = bytes_rcvd,
      ["bytes_sent"] = bytes_sent
    },
    ["throughput"] = throughput,
    ["traffic"] = traffic,
    ["clean_members"] = clean_members,
    ["members"] = members
  })
end

rest_utils.answer(rest_utils.consts.success.ok, result)
