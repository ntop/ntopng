--
-- (C) 2017-21 - ntop.org
--
-- Module to keep things in common across pools of various type
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/notifications/?.lua;" .. package.path


require "lua_utils"
local pools = require "pools"
local checks = require "checks"
local ts_utils = require "ts_utils_core"
local json = require "dkjson"

local recipients_mod = require "recipients"

-- ##############################################

local host_pools = {}

-- ##############################################

function host_pools:create(args)
    -- Instance of the base class
    local _host_pools = pools:create()

    -- Subclass using the base class instance
    self.key = "host"
    -- self is passed as argument so it will be set as base class metatable
    -- and this will actually make it possible to override functions
    local _host_pools_instance = _host_pools:create(self)

    -- Compute

    -- Return the instance
    return _host_pools_instance
end

-- ##############################################

-- @brief Start a pool transaction.
--        See pools:start_transaction() for additional comments
function host_pools:start_transaction()
   -- OVERRIDE
   self.transaction_started = true
end

-- ##############################################

-- Overwrite the pool name, members and recipients
function host_pools:set_pool_policy(pool_id, new_policy)
   return self:edit_pool(pool_id, nil, nil, nil, new_policy)
end
   
-- ##############################################

-- @brief Ends a pool transaction.
function host_pools:end_transaction()
   -- Perform end-of-transaction operations. Basically all the operations
   -- that are needed when doing a _persist
   -- Reload pools
    ntop.reloadHostPools()

    -- Reload periodic scripts
    ntop.reloadPeriodicScripts()

    self.transaction_started = nil
end

-- ##############################################

-- @brief Given a member key, returns a table of member details such as member name.
function host_pools:get_member_details(member)
    local res = {}
    local member_name
    local member_type
    local host_info = hostkey2hostinfo(member)
    local address = host_info["host"]

    if isMacAddress(address) then
        member_name = address
        member_type = "mac"
    else
        local network, prefix = splitNetworkPrefix(address)

        if (((isIPv4(network)) and (prefix ~= 32)) or
            ((isIPv6(network)) and (prefix ~= 128))) then
            -- this is a network
            member_name = address
            member_type = "net"
        else
            -- this is an host
            member_name = network
            member_type = "ip"
        end
    end

    host_info["host"] = member_name
    res = {
        name = member_name,
        vlan = host_info["vlan"],
        member = member,
        type = member_type,
        hostkey = hostinfo2hostkey(host_info)
    }

    -- Only the name is relevant for hosts
    return res
end

-- ##############################################

-- @brief Returns a table of all possible host ids, both assigned and unassigned to pool members
function host_pools:get_all_members()
    -- There is not a fixed set of host members for host pools
    return
end

-- ##############################################

function host_pools:_get_pools_prefix_key()
    -- OVERRIDE
    -- Key name is in sync with include/ntop_defines.h
    -- and with former host_pools_nedge.lua
    local key = string.format("ntopng.prefs.host_pools")

    return key
end

-- ##############################################

function host_pools:_get_pool_ids_key()
    -- OVERRIDE
    -- Key name is in sync with include/ntop_defines.h
    -- and with former host_pools_nedge.lua method get_pool_ids_key()
    local key = string.format("%s.pool_ids", self:_get_pools_prefix_key())

    return key
end

-- ##############################################

function host_pools:_get_pool_details_key(pool_id)
    -- OVERRIDE
    -- Key name is in sync with include/ntop_defines.h
    -- and with former host_pools_nedge.lua method get_pool_details_key(pool_id)

    if not pool_id then
        -- A pool id is always needed
        return nil
    end

    local key = string.format("%s.details.%d", self:_get_pools_prefix_key(),
                              pool_id)

    return key
end

-- ##############################################

function host_pools:_get_pool_members_key(pool_id)
    -- Key name is in sync with include/ntop_defines.h
    -- and with former host_pools_nedge.lua method get_pool_members_key(pool_id)

    if not pool_id then
        -- A pool id is always needed
        return nil
    end

    local key = string.format("%s.members.%d", self:_get_pools_prefix_key(),
                              pool_id)

    return key
end

-- ##############################################

function host_pools:_assign_pool_id()
    -- OVERRIDE
    -- To stay consistent with the old implementation host_pools_nedge.lua
    -- pool_ids are re-used. This means reading the set  of currently used pool
    -- ids, and chosing the minimum not available pool id
    -- This method is called from functions which perform locks so
    -- there's no risk to assign the same id multiple times
    local cur_pool_ids = self:_get_assigned_pool_ids()

    local next_pool_id = pools.MIN_ASSIGNED_POOL_ID

    -- Find the first available pool id which is not in the set
    for _, pool_id in pairsByValues(cur_pool_ids, asc) do
        if pool_id > next_pool_id then break end

        next_pool_id = math.max(pool_id + 1, next_pool_id)
    end

    ntop.setMembersCache(self:_get_pool_ids_key(),
                         string.format("%d", next_pool_id))

    return next_pool_id
end

-- ##############################################

