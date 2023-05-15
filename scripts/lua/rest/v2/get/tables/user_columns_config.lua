--
-- (C) 2013-23 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

-- #####################################

local rest_utils = require("rest_utils")

-- #####################################

local redis_base_key = "ntopng.columns_config.%s.%s"

-- #####################################


-- @brief Retrieves columns configurations
local function get_column_config() 

  local table_id = _GET["table_id"]
  local user_id = _SESSION["user"]

  if(isEmptyString(table_id)) then
    rest_utils.answer(rest_utils.consts.err.invalid_args)
  end

  local redis_key = string.format(redis_base_key, table_id, user_id)

  local visible_columns = ntop.getCache(redis_key) or {}
  if visible_columns == nil or visible_columns == "" then
     visible_columns = {}
  end
  return(rest_utils.answer(rest_utils.consts.success.ok, visible_columns))
end

return(get_column_config())


