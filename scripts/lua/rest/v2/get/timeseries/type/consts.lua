--
-- (C) 2013-22 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local rest_utils = require "rest_utils"
local timeseries_info = require "timeseries_info"

local rc = rest_utils.consts.success.ok
local ifid = _GET["ifid"]

local res = {}

if ifid then
  interface.select(ifid)
end

res = table.merge(res, timeseries_info.get_interface_timeseries())      
rest_utils.answer(rc, res)
