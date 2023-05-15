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
    local session_id = tostring(math.random(10000000000, 99999999999))
    local accounting_started = interface.radiusAccountingStart(name --[[ MAC Address ]] , session_id)

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
function radius_handler.accountingStop(name)
    if not radius_handler.isAccountingEnabled() then
        return true
    end

    local is_accounting_on, user_data = radius_handler.isAccountingRequested(name)

    if is_accounting_on then
        interface.radiusAccountingStop(name --[[ MAC Address ]] , user_data.session_id)
        ntop.delCache(string.format(redis_accounting_key, name))
    end
end

-- ##############################################

-- @brief Execute the accounting update if the name has to be updated
---@param name string, used to check if name is an accounting going on
---@return boolean, true if the accounting went well, false otherwise and the stop was called
function radius_handler.accountingUpdate(name)
    if not radius_handler.isAccountingEnabled() then
        return true
    end

    local is_accounting_on, user_data = radius_handler.isAccountingRequested(name)
    local res = true

    if is_accounting_on then
        local is_accounting_ok = interface.radiusAccountingUpdate(name, user_data.session_id, user_data.username,
            user_data.password)

        if not is_accounting_ok then
            -- An accounting stop has to be sent, the allowed data for name
            -- are expired, requesting stop 
            radius_handler.accountingStop(name)
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
