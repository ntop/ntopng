--
-- (C) 2013-24 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
local json = require "dkjson"

-- #####################################

local rest_utils = require("rest_utils")

-- #####################################

local redis_base_key = "ntopng.columns_config.%s.%s"

-- #####################################

-- @brief Save columns configurations
local function save_column_config()
   local payload = json.decode(_POST.payload)
   local visible_columns = payload.visible_columns_ids
   local table_id = payload.table_id
   local user_id = _SESSION["user"]

  if(isEmptyString(table_id)) then
    rest_utils.answer(rest_utils.consts.err.invalid_args)
  end

  local redis_key = string.format(redis_base_key, table_id, user_id)
  ntop.setCache(redis_key, json.encode(visible_columns))

  return(rest_utils.answer(rest_utils.consts.success.ok, visible_columns))
end

return(save_column_config())


