--
-- (C) 2017 - ntop.org
--
dirs = ntop.getDirs()

package.path = dirs.installdir .. "/scripts/lua/modules/?/init.lua;" .. package.path

require "lua_utils"

local host_pools_utils = {}
host_pools_utils.DEFAULT_POOL_ID = "0"
host_pools_utils.FIRST_AVAILABLE_POOL_ID = "1"
host_pools_utils.DEFAULT_POOL_NAME = "Not Assigned"
host_pools_utils.MAX_NUM_POOLS = 16

local function get_pool_members_key(ifid, pool_id)
  return "ntopng.prefs." .. ifid .. ".host_pools.members." .. pool_id
end

local function get_pool_ids_key(ifid)
  return "ntopng.prefs." .. ifid .. ".host_pools.pool_ids"
end

local function get_pool_details_key(ifid, pool_id)
  return "ntopng.prefs." .. ifid .. ".host_pools.details." .. pool_id
end

local function get_user_pool_dump_key(ifid)
  return "ntopng.prefs." .. ifid .. ".host_pools.dump"
end

-- It is safe to call this multiple times
local function initInterfacePools(ifid)
  host_pools_utils.createPool(ifid, host_pools_utils.DEFAULT_POOL_ID, host_pools_utils.DEFAULT_POOL_NAME)
end

local function get_pool_detail(ifid, pool_id, detail)
  local details_key = get_pool_details_key(ifid, pool_id)

  return ntop.getHashCache(details_key, detail)
end

local function set_pool_detail(ifid, pool_id, detail, value)
  local details_key = get_pool_details_key(ifid, pool_id)

  ntop.setHashCache(details_key, detail, value)
end

--------------------------------------------------------------------------------

function host_pools_utils.createPool(ifid, pool_id, pool_name, children_safe, enforce_quotas_per_pool_member)
  local details_key = get_pool_details_key(ifid, pool_id)
  local ids_key = get_pool_ids_key(ifid)

  ntop.setMembersCache(ids_key, pool_id)
  ntop.setHashCache(details_key, "name", pool_name)
  ntop.setHashCache(details_key, "children_safe", tostring(children_safe or false))
  ntop.setHashCache(details_key, "enforce_quotas_per_pool_member", tostring(enforce_quotas_per_pool_member or false)) 
end

function host_pools_utils.deletePool(ifid, pool_id)
  local rrd_base = host_pools_utils.getRRDBase(ifid, pool_id)
  local ids_key = get_pool_ids_key(ifid)
  local details_key = get_pool_details_key(ifid, pool_id)
  local members_key = get_pool_members_key(ifid, pool_id)
  local dump_key = get_user_pool_dump_key(ifid)

  ntop.delMembersCache(ids_key, pool_id)
  ntop.delCache(details_key)
  ntop.delCache(members_key)
  ntop.delHashCache(dump_key, pool_id)
  ntop.rmdir(rrd_base)
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

--
-- Note:
--
-- When strict_host_mode is not set, hosts which have a MAC address will have the
-- MAC address changed instead of the IP address.
--
function host_pools_utils.changeMemberPool(ifid, member_and_vlan, new_pool, info --[[optional]], strict_host_mode --[[optional]])
  if not strict_host_mode then
    local hostkey, is_network = host_pools_utils.getMemberKey(member_and_vlan)

    if (not is_network) and (not isMacAddress(member_and_vlan)) then
      -- this is a single host, try to get the MAC address
      if info == nil then
        local hostinfo = hostkey2hostinfo(hostkey)
        info = interface.getHostInfo(hostinfo["host"], hostinfo["vlan"])
      end

      if not isEmptyString(info["mac"]) then
        -- host has a MAC, use it
        member_and_vlan = info["mac"]
      end
    end
  end

  local members_key = get_pool_members_key(ifid, new_pool)
  local member_exists, info = getMembershipInfo(member_and_vlan)
  local prev_pool

  if member_exists then
    -- use the normalized key
    member_and_vlan = info.key
    prev_pool = info.existing_member_pool
  else
    prev_pool = host_pools_utils.DEFAULT_POOL_ID
  end

  if prev_pool == new_pool then
    return false
  end

  host_pools_utils.deletePoolMember(ifid, prev_pool, info.key)
  ntop.setMembersCache(members_key, info.key)
  return true
