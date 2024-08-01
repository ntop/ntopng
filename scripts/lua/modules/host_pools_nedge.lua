--
-- (C) 2017-24 - ntop.org
--
dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/?/init.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path

local ntop_info = ntop.getInfo()

local os_utils = require "os_utils"
local host_pools = require "host_pools"

-- This is an nEdge extension of the host pools
-- E.g. this is storing pool members in ntopng.prefs.host_pools.members.<pool id>
-- which is the same used by host_pools.lua

local host_pools_nedge = {}

-- Keep in sync with pools.lua
host_pools_nedge.DEFAULT_POOL_ID = 0
host_pools_nedge.DEFAULT_POOL_NAME = "Not Assigned"

host_pools_nedge.DEFAULT_ROUTING_POLICY_ID = "1"

function host_pools_nedge.usernameToPoolId(username)
  -- Check in user info in redis
  local res = ntop.getPref("ntopng.user."..string.lower(username)..".host_pool_id")

  -- If not found due to some (should veder happen), do a lookup
  if isEmptyString(res) then
    local s = host_pools:create()
    local list = s:get_all_pools()
    for _, pool_info in pairs(list) do
      if pool_info.name == username then
        res = pool_info.pool_id
      end
    end
  end

  if isEmptyString(res) then
    return nil
  end

  return tonumber(res)
end

function host_pools_nedge.poolIdToUsername(pool_id)
  return host_pools_nedge.getPoolName(pool_id)
end

-- Compare pool_id with DEFAULT_POOL_ID and handle int or string type
local function is_default_pool_id(pool_id)
  return tonumber(pool_id) == host_pools.DEFAULT_POOL_ID
end

function host_pools_nedge.getUserUrl(pool_id)
  return ntop.getHttpPrefix() .."/lua/pro/nedge/admin/nf_edit_user.lua?username=" ..
    ternary(is_default_pool_id(pool_id), "", host_pools_nedge.poolIdToUsername(pool_id))
end

-- LIMITED_NUMBER_TOTAL_HOST_POOLS - this takes into account the special pools
host_pools_nedge.LIMITED_NUMBER_TOTAL_HOST_POOLS = ntop_info["constants.max_num_host_pools"]
-- LIMITED_NUMBER_USER_HOST_POOLS - this does not take into account the special pools
host_pools_nedge.LIMITED_NUMBER_USER_HOST_POOLS = host_pools_nedge.LIMITED_NUMBER_TOTAL_HOST_POOLS - 1

local function get_pool_details_key(pool_id)
  if pool_id == nil then
    tprint(debug.traceback()) 
  end  
  return string.format("ntopng.prefs.host_pools.details.%d", tonumber(pool_id))
end

local function get_pools_serialized_key(ifid)
  return "ntopng.serialized_host_pools.ifid_" .. ifid
end

function host_pools_nedge.getPoolDetail(pool_id, detail)
  local details_key = get_pool_details_key(pool_id)
  value = ntop.getHashCache(details_key, detail)
  return value
end

function host_pools_nedge.setPoolDetail(pool_id, detail, value)
  local details_key = get_pool_details_key(pool_id)

  return ntop.setHashCache(details_key, detail, tostring(value))
end

local function traceHostPoolEvent(severity, event)
    local force_debug = false

    if not force_debug and ntop.getPref("ntopng.prefs.enable_host_pools_log") ~= "1" then
       return
    end

    local f_name = debug.getinfo(2, "n").name
    if f_name ~= nil then
       f_name = string.format("[%s] ", f_name)
    end

    traceError(severity, TRACE_CONSOLE, string.format("%s%s", f_name or '', event))
end

--------------------------------------------------------------------------------

