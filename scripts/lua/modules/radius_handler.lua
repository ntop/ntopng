--
-- (C) 2020-22 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path

require "lua_utils"
-- ##############################################

local radius_handler = {}
local session_id_length = 32
local redis_accounting_key = "ntopng.radius.accounting.%s"

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

    math.randomseed(os.time())
    local session_id = tostring(math.random(100000000000000000, 999999999999999999))
    local accounting_started = interface.radiusAccountingStart(username --[[ Username ]], name --[[ MAC Address ]], session_id)

    tprint("Accounting Started for user: " .. username .. ", " .. ternary(accounting_started, "OK", "Error"))
    if accounting_started then
        local json = require("dkjson")
        local key = string.format(redis_accounting_key, name)
        local user_data = {
            name = name,
            username = username,
            password = password,
            session_id = session_id
        }
        
        ntop.setCache(key, json.encode(user_data))
    end

    return accounting_started
end

-- ##############################################

-- @brief Handles the Radius accounting stop request
---@param name string, used to check if name is an accounting going on
---@return boolean, true if the accounting went well, false otherwise and the stop was called
function radius_handler.accountingStop(name, terminate_cause, bytes_sent, bytes_rcvd, packets_sent, packets_rcvd)
    if not radius_handler.isAccountingEnabled() then
        return true
    end

    local is_accounting_on, user_data = radius_handler.isAccountingRequested(name)

    if is_accounting_on then
        -- Get the first ip used by the mac
        local first_host = {}
        local mac_hosts = interface.getMacHosts(name) or {}
        if table.len(mac_hosts) > 0 then
            for _, h in pairsByKeys(mac_hosts, asc) do
                first_host = h
                break
            end    
        end

        interface.radiusAccountingStop(user_data.username --[[ Username ]], user_data.session_id, name --[[ MAC Address]], 
            first_host["ip"] --[[ First IP Address ]], bytes_sent, bytes_rcvd, packets_sent, packets_rcvd, terminate_cause)
        ntop.delCache(string.format(redis_accounting_key, name))
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

    local is_accounting_on, user_data = radius_handler.isAccountingRequested(name)
    local res = true

    if is_accounting_on then
        local bytes_sent = info["bytes.sent"]
        local bytes_rcvd = info["bytes.rcvd"]
        local packets_sent = info["packets.sent"]
        local packets_rcvd = info["packets.rcvd"]

        local is_accounting_ok = interface.radiusAccountingUpdate(name, user_data.session_id, user_data.username,
            user_data.password, bytes_sent, bytes_rcvd, packets_sent, packets_rcvd)

        if not is_accounting_ok then
            -- An accounting stop has to be sent, the allowed data for name
            -- are expired, requesting stop 
            local termination_cause = 3 -- Lost service
            radius_handler.accountingStop(user_data.username, termination_cause, bytes_sent, bytes_rcvd, packets_sent, packets_rcvd)
            res = false
        end
    end

    return res
end

-- ##############################################

-- @brief Check if name has an accounting going on
---@param name string, used to check if name is an accounting going on
---@return boolean, in case the accounting is up or not
---@return table, containing the user data in case an accounting is up
function radius_handler.isAccountingRequested(name)
    local key = string.format(redis_accounting_key, name)
    local user_data = ntop.getCache(key)

    if not isEmptyString(user_data) then
        local json = require("dkjson")

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

return radius_handler

-- ##############################################
