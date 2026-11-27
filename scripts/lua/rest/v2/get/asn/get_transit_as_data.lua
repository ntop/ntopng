--
-- (C) 2026 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "http_lint"
local format_utils = require "format_utils"
local as_utils = require "as_utils"
local rest_utils = require "rest_utils"

--
-- Traffic carried by the transit ASNs, per destination ASN: live or historical (ClickHouse)
-- Example: curl -u admin:admin "http://localhost:3000/lua/rest/v2/get/asn/get_transit_as_data.lua?ifid=0&is_live=true"
--

local ifid = _GET["ifid"]
local is_live = toboolean(_GET["is_live"] or true)

-- interface.select silently falls back to an allowed interface: check it
if not isEmptyString(ifid) then
    interface.select(tostring(ifid))
    if tostring(interface.getId()) ~= tostring(ifid) then
        rest_utils.answer(rest_utils.consts.err.invalid_interface)
        return
    end
end

local options = {
    -- The selected interface, never the raw parameter (used in the historical query)
    ifid = interface.getId(),
    epoch_begin = _GET["epoch_begin"] or 0,
    epoch_end = _GET["epoch_end"] or 0,
    interface_role = _GET["interface_role"],
}

local transit_rows
if is_live then
    transit_rows = as_utils.retrieveTransitASLiveTraffic(options)
elseif hasClickHouseSupport() then
    transit_rows = as_utils.retrieveTransitASHistoricalTraffic(options)
else
    rest_utils.answer(rest_utils.consts.err.clickhouse_missing)
    return
end

-- The same ASN is in many rows: each AS is formatted once, with the fields of the get_as_data.lua rows
local as_by_asn = {}
local function get_as(asn)
    if not as_by_asn[asn] then
        local as = {
            asn = asn,
            asname = format_utils.getASDisplayName(asn),
        }
        as_utils.addASNConfiguration(as, asn)
        as_by_asn[asn] = as
    end
    return as_by_asn[asn]
end

local res = {}
for _, row in ipairs(transit_rows) do
    local transit_asn = tonumber(row.transit_asn)
    local dst_asn = tonumber(row.dst_asn)
    local traffic = tonumber(row.traffic)
    local transit_traffic = tonumber(row.transit_traffic)

    res[#res + 1] = {
        transit_asn = transit_asn,
        transit_as = get_as(transit_asn),
        dst_asn = dst_asn,
        dst_as = get_as(dst_asn),
        traffic = traffic,
        transit_traffic = transit_traffic,
        -- Share of the traffic of the transit ASN going to this destination ASN
        transit_share = (transit_traffic > 0) and (traffic * 100 / transit_traffic) or 0,
    }
end

rest_utils.answer(rest_utils.consts.success.ok, res)
