--
-- (C) 2013-24 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path

local host_pools = require "host_pools"
local pools_rest_utils = require "pools_rest_utils"

--
-- Add host pool
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{"pool_name":"TestPool","pool_members":"192.168.223.128/32@0,192.168.223.129/32@0"}' http://localhost:3000/lua/rest/v2/add/host/pool.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

pools_rest_utils.add_pool(host_pools)
