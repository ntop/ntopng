--
-- (C) 2017-22 - ntop.org
--
dirs = ntop.getDirs()

package.path = dirs.installdir .. "/scripts/lua/modules/?/init.lua;" .. package.path

local ntop_info = ntop.getInfo()

local os_utils = require "os_utils"

-- This is an nEdge extension of the host pools
-- E.g. this is storing pool members in ntopng.prefs.host_pools.members.<pool id>
-- which is the same used by host_pools.lua

local host_pools_nedge = {}
host_pools_nedge.DEFAULT_POOL_ID = "0"
host_pools_nedge.DEFAULT_ROUTING_POLICY_ID = "1"
host_pools_nedge.FIRST_AVAILABLE_POOL_ID = "2" -- 0 is the default, 1 is the jail
host_pools_nedge.DEFAULT_POOL_NAME = "Not Assigned"
host_pools_nedge.MAX_NUM_POOLS = 128 -- Note: keep in sync with C

function host_pools_nedge.usernameToPoolId(username)
  local res = ntop.getPref("ntopng.user."..string.lower(username)..".host_pool_id")
  return ternary(not isEmptyString(res), res, nil)
end

function host_pools_nedge.poolIdToUsername(pool_id)
  local ifid = getInterfaceId(ifname) -- in nEdge this always takes one interface
  return host_pools_nedge.getPoolName(pool_id)
end

function host_pools_nedge.getUserUrl(pool_id)
  return ntop.getHttpPrefix() .."/lua/pro/nedge/admin/nf_edit_user.lua?username=" ..
    ternary(tostring(pool_id) == host_pools_nedge.DEFAULT_POOL_ID, "", host_pools_nedge.poolIdToUsername(pool_id))
end

-- LIMITED_NUMBER_POOL_MEMBERS
host_pools_nedge.LIMITED_NUMBER_POOL_MEMBERS = ntop_info["constants.max_num_pool_members"]
-- LIMITED_NUMBER_TOTAL_HOST_POOLS - this takes into account the special pools
host_pools_nedge.LIMITED_NUMBER_TOTAL_HOST_POOLS = ntop_info["constants.max_num_host_pools"]
-- LIMITED_NUMBER_USER_HOST_POOLS - this does not take into account the special pools
host_pools_nedge.LIMITED_NUMBER_USER_HOST_POOLS = host_pools_nedge.LIMITED_NUMBER_TOTAL_HOST_POOLS - 1

-- Note: this is the same key used in scripts/lua/modules/pools/host_pools.lua
local function get_pool_members_key(pool_id)
  return "ntopng.prefs.host_pools.members." .. pool_id
end

local function get_pool_ids_key()
  return "ntopng.prefs.host_pools.pool_ids"
end

local function get_pool_details_key(pool_id)
  return "ntopng.prefs.host_pools.details." .. pool_id
end

local function get_pools_serialized_key(ifid)
  return "ntopng.serialized_host_pools.ifid_" .. ifid
end

function host_pools_nedge.getPoolDetail(pool_id, detail)
  local details_key = get_pool_details_key(pool_id)

  return ntop.getHashCache(details_key, detail)
end

function host_pools_nedge.setPoolDetail(pool_id, detail, value)
  local details_key = get_pool_details_key(pool_id)

  return ntop.setHashCache(details_key, detail, tostring(value))
end

local function traceHostPoolEvent(severity, event)
    if ntop.getPref("ntopng.prefs.enable_host_pools_log") ~= "1" then
       return
    end

    local f_name = debug.getinfo(2, "n").name
    if f_name ~= nil then
       f_name = string.format("[%s] ", f_name)
    end

    traceError(severity, TRACE_CONSOLE, string.format("%s%s", f_name or '', event))
end

