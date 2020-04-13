--
-- (C) 2020 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require ("lua_utils")

local ifid              = _GET["ifid"]
local key_ip            = _GET["key_ip"]
local key_mac           = _GET["key_mac"]
local key_asn           = _GET["key_asn"]
local key_metric        = _GET["key_metric"]

local json = require("dkjson")
local datasources_utils = require("datasources_utils")

math.randomseed(os.time())

sendHTTPContentTypeHeader('application/json')

local function reportError(msg)
    print(json.encode({ error = msg, success = false, csrf = ntop.getRandomCSRFValue() }))
end

interface.select(ifname)
local hosts_info =  interface.getHostsInfo(false, "column_traffic")
local hosts_stats = hosts_info["hosts"]

local total = 0
local top_key = nil
local top_value = 0
local max_num_entries = 10
local _hosts_stats = {}

for key, value in pairs(hosts_stats) do

    local host_info = hostkey2hostinfo(key)
    local bytes = value["bytes.sent"] + value["bytes.rcvd"]
    local is_broadcast = false

    if (bytes ~= nil) then

        is_broadcast = (host_info["host"] == "255.255.255.255")
        _hosts_stats[bytes] = (is_broadcast) and "Broadcast" or key

        if ((top_value < bytes) or (top_key == nil)) then
            top_key = key
            top_value = bytes
        end

        total = total + bytes
    end
end

local threshold = (total * 5) / 100
local accumulator = 0
local response = {}
local counter = 0

for key, value in pairsByKeys(_hosts_stats, rev) do

    if (key < threshold) then break end
    response[#response + 1] = { label = value, value = key }

    accumulator = accumulator + key
    counter = counter + 1

    if (counter == max_num_entries) then break end
end

if ((counter == 0) and (top_key ~= nil)) then
    response[#response + 1] = {top_key, top_value}
    accumulator = accumulator + top_value
end

if (accumulator < total) then
    response[#response + 1] = {label = "Other", value = ((total - accumulator))}
end

print(json.encode(datasources_utils.prepareResponse(response)))