--
-- (C) 2019-21 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local user_scripts = require("user_scripts")

-- #################################################################

local function dummy()
   -- Nothing to do here, the plugin is only meant to set a preference which is then
   -- read from C.
   return
end

-- #################################################################

local script = {
   -- Script category
   category = user_scripts.script_categories.network,

   -- Off by default
   default_enabled = false,

   -- NOTE: hooks defined below
   hooks = {
      min = dummy
   },

   gui = {
      i18n_title = "ip_reassignment.title",
      i18n_description = "ip_reassignment.description",
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
