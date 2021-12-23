--
-- (C) 2020 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require("dkjson")
local http_lint = require("http_lint")
local datatable_utils = require("datatable_utils")

---Report an error message for the developer
---@param msg string
local function reportError(msg)
    print(json.encode({ message = msg, success = false }))
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
   result.columns = datatable_utils.load_saved_column_preferences(table_name)
   result.message = "Columns loaded."

elseif action == "save" then
   local columns = _POST["columns"] or ''
   datatable_utils.save_column_preferences(table_name, columns)
    
   result.message = "Columns visibility saved."

else
    reportError("Invalid action. The action can be 'load' or 'save'.")
    return
end

print(json.encode(result))
