--
-- (C) 2020 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/import_export/?.lua;" .. package.path
package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils" 
local import_export = require "import_export"
local json = require "dkjson"
local endpoints = require "endpoints"
local recipients = require "recipients"
local notification_policies = require "notification_policies"
local rest_utils = require "rest_utils"

-- ##############################################

local notifications_import_export = {}

-- ##############################################

function notifications_import_export:create(args)
    -- Instance of the base class
    local _notifications_import_export = import_export:create()

    -- Subclass using the base class instance
    self.key = "notifications"
    -- self is passed as argument so it will be set as base class metatable
    -- and this will actually make it possible to override functions
    local _notifications_import_export_instance = _notifications_import_export:create(self)

    -- Compute

    -- Return the instance
    return _notifications_import_export_instance
end

-- ##############################################

-- @brief Import configuration
-- @param conf The configuration to be imported: { endpoints = ..., policies = ... } (see export),
--        or the endpoints array only, exported before the notification policies (their recipients
--        carry the filters, that become policies)
-- @return A table with a key "success" set to true is returned on success. A key "err" is set in case of failure, with one of the errors defined in rest_utils.consts.err.
function notifications_import_export:import(conf)
   local res = {}
   local success = endpoints.add_configs_with_recipients(conf.endpoints or conf)

   -- The policies, with the ids of the imported recipients
   for _, policy in ipairs(conf.policies or {}) do
      policy.recipient_ids = {}

      for _, recipient_name in ipairs(policy.recipient_names or {}) do
         local recipient = recipients.get_recipient_by_name(recipient_name)

         if recipient then
            policy.recipient_ids[#policy.recipient_ids + 1] = recipient.recipient_id
         end
      end

      if notification_policies.add_policy(policy).status ~= "OK" then
         success = false
      end
   end

   if not success then
      res.err = rest_utils.consts.err.partial_import
   else
      res.success = true
   end

   return res
end

-- ##############################################

-- @brief Export configuration
-- @return The current configuration: the endpoints with their recipients, and the policies
--         (with the recipient names: the ids change on import)
function notifications_import_export:export()
   local recipient_names = {}
   for _, recipient in ipairs(recipients.get_all_recipients()) do
      recipient_names[recipient.recipient_id] = recipient.recipient_name
   end

   local policies = notification_policies.get_all_policies()
   for _, policy in ipairs(policies) do
      policy.recipient_names = {}

      for _, recipient_id in ipairs(policy.recipient_ids) do
         policy.recipient_names[#policy.recipient_names + 1] = recipient_names[recipient_id]
      end

      policy.policy_id = nil
      policy.recipient_ids = nil
   end

   return {
      endpoints = endpoints.get_configs_with_recipients(),
      policies = policies,
   }
end

-- ##############################################

-- @brief Reset configuration
function notifications_import_export:reset()
   endpoints.reset_configs()
   recipients.cleanup()
end

-- ##############################################

return notifications_import_export