function host_pools_nedge.createPool(pool_name, children_safe, enforce_quotas_per_pool_member, enforce_shapers_per_pool_member)

  -- Add pool to the set of pools
  local s = host_pools:create()
  local pool_id = s:add_pool(pool_name, {})

  -- Add pool details
  local details_key = get_pool_details_key(pool_id)
  -- ntop.setHashCache(details_key, "name", pool_name)
  ntop.setHashCache(details_key, "children_safe", tostring(children_safe or false))
  ntop.setHashCache(details_key, "enforce_quotas_per_pool_member",  tostring(enforce_quotas_per_pool_member  or false))
  ntop.setHashCache(details_key, "enforce_shapers_per_pool_member", tostring(enforce_shapers_per_pool_member or false))
  ntop.setHashCache(details_key, "forge_global_dns", "true")

  return pool_id
end

function host_pools_nedge.deletePool(pool_id)
  local details_key = get_pool_details_key(pool_id)

  -- Remove pool
  local s = host_pools:create()
  local list = s:delete_pool(tonumber(pool_id))

  -- Delete nEdge pool details
  ntop.delCache(details_key)

  -- Delete serialized values and timeseries across all interfaces
  local ts_utils = require "ts_utils"
  for ifid, ifname in pairs(interface.getIfNames()) do
     local serialized_key = get_pools_serialized_key(ifid)
     ntop.delHashCache(serialized_key, tostring(pool_id))
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

  

  traceHostPoolEvent(TRACE_NORMAL, string.format("Member added to pool. [member: %s] [members_key: %s]", member_key, members_key))

  local member_exists, info = getMembershipInfo(member_and_vlan)

  if member_exists then
     traceHostPoolEvent(TRACE_NORMAL, string.format("Member already in pool. [pool_id: %d] [member: %s]", pool_id, member_and_vlan))
    return false, info
  end

  local s = host_pools:create()
  local rv, err = s:bind_member(info.key, tonumber(pool_id))

  return rv, info
end

-- Do we really need this?
function host_pools_nedge.initPools()
  -- Note pool id is no longer a host_pools_nedge.createPool paramter
  -- host_pools_nedge.createPool(host_pools.DEFAULT_POOL_ID, host_pools_nedge.DEFAULT_POOL_NAME)
end

function host_pools_nedge.getPoolsList(without_info)
  local pools = {}

  local s = host_pools:create()
  local list = s:get_all_pools()

  for _, pool_info in pairs(list) do
    local pool

    if without_info then
      pool = {
        id=pool_info.pool_id
      }
    else
      -- Augment pool information with nEdge details
      pool = {
        id = pool_info.pool_id,
        name = host_pools_nedge.getPoolName(pool_info.pool_id),
        children_safe = host_pools_nedge.getChildrenSafe(pool_info.pool_id),
	enforce_quotas_per_pool_member  = host_pools_nedge.getEnforceQuotasPerPoolMember(pool_info.pool_id),
	enforce_shapers_per_pool_member = host_pools_nedge.getEnforceShapersPerPoolMember(pool_info.pool_id),
      }
    end

    pools[#pools + 1] = pool
  end

  return pools
end

-- Delete a member (IP or Mac) from all pools if any
function host_pools_nedge.deletePoolMember(member)
  traceHostPoolEvent(TRACE_NORMAL,
    string.format("Pool member deletion requested. [member: %s]",
      member_and_vlan))

  local s = host_pools:create()
  s:bind_member(member, host_pools.DEFAULT_POOL_ID)
end

function host_pools_nedge.getPoolMembers(pool_id)
  local members = {}
  local s = host_pools:create()
  local cur_pool = s:get_pool(tonumber(pool_id))

  if not cur_pool then
     return members
  end

  for member, details in pairs(cur_pool["member_details"]) do
     members[#members + 1] = {address=details.hostkey, vlan=details.vlan, key=details.member}
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
  local s = host_pools:create()
  local cur_pool = s:get_pool(tonumber(pool_id))

  if not cur_pool then
     return
  end

  for member, details in pairs(cur_pool["member_details"]) do
     s:bind_member(member, host_pools.DEFAULT_POOL_ID)
  end
end

function host_pools_nedge.emptyPools()

  local s = host_pools:create()
  local list = s:get_all_pools()

  for _, pool_info in pairs(list) do 
    host_pools_nedge.emptyPool(pool_info.pool_id)
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
