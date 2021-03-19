--
-- (C) 2020 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require("dkjson")
local http_lint = require("http_lint")

local REDIS_KEY = "ntopng.prefs.%s.table.%s.columns"

---Report an error message for the developer
---@param msg string
local function reportError(msg)
    print(json.encode({ message = msg, success = false }))
end

local function get_username()

    local username = _SESSION["user"] or ''
    if (isNoLoginUser()) then username = 'no_login' end

    return username
end

---Save the columns visibility inside Redis 
---@param table_name string The HTML table id
---@param columns string String containing ids separeted by comma
local function save_column_preferences(table_name, columns)

    -- avoid the save of nil value
    if columns == nil then return end

    local key = string.format(REDIS_KEY, get_username(), table_name)
    local cols = split(columns, ",")

    tprint(cols)

    ntop.setPref(key, json.encode(cols))

end

---Load saved column visibility from Redis
---@param table_name string The HTML table id
---@return table
local function load_saved_column_preferences(table_name)
    
    local key = string.format(REDIS_KEY, get_username(), table_name)
    local columns = ntop.getPref(key)

    if isEmptyString(columns) then
        return { -1 }
    end

    return json.decode(columns)
end

local result = {success = true, message = nil, columns = nil}
local action = _GET["action"] or _POST["action"]
local table_name = _GET["table"] or _POST["table"]

sendHTTPContentTypeHeader('application/json')

if isEmptyString(table_name) then
    reportError("The table param cannot be empty!")
    return
end

if action == "load" then    

    result.columns = load_saved_column_preferences(table_name)
    result.message = "Columns loaded."

elseif action == "save" then
    
    local columns = _POST["columns"] or ''
    save_column_preferences(table_name, columns)
    
    result.message = "Columns visibility saved."

else
    reportError("Invalid action. The action can be 'load' or 'save'.")
    return
end

print(json.encode(result))