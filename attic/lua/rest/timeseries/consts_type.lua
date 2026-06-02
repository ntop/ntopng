--
-- (C) 2013-26 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local rest_utils = require "rest_utils"
local timeseries_info = require "timeseries_info"
require "lua_utils_gui"

local rc = rest_utils.consts.success.ok
local ifid = tostring(_GET["ifid"] or interface.getId())
local query = _GET["query"] or ''
local host = _GET["host"]
local asn = _GET["asn"]
local pool = _GET["pool"]
local vlan = _GET["vlan"]
local mac = _GET["mac"]
local subnet = _GET["subnet"]
local device = _GET["device"]
local port = _GET["port"]
local blacklist_name = _GET["blacklist_name"]
local epoch_begin = _GET["epoch_begin"]
local epoch_end = _GET["epoch_end"]
local if_index = _GET["if_index"]
local profile = _GET["profile"]

-- flow 5-tuple tags (used by flow:hr_traffic schema)
local cli_ip     = _GET["cli_ip"]
local srv_ip     = _GET["srv_ip"]
local cli_port   = _GET["cli_port"]
local srv_port   = _GET["srv_port"]
local protocol   = _GET["protocol"]
local first_seen = _GET["first_seen"]

local res = {}

if ifid then
    interface.select(ifid)
end

if isEmptyString(query) then
    rest_utils.answer(rest_utils.consts.err.invalid_args)
end

local tags = {
    ifid       = ifid,
    host       = host,
    asn        = asn,
    pool       = pool,
    vlan       = vlan,
    mac        = mac,
    subnet     = subnet,
    device     = device,
    port       = port,
    blacklist_name = blacklist_name,
    if_index   = if_index,
    profile    = profile,
    epoch_begin = tonumber(epoch_begin),
    epoch_end  = tonumber(epoch_end),
    -- flow 5-tuple tags
    cli_ip     = cli_ip,
    srv_ip     = srv_ip,
    cli_port   = cli_port,
    srv_port   = srv_port,
    protocol   = protocol,
    first_seen = first_seen,
}

-- For flow_aggr: convert GET params to filters so that any flowfilter
-- reaches clickhouse_utils.formatWhere dinamically/generically
if query == "flow_aggr" then
    local skip = { ifid=true, query=true, epoch_begin=true, epoch_end=true }
    for key, val in pairs(_GET) do
        if not skip[key] and not isEmptyString(val) then
            tags[key] = val
        end
    end
end

res = table.merge(res, timeseries_info.getTimeseries(tags, query))
rest_utils.answer(rc, res)