local function addMemberToRedisPool(pool_id, member_key)
  if pool_id == host_pools_nedge.DEFAULT_POOL_ID then
    -- avoid adding default pool members explicitly
    traceHostPoolEvent(TRACE_NORMAL,
		       string.format("Setting DEFAULT_POOL_ID (aka 'Not Assigned'). [pool_id: %d][member: %s]",
				     host_pools_nedge.DEFAULT_POOL_ID, member_key))
    return true
  end

  local members_key = get_pool_members_key(pool_id)
  local n = table.len(ntop.getMembersCache(members_key) or {})

  if n >= host_pools_nedge.LIMITED_NUMBER_POOL_MEMBERS then
    traceHostPoolEvent(TRACE_ERROR, string.format("Unable to set host pool, maximum number of pool members hit. [max num pool members: %d][member: %s] [members_key: %s]", host_pools_nedge.LIMITED_NUMBER_POOL_MEMBERS, member_key, members_key))
    return false
  end

  ntop.setMembersCache(members_key, member_key)

  traceHostPoolEvent(TRACE_NORMAL, string.format("Member added to pool. [member: %s] [members_key: %s]", member_key, members_key))

  return true
end

--------------------------------------------------------------------------------

function host_pools_nedge.getPoolMembersRaw(pool_id)
  local members_key = get_pool_members_key(pool_id)
  return ntop.getMembersCache(members_key) or {}
end

-- Export host pools
function host_pools_nedge.export()
  local pools = {}

  for _,pool in pairs(host_pools_nedge.getPoolsList()) do
    pool.members = host_pools_nedge.getPoolMembersRaw(pool.id)
    pools[pool.id] = pool
  end

  return pools
end

--------------------------------------------------------------------------------

function host_pools_nedge.createPool(pool_id, pool_name, children_safe,
				     enforce_quotas_per_pool_member, enforce_shapers_per_pool_member, ignore_exist)
  local details_key = get_pool_details_key(pool_id)
  local ids_key = get_pool_ids_key()
  local members = ntop.getMembersCache(ids_key) or {}

  local n = table.len(members)

  if n >= host_pools_nedge.LIMITED_NUMBER_TOTAL_HOST_POOLS then
    return false
  end

  if not ignore_exist then
    for _, m in pairs(members) do
      if m == pool_id then
        return true
      end
    end
  end

  -- Add pool to the set of pools
  ntop.setMembersCache(ids_key, pool_id)

  -- Add pool details
  ntop.setHashCache(details_key, "name", pool_name)
  ntop.setHashCache(details_key, "children_safe", tostring(children_safe or false))
  ntop.setHashCache(details_key, "enforce_quotas_per_pool_member",  tostring(enforce_quotas_per_pool_member  or false))
  ntop.setHashCache(details_key, "enforce_shapers_per_pool_member", tostring(enforce_shapers_per_pool_member or false))
  ntop.setHashCache(details_key, "forge_global_dns", "true")
  return true
end

function host_pools_nedge.deletePool(pool_id)
  local ts_utils = require "ts_utils"
  local ids_key = get_pool_ids_key()
  local details_key = get_pool_details_key(pool_id)
  local members_key = get_pool_members_key(pool_id)

  host_pools_nedge.emptyPool(pool_id)

  -- Remove pool from set of pools
  ntop.delMembersCache(ids_key, pool_id)

  -- Delete pool details
  ntop.delCache(details_key)
  ntop.delCache(members_key)

  -- Delete serialized values and timeseries across all interfaces
  for ifid, ifname in pairs(interface.getIfNames()) do
     local serialized_key = get_pools_serialized_key(ifid)
     ntop.delHashCache(serialized_key, pool_id)
     ts_utils.delete("host_pool", {ifid = tonumber(ifid), pool = pool_id})
  end
end

function getMembershipInfo(member_and_vlan)
  -- Check if the member is already in another pool
  local hostinfo = hostkey2hostinfo(member_and_vlan)
  local addr, mask = splitNetworkPrefix(hostinfo["host"])
  local vlan = hostinfo["vlan"]
  local is_mac = isMacAddress(addr)

  if not is_mac then
    addr = ntop.networkPrefix(addr, mask)
  end

  local find_info = interface.findMemberPool(addr, vlan, is_mac)

  -- This is the normalized key, which should always be used to refer to the member
  local key
  if not is_mac then
    key = host2member(addr, vlan, mask)
  else
    key = addr
  end

  local info = {key=key}
  local exists = false

  if find_info ~= nil then
    -- The host has been found
    if is_mac or ((not is_mac)
                  and (find_info.matched_prefix == addr)
                  and (find_info.matched_bitmask == mask)) then
      info["existing_member_pool"] = find_info.pool_id
      exists = true
    end
  end

  return exists, info