--@brief Tells the C++ core about the host recipients
function host_pools:set_host_recipients(recipients)
   -- Create a bitmap of all recipients responsible for hosts (pool_id in this case is ignored)
   local recipients_bitmap = 0

   for _, recipient_id in ipairs(recipients) do
      recipients_bitmap = recipients_bitmap | (1 << recipient_id)
   end

   -- Tell the C++ that host recipients have changed
   ntop.recipient_set_host_recipients(recipients_bitmap)
end

-- ##############################################

-- @brief Persist pool details to disk. Possibly assign a pool id
-- @param pool_id The pool_id of the pool which needs to be persisted. If nil, a new pool id is assigned
function host_pools:_persist(pool_id, name, members, recipients, policy)
    -- OVERRIDE
    -- Method must be overridden as host pool details and members are kept as hash caches, which are also used by the C++

    -- Default pool name and members cannot be modified
    if pool_id == pools.DEFAULT_POOL_ID then
        name = pools.DEFAULT_POOL_NAME
        members = {}
    end

    -- The cache for the pool
    local pool_details_key = self:_get_pool_details_key(pool_id)
    ntop.setHashCache(pool_details_key, "name", name)

    -- The cache for pool members
    local pool_members_key = self:_get_pool_members_key(pool_id)
    ntop.delCache(pool_members_key)
    for _, member in pairs(members) do
        ntop.setMembersCache(pool_members_key, member)
    end

    -- Recipients
    if recipients then -- safety check
       ntop.setHashCache(pool_details_key, "recipients", json.encode(recipients));
    end    

    -- Policy
    -- NB: the policy is already a string
    ntop.setHashCache(pool_details_key, "policy", (policy or ""));

    -- Only reload if a transaction is not started. If a transaction is in progress
    -- no reload is performed: it is UP TO THE CALLER to call end_transaction and
    -- which will perform these operations
    if not self.transaction_started then
       -- Reload pools
       ntop.reloadHostPools()

       -- Set host recipients in the C++ core
       if recipients then -- safety check
          self:set_host_recipients(recipients)
       end

       -- Reload periodic scripts
       ntop.reloadPeriodicScripts()
    end

    -- Return the assigned pool_id
    return pool_id
end

-- ##############################################

function host_pools:delete_pool(pool_id)
    local ret = false

    local locked = self:_lock()

    if locked then
        -- Make sure the pool exists
        local cur_pool_details = self:get_pool(pool_id)

        if cur_pool_details then
            -- Remove the key with all the pool details (e.g., with members)
            ntop.delCache(self:_get_pool_details_key(pool_id))

            -- Remove the key with all the pool member details
            ntop.delCache(self:_get_pool_members_key(pool_id))

            -- Remove the pool_id from the set of all currently existing pool ids
            ntop.delMembersCache(self:_get_pool_ids_key(),
                                 string.format("%d", pool_id))

            -- Delete serialized values and timeseries across all interfaces
            for ifid, ifname in pairs(interface.getIfNames()) do
                -- serialized key is in sync with include/ntop_defines.h constant HOST_POOL_SERIALIZED_KEY
                -- As host pools have stats which are kept on a per-interface basis, all the interfaces need to
                -- be iterated and their historical data deleted
                local serialized_key = "ntopng.serialized_host_pools.ifid_" ..
                                           ifid
                ntop.delHashCache(serialized_key, tostring(pool_id))
                ts_utils.delete("host_pool",
                                {ifid = tonumber(ifid), pool = pool_id})
            end

            -- Reload pools
            ntop.reloadHostPools()

	    -- Reload periodic scripts
	    ntop.reloadPeriodicScripts()

            ret = true
        end

        self:_unlock()
    end

    return ret
end

-- ##############################################

function host_pools:_get_pool_detail(pool_id, detail)
    local details_key = self:_get_pool_details_key(pool_id)

    return ntop.getHashCache(details_key, detail)
end

-- ##############################################

function host_pools:get_pool_policy(pool_id)
   return (self:_get_pool_detail(pool_id, "policy") or "")
end
   
-- ##############################################

