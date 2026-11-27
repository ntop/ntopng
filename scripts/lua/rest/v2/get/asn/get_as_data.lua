--
-- (C) 2013-26 - ntop.org
--
dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "http_lint"
local format_utils = require "format_utils"
local as_utils = require "as_utils"
local rest_utils = require "rest_utils"

--
-- The ASes of an interface with their traffic, live or historical (is_live=false, ClickHouse)
-- Optional paging, as the GUI table asks it (start, length, sort, order, map_search): only the rows of
-- the page, recordsTotal = the rows matching the search. Without length: every row.
-- Example: curl -u admin:admin -H "Content-Type: application/json" "http://localhost:3000/lua/rest/v2/get/asn/get_as_data.lua?ifid=1&start=0&length=10&sort=traffic&order=desc"
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

-- Fields the live rows can be sorted by: column id of the GUI table (as_stats.json) or field of the row -> field
local LIVE_SORT_FIELDS = {
    as_number = "asn", asn = "asn", name = "asname", asname = "asname", num_hosts = "num_hosts",
    score = "score", alerted_flows = "alerted_flows", throughput = "throughput", traffic = "traffic",
}

local ifid = _GET["ifid"]
local epoch_begin = _GET["epoch_begin"] or 0
local epoch_end = _GET["epoch_end"] or 0
local is_live = toboolean(_GET["is_live"] or true)
local selected_asn = _GET["show_as"]
local interface_role = _GET["interface_role"]
local page = {
    start = tonumber(_GET["start"]) or 0,
    length = tonumber(_GET["length"]),
    sort = _GET["sort"],
    order = _GET["order"],
    search = _GET["map_search"],
}

-- interface.select silently falls back to an allowed interface: check it
if not isEmptyString(ifid) then
    interface.select(tostring(ifid))
    if tostring(interface.getId()) ~= tostring(ifid) then
        rest_utils.answer(rest_utils.consts.err.invalid_interface)
        return
    end
end

if not is_live and not hasClickHouseSupport() then
    rest_utils.answer(rest_utils.consts.err.clickhouse_missing)
    return
end

local options = {
    -- The selected interface, never the raw parameter (used in the historical query)
    ifid = interface.getId(),
    epoch_begin = epoch_begin,
    epoch_end = epoch_end,
    selected_asn = selected_asn,
    interface_role = interface_role,
}

-- The row of the table of an AS (live or historical statistics)
local function format_record(value)
    local record = {}
    local asn = tonumber(value["asn"])
    local bytes_sent = value["bytes.sent"]
    local bytes_rcvd = value["bytes.rcvd"]

    record["asn"] = asn
    if value["num_hosts"] then
        record["num_hosts"] = value["num_hosts"]
        record["avg_host_score"] = math.floor(value["score"] / value["num_hosts"])
    end
    record["bytes_sent"] = bytes_sent
    record["bytes_rcvd"] = bytes_rcvd
    if value["alerted_flows"] then
        record["alerted_flows"] = value["alerted_flows"]["total"]
    end
    if bytes_sent and bytes_rcvd then
        record["traffic"] = bytes_sent + bytes_rcvd
    end
    record["seen_since"] = tonumber(value["seen.first"])
    record["score"] = value["score"]
    record["throughput"] = value["throughput_bps"]
    -- ASN 0 (private hosts) has no name: the page shows its label
    if asn ~= 0 then
        record["asname"] = (not isEmptyString(value["asname"])) and value["asname"] or format_utils.getASDisplayName(asn)
    end

    record["breakdown"] = {
        bytes_sent = bytes_sent,
        bytes_rcvd = bytes_rcvd
    }

    record["breakdown_role"] = {
        bytes_other  = (value["bytes_other"] or 0),
        bytes_transit = (value["bytes_transit"] or 0),
        bytes_peering = (value["bytes_peering"] or 0),
        bytes_ix      = (value["bytes_ix"] or 0),
    }

    return record
end

-- Live: the ASes are in memory, searched (ASN number and name), sorted and paged here
local function live_page(records)
    local search = string.lower(as_utils.cleanASSearch(page.search))
    local private_hosts = string.lower(i18n("as_stats.private_hosts") or "")
    local found = {}

    for _, record in ipairs(records) do
        if (search == "") or string.find(tostring(record.asn), search, 1, true)
            or string.find(string.lower(record.asname or ""), search, 1, true)
            or ((record.asn == 0) and string.find(private_hosts, search, 1, true)) then
            found[#found + 1] = record
        end
    end

    if LIVE_SORT_FIELDS[page.sort] then
        local field = LIVE_SORT_FIELDS[page.sort]
        local desc = (page.order ~= "asc")
        local default = ternary(field == "asname", "", 0)

        table.sort(found, function(a, b)
            local va, vb = a[field] or default, b[field] or default

            if field == "asname" then
                va, vb = string.lower(va), string.lower(vb)
            end

            if va == vb then
                return a.asn < b.asn
            end

            return ternary(desc, va > vb, va < vb)
        end)
    end

    if not page.length then
        return found, #found
    end

    local rows = {}

    for i = page.start + 1, math.min(page.start + page.length, #found) do
        rows[#rows + 1] = found[i]
    end

    return rows, #found
end

local res = {}
local total = 0

if is_live then
    local records = {}

    for _, value in pairs(as_utils.retrieveASLiveTraffic(options) or {}) do
        records[#records + 1] = format_record(value)
    end

    res, total = live_page(records)
else
    -- Historical: ClickHouse aggregates, names, searches, sorts and pages the rows
    local rows

    rows, total = as_utils.retrieveASHistoricalPage(options, page)

    for _, value in ipairs(rows) do
        local record = format_record(value)

        record["is_in_memory"] = (interface.getASInfo(record.asn) ~= nil)
        res[#res + 1] = record
    end
end

-- Only the rows of the page
for _, record in ipairs(res) do
    as_utils.addASNConfiguration(record, record.asn)
end

rest_utils.extended_answer(rest_utils.consts.success.ok, res, {
    recordsTotal = total,
    recordsFiltered = total,
})
