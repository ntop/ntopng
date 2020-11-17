--
-- (C) 2020 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/system_config/?.lua;" .. package.path
package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils" 
local system_config = require "system_config"
local json = require "dkjson"
local rest_utils = require "rest_utils"

-- ##############################################

-- Example 
-- package.path = dirs.installdir .. "/scripts/lua/modules/system_config/?.lua;" .. package.path
-- -- Editable
-- local appliance_config = require "appliance_config":create(true)
-- -- Readable
-- local appliance_config = require "appliance_config":create()

-- ##############################################

local appliance_config = {}

-- ##############################################

function appliance_config:create(editable)
   -- Instance of the base class
   local _system_config = system_config:create()

   -- Subclass using the base class instance
   self.key = "appliance"
   -- self is passed as argument so it will be set as base class metatable
   -- and this will actually make it possible to override functions
   local _appliance_config = _system_config:create(self)

   if editable then
      _appliance_config:editable()
   else
      _appliance_config:readable()
   end

   -- Return the instance
   return _appliance_config
end

-- ##############################################

function appliance_config:guess_config()
   local config = {}

   -- TODO

   return config
end

-- ##############################################

return appliance_config
