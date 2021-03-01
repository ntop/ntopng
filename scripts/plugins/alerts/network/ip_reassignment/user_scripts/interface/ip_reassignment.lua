--
-- (C) 2019-21 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local user_scripts = require("user_scripts")

-- #################################################################

-- Used to remember when the preferences are reloaded
local IP_REASSIGNMENT_PREF_UPDATED = "ntopng.cache.ip_reassignment_pref_updated"

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

function script.setup()
   local pref_updated = ntop.getCache(IP_REASSIGNMENT_PREF_UPDATED)

   -- If in-memory settings for interfaces have not yet been updated...
   if pref_updated ~= "1" then
      -- Fetch the configsets
      local configsets = user_scripts.getConfigsets()
      local iface_config = user_scripts.getConfigById(configsets, user_scripts.DEFAULT_CONFIGSET_ID --[[ TODO: remove when single configset will be implemented --]], "interface")

      -- For each interface, get its pool configuration, and check whether this script is enabled or not
      for ifid, _ in pairs(interface.getIfNames()) do
	 local conf = user_scripts.getTargetHookConfig(iface_config, "ip_reassignment", "min")
	 local enabled = conf and conf.enabled

	 -- Set the in-memory pref for the interface
	 interface.updateIPReassignment(tonumber(ifid), enabled)
      end

      -- Don't redo this code, unless a script.on<Something> event marks the configuration as changed
      ntop.setCache(IP_REASSIGNMENT_PREF_UPDATED, "1")
   end

   return true
end

-- #################################################################

function script.onLoad(hook, hook_config, configset_id)
   ntop.delCache(IP_REASSIGNMENT_PREF_UPDATED)
end

-- #################################################################

function script.onUnload(hook, hook_config, configset_id)
   ntop.delCache(IP_REASSIGNMENT_PREF_UPDATED)
end

-- #################################################################

function script.onEnable(hook, hook_config, configset_id)
   ntop.delCache(IP_REASSIGNMENT_PREF_UPDATED)
end

-- #################################################################

function script.onDisable(hook, hook_config, configset_id)
   ntop.delCache(IP_REASSIGNMENT_PREF_UPDATED)
end

-- #################################################################

return script
