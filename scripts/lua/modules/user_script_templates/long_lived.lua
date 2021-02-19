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

local long_lived = classes.class(user_script_template)

-- ##############################################

long_lived.meta = {
}

-- ##############################################

-- @brief Prepare an instance of the template
-- @return A table with the template built
function long_lived:init(user_script)
   -- Call the parent constructor
   self.super:init(user_script)
end

-- #######################################################

function long_lived:parseConfig(script, conf)
  if(tonumber(conf.min_duration) == nil) then
    return false, "bad min_duration value"
  end

  return http_lint.validateListItems(script, conf)
end

-- #######################################################

function long_lived:describeConfig(script, hooks_conf)
  if not hooks_conf.all then
    return '' -- disabled, nothing to show
  end

  local conf = hooks_conf.all.script_conf
  local msg = i18n("user_scripts.long_lived_flows_descr", {
    duration = secondsToTime(conf.min_duration),
  })

  if(not table.empty(conf.items)) then
    msg = msg .. ". " .. i18n("user_scripts.exceptions", {exceptions = table.concat(conf.items, ', ')})
  end

  return(msg)
end

-- #######################################################

return long_lived
