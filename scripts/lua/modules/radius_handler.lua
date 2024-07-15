--
-- (C) 2020-24 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path

require "ntop_utils"
local json = require("dkjson")

-- ##############################################

local radius_handler = {}
local session_id_length = 32
local redis_accounting_key = "ntopng.radius.accounting.%s"

local function get_first_ip(mac)
    -- Get the first ip used by the mac
    local first_host = {}
    local mac_hosts = interface.getMacHosts(mac) or {}
    if table.len(mac_hosts) > 0 then
        for _, h in pairsByKeys(mac_hosts, asc) do
            first_host = h
            break
        end
    end

    local ip_address = first_host["ip"]
    if isEmptyString(ip_address) then
        ip_address = nil
    end

    return ip_address
end

-- ##############################################

---@brief Handles the Radius accounting start request
---@param name string, used to identify the the user logged in
---@param username string, used to login the account to radius
---@param password string, used to login the account to radius
---@return boolean, true if the accounting start went well, false otherwise
function radius_handler.accountingStart(name, username, password)
    if not radius_handler.isAccountingEnabled() then
        return true
    end
    name = string.upper(name)

    -- Check if the user is already saved on redis
    local is_accounting_on = radius_handler.isAccountingRequested(name)

    -- In case the info are already on redis, means that the  system is restarted
    -- or the same request has been done twice, so just skip this
    if is_accounting_on then
        return true
    end

    traceError(TRACE_NORMAL, TRACE_CONSOLE,
        string.format("Accounting start requested for MAC [%s] with username [%s]", name, username))

    local session_id = tostring(math.random(100000000000000000, 999999999999999999))
    local ip_address = get_first_ip(name)
    local current_time = os.time()
    math.randomseed(current_time)
    local accounting_started = interface.radiusAccountingStart(username --[[ Username ]] , name --[[ MAC Address ]] ,
        session_id, ip_address --[[ First IP Address ]] , current_time)
    if accounting_started then
        local key = string.format(redis_accounting_key, name)
        local user_data = {
            name = name,
            username = username,
            password = password,
            session_id = session_id,
            start_session_time = current_time,
            ip_address = ip_address,
            bytes_sent = 0,
            bytes_rcvd = 0,
            packets_sent = 0,
            packets_rcvd = 0
        }

        ntop.setCache(key, json.encode(user_data))
    end

    return true
end

-- ##############################################

-- @brief Handles the Radius accounting stop request
---@param name string, used to check if name is an accounting going on
---@return boolean, true if the accounting went well, false otherwise and the stop was called
function radius_handler.accountingStop(name, terminate_cause, info)
    if not radius_handler.isAccountingEnabled() then
        return true
    end
    name = string.upper(name)

    local _, user_data = radius_handler.isAccountingRequested(name)
    -- Removing the entry from redis
    ntop.delCache(string.format(redis_accounting_key, name))

    traceError(TRACE_NORMAL, TRACE_CONSOLE, string.format("Accounting stop requested for MAC [%s]", name))

    -- Check in case no user_data is found
    if user_data then
        local bytes_sent = 0
        local bytes_rcvd = 0
        local packets_sent = 0
        local packets_rcvd = 0
        local current_time = os.time()
        local ip_address = ""
        if user_data and not isEmptyString(user_data.ip_address) then
            ip_address = user_data.ip_address
        else
            ip_address = get_first_ip(name)
            if not isEmptyString(ip_address) then
                user_data.ip_address = ip_address
            end
        end

        if info then
            bytes_sent = info["bytes.sent"] or user_data.bytes_sent
            bytes_rcvd = info["bytes.rcvd"] or user_data.bytes_rcvd
            packets_sent = info["packets.sent"] or user_data.packets_sent
            packets_rcvd = info["packets.rcvd"] or user_data.packets_rcvd
        else
            bytes_sent = user_data.bytes_sent
            bytes_rcvd = user_data.bytes_rcvd
            packets_sent = user_data.packets_sent
            packets_rcvd = user_data.packets_rcvd
        end

        interface.radiusAccountingStop(user_data.username --[[ Username ]] , user_data.session_id, name --[[ MAC Address]] ,
            ip_address, bytes_sent, bytes_rcvd, packets_sent, packets_rcvd, terminate_cause,
            current_time - user_data.start_session_time)
    end
end

-- ##############################################

-- @brief Execute the accounting update if the name has to be updated
---@param name string, used to check if name is an accounting going on
---@return boolean, true if the accounting went well, false otherwise and the stop was called
function radius_handler.accountingUpdate(name, info)
    if not radius_handler.isAccountingEnabled() then
        return true
    end
    name = string.upper(name)

    local is_accounting_on, user_data = radius_handler.isAccountingRequested(name)
    local res = true

    if is_accounting_on and user_data then
        local key = string.format(redis_accounting_key, name)
        local ip_address
        if user_data and not isEmptyString(user_data.ip_address) then
            ip_address = user_data.ip_address
        else
            ip_address = get_first_ip(name)
            if not isEmptyString(ip_address) then
                -- Update the info with the ip_address if it's not empty
                user_data.ip_address = ip_address
            end
        end
        local bytes_sent = info["bytes.sent"]
        local bytes_rcvd = info["bytes.rcvd"]
        local packets_sent = info["packets.sent"]
        local packets_rcvd = info["packets.rcvd"]
        local current_time = os.time()

        user_data.bytes_sent = bytes_sent
        user_data.bytes_rcvd = bytes_rcvd
        user_data.packets_sent = packets_sent
        user_data.packets_rcvd = packets_rcvd

        ntop.setCache(key, json.encode(user_data))

        interface.radiusAccountingUpdate(name, user_data.session_id, user_data.username, user_data.password, ip_address,
            bytes_sent, bytes_rcvd, packets_sent, packets_rcvd, current_time - user_data.start_session_time)
    end

    return res
end

-- ##############################################

-- @brief Check if name has an accounting going on
---@param name string, used to check if name is an accounting going on
---@return boolean, in case the accounting is up or not
---@return table, containing the user data in case an accounting is up
function radius_handler.isAccountingRequested(name)
    name = string.upper(name)
    local key = string.format(redis_accounting_key, name)
    local user_data = ntop.getCache(key)

    if not isEmptyString(user_data) then
        return true, json.decode(user_data)
    end

    return false, nil
end

-- ##############################################

function radius_handler.isAccountingEnabled()
    local accounting_enabled = ntop.getPref("ntopng.prefs.radius.accounting_enabled")
    if (not accounting_enabled) or (isEmptyString(accounting_enabled) or (accounting_enabled == "0")) then
        return false
    end

    return true
end

-- ##############################################

function radius_handler.getAllKeys()
    local keys = ntop.getKeysCache("ntopng.radius.accounting.*")
    if keys then
        require "lua_utils"
        local prefix_to_remove = "ntopng.radius.accounting."
        local characters_to_remove = string.len(prefix_to_remove)
        local new_keys = {}
        for member, _ in pairs(keys) do
            local mac_address = member:gsub(prefix_to_remove, "")
            if isMacAddress(mac_address) then
                new_keys[#new_keys + 1] = mac_address
            end
        end
        keys = new_keys
    end
    return keys or {}
end

-- ##############################################

return radius_handler

-- ##############################################
