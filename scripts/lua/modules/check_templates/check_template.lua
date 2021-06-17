--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

-- Import the classes library.
local classes = require "classes"

-- ##############################################

local check_template = classes.class()

-- ##############################################

function check_template:init(check)
   self._check = check
end

-- ##############################################

function check_template:parseConfig(conf)
  return true, conf
end

-- ##############################################

function check_template:describeConfig(hooks_conf)
  return ''
end

-- ##############################################

-- @brief Render user script HTML templates for all the available user script hooks
--        To locate an HTML template file, user script gui.input_builder variable is taken and
--        concatenated with ".template". For example, user script long_lived.lua has gui.input_builder == "long_lived"
--        will cause template "long_lived.template" to be located and then rendered.
-- @return Rendered templates in a table whose keys are hook names and whose values are rendered templates.
function check_template:render(hooks_conf)
   local res = {}
   local plugins_utils = require "plugins_utils"

   -- check if the input_builder is defined
   -- TODO: define empty template for the checks without input_builder/template
   if (isEmptyString(self._check.gui.input_builder)) then
      return { templates = {{hook = "all", template = ""}}, check = self._check }
   end

   -- Use ipairs on script type hooks to make sure hooks are always returned sorted and in the same order
   for _, hook in ipairs(table.merge({"all"} --[[ Hook "all" always go first --]], self._check.script_type.hooks)) do
      local hook_conf =  hooks_conf[hook]

      -- If the hook is among those passed as parameter, add it to the result
      if hook_conf then
	      res[#res + 1] = {
            hook = hook, -- Hook Name
            template = plugins_utils.renderTemplate(self._check.plugin.key, self._check.gui.input_builder..".template", {
               hook_conf = hook_conf,
               hook_name = hook,
               check = self._check
            }) -- Rendered Template
      }
      end
   end

   return {
      templates = res,
      check = self._check
   }
end

-- ##############################################

return check_template

-- ##############################################
