--
-- (C) 2019-21 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local checks = require("checks")
local alert_consts = require "alert_consts"

-- #################################################################

local function dummy()
   -- Nothing to do here, the plugin is only meant to set a preference which is then
   -- read from C.
   return
end

-- #################################################################

local script = {
   -- Script category
   category = checks.check_categories.network,
   severity = alert_consts.get_printable_severities().warning,

   -- Off by default
   default_enabled = false,

   -- NOTE: hooks defined below
   hooks = {
      min = dummy
   },

   gui = {
      i18n_title = "alerts_dashboard.mac_ip_association_change",
      i18n_description = "alerts_dashboard.mac_ip_association_change_descr",
   }
}

-- #################################################################

local function update_ip_reassignment(enabled)
   -- For each interface, get its pool configuration, and check whether this script is enabled or not
   for ifid, _ in pairs(interface.getIfNames()) do
      -- Set the in-memory pref for the interface
      interface.updateIPReassignment(tonumber(ifid), enabled == true)
   end

   return true
end

-- #################################################################

function script.onLoad(hook, hook_config)
   update_ip_reassignment(hook_config and hook_config.enabled)
end

-- #################################################################

function script.onUnload(hook, hook_config)
   update_ip_reassignment(hook_config and hook_config.enabled)
end

-- #################################################################

function script.onEnable(hook, hook_config)
   update_ip_reassignment(hook_config and hook_config.enabled)
end

-- #################################################################

function script.onDisable(hook, hook_config)
   update_ip_reassignment(hook_config and hook_config.enabled)
end

-- #################################################################

return script