function host_pools:get_pool(pool_id, recipient_details)

    local recipient_details = recipient_details or true

    local pool_name = self:_get_pool_detail(pool_id, "name")
    if pool_name == "" then
        return nil -- Pool not existing
    end

    -- Pool members
    local members = ntop.getMembersCache(self:_get_pool_members_key(pool_id))

    local member_details = {}
    if members then
        for _, member in pairs(members) do
            member_details[member] = self:get_member_details(member)
        end
    else
        members = {}
    end

    -- Recipients
    local recipients = self:_get_pool_detail(pool_id, "recipients")
    if recipients then
       recipients = json.decode(recipients) or {}

       local temp_recipients = {}
       -- get recipient metadata
       for _, recipient_id in pairs(recipients) do
	  if tonumber(recipient_id) then -- Handles previously string-keyed recipients
	     local res = { recipient_id = recipient_id }

	     if recipient_details then
		local recipient = recipients_mod.get_recipient(recipient_id)

		if recipient and recipient.recipient_name then
		   res["recipient_name"] = recipient.recipient_name
		   res["recipient_check_categories"] = recipient.check_categories
		   res["recipient_minimum_severity"] = recipient.minimum_severity
		end
	     end

	     temp_recipients[#temp_recipients + 1] = res
	  end
       end

       recipients = temp_recipients
    else
        recipients = {}
    end

    local policy = self:_get_pool_detail(pool_id, "policy")

    local pool_details = {
        pool_id = tonumber(pool_id),
        name = pool_name,
        members = members,
        member_details = member_details,
        recipients = recipients,
	policy = policy,
    }

    -- Upon success, pool details are returned, otherwise nil
    return pool_details
end

-- ##############################################

-- @param member a valid pool member
-- @return The pool_id found for the currently selected host.
--         `member` here is IGNORED: argument is just kept to
--         preserve method fingerprint.
function host_pools:get_pool_id(member)
    -- OVERRIDE
    local res = host.getPoolId()

    if res and res["host_pool_id"] then return res["host_pool_id"] end

    return host_pools.DEFAULT_POOL_ID
end

-- ##############################################

-- @brief Returns a boolean indicating whether the member is a valid pool member
function host_pools:is_valid_member(member)
    local res = isValidPoolMember(member)

    return res
end

-- ##############################################

-- @brief Returns available members which don't already belong to any defined pool
function host_pools:get_available_members()
    -- Available host pool memebers is not a finite set
    return nil
end

-- ##############################################

function host_pools:hostpool2record(ifid, pool_id, pool)
    local record = {}
    record["key"] = tostring(pool_id)

    local pool_name = self:get_pool_name(pool_id)
    local pool_link = "<A HREF='" .. ntop.getHttpPrefix() ..
                          '/lua/hosts_stats.lua?pool=' .. pool_id .. "' title='" ..
                          pool_name .. "'>" .. pool_name .. '</A>'
    record["column_id"] = pool_link

    record["column_hosts"] = pool["num_hosts"] .. ""
    record["column_since"] = secondsToTime(os.time() - pool["seen.first"] + 1)
    record["column_num_dropped_flows"] = (pool["flows.dropped"] or 0) .. ""

    local sent2rcvd = round((pool["bytes.sent"] * 100) /
                                (pool["bytes.sent"] + pool["bytes.rcvd"]), 0)
    record["column_breakdown"] =
        "<div class='progress'><div class='progress-bar bg-warning' style='width: " ..
            sent2rcvd ..
            "%;'>Sent</div><div class='progress-bar bg-success' style='width: " ..
            (100 - sent2rcvd) .. "%;'>Rcvd</div></div>"

    if (throughput_type == "pps") then
        record["column_thpt"] = pktsToSize(pool["throughput_pps"])
    else
        record["column_thpt"] = bitsToSize(8 * pool["throughput_bps"])
    end

    record["column_traffic"] = bytesToSize(
                                   pool["bytes.sent"] + pool["bytes.rcvd"])

    record["column_chart"] = ""

    if areHostPoolsTimeseriesEnabled(ifid) then
        record["column_chart"] = '<A HREF="' .. ntop.getHttpPrefix() ..
                                     '/lua/pool_details.lua?pool=' .. pool_id ..
                                     '&page=historical"><i class=\'fas fa-chart-area fa-lg\'></i></A>'
    end

    return record
end

-- ##############################################

function host_pools:updateRRDs(ifid, dump_ndpi, verbose)
    local ts_utils = require "ts_utils"
    require "ts_5min"

    -- NOTE: requires graph_utils
    for pool_id, pool_stats in pairs(interface.getHostPoolsStats() or {}) do
        ts_utils.append("host_pool:traffic", {
            ifid = ifid,
            pool = pool_id,
            bytes_sent = pool_stats["bytes.sent"],
            bytes_rcvd = pool_stats["bytes.rcvd"]
        }, when)

        if pool_id ~= tonumber(host_pools.DEFAULT_POOL_ID) then
            local flows_dropped = pool_stats["flows.dropped"] or 0

            ts_utils.append("host_pool:blocked_flows", {
                ifid = ifid,
                pool = pool_id,
                num_flows = flows_dropped
            }, when)
        end

        -- nDPI stats
        if dump_ndpi then
            for proto, v in pairs(pool_stats["ndpi"] or {}) do
                ts_utils.append("host_pool:ndpi", {
                    ifid = ifid,
                    pool = pool_id,
                    protocol = proto,
                    bytes_sent = v["bytes.sent"],
                    bytes_rcvd = v["bytes.rcvd"]
                }, when)
            end
        end
    end

    -- Also write info on the number of members per pool, both in terms of hosts and l2 devices
    local pools = interface.getHostPoolsInfo() or {}
    for pool, info in pairs(pools.num_members_per_pool or {}) do
        ts_utils.append("host_pool:hosts", {
            ifid = ifid,
            pool = pool,
            num_hosts = info["num_hosts"]
        }, when)
        ts_utils.append("host_pool:devices", {
            ifid = ifid,
            pool = pool,
            num_devices = info["num_l2_devices"]
        }, when)
    end
end

-- ##############################################

return host_pools
