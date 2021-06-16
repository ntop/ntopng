--
-- (C) 2020 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/import_export/?.lua;" .. package.path
package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils" 
local import_export = require "import_export"
local json = require "dkjson"
local rest_utils = require "rest_utils"
local checks = require "checks"
local recipients_mod = require "recipients"

local host_pools              = require "host_pools":create()
local flow_pools              = require "flow_pools":create()
local system_pools            = require "system_pools":create()
local mac_pools               = require "mac_pools":create()
local interface_pools         = require "interface_pools":create()
local host_pool_pools         = require "host_pool_pools":create()
local local_network_pools     = require "local_network_pools":create()
local active_monitoring_pools = require "active_monitoring_pools":create()
local snmp_device_pools       = require "snmp_device_pools":create()

local pool_instances = {
  ["host"] = host_pools,
  ["flow"] = flow_pools,
  ["system"] = system_pools,
  ["mac"] = mac_pools,
  ["interface"] = interface_pools,
  ["host_pool"] = host_pool_pools,
  ["local_network"] = local_network_pools,
  ["active_monitoring"] = active_monitoring_pools,
  ["snmp_device"] = snmp_device_pools,
}

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
   -- local recipients = recipients_mod.get_all_recipients()

   for pool_name, pool_list in pairs(conf) do
      if pool_instances[pool_name] ~= nil then
         local pool_instance = pool_instances[pool_name]

         for _, pool_conf in ipairs(pool_list) do
            -- Recipient lookup to remap the ID
            local recipients_ids = {}
            for _, recipient_details in pairs(pool_conf.recipients) do
               local recipient = recipients_mod.get_recipient_by_name(recipient_details.recipient_name)
               recipients_ids[#recipients_ids+1] = recipient.recipient_id 
               --tprint("Recipient "..recipient_details.recipient_name.." with ID "..recipient_details.recipient_id.." mapped to "..recipient.recipient_id)
            end

            -- Add Pool
            local new_pool_id = pool_instance:add_pool(
               pool_conf.name,
               pool_conf.members,
               recipients_ids
            )

	    if not new_pool_id then
	       -- Pool not created, it is likely it exists already,
	       -- trying importing/merging members and recipients
	       local ret, err = pool_instance:add_to_pool(
	          pool_conf.name,
		  pool_conf.members,
		  recipients_ids)
	    end
         end
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
function pool_import_export:export()
   local conf = {}

   for pool_name, pool_instance in pairs(pool_instances) do
      conf[pool_name] = pool_instance:get_all_pools() or {}
   end

   return conf
end

-- ##############################################

-- @brief Reset configuration
function pool_import_export:reset()
   for pool_name, pool_instance in pairs(pool_instances) do
      pool_instance:cleanup()
   end
end

-- ##############################################

return pool_import_export
