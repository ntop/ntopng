--
-- (C) 2013-26 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local rest_utils    = require "rest_utils"
local ts_info       = require "timeseries_info"

--
-- Returns the community timeseries schema definitions.
-- Example: curl -u admin:admin http://localhost:3000/lua/rest/v2/get/ntopng/timeseries.lua
--

local res = ts_info.retrieve_community_timeseries()

rest_utils.answer(rest_utils.consts.success.ok, res)
