--
-- (C) 2013-26 - ntop.org
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

return check_template

-- ##############################################
