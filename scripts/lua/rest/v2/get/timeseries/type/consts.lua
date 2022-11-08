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
local asn = _GET["asn"]
local pool = _GET["pool"]
local vlan = _GET["vlan"]
local mac = _GET["mac"]

local res = {}

if ifid then
  interface.select(ifid)
end

local tags = {
  ifid = ifid,
  host = host,
  asn  = asn,
  pool = pool,
  vlan = vlan,
  mac  = mac,
}

res = table.merge(res, timeseries_info.retrieve_specific_timeseries(tags, query))
rest_utils.answer(rc, res)
