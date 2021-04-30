--
-- (C) 2021-21 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/alert_store/?.lua;" .. package.path

require "lua_utils"
local os_utils = require "os_utils"

-- ##############################################

local alert_store_utils = {}

-- ##############################################

-- @brief Returns an array of all available alert_store Lua class instances
function alert_store_utils.all_instances_factory()
   local alert_store_dir = os_utils.fixPath(dirs.installdir .. "/scripts/lua/modules/alert_store/")
   local res = {}

   for alert_store_file in pairs(ntop.readdir(alert_store_dir)) do

      -- Load all sub-classes of alert_store
      if alert_store_file:match("_alert_store%.lua$") then
         local file_info = string.split(alert_store_file, "%.")
         local instance_name = file_info[1]

	 local instance = require(instance_name).new()

	 if instance then
	    res[#res + 1] = instance
	 end
      end
   end

   return res
end

-- ##############################################

-- @brief Call instance:db_cleanup for every available alert_store instance
function alert_store_utils.housekeeping()
   local all_instances = alert_store_utils.all_instances_factory()
tprint("db housekeeping")
   for _, instance in pairs(all_instances) do
      instance:housekeeping()
   end
end

-- ##############################################

return alert_store_utils
