--
-- (C) 2019-22 - ntop.org
--

-- ##############################################

package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/check_templates/?.lua;" .. package.path

-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local check_template = require "check_template"

-- ##############################################

local multi_threshold_cross = classes.class(check_template)

-- ##############################################

multi_threshold_cross.meta = {
}

-- ##############################################

-- @brief Prepare an instance of the template
-- @return A table with the template built
function multi_threshold_cross:init(check)
   -- Call the parent constructor
   self.super:init(check)
end

-- #######################################################

function multi_threshold_cross:parseConfig(conf)
  return true, conf
end

-- #######################################################

function multi_threshold_cross:describeConfig(hooks_conf)
  local configured_threshold = hooks_conf.all.script_conf
  local msg = ''

  for field, value in pairs(configured_threshold) do
    msg = msg .. i18n(field) .. ": " .. value.threshold .. "%, " 
  end

  return msg
end

-- #######################################################

return multi_threshold_cross
