--
-- (C) 2017 - ntop.org
--
dirs = ntop.getDirs()

package.path = dirs.installdir .. "/scripts/lua/modules/?/init.lua;" .. package.path

local host_pools_utils = {}
host_pools_utils.DEFAULT_POOL_ID = "0"
host_pools_utils.DEFAULT_POOL_NAME = "Default"
host_pools_utils.MAX_NUM_POOLS = 16
host_pools_utils.MAX_MEMBERS_NUM = 32

local function get_pool_members_key(ifid, pool_id)
  return "ntopng.prefs." .. ifid .. ".host_pools.members." .. pool_id
end

local function get_pool_ids_key(ifid)
  return "ntopng.prefs." .. ifid .. ".host_pools.pool_ids"
end

local function get_pool_details_key(ifid, pool_id)
  return "ntopng.prefs." .. ifid .. ".host_pools.details." .. pool_id
end

local function get_pool_detail(ifid, pool_id, detail)
  local details_key = get_pool_details_key(ifid, pool_id)

  return ntop.getHashCache(details_key, detail)
end

local function addressSplitVlan(mixed)
  local parts = split(mixed, "@")
  if #parts == 2 then
    return parts[1], parts[2]
  else
    return mixed, "0"
  end
end

--------------------------------------------------------------------------------

function host_pools_utils.createPool(ifid, pool_id, pool_name)
  local details_key = get_pool_details_key(ifid, pool_id)
  local ids_key = get_pool_ids_key(ifid)

  ntop.setMembersCache(ids_key, pool_id)
  ntop.setHashCache(details_key, "name", pool_name)
end

function host_pools_utils.deletePool(ifid, pool_id)
  local ids_key = get_pool_ids_key(ifid)
  local details_key = get_pool_details_key(ifid, pool_id)
  local members_key = get_pool_members_key(ifid, pool_id)

  ntop.delMembersCache(ids_key, pool_id)
  ntop.delCache(details_key)
  ntop.delCache(members_key)
end

function host_pools_utils.addToPool(ifid, pool_id, member_and_vlan)
  local members_key = get_pool_members_key(ifid, pool_id)

  ntop.setMembersCache(members_key, member_and_vlan)
end

function host_pools_utils.deleteFromPoll(ifid, pool_id, member_and_vlan)
  local members_key = get_pool_members_key(ifid, pool_id)

  ntop.delMembersCache(members_key, member_and_vlan)
end

function host_pools_utils.getPoolsList(ifid)
  local ids_key = get_pool_ids_key(ifid)
  local pools = {}

  for _, pool_id in pairsByValues(ntop.getMembersCache(ids_key) or {}, asc) do
    pools[#pools + 1] = {id=pool_id, name=host_pools_utils.getPoolName(ifid, pool_id)}
  end

  return pools
end

function host_pools_utils.getPoolMembers(ifid, pool_id)
  local members_key = get_pool_members_key(ifid, pool_id)
  local members = {}

  for _,v in pairsByValues(ntop.getMembersCache(members_key) or {}, asc) do
    local address, vlan = addressSplitVlan(v)
    members[#members + 1] = {address=address, vlan=vlan}
  end

  return members
end

function host_pools_utils.getPoolName(ifid, pool_id)
  return get_pool_detail(ifid, pool_id, "name")
end

function host_pools_utils.initPools()
  for _, ifname in pairs(interface.getIfNames()) do
    local ifid = getInterfaceId(ifname)

    -- Note: possible shapers are initialized in shaper_utils::initShapers
    host_pools_utils.createPool(ifid, host_pools_utils.DEFAULT_POOL_ID, host_pools_utils.DEFAULT_POOL_NAME)
  end
end

return host_pools_utils
