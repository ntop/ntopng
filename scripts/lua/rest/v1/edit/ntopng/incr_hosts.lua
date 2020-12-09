--
-- (C) 2013-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

local rest_utils = require("rest_utils")
local configuration_utils = require "configuration_utils"

-- #################################

local res = {}

-- Checking root privileges
if not isAdministrator() then
    rest_utils.answer(rest_utils.consts.err.not_granted)
    return
 end

-- #################################

--
-- Increase the max number of hosts or flows of the configuration file
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{}' http://localhost:3000/lua/rest/v1/edit/ntopng/incr_hosts.lua
--

if table.len(_POST) > 0 then 
    configuration_utils.increase_num_host_num_flows(true, false)
else
    rest_utils.answer(rest_utils.consts.err.bad_format)
end