--
-- (C) 2019-21 - ntop.org
--

-- ##############################################

package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/check_templates/?.lua;" .. package.path

-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local check_template = require "check_template"
local http_lint = require "http_lint"

-- ##############################################

local items_list = classes.class(check_template)

-- ##############################################

items_list.meta = {
}

-- ##############################################

-- @brief Prepare an instance of the template
-- @return A table with the template built
function items_list:init(check)
   -- Call the parent constructor
   self.super:init(check)
end

function items_list:parseConfig(conf)
   return http_lint.validateListItems(self._check, conf)
end

-- #######################################################

function items_list:describeConfig(hooks_conf)
   if((not hooks_conf.all) or (not hooks_conf.all.script_conf)) then
      return '' -- disabled, nothing to show
   end

   local items = hooks_conf.all.script_conf.items or {}

   return table.concat(items, ", ")
end

-- #######################################################

return items_list