end

function host_pools_utils.addPoolMember(ifid, pool_id, member_and_vlan)
  local members_key = get_pool_members_key(ifid, pool_id)
  local member_exists, info = getMembershipInfo(member_and_vlan)

  if member_exists then
    return false, info
  else
    ntop.setMembersCache(members_key, info.key)
    return true, info
  end
end

function host_pools_utils.deletePoolMember(ifid, pool_id, member_and_vlan)
  local members_key = get_pool_members_key(ifid, pool_id)

  -- Possible delete volatile member
  if ntop.isPro() then
    interface.removeVolatileMemberFromPool(member_and_vlan, tonumber(pool_id))
  end

  -- Possible delete non-volatile member
  ntop.delMembersCache(members_key, member_and_vlan)
end

function host_pools_utils.emptyPool(ifid, pool_id)
  local members_key = get_pool_members_key(ifid, pool_id)

  if ntop.isPro() then
    -- Remove volatile members
    for _,v in pairs(interface.getHostPoolsVolatileMembers()[tonumber(pool_id)] or {}) do
      interface.removeVolatileMemberFromPool(v.member, tonumber(pool_id))
    end
  end

  -- Remove non-volatile members
  ntop.delCache(members_key)
end

function host_pools_utils.getPoolsList(ifid, without_info)
  local ids_key = get_pool_ids_key(ifid)
  local pools = {}

  initInterfacePools(ifid)

  for _, pool_id in pairsByValues(ntop.getMembersCache(ids_key) or {}, asc) do
    local pool

    if without_info then
      pool = {id=pool_id}
    else
      pool = {
        id = pool_id,
        name = host_pools_utils.getPoolName(ifid, pool_id),
        children_safe = host_pools_utils.getChildrenSafe(ifid, pool_id),
	enforce_quotas_per_pool_member = host_pools_utils.getEnforceQuotasPerPoolMember(ifid, pool_id),
      }
    end

    pools[#pools + 1] = pool
  end

  return pools
end

function host_pools_utils.getPoolMembers(ifid, pool_id)
  local members_key = get_pool_members_key(ifid, pool_id)
  local members = {}

  local all_members = ntop.getMembersCache(members_key) or {}
  local volatile = {}

  if ntop.isPro() then
    for _,v in pairs(interface.getHostPoolsVolatileMembers()[tonumber(pool_id)] or {}) do
      if not v.expired then
        all_members[#all_members + 1] = v["member"]
        volatile[v["member"]] = v["residual_lifetime"]
      end
    end
  end

  for _,v in pairsByValues(all_members, asc) do
    local hostinfo = hostkey2hostinfo(v)
    local residual_lifetime = NULL
    if volatile[v] ~= nil then
      residual_lifetime = volatile[v];
    end

    members[#members + 1] = {address=hostinfo["host"], vlan=hostinfo["vlan"], key=v, residual=residual_lifetime}
  end

  return members
end

function host_pools_utils.getMemberKey(member)
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

function host_pools_utils.getPoolName(ifid, pool_id)
  return get_pool_detail(ifid, pool_id, "name")
end

function host_pools_utils.getChildrenSafe(ifid, pool_id)
  return toboolean(get_pool_detail(ifid, pool_id, "children_safe"))
end

function host_pools_utils.getEnforceQuotasPerPoolMember(ifid, pool_id)
  return toboolean(get_pool_detail(ifid, pool_id, "enforce_quotas_per_pool_member"))
end

function host_pools_utils.initPools()
  for _, ifname in pairs(interface.getIfNames()) do
    local ifid = getInterfaceId(ifname)
    local ifstats = interface.getStats()

    -- Note: possible shapers are initialized in shaper_utils::initShapers
    if not ifstats.isView then
      initInterfacePools(ifid)
    end
  end
end

function host_pools_utils.getMacPool(mac_address)
  local exists, info = getMembershipInfo(mac_address)
  if exists then
    return tostring(info.existing_member_pool)
  else
    return host_pools_utils.DEFAULT_POOL_ID
  end
end

function host_pools_utils.getUndeletablePools(ifid)
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

function host_pools_utils.purgeExpiredPoolsMembers()
   local ifnames = interface.getIfNames()

   for _, ifname in pairs(ifnames) do
      interface.select(ifname)

      if isCaptivePortalActive() then
        interface.purgeExpiredPoolsMembers()
      end
   end
end

function host_pools_utils.getRRDBase(ifid, pool_id)
  local dirs = ntop.getDirs()
  return fixPath(dirs.workingdir .. "/" .. ifid .. "/host_pools/" .. pool_id)
end

function host_pools_utils.updateRRDs(ifid, dump_ndpi, verbose)
  -- NOTE: requires graph_utils
  for pool_id, pool_stats in pairs(interface.getHostPoolsStats()) do
    local pool_base = host_pools_utils.getRRDBase(ifid, pool_id)

    if(not(ntop.exists(pool_base))) then
      ntop.mkdir(pool_base)
    end

    -- Traffic stats
    local rrdpath = fixPath(pool_base .. "/bytes.rrd")
    createRRDcounter(rrdpath, 300, verbose)
    ntop.rrd_update(rrdpath, "N:"..tolongint(pool_stats["bytes.sent"]) .. ":" .. tolongint(pool_stats["bytes.rcvd"]))

    -- nDPI stats
    if dump_ndpi then
      for proto,v in pairs(pool_stats["ndpi"] or {}) do
        local ndpiname = fixPath(pool_base.."/"..proto..".rrd")
        createRRDcounter(ndpiname, 300, verbose)
        ntop.rrd_update(ndpiname, "N:"..tolongint(v["bytes.sent"])..":"..tolongint(v["bytes.rcvd"]))
      end
    end
  end
end

function host_pools_utils.printQuotas(pool_id, host, page_params)
  local pools_stats = interface.getHostPoolsStats()
  local pool_stats = pools_stats and pools_stats[tonumber(pool_id)]

  local ndpi_stats = pool_stats.ndpi
  local category_stats = pool_stats.ndpi_categories
  local quota_and_protos = shaper_utils.getPoolProtoShapers(ifId, pool_id)

  -- Empty check
  local empty = true
  for _, proto in pairs(quota_and_protos) do
    if ((tonumber(proto.traffic_quota) > 0) or (tonumber(proto.time_quota) > 0)) then
      -- at least a quota is set
      empty = false
      break
    end
  end

  if empty then
    print("<div class=\"alert alert alert-danger\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png>"..i18n("shaping.no_quota_data")..
      ". Create new quotas <a href=\""..ntop.getHttpPrefix().."/lua/if_stats.lua?page=filtering&pool="..pool_id.."\">here</a>.</div>")
  else
    print[[
    <table class="table table-bordered table-striped">
    <thead>
      <tr>
        <th>]] print(i18n("protocol")) print[[</th>
        <th class="text-center">]] print(i18n("shaping.daily_traffic")) print[[</th>
        <th class="text-center">]] print(i18n("shaping.daily_time")) print[[</th>]]
    if (host ~= nil) then
      print('<th class="text-center">'..i18n("actions")..'</th>')
    end
    print[[
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
              $('#pool_quotas_ndpi_tbody').html('<tr><td colspan="4"><i>]] print(i18n("shaping.no_quota_traffic")) print[[</i></td></tr>');
          }
        });
      }

      setInterval(update_ndpi_table, 5000);
      update_ndpi_table();
     </script>]]
  end

end

return host_pools_utils