end

function host_pools_nedge.addPoolMember(pool_id, member_and_vlan)
  traceHostPoolEvent(TRACE_NORMAL,
		     string.format("Pool member addition requested. [member: %s][pool_id: %s]",
				   member_and_vlan, pool_id))

  local member_exists, info = getMembershipInfo(member_and_vlan)

  if member_exists then
     traceHostPoolEvent(TRACE_NORMAL, string.format("Member already in pool. [pool_id: %d] [member: %s]", pool_id, member_and_vlan))
    return false, info
  end

  local rv = addMemberToRedisPool(pool_id, info.key)
  return rv, info
end

function host_pools_nedge.deletePoolMember(pool_id, member_and_vlan)
  traceHostPoolEvent(TRACE_NORMAL,
		     string.format("Pool member deletion requested. [member: %s][pool_id: %s]",
				   member_and_vlan, pool_id))

  local members_key = get_pool_members_key(pool_id)

  -- Possible delete non-volatile member
  ntop.delMembersCache(members_key, member_and_vlan)
end

function host_pools_nedge.initPools()
  host_pools_nedge.createPool(host_pools_nedge.DEFAULT_POOL_ID, host_pools_nedge.DEFAULT_POOL_NAME)
end

function host_pools_nedge.getPoolsList(without_info)
  local ids_key = get_pool_ids_key()
  local ids = ntop.getMembersCache(ids_key)

  if not ids then ids = {} end
  for i, id in pairs(ids) do
     ids[i] = tonumber(id)
  end

  local pools = {}

  host_pools_nedge.initPools()

  for _, pool_id in pairsByValues(ids, asc) do
    pool_id = tostring(pool_id)
    local pool

    if without_info then
      pool = {id=pool_id}
    else
      pool = {
        id = pool_id,
        name = host_pools_nedge.getPoolName(pool_id),
        children_safe = host_pools_nedge.getChildrenSafe(pool_id),
	enforce_quotas_per_pool_member  = host_pools_nedge.getEnforceQuotasPerPoolMember(pool_id),
	enforce_shapers_per_pool_member = host_pools_nedge.getEnforceShapersPerPoolMember(pool_id),
      }
    end

    pools[#pools + 1] = pool
  end

  return pools
end

-- Delete a member (IP or Mac) from all pools if any
function host_pools_nedge.deletePoolMemberFromAllPools(member)
  for _, pool in pairs(host_pools_nedge.getPoolsList()) do
    host_pools_nedge.deletePoolMember(pool.id, member)
  end
end

function host_pools_nedge.getPoolMembers(pool_id)
  local members_key = get_pool_members_key(pool_id)
  local members = {}

  local all_members = ntop.getMembersCache(members_key) or {}

  for _,v in pairsByValues(all_members, asc) do
    local hostinfo = hostkey2hostinfo(v)

    members[#members + 1] = {address=hostinfo["host"], vlan=hostinfo["vlan"], key=v}
  end

  return members
end

function host_pools_nedge.getMemberKey(member)
  -- handle vlan
  local is_network
  local host_key
  local address = hostkey2hostinfo(member)["host"]

  if isMacAddress(address) then
    host_key = address
    is_network = false
  else
    local network, prefix = splitNetworkPrefix(address)

    if(((isIPv4(network)) and (prefix ~= 32)) or
      ((isIPv6(network)) and (prefix ~= 128))) then
      -- this is a network
      host_key = address
      is_network = true
    else
      -- this is an host
      host_key = network
      is_network = false
    end
  end

  return host_key, is_network
end

function host_pools_nedge.getPoolName(pool_id)
  return host_pools_nedge.getPoolDetail(pool_id, "name")
end

function host_pools_nedge.getChildrenSafe(pool_id)
  return toboolean(host_pools_nedge.getPoolDetail(pool_id, "children_safe"))
end

function host_pools_nedge.setChildrenSafe(pool_id, value)
  host_pools_nedge.setPoolDetail(pool_id, "children_safe", ternary(value, "true", "false"))
end

function host_pools_nedge.routingPolicyNameToId(policy_name)
  package.path = dirs.installdir .. "/pro/scripts/lua/nedge/modules/system_config/?.lua;" .. package.path
  local nf_config = require("nf_config"):create()
  local routing_policies = nf_config:getRoutingPolicies()

  -- Return default policy on failure
  local policy_id = host_pools_nedge.DEFAULT_ROUTING_POLICY_ID

  local routing_policy = routing_policies[policy_name]
  if routing_policy then
    policy_id = routing_policy.id
  end

  return policy_id
end

function host_pools_nedge.getRoutingPolicyId(pool_id)
  local routing_policy_id = host_pools_nedge.getPoolDetail(pool_id, "routing_policy_id")
  if isEmptyString(routing_policy_id) then routing_policy_id = host_pools_nedge.DEFAULT_ROUTING_POLICY_ID end
  return routing_policy_id
end

function host_pools_nedge.setRoutingPolicyId(pool_id, routing_policy_id)
  return host_pools_nedge.setPoolDetail(pool_id, "routing_policy_id", routing_policy_id)
end

function host_pools_nedge.getEnforceQuotasPerPoolMember(pool_id)
  return toboolean(host_pools_nedge.getPoolDetail(pool_id, "enforce_quotas_per_pool_member"))
end

function host_pools_nedge.getEnforceShapersPerPoolMember(pool_id)
  return toboolean(host_pools_nedge.getPoolDetail(pool_id, "enforce_shapers_per_pool_member"))
end

function host_pools_nedge.emptyPool(pool_id)
  local members_key = get_pool_members_key(pool_id)

  -- Remove non-volatile members
  ntop.delCache(members_key)
end

function host_pools_nedge.emptyPools()
  for _, ifname in pairs(interface.getIfNames()) do
    local ifid = getInterfaceId(ifname)
    local ifstats = interface.getStats()

    local pools_list = host_pools_nedge.getPoolsList()
    for _, pool in pairs(pools_list) do
       host_pools_nedge.emptyPool(pool["id"])
    end
  end
end

function host_pools_nedge.getUndeletablePools()
  local pools = {}

  for user_key,_ in pairs(ntop.getKeysCache("ntopng.user.*.host_pool_id") or {}) do
    local pool_id = ntop.getCache(user_key)

    if tonumber(pool_id) ~= nil then
      local username = string.split(user_key, "%.")[3]
      local allowed_ifname = ntop.getCache("ntopng.user."..username..".allowed_ifname")

      -- verify if the Captive Portal User is actually active for the interface
      if getInterfaceName(ifid) == allowed_ifname then
        pools[pool_id] = true
      end
    end
  end

  return pools
end

function host_pools_nedge.printQuotas(pool_id, host, page_params)
  --[[
  local pools_stats = interface.getHostPoolsStats()
  local pool_stats = pools_stats and pools_stats[tonumber(pool_id)]

  local ndpi_stats = pool_stats.ndpi
  local category_stats = pool_stats.ndpi_categories
  --]]

  -- ifId is a global variable here
  local quota_and_protos = shaper_utils.getPoolProtoShapers(ifId, pool_id)
  local cross_traffic_quota, cross_time_quota = shaper_utils.getCrossApplicationQuotas(ifId, pool_id)

  -- Empty check
  local empty = (cross_traffic_quota == shaper_utils.NO_QUOTA) and (cross_time_quota == shaper_utils.NO_QUOTA)

  if empty then
    for _, proto in pairs(quota_and_protos) do
      if ((tonumber(proto.traffic_quota) > 0) or (tonumber(proto.time_quota) > 0)) then
        -- at least a quota is set
        empty = false
        break
      end
    end
  end

  if empty then
    local url = "/lua/pro/nedge/admin/nf_edit_user.lua?page=protocols&username=" .. host_pools_nedge.poolIdToUsername(pool_id)

    print("<div class=\"alert alert alert-danger\"><i class='fas fa-exclamation-triangle fa-lg fa-ntopng-warning'></i> "..i18n("shaping.no_quota_data")..
      ". " .. i18n("host_pools.create_new_quotas_here", {url=ntop.getHttpPrefix()..url}) .. "</div>")
  else
    print[[
    <table class="table table-bordered table-striped">
    <thead>
      <tr>
        <th>]] print(i18n("application")) print[[</th>
        <th class="text-center">]] print(i18n("shaping.daily_traffic")) print[[</th>
        <th class="text-center">]] print(i18n("shaping.daily_time")) print[[</th>
      </tr>
    </thead>
    <tbody id="pool_quotas_ndpi_tbody">
    </tbody>
    </table>

    <script>
      function update_ndpi_table() {
        $.ajax({
          type: 'GET',
          url: ']]
    print(getPageUrl(ntop.getHttpPrefix().."/lua/pro/pool_details_ndpi.lua").."', data: ")
    print(tableToJsObject(page_params))
    print[[,
          success: function(content) {
            if(content)
              $('#pool_quotas_ndpi_tbody').html(content);
            else
              $('#pool_quotas_ndpi_tbody').html('<tr><td colspan="3"><i>]] print(i18n("shaping.no_quota_traffic")) print[[</i></td></tr>');
          }
        });
      }

      setInterval(update_ndpi_table, 5000);
      update_ndpi_table();
     </script>]]
  end

end

function host_pools_nedge.getFirstAvailablePoolId()
  local ids_key = get_pool_ids_key()
  local ids = ntop.getMembersCache(ids_key) or {}

  for i, id in pairs(ids) do
    ids[i] = tonumber(id)
  end

  local host_pool_id = tonumber(host_pools_nedge.FIRST_AVAILABLE_POOL_ID)

  for _, pool_id in pairsByValues(ids, asc) do
    if pool_id > host_pool_id then
      break
    end

    host_pool_id = math.max(pool_id + 1, host_pool_id)
  end

  return tostring(host_pool_id)
end

function host_pools_nedge.resetPoolsQuotas(pool_filter)
  local serialized_key = get_pools_serialized_key(tostring(interface.getFirstInterfaceId()))
  local keys_to_del

  if pool_filter ~= nil then
    keys_to_del = {[pool_filter]=1, }
  else
    keys_to_del = ntop.getHashKeysCache(serialized_key) or {}
  end

  -- Delete the redis serialization
  for key in pairs(keys_to_del) do
    ntop.delHashCache(serialized_key, tostring(key))
  end

  -- Delete the in-memory stats
  interface.resetPoolsQuotas(pool_filter)
end

-- @brief Performs a daily check and possibly resets host quotas.
--        NOTE: This function must be called one time per day.
function host_pools_nedge.dailyCheckResetPoolsQuotas()
  package.path = dirs.installdir .. "/pro/scripts/lua/nedge/modules/system_config/?.lua;" .. package.path
  local nf_config = require("nf_config"):create()
  local shapers_config = nf_config:getShapersConfig()
  local quotas_control = shapers_config.quotas_control
  local do_reset = true

  if quotas_control.reset == "monthly" then
     local day_of_month = os.date("*t").day

     if day_of_month ~= 1 --[[ First day of the month --]] then
	do_reset = false
     end
  elseif quotas_control.reset == "weekly" then
     local day_of_week = os.date("*t").wday

     if day_of_week ~= 2 --[[ Monday --]] then
	do_reset = false
     end
  end

  if do_reset then
     host_pools_nedge.resetPoolsQuotas()
  end
end

host_pools_nedge.traceHostPoolEvent = traceHostPoolEvent

return host_pools_nedge
