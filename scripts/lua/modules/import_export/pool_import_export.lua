--
-- (C) 2020 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/import_export/?.lua;" .. package.path
package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils" 
local import_export = require "import_export"
local json = require "dkjson"
-- local pool_config = require "pool_config"
local rest_utils = require "rest_utils"

local host_pools              = require "host_pools":create()
local flow_pools              = require "flow_pools":create()
local system_pools            = require "system_pools":create()
local mac_pools               = require "mac_pools":create()
local interface_pools         = require "interface_pools":create()
local host_pool_pools         = require "host_pool_pools":create()
local local_network_pools     = require "local_network_pools":create()
local active_monitoring_pools = require "active_monitoring_pools":create()

-- ##############################################

local pool_import_export = {}

-- ##############################################

function pool_import_export:create(args)
   -- Instance of the base class
   local _pool_import_export = import_export:create()

   -- Subclass using the base class instance
   self.key = "pool"
   -- self is passed as argument so it will be set as base class metatable
   -- and this will actually make it possible to override functions
   local _pool_import_export_instance = _pool_import_export:create(self)

   -- Compute

   -- Return the instance
   return _pool_import_export_instance
end

-- ##############################################

-- @brief Import configuration
-- @param conf The configuration to be imported
-- @return A table with a key "success" set to true is returned on success. A key "err" is set in case of failure, with one of the errors defined in rest_utils.consts.err.
function pool_import_export:import(conf)
   local res = {}

   local success = false -- TODO

   if not success then
      res.err = rest_utils.consts.err.internal_error
   else
      res.success = true
   end

   return res
end

-- ##############################################

-- @brief Export configuration
-- @return The current configuration
function pool_import_export:export()
   
   local conf = {}

   conf["host"]              = host_pools:get_all_pools()              or {}
   conf["flow"]              = flow_pools:get_all_pools()              or {}
   conf["system"]            = system_pools:get_all_pools()            or {}
   conf["mac"]               = mac_pools:get_all_pools()               or {}
   conf["interface"]         = interface_pools:get_all_pools()         or {}
   conf["host_pool"]         = host_pool_pools:get_all_pools()         or {}
   conf["local_network"]     = local_network_pools:get_all_pools()     or {}
   conf["active_monitoring"] = active_monitoring_pools:get_all_pools() or {}

   return conf
end

-- ##############################################

-- @brief Reset configuration
function pool_import_export:reset()
   host_pools:cleanup()
   flow_pools:cleanup()
   system_pools:cleanup()
   mac_pools:cleanup()
   interface_pools:cleanup()
   host_pool_pools:cleanup()
   local_network_pools:cleanup()
   active_monitoring_pools:cleanup()
end

-- ##############################################

return pool_import_export
