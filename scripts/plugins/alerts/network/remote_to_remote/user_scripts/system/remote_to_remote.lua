--
-- (C) 2019-20 - ntop.org
--

local flow_consts = require("flow_consts")
local user_scripts = require("user_scripts")

-- #################################################################

local REMOTE_TO_REMOTE_KEY = "ntopng.prefs.remote_to_remote_alerts"

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
      i18n_title = "remote_to_remote.title",
      i18n_description = "remote_to_remote.description",
   }
}

-- #################################################################

function script.onLoad(hook, hook_config)
   if hook_config and hook_config.enabled then
      ntop.setPref(REMOTE_TO_REMOTE_KEY, "1")
   end

end

-- #################################################################

function script.onUnload(hook, hook_config)
   ntop.delCache(REMOTE_TO_REMOTE_KEY)
end

-- #################################################################

function script.onEnable(hook, hook_config)
   ntop.setPref(REMOTE_TO_REMOTE_KEY, "1")
end

-- #################################################################

function script.onDisable(hook, hook_config)
   ntop.delCache(REMOTE_TO_REMOTE_KEY)
end

-- #################################################################

return script
