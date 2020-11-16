--
-- (C) 2020 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/import_export/?.lua;" .. package.path
require "lua_utils" 
local import_export = require "import_export"
local json = require "dkjson"
local rest_utils = require "rest_utils"
local plugins_utils = require("plugins_utils")
local host_pools = require "host_pools"
local am_utils = plugins_utils.loadModule("active_monitoring", "am_utils")

-- ##############################################

local am_import_export = {}

-- ##############################################

function am_import_export:create(args)
    -- Instance of the base class
    local _am_import_export = import_export:create()

    -- Subclass using the base class instance
    self.key = "am"
    -- self is passed as argument so it will be set as base class metatable
    -- and this will actually make it possible to override functions
    local _am_import_export_instance = _am_import_export:create(self)

    -- Compute

    -- Return the instance
    return _am_import_export_instance
end

-- ##############################################

-- @brief Import configuration
-- @param conf The configuration to be imported
-- @return A table with a key "success" set to true is returned on success. A key "err" is set in case of failure, with one of the errors defined in rest_utils.consts.err.
function am_import_export:import(conf)
   local res = {}

   -- TODO Validate the configuration and set
   -- res.err = rest_utils.consts.err.bad_content

   local old_hosts = am_utils.getHosts(true --[[ config only ]])

   for host_key, conf in pairs(conf) do
      local host = am_utils.key2host(host_key)

      if old_hosts[host_key] then
         am_utils.editHost(host.host, host.measurement, conf.threshold, conf.granularity, host_pools.DEFAULT_POOL_ID, conf.token, conf.save_result, conf.readonly)
      else
         am_utils.addHost(host.host, host.measurement, conf.threshold, conf.granularity, host_pools.DEFAULT_POOL_ID, conf.token, conf.save_result, conf.readonly)
      end
   end

   if not res.err then 
      res.success = true
   end

   return res
end

-- ##############################################

-- @brief Export configuration
-- @return The current configuration
function am_import_export:export()
   local conf = am_utils.getHosts(true --[[ only retrieve the configuration ]])
   return conf
end

-- ##############################################

-- @brief Reset configuration
function am_import_export:reset()
   am_utils.resetConfig()   
end

-- ##############################################

return am_import_export
