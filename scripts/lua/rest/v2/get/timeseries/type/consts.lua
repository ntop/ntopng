--
-- (C) 2013-22 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local rest_utils = require "rest_utils"
local timeseries_info = require "timeseries_info"

local rc = rest_utils.consts.success.ok
local ifid = tostring(_GET["ifid"] or interface.getId())
local query = _GET["query"]
local host = _GET["host"]

local res = {}

if ifid then
  interface.select(ifid)
end

local tags = {
  ifid = ifid,
  host = host
}

if query == "ifid" then
  res = table.merge(res, timeseries_info.get_interface_timeseries(tags))
elseif query == "host" then
  res = table.merge(res, timeseries_info.get_host_timeseries(tags))
elseif query == "mac" then
  res = table.merge(res, timeseries_info.get_mac_timeseries(tags))
end
rest_utils.answer(rc, res)
