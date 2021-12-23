--
-- (C) 2020-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require("dkjson")

local datatable_utils = {}

local REDIS_KEY = "ntopng.prefs.%s.table.%s.columns"

local function get_username()
   local username = _SESSION["user"] or ''
   if (isNoLoginUser()) then username = 'no_login' end

   return username
end

---Save the columns visibility inside Redis 
---@param table_name string The HTML table id
---@param columns string String containing ids separeted by comma
function datatable_utils.save_column_preferences(table_name, columns)
   -- avoid the save of nil value
   if columns == nil then return end
tprint(columns)
   local key = string.format(REDIS_KEY, get_username(), table_name)
   local cols = split(columns, ",")

   ntop.setPref(key, json.encode(cols))
end

---Load saved column visibility from Redis
---@param table_name string The HTML table id
---@return table
function datatable_utils.load_saved_column_preferences(table_name)
   local key = string.format(REDIS_KEY, get_username(), table_name)
   local columns = ntop.getPref(key)

   if isEmptyString(columns) then
      return { -1 }
   end

   return json.decode(columns)
end

---Check if there are saved visible columns
---@param table_name string The HTML table id
---@return boolean
function datatable_utils.has_saved_column_preferences(table_name)
   local key = string.format(REDIS_KEY, get_username(), table_name)
   local columns = ntop.getPref(key)

   return not isEmptyString(columns)
end

return datatable_utils
