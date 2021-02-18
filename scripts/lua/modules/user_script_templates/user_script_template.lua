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

function user_script_template:init()
end

-- ##############################################

function user_script_template:parseConfig(script, conf)
  return true, conf
end

-- ##############################################

function user_script_template:describeConfig(script, hooks_conf)
  return ''
end

-- ##############################################

return user_script_template

-- ##############################################
