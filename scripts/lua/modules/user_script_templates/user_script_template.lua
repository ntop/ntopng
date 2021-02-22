--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

-- Import the classes library.
local classes = require "classes"

-- ##############################################

local user_script_template = classes.class()

-- ##############################################

function user_script_template:init(user_script)
   self._user_script = user_script
end

-- ##############################################

function user_script_template:parseConfig(conf)
  return true, conf
end

-- ##############################################

function user_script_template:describeConfig(hooks_conf)
  return ''
end

-- ##############################################

-- @brief Render user script HTML templates for all the available user script hooks
--        To locate an HTML template file, user script gui.input_builder variable is taken and
--        concatenated with ".template". For example, user script long_lived.lua has gui.input_builder == "long_lived"
--        will cause template "long_lived.template" to be located and then rendered.
-- @return Rendered templates in a table whose keys are hook names and whose values are rendered templates.
function user_script_template:render(hooks_conf)
   local res = {}
   local plugins_utils = require "plugins_utils"

   for hook, hook_conf in pairs(hooks_conf) do
      res[hook] = plugins_utils.renderTemplate(self._user_script.plugin.key, self._user_script.gui.input_builder..".template", hook_conf)
   end

   return res
end

-- ##############################################

return user_script_template

-- ##############################################
