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

local elephant_flows = classes.class(user_script_template)

-- ##############################################

elephant_flows.meta = {
}

-- ##############################################

-- @brief Prepare an instance of the template
-- @return A table with the template built
function elephant_flows:init(user_script)
   -- Call the parent constructor
   self.super:init(user_script)
end

-- #######################################################

function elephant_flows:parseConfig(script, conf)
  if(tonumber(conf.l2r_bytes_value) == nil) then
    return false, "bad l2r_bytes_value value"
  end

  if(tonumber(conf.r2l_bytes_value) == nil) then
    return false, "bad r2l_bytes_value value"
  end

  return http_lint.validateListItems(script, conf)
end

-- #######################################################

function elephant_flows:describeConfig(script, hooks_conf)
  if not hooks_conf.all then
    return '' -- disabled, nothing to show
  end

  -- E.g. '> 1 GB (L2R), > 2 GB (R2L), except: Datatransfer, Git'
  local conf = hooks_conf.all.script_conf
  local msg = i18n("user_scripts.elephant_flows_descr", {
    l2r_bytes = bytesToSize(conf.l2r_bytes_value),
    r2l_bytes = bytesToSize(conf.r2l_bytes_value),
  })

  if not table.empty(conf.items) then
    msg = msg .. ". " .. i18n("user_scripts.exceptions", {exceptions = table.concat(conf.items, ', ')})
  end

  return(msg)
end


-- #######################################################

return elephant_flows
