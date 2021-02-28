--
-- (C) 2019-21 - ntop.org
--

-- ##############################################

package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/user_script_templates/?.lua;" .. package.path

-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local user_script_template = require "user_script_template"
local http_lint = require "http_lint"

-- ##############################################

local multi_select = classes.class(user_script_template)

-- ##############################################

multi_select.meta = {
}

-- ##############################################

-- @brief Prepare an instance of the template
-- @return A table with the template built
function multi_select:init(user_script)
   -- Call the parent constructor
   self.super:init(user_script)
end

-- #######################################################

function multi_select:parseConfig(conf)
  return http_lint.validateListItems(self._user_script, conf)
end

-- #######################################################

function multi_select:describeConfig(hooks_conf)
  if (not hooks_conf.all) then
    return '' -- disabled, nothing to show
  end

  local conf = hooks_conf.all.script_conf

  local msg = ''
  if not table.empty(conf.items) then

    local temp_msg = {}
    local groups = self._user_script.gui.groups

    -- build a string containing selected elements separated by comma
    for _, group in ipairs(groups) do
      local elements = group.elements
      for _, element in ipairs(elements) do

        local id = element[1]
        local label = element[2]

        if table.has_key(conf.items, id) then
          -- if the label is nil then use the id
          table.insert(temp_msg, label or id)
        end
      end
    end

    msg = table.concat(temp_msg, ', ')
  end

  return (msg)
end

-- #######################################################

return multi_select
