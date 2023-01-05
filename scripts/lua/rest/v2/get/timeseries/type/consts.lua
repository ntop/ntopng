--
-- (C) 2013-23 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local rest_utils = require "rest_utils"
local timeseries_info = require "timeseries_info"

local rc = rest_utils.consts.success.ok
local ifid = tostring(_GET["ifid"] or interface.getId())
local query = _GET["query"] or ''
local host = _GET["host"]
local asn = _GET["asn"]
local pool = _GET["pool"]
local vlan = _GET["vlan"]
local mac = _GET["mac"]
local subnet = _GET["subnet"]

local res = {}

if ifid then
  interface.select(ifid)
end

if isEmptyString(query) then
  rest_utils.answer(rest_utils.consts.err.invalid_args)
end

local tags = {
  ifid = ifid,
  host = host,
  asn  = asn,
  pool = pool,
  vlan = vlan,
  mac  = mac,
  subnet = subnet,
}

res = table.merge(res, timeseries_info.retrieve_specific_timeseries(tags, query))
rest_utils.answer(rc, res)
