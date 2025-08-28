--
-- (C) 2013-25 - ntop.org
--
dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local format_utils = require "format_utils"
local as_utils = require "as_utils"
local rest_utils = require "rest_utils"
local json = require("dkjson")
require "lua_utils"

--
-- Get AS Name from IP
-- Example: curl -u admin:admin -H "Content-Type: application/json" http://localhost:3000/lua/rest/v2/get/asn/get_as_data.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

-- Get from redis the throughput type bps or pps
local throughput_type = getThroughputType()
local now = os.time()

interface.select(ifname)
local selected_asn = _GET["show_as"]
local check_as = nil

if not isEmptyString(selected_asn) then
    local customer_as, sub_customer_as, remote_as =
        as_utils.getAllConfigurations()

    if selected_asn == "my_as" then
        check_as = customer_as
    elseif selected_asn == "my_customer_as" then
        check_as = sub_customer_as
    elseif selected_asn == "remote_as" then
        check_as = remote_as
    end
end

local asn = tonumber(_GET["asn"])
local as_info;

if (asn ~= nil) then
    as_info = interface.getASInfo(asn)

    if (as_info) then as_info = {as_info} end
else
    as_info = interface.getASesInfo({detailsLevel = "high"})
    as_info = as_info["ASes"]
end

local res = {}

if as_info ~= nil then
    for key, value in pairs(as_info) do
        local record = {}
        local add_record = true

        local bytes_sent = value["bytes.sent"]
        local bytes_rcvd = value["bytes.rcvd"]

        record["asn"] = value["asn"]
        record["avg_host_score"] = math.floor(value["score"] /
                                                  value["num_hosts"])
        record["bytes_sent"] = bytes_sent
        record["bytes_rcvd"] = bytes_rcvd
        record["alerted_flows"] = value["alerted_flows"]["total"]
        record["traffic"] = bytes_sent + bytes_rcvd
        record["seen_since"] = value["seen.first"]
        record["score"] = value["score"]
        record["num_hosts"] = value["num_hosts"]
        record["throughput"] = value["throughput_bps"]
        record["asname"] = value["asname"]

        if value["asn"] == 0 then record["asname"] = "Private hosts" end

        record["breakdown"] = {bytes_sent = bytes_sent, bytes_rcvd = bytes_rcvd}

        if check_as then
            if not check_as[tostring(value["asn"])] then
                add_record = false
            end
        end

        if add_record then
            table.insert(res, record)
        end
    end
end

-- sort by asn number ascending
table.sort(res, function(a, b)
    return a.asn < b.asn
end)

rest_utils.answer(rest_utils.consts.success.ok, res)
