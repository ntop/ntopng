--
-- (C) 2014-24 - ntop.org
--
-- ###############################################
if (pragma_once_lua_utils == true) then
    -- io.write(debug.traceback().."\n")
    -- avoid multiple inclusions
    return
end

pragma_once_lua_utils = true

local clock_start = os.clock()

dirs = ntop.getDirs()

package.path = dirs.installdir .. "/scripts/lua/modules/i18n/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/timeseries/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path

require "label_utils"
require "check_redis_prefs"
require "lua_trace"
require "lua_utils_generic"
require "ntop_utils"
require "locales_utils"
local l4_protocol_list = require "l4_protocol_list"
local format_utils = require "format_utils"

-- TODO: replace those globals with locals everywhere

secondsToTime = format_utils.secondsToTime
msToTime = format_utils.msToTime
bytesToSize = format_utils.bytesToSize
formatPackets = format_utils.formatPackets
formatFlows = format_utils.formatFlows
formatValue = format_utils.formatValue
pktsToSize = format_utils.pktsToSize
bitsToSize = format_utils.bitsToSize
round = format_utils.round
bitsToSizeMultiplier = format_utils.bitsToSizeMultiplier
format_high_num_value_for_tables = format_utils.format_high_num_value_for_tables
l4_keys = l4_protocol_list.l4_keys
format_name_value = format_utils.format_name_value

-- ##############################################

local cached_allowed_networks_set = nil

function hasAllowedNetworksSet()
    if (cached_allowed_networks_set == nil) then
        local nets = ntop.getAllowedNetworks()
        local allowed_nets = string.split(nets, ",") or {nets}
        cached_allowed_networks_set = false

        for _, net in pairs(allowed_nets) do
            if ((not isEmptyString(net)) and (net ~= "0.0.0.0/0") and (net ~= "::/0")) then
                cached_allowed_networks_set = true
                break
            end
        end
    end

    return (cached_allowed_networks_set)
end

-- ##############################################

function hasSoftwareUpdatesSupport()
    return (not ntop.isOffline() and isAdministrator() and ntop.isPackage() and not ntop.isWindows())
end

function __FILE__()
    return debug.getinfo(2, 'S').source
end
function __LINE__()
    return debug.getinfo(2, 'l').currentline
end

-- ##############################################

function findString(str, tofind)
    if (str == nil) then
        return (nil)
    end
    if (tofind == nil) then
        return (nil)
    end

    str1 = string.lower(string.gsub(str, "-", "_"))
    tofind1 = string.lower(string.gsub(tofind, "-", "_"))

    return (string.find(str1, tofind1, 1))
end

-- ##############################################

function findStringArray(str, tofind)
    if (str == nil) then
        return (nil)
    end
    if (tofind == nil) then
        return (nil)
    end
    local rsp = false

    for k, v in pairs(tofind) do
        str1 = string.gsub(str, "-", "_")
        tofind1 = string.gsub(v, "-", "_")
        if (str1 == tofind1) then
            rsp = true
        end

    end

    return (rsp)
end

-- ##############################################

--
-- Returns indexes to be used for string shortening. The portion of to_shorten between
-- middle_start and middle_end will be inside the bounds.
--
--    to_shorten: string to be shorten
--    middle_start: middle part begin index
--    middle_end: middle part begin index
--    maxlen: maximum length
--
function shortenInTheMiddle(to_shorten, middle_start, middle_end, maxlen)
    local maxlen = maxlen - (middle_end - middle_start)

    if maxlen <= 0 then
        return 0, string.len(to_shorten)
    end

    local left_slice = math.max(middle_start - math.floor(maxlen / 2), 1)
    maxlen = maxlen - (middle_start - left_slice - 1)
    local right_slice = math.min(middle_end + maxlen, string.len(to_shorten))

    return left_slice, right_slice
end

-- ##############################################

function shortHostName(name)
    local chunks = {name:match("(%d+)%.(%d+)%.(%d+)%.(%d+)")}
    if (#chunks == 4) then
        return (name)
    else
        local max_len = ntop.getPref("ntopng.prefs.max_ui_strlen")
        max_len = tonumber(max_len)
        if (max_len == nil) then
            max_len = 24
        end

        chunks = {name:match("%w+:%w+:%w+:%w+:%w+:%w+")}
        -- io.write(#chunks.."\n")
        if (#chunks == 1) then
            return (name)
        end

        if (string.len(name) < max_len) then
            return (name)
        else
            tot = 0
            n = 0
            ret = ""

            for token in string.gmatch(name, "([%w-]+).") do
                if (tot < max_len) then
                    if (n > 0) then
                        ret = ret .. "."
                    end
                    ret = ret .. token
                    tot = tot + string.len(token)
                    n = n + 1
                end
            end

            return (ret .. "...")
        end
    end

    return (name)
end

-- ##############################################

function _handleArray(name, sev)
    local id

    for id, _ in ipairs(name) do
        local l = name[id][1]
        local key = name[id][2]

        if (string.upper(key) == string.upper(sev)) then
            return (l)
        end
    end

    return (firstToUpper(sev))
end

-- ##############################################

function l4Label(proto)
    return (_handleArray(l4_keys, proto))
end

-- ##############################################

function l4_proto_to_id(proto_name)
    for _, proto in pairs(l4_keys) do
        if proto[1] == proto_name or proto[2] == proto_name then
            return (proto[3])
        end
    end
end

-- ##############################################

function l4_proto_to_string(proto_id)
    if not proto_id then
        return ""
    end
    if isEmptyString(proto_id) then
        return ""
    end

    proto_id_num = tonumber(proto_id)

    if proto_id_num == nil then
        -- Already string?
        return proto_id
    end

    for _, proto in pairs(l4_keys) do
        if proto[3] == proto_id_num then
            return proto[1], proto[2]
        end
    end

    return string.format("%d", proto_id_num)
end

-- ##############################################

-- Return the list of L4 proto (key = name, value = id)
function l4_proto_list()
    local list = {}

    for _, proto in pairs(l4_keys) do
        -- add L4 proto only
        if proto[2] ~= 'ip' and proto[2] ~= 'ipv6' then
            list[proto[1]] = proto[3]
        end
    end

    return list
end

-- ##############################################

function isScoreEnabled()
    return (ntop.isEnterpriseM() or ntop.isnEdgeEnterprise())
end

-- ##############################################

function hasTrafficReport()
    local ts_utils = require("ts_utils_core")
    local is_pcap_dump = interface.isPcapDumpInterface()

    return ((not is_pcap_dump) and (ts_utils.getDriverName() == "rrd") and ntop.isEnterpriseM())
end

function hasAlertsDisabled()
    _POST = _POST or {}
    return ((_POST["disable_alerts_generation"] ~= nil) and (_POST["disable_alerts_generation"] == "1")) or
               ((_POST["disable_alerts_generation"] == nil) and
                   (ntop.getPref("ntopng.prefs.disable_alerts_generation") == "1"))
end

-- ##############################################

function truncate(x)
    if (x == nil) then
        tprint(debug.traceback())
    end
    return x < 0 and math.ceil(x) or math.floor(x)
end

-- ##############################################

-- Note that the function below returns a string as returning a number
-- would not help as a new float would be returned
function toint(num)
    return string.format("%u", truncate(num))
end

-- ##############################################

function capitalize(str)
    return (str:gsub("^%l", string.upper))
end

-- ##############################################

local function starstring(len)
    local s = ""

    while (len > 0) do
        s = s .. "*"
        len = len - 1
    end

    return (s)
end

-- ##############################################

function obfuscate(str)
    local len = string.len(str)
    local in_clear = 2

    if (len <= in_clear) then
        return (starstring(len))
    else
        return (string.sub(str, 0, in_clear) .. starstring(len - in_clear))
    end
end

-- ##############################################

function isnumber(str)
    if ((str ~= nil) and (string.len(str) > 0) and (tonumber(str) ~= nil)) then
        return (true)
    else
        return (false)
    end
end

-- ##############################################

-- split
function split(s, delimiter)
    result = {};
    if (s ~= nil) then
        if delimiter == nil then
            -- No delimiter, split all characters
            for match in s:gmatch "." do
                table.insert(result, match);
            end
        else
            -- Split by delimiter
            for match in (s .. delimiter):gmatch("(.-)" .. delimiter) do
                table.insert(result, match);
            end
        end
    end
    return result;
end

-- ##############################################

function replace(str, o, n)
    return string.gsub(str, o, n)
end

-- ##############################################

function formatEpoch(epoch, full_time)
    return (format_utils.formatEpoch(epoch, full_time))
end

-- ##############################################

function isBroadMulticast(ip)
    if (ip == "0.0.0.0") then
        return true
    end
    -- print(ip)
    t = string.split(ip, "%.")
    -- print(table.concat(t, "\n"))
    if (t == nil) then
        return false -- Might be an IPv6 address
    else
        if (tonumber(t[1]) >= 224) then
            return true
        end
    end

    return false
end

-- ##############################################

function isBroadcastMulticast(ip)
    local ainfo = interface.getAddressInfo(ip)

    if (ainfo.is_multicast or ainfo.is_broadcast) then
        return true
    else
        return false
    end
end

-- ##############################################

function host2member(ip, vlan, prefix)
    if prefix == nil then
        if isIPv4(ip) then
            prefix = 32
        else
            prefix = 128
        end
    end

    return ip .. "/" .. tostring(prefix) .. "@" .. tostring(vlan)
end

-- ##############################################

function isLocal(host_ip)
    host = interface.getHostInfo(host_ip)

    if ((host == nil) or (host['localhost'] ~= true)) then
        return (false)
    else
        return (true)
    end
end

-- ##############################################

-- Windows fixes for interfaces with "uncommon chars"
function purifyInterfaceName(interface_name)
    -- io.write(debug.traceback().."\n")
    interface_name = string.gsub(interface_name, "@", "_")
    interface_name = string.gsub(interface_name, ":", "_")
    interface_name = string.gsub(interface_name, "/", "_")
    return (interface_name)
end

-- ##############################################

-- See datatype AggregationType in ntop_typedefs.h
function aggregation2String(value)
    if (value == 0) then
        return ("Client Name")
    elseif (value == 1) then
        return ("Server Name")
    elseif (value == 2) then
        return ("Domain Name")
    elseif (value == 3) then
        return ("Operating System")
    elseif (value == 4) then
        return ("Registrar Name")
    else
        return (value)
    end
end

-- #################################

-- Aggregates items below some edge
-- edge: minimum percentage value to create collision
-- min_col: minimum collision groups to aggregate
function aggregatePie(values, values_sum, edge, min_col)
    local edge = edge or 0.09
    min_col = min_col or 2
    local aggr = {}
    local other = i18n("other")
    local below_edge = {}

    -- Initial lookup
    for k, v in pairs(values) do
        if v / values_sum <= edge then
            -- too small
            below_edge[#below_edge + 1] = k
        else
            aggr[k] = v
        end
    end

    -- Decide if to aggregate
    for _, k in pairs(below_edge) do
        if #below_edge >= min_col then
            -- aggregate
            aggr[other] = aggr[other] or 0
            aggr[other] = aggr[other] + values[k]
        else
            -- do not aggregate
            aggr[k] = values[k]
        end
    end

    return aggr
end

-- ###########################################

function computeL7Stats(stats, show_breed, show_ndpi_category)
    local _ifstats = {}

    if (show_breed) then
        local breed_stats = {}

        for key, value in pairs(stats["ndpi"]) do
            local b = stats["ndpi"][key]["breed"]

            local traffic = stats["ndpi"][key]["bytes.sent"] + stats["ndpi"][key]["bytes.rcvd"]

            if (breed_stats[b] == nil) then
                breed_stats[b] = traffic
            else
                breed_stats[b] = breed_stats[b] + traffic
            end
        end

        for key, value in pairs(breed_stats) do
            _ifstats[key] = value
        end

    elseif (show_ndpi_category) then
        local ndpi_category_stats = {}

        for key, value in pairs(stats["ndpi_categories"]) do
            key = getCategoryLabel(key, value.category)
            local traffic = value["bytes"]

            if (ndpi_category_stats[key] == nil) then
                ndpi_category_stats[key] = traffic
            else
                ndpi_category_stats[key] = ndpi_category_stats[key] + traffic
            end
        end

        for key, value in pairs(ndpi_category_stats) do
            _ifstats[key] = value
        end

    else
        -- Add ARP to stats
        local arpBytes = 0
        if (stats["eth"] ~= nil) then
            arpBytes = stats["eth"]["ARP_bytes"]
            if (arpBytes > 0) then
                _ifstats["ARP"] = arpBytes
            end
        end

        for key, value in pairs(stats["ndpi"]) do
            local traffic = value["bytes.sent"] + value["bytes.rcvd"]
            if (key == "Unknown") then
                traffic = traffic - arpBytes
            end

            if (traffic > 0) then
                if (show_breed) then
                    _ifstats[value["breed"]] = traffic
                else
                    _ifstats[key] = traffic
                end
            end
        end
    end

    return _ifstats
end

-- ##############################################

function splitNetworkWithVLANPrefix(net_mask_vlan)
    local vlan = tonumber(net_mask_vlan:match("@(.+)"))
    local net_mask = net_mask_vlan:gsub("@.+", "")
    local prefix = tonumber(net_mask:match("/(.+)"))
    local address = net_mask:gsub("/.+", "")
    return address, prefix, vlan
end

-- ##############################################

function splitProtocol(proto_string)
    local parts = string.split(proto_string, "%.")
    local app_proto
    local master_proto

    if parts == nil then
        master_proto = proto_string
        app_proto = nil
    else
        master_proto = parts[1]
        app_proto = parts[2]
    end

    return master_proto, app_proto
end

-- ##############################################

function setHostNotes(host_info, notes)
    local host_key

    if type(host_info) == "table" then
        -- Note: we are not using hostinfo2hostkey which includes the
        -- vlan for backward compatibility, compatibility with
        -- the backend, and compatibility with the vpn scripts
        host_key = host_info["host"] -- hostinfo2hostkey(host_info)
    else
        host_key = host_info
    end

    ntop.setCache(getHostNotesKey(host_key), notes)
end

-- ##############################################

-- This function set the interface alias, return true if the
-- alias is set, false otherwise
function setInterfaceAlias(iface, alias)
    local ok = true

    if (isEmptyString(iface)) then
        ok = false
    end

    if (ok and (iface ~= alias) and not isEmptyString(alias)) then
        ntop.setCache(getInterfaceAliasKey(iface), alias)
    else
        ok = false
    end

    return ok
end

-- ##############################################

function setLocalNetworkAlias(network, alias)
    if ((network ~= alias) or isEmptyString(alias)) then
        ntop.setHashCache(getLocalNetworkAliasKey(), network, alias)
    else
        ntop.delHashCache(getLocalNetworkAliasKey(), network)
    end
end

-- ##############################################

function setVlanAlias(vlan_id, alias)
    if ((vlan_id ~= alias) or isEmptyString(alias)) then
        ntop.setHashCache(getVlanAliasKey(), vlan_id, alias)
    else
        ntop.delHashCache(getVlanAliasKey(), vlan_id)
    end
end

-- ##############################################

function isHostKey(key)
    local info = split(key, "@")
    -- Check format
    if not info or #info < 1 or #info > 2 then
        return false
    end
    -- Check IP format
    if isEmptyString(info[1]) or (not isIPv4(info[1]) and not isIPv6(info[1])) then
        return false
    end
    -- Check VLAN format (if any)
    if not isEmptyString(info[2]) and tonumber(info[2]) == nil then
        return false
    end
    -- Ok
    return true
end

-- ##############################################

function member2visual(member)
    local info = hostkey2hostinfo(member)
    local host = info.host
    local hlen = string.len(host)

    if string.ends(host, "/32") and isIPv4(string.sub(host, 1, hlen - 3)) then
        host = string.sub(host, 1, hlen - 3)
    elseif string.ends(host, "/128") and isIPv6(string.sub(host, 1, hlen - 4)) then
        host = string.sub(host, 1, hlen - 4)
    end

    return hostinfo2hostkey({
        host = host,
        vlan = info.vlan
    })
end

-- ##############################################

--
-- Catch the main information about an host from the host_info table and return the corresponding json.
-- Example:
--          hostinfo2json(host[key]), return a json string based on the host value
--          hostinfo2json(flow[key],"cli"), return a json string based on the client host information in the flow table
--          hostinfo2json(flow[key],"srv"), return a json string based on the server host information in the flow table
--
function hostinfo2json(host_info, host_type)
    local rsp = ''

    if (host_type == "cli") then
        if (host_info["cli.ip"] ~= nil) then
            rsp = rsp .. 'host: "' .. host_info["cli.ip"] .. '"'
        end
    elseif (host_type == "srv") then
        if (host_info["srv.ip"] ~= nil) then
            rsp = rsp .. 'host: "' .. host_info["srv.ip"] .. '"'
        end
    else
        if ((type(host_info) ~= "table") and (string.find(host_info, "@"))) then
            host_info = hostkey2hostinfo(host_info)
        end

        if (host_info["host"] ~= nil) then
            rsp = rsp .. 'host: "' .. host_info["host"] .. '"'
        elseif (host_info["ip"] ~= nil) then
            rsp = rsp .. 'host: "' .. host_info["ip"] .. '"'
        elseif (host_info["name"] ~= nil) then
            rsp = rsp .. 'host: "' .. host_info["name"] .. '"'
        elseif (host_info["mac"] ~= nil) then
            rsp = rsp .. 'host: "' .. host_info["mac"] .. '"'
        end
    end

    if ((host_info["vlan"] ~= nil) and (host_info["vlan"] ~= 0)) then
        rsp = rsp .. ', vlan: "' .. tostring(host_info["vlan"]) .. '"'
    end

    if (debug_host) then
        traceError(TRACE_DEBUG, TRACE_CONSOLE, "HOST2JSON => " .. rsp .. "\n")
    end

    return rsp
end

-- ##############################################

--
-- Catch the main information about an host from the host_info table and return the corresponding jqueryid.
-- Example: host 192.168.1.254, vlan0  ==> 1921681254_0
function hostinfo2jqueryid(host_info, host_type)
    local rsp = ''

    if (host_type == "cli") then
        if (host_info["cli.ip"] ~= nil) then
            rsp = rsp .. '' .. host_info["cli.ip"]
        end

    elseif (host_type == "srv") then
        if (host_info["srv.ip"] ~= nil) then
            rsp = rsp .. '' .. host_info["srv.ip"]
        end
    else
        if ((type(host_info) ~= "table") and (string.find(host_info, "@"))) then
            host_info = hostkey2hostinfo(host_info)
        end

        if (host_info["host"] ~= nil) then
            rsp = rsp .. '' .. host_info["host"]
        elseif (host_info["ip"] ~= nil) then
            rsp = rsp .. '' .. host_info["ip"]
        elseif (host_info["name"] ~= nil) then
            rsp = rsp .. '' .. host_info["name"]
        elseif (host_info["mac"] ~= nil) then
            rsp = rsp .. '' .. host_info["mac"]
        end
    end

    if ((host_info["vlan"] ~= nil) and (host_info["vlan"] ~= 0)) then
        rsp = rsp .. '@' .. tostring(host_info["vlan"])
    end

    rsp = string.gsub(rsp, "%.", "__")
    rsp = string.gsub(rsp, "/", "___")
    rsp = string.gsub(rsp, ":", "____")

    if (debug_host) then
        traceError(TRACE_DEBUG, TRACE_CONSOLE, "HOST2KEY => " .. rsp .. "\n")
    end

    return rsp
end

-- ##############################################

function isPausedInterface(current_ifname)
    if (not isEmptyString(_POST["toggle_local"])) then
        return (_POST["toggle_local"] == "0")
    end

    state = ntop.getCache("ntopng.prefs.ifid_" .. tostring(interface.name2id(current_ifname)) .. "_not_idle")
    if (state == "0") then
        return true
    else
        return false
    end
end

-- ##############################################

function tablePreferences(key, value, force_set)
    if not _SESSION then
        -- Not in a user session, ignore preferences
        return
    end

    table_key = getRedisPrefix("ntopng.sort.table")

    if ((value == nil) or (value == "")) and (force_set ~= true) then
        -- Get preferences
        return ntop.getHashCache(table_key, key)
    else
        -- Set preferences
        ntop.setHashCache(table_key, key, value)
        return (value)
    end
end

-- ##############################################

function setInterfaceRegreshRate(ifid, refreshrate)
    local key = "ntopng.prefs.ifid_" .. tostring(ifid) .. ".refresh_rate"

    if isEmptyString(refreshrate) then
        ntop.delCache(key)
    else
        ntop.setCache(key, tostring(refreshrate))
    end
end

-- ###############################################

-- prints purged information for hosts / flows
function purgedErrorString()
    local info = ntop.getInfo(false)
    return i18n("purged_error_message", {
        url = ntop.getHttpPrefix() .. '/lua/admin/prefs.lua?tab=in_memory',
        product = info["product"]
    })
end

-- print TCP flags
function formatTCPFlags(flags)
    local out = ''

    if (hasbit(flags, 0x02)) then
        out = out .. '<span class="badge bg-info"    title="SYN">S</span> '
    end
    if (hasbit(flags, 0x10)) then
        out = out .. '<span class="badge bg-info"    title="ACK">A</span> '
    end
    if (hasbit(flags, 0x01)) then
        out = out .. '<span class="badge bg-info"    title="FIN">F</span> '
    end
    if (hasbit(flags, 0x08)) then
        out = out .. '<span class="badge bg-info"    title="PSH">P</span> '
    end
    if (hasbit(flags, 0x04)) then
        out = out .. '<span class="badge bg-danger"  title="RST">R</span> '
    end
    if (hasbit(flags, 0x20)) then
        out = out .. '<span class="badge bg-primary" title="URG">U</span> '
    end
    if (hasbit(flags, 0x40)) then
        out = out .. '<span class="badge bg-info"    title="ECE">E</span> '
    end
    if (hasbit(flags, 0x80)) then
        out = out .. '<span class="badge bg-info"    title="CWR">C</span> '
    end

    return out
end

-- convert the integer carrying TCP flags in a more convenient lua table
function TCPFlags2table(flags)
    local res = {
        ["FIN"] = 0,
        ["SYN"] = 0,
        ["RST"] = 0,
        ["PSH"] = 0,
        ["ACK"] = 0,
        ["URG"] = 0,
        ["ECE"] = 0,
        ["CWR"] = 0
    }

    if (hasbit(flags, 0x01)) then
        res["FIN"] = 1
    end
    if (hasbit(flags, 0x02)) then
        res["SYN"] = 1
    end
    if (hasbit(flags, 0x04)) then
        res["RST"] = 1
    end
    if (hasbit(flags, 0x08)) then
        res["PSH"] = 1
    end
    if (hasbit(flags, 0x10)) then
        res["ACK"] = 1
    end
    if (hasbit(flags, 0x20)) then
        res["URG"] = 1
    end
    if (hasbit(flags, 0x40)) then
        res["ECE"] = 1
    end
    if (hasbit(flags, 0x80)) then
        res["CWR"] = 1
    end
    return res
end

-- ##########################################

function historicalProtoHostHref(ifId, host, l4_proto, ndpi_proto_id, info, vlan, no_print)
    if ntop.isEnterpriseM() then
        local now = os.time()
        local ago1h = now - 3600

        if ntop.isClickHouseEnabled() then
            local hist_url = ntop.getHttpPrefix() .. "/lua/pro/db_search.lua?"
            local params = {
                epoch_end = now,
                epoch_begin = ago1h,
                ifid = ifId
            }

            if host then
                local host_k = hostinfo2hostkey(host)
                if isEmptyString(host_k) then
                    host_k = host
                end
                params["ip"] = host_k .. ";eq"
            end
            if l4_proto then
                params["l4proto"] = l4_proto .. ";eq"
            end
            if ndpi_proto_id then
                params["l7proto"] = ndpi_proto_id .. ";eq"
            end
            if vlan and vlan ~= 0 then
                params["vlan_id"] = vlan .. ";eq"
            end
            if info then
                params["info"] = info .. ";in"
            end

            local url_params = table.tconcat(params, "=", "&")

            if not no_print then
                print('&nbsp;')
                -- print('<span class="badge bg-info">')
                print('<a href="' .. hist_url .. url_params .. '" title="' .. i18n("db_explorer.last_hour_flows") ..
                          '"><i class="fas fa-search-plus"></i></a>')
                -- print('</span>')
            else
                return '<a href="' .. hist_url .. url_params .. '" title="' .. i18n("db_explorer.last_hour_flows") ..
                           '"><i class="fas fa-search-plus"></i></a>'
            end
        end
    end
end

-- ####################################################

function tableToJsObject(lua_table)
    local json = require("dkjson")
    return json.encode(lua_table, nil)
end

-- ####################################################

-- @brief The difference, in seconds, between the local time of this instance and GMT
local server_timezone_diff_seconds

-- ####################################################

-- @brief Converts a datetime string into an epoch, adjusted with the client time
function makeTimeStamp(d)
    local pattern = "(%d+)%/(%d+)%/(%d+) (%d+):(%d+):(%d+)"
    local day, month, year, hour, minute, seconds = string.match(d, pattern);

    -- Get the epoch out of d. The epoch gets adjusted by os.time in the server timezone, that is, in
    -- the timezone of this running ntopng instance
    -- See https://www.lua.org/pil/22.1.html
    local server_epoch = os.time({
        year = year,
        month = month,
        day = day,
        hour = hour,
        min = minute,
        sec = seconds
    });

    -- Convert the server_epoch into a gmt_epoch which is adjusted to GMT
    local gmt_epoch = server_epoch + get_server_timezone_diff_seconds()

    -- Finally, compute a client_epoch by adding the seconds of getFrontendTzSeconds() to the GMT epoch just computed
    local client_epoch = gmt_epoch + getFrontendTzSeconds()

    -- Now we can compute the deltas to know the extact number of seconds between the server and the client timezone
    local server_to_gmt_delta = gmt_epoch - server_epoch
    local gmt_to_client_delta = client_epoch - gmt_epoch
    local server_to_client_delta = client_epoch - server_epoch

    -- Make sure everything is OK...
    assert(server_to_client_delta == server_to_gmt_delta + gmt_to_client_delta)

    -- tprint({
    --    server_ts = server_epoch,
    --    gmt_ts = gmt_epoch,
    --    server_to_gmt_delta = (server_to_gmt_delta) / 60 / 60,
    --    gmt_to_client_delta = (gmt_to_client_delta) / 60 / 60,
    --    server_to_client_delta = (server_to_client_delta) / 60 / 60
    -- })

    -- Return the epoch in the client timezone
    return string.format("%u", server_epoch - server_to_client_delta)
end

-- ###########################################

-- Note: the base unit is Kbps here
FMT_TO_DATA_RATES_KBPS = {
    ["k"] = {
        label = "Kbps",
        value = 1
    },
    ["m"] = {
        label = "Mbps",
        value = 1000
    },
    ["g"] = {
        label = "Gbps",
        value = 1000 * 1000
    }
}

FMT_TO_DATA_BYTES = {
    ["b"] = {
        label = "B",
        value = 1
    },
    ["k"] = {
        label = "KB",
        value = 1024
    },
    ["m"] = {
        label = "MB",
        value = 1024 * 1024
    },
    ["g"] = {
        label = "GB",
        value = 1024 * 1024 * 1024
    }
}

FMT_TO_DATA_TIME = {
    ["s"] = {
        label = i18n("metrics.secs"),
        value = 1
    },
    ["m"] = {
        label = i18n("metrics.mins"),
        value = 60
    },
    ["h"] = {
        label = i18n("metrics.hours"),
        value = 3600
    },
    ["d"] = {
        label = i18n("metrics.days"),
        value = 3600 * 24
    }
}

-- ###########################################

--
-- Extracts parameters from a lua table.
-- This function performs the inverse conversion of javascript paramsPairsEncode.
--
-- Note: plain parameters (not encoded with paramsPairsEncode) remain unchanged only
-- when strict mode is *not* enabled
--
function paramsPairsDecode(params, strict_mode)
    local res = {}

    for k, v in pairs(params) do
        local sp = split(k, "key_")
        if #sp == 2 then
            local keyid = sp[2]
            local value = "val_" .. keyid
            if params[value] then
                res[v] = params[value]
            end
        end

        if ((not strict_mode) and (res[v] == nil)) then
            -- this is a plain parameter
            res[k] = v
        end
    end

    return res
end

function isBridgeInterface(ifstats)
    return ifstats.inline
end

function hasSnmpDevices(ifid)
    if (not ntop.isEnterpriseM()) or (not isAdministrator()) then
        return false
    end

    return has_snmp_devices(ifid)
end

function stripVlan(name)
    local key = string.split(name, "@")
    if ((key ~= nil) and (#key == 2)) then
        -- Verify that the host is actually an IP address and the VLAN actually
        -- a number to avoid stripping things that are not vlans (e.g. part of an host name)
        local addr = key[1]

        if ((tonumber(key[2]) ~= nil) and (isIPv6(addr) or isIPv4(addr))) then
            return (addr)
        end
    end

    return (name)
end

-- ###########################################

function tsQueryToTags(query)
    local tags = {}

    for _, part in pairs(split(query, ",")) do
        local sep_pos = string.find(part, ":")

        if sep_pos then
            local k = string.sub(part, 1, sep_pos - 1)
            local v = string.sub(part, sep_pos + 1)
            tags[k] = v
        end
    end

    return tags
end

function tsTagsToQuery(tags)
    return table.tconcat(tags, ":", ",")
end

-- ###########################################

-- Compares IPv4 / IPv6 addresses
function ip_address_asc(a, b)
    return (ntop.ipCmp(a, b) < 0)
end

function ip_address_rev(a, b)
    return (ntop.ipCmp(a, b) > 0)
end

-- ###########################################

-- version is major.minor.veryminor
function version2int(v)
    if (v == nil) then
        return (0)
    end

    e = string.split(v, "%.");
    if (e ~= nil) then
        major = e[1]
        minor = e[2]
        veryminor = e[3]

        if (major == nil or tonumber(major) == nil or type(major) ~= "string") then
            major = 0
        end
        if (minor == nil or tonumber(minor) == nil or type(minor) ~= "string") then
            minor = 0
        end
        if (veryminor == nil or tonumber(veryminor) == nil or type(veryminor) ~= "string") then
            veryminor = 0
        end

        version = tonumber(major) * 1000 + tonumber(minor) * 100 -- + tonumber(veryminor)
        return (version)
    else
        return (0)
    end
end

--- Check if there is a new major release
--- @return string message If there is a new major release then return a non-nil string
--- containing the update message.
function check_latest_major_release()

    if ntop.isOffline() then
        return nil
    end

    -- get the latest major release
    local latest_version = ntop.getCache("ntopng.cache.major_release")

    -- tprint(debug.traceback())

    if isEmptyString(latest_version) then
        local rsp = ntop.httpGet("https://www.ntop.org/ntopng.version", "", "", 10 --[[ seconds ]] )

        if (not isEmptyString(rsp)) and (not isEmptyString(rsp["CONTENT"])) then
            latest_version = trimSpace(string.gsub(rsp["CONTENT"], "\n", ""))
        else
            -- a value that won't trigger an update message
            latest_version = "0.0.0"
        end

        ntop.setCache("ntopng.cache.major_release", latest_version, 86400 --[[ recheck interval]] )
    end

    return get_version_update_msg(info, latest_version)
end

-- ###########################################

-- To be called inside the flows tableCallback
function initFlowsRefreshRows()
    print [[
datatableInitRefreshRows($("#table-flows"), "key_and_hash", 10000, {
   /* List of rows with trend icons */
   "column_thpt": ]]
    print(ternary(getThroughputType() ~= "bps", "NtopUtils.fpackets", "NtopUtils.bitsToSize"))
    print [[,
   "column_bytes": NtopUtils.bytesToSize,
});

$("#dt-bottom-details > .float-left > p").first().append('. ]]
    print(i18n('flows_page.idle_flows_not_listed'))
    print [[');]]
end

-- ###########################################

function canRestoreHost(ifid, ip, vlan)
    local ip_to_mac = string.format("ntopng.ip_to_mac.ifid_%u__%s@%d", ifid, ip, vlan)
    local key_to_check

    -- Check if there is a MAC address associated
    local mac = ntop.getCache(ip_to_mac)

    if not isEmptyString(mac) then
        key_to_check = string.format("ntopng.serialized_hostsbymac.ifid_%u__%s_%s", ifid, mac,
            ternary(isIPv4(ip), "v4", "v6"))
    else
        key_to_check = string.format("ntopng.serialized_hosts.ifid_%u__%s@%d", ifid, ip, vlan)
    end

    return (not table.empty(ntop.getKeysCache(key_to_check)))
end

-- ###########################################

function create_ndpi_proto_name(v)
    local app = ""

    if v["proto.ndpi"] then
        app = getApplicationLabel(v["proto.ndpi"])
    else
        local master_proto = interface.getnDPIProtoName(tonumber(v["l7_master_proto"]))
        local app_proto = interface.getnDPIProtoName(tonumber(v["l7_proto"]))

        if master_proto == app_proto then
            app = app_proto
        elseif master_proto == "Unknown" then
            app = app_proto
        else
            app = master_proto

            if app_proto ~= "Unknown" then
                app = app .. "." .. app_proto
            end
        end

        app = getApplicationLabel(app)
    end

    return app
end

-- ##############################################

function setObsPointAlias(observation_point_id, alias)
    if ((observation_point_id ~= alias) and not isEmptyString(alias)) then
        ntop.setHashCache(getObsPointAliasKey(), observation_point_id, alias)
    else
        ntop.delHashCache(getObsPointAliasKey(), observation_point_id)
    end
end

-- ##############################################

function setFlowDevAlias(flowdev_ip, alias)
    if ((flowdev_ip ~= alias) and not isEmptyString(alias)) then
        ntop.setHashCache(getFlowDevAliasKey(), flowdev_ip, alias)
    else
        ntop.delHashCache(getFlowDevAliasKey(), flowdev_ip)
    end
end

-- ##############################################

function addScoreToAlertDescr(msg, score)
    return (msg .. string.format(" [%s: %s]", i18n("score"), format_utils.formatValue(score)))
end

-- ##############################################

function addHTTPInfoToAlertDescr(msg, alert_json, url_only, json_format)
    if ((alert_json) and (table.len(alert_json["proto"] or {}) > 0) and
        (table.len(alert_json["proto"]["http"] or {}) > 0)) then

        local http_info = format_http_info({
            http_info = alert_json["proto"]["http"]["last_method"],
            last_return_code = alert_json["proto"]["http"]["last_return_code"],
            last_user_agent = alert_json["proto"]["http"]["last_user_agent"],
            last_url = alert_json["proto"]["http"]["last_url"]
        }, url_only)

        if json_format then
            msg = http_info
        else
            if http_info["last_method"] then
                msg = msg .. string.format(" [ %s: %s ]", i18n("db_explorer.http_method"), http_info["last_method"])
            end

            if http_info["last_return_code"] then
                msg = msg ..
                          string.format(" [ %s: %s ]", i18n("last_response_status_code"), http_info["last_return_code"])
            end

            if http_info["last_user_agent"] then
                msg = msg .. string.format(" [ %s: %s ]", i18n("last_user_agent"), http_info["last_user_agent"])
            end

            if http_info["last_url"] then
                msg = msg .. string.format(" [ %s: %s ]", i18n("last_url"), http_info["last_url"])
            end
        end
    end

    return msg
end

-- ##############################################

function addDNSInfoToAlertDescr(msg, alert_json, json_format)
    if ((alert_json) and (table.len(alert_json["proto"] or {}) > 0) and
        (table.len(alert_json["proto"]["dns"] or {}) > 0)) then

        local dns_info = format_dns_query_info({
            last_query_type = alert_json["proto"]["dns"]["last_query_type"],
            last_return_code = alert_json["proto"]["dns"]["last_return_code"],
            last_query = alert_json["proto"]["dns"]["last_query"]
        }, json_format)

        if json_format then
            return dns_info
        else
            if dns_info["last_query_type"] then
                msg = msg .. string.format(" [ %s: %s ]", i18n("last_query_type"), dns_info["last_query_type"])
            end

            if dns_info["last_return_code"] then
                msg = msg .. string.format(" [ %s: %s ]", i18n("last_return_code"), dns_info["last_return_code"])
            end

            if dns_info["last_query"] then
                msg = msg .. string.format(" [ %s: %s ]", i18n("last_url"), dns_info["last_query"])
            end
        end
    end

    return msg
end

-- ##############################################

function addTLSInfoToAlertDescr(msg, alert_json, json_format)
    if ((alert_json) and (table.len(alert_json["proto"] or {}) > 0) and
        (table.len(alert_json["proto"]["tls"] or {}) > 0)) then

        local tls_info = format_tls_info({
            ja3_client_hash = alert_json["proto"]["tls"]["ja3_client_hash"],
            issuerDN = alert_json["proto"]["tls"]["issuerDN"],
            ja4_client_hash = alert_json["proto"]["tls"]["ja4_client_hash"],
            tls_version = alert_json["proto"]["tls"]["tls_version"],
            ja3_server_hash = alert_json["proto"]["tls"]["ja3_server_hash"],
            ja3_server_cipher = alert_json["proto"]["tls"]["ja3_server_cipher"],
            notBefore = alert_json["proto"]["tls"]["notBefore"],
            notAfter = alert_json["proto"]["tls"]["notAfter"],
            client_requested_server_name = alert_json["proto"]["tls"]["client_requested_server_name"],
            ['ja3.server_unsafe_cipher'] = alert_json["proto"]["tls"]["ja3.server_unsafe_cipher"]
        }, json_format)

        if json_format then
            return tls_info
        else
            if tls_info["tls_certificate_validity"] then
                msg = msg ..
                          string.format(" [ %s: %s ]", i18n("tls_certificate_validity"),
                        tls_info["tls_certificate_validity"])
            end

            if tls_info["ja3.server_unsafe_cipher"] then
                msg = msg ..
                          string.format(" [ %s: %s ]", i18n("ja3.server_unsafe_cipher"),
                        tls_info["ja3.server_unsafe_cipher"])
            end

            if tls_info["client_requested_server_name"] then
                msg = msg ..
                          string.format(" [ %s: %s ]", i18n("client_requested_server_name"),
                        tls_info["client_requested_server_name"])
            end
        end
    end

    return msg
end

-- ##############################################

function addICMPInfoToAlertDescr(msg, alert_json, json_format)
    if ((alert_json) and (table.len(alert_json["proto"] or {}) > 0) and
        (table.len(alert_json["proto"]["icmp"] or {}) > 0)) then

        local icmp_info = format_icmp_info({
            code = alert_json["proto"]["icmp"]["code"],
            type = alert_json["proto"]["icmp"]["type"]
        })

        if json_format then
            return icmp_info
        else
            -- Already formatted by the function
            if icmp_info["type"] then
                msg = msg .. string.format(" [ %s: %s ]", i18n("icmp_type"), icmp_info["type"])
            end

            if icmp_info["code"] then
                msg = msg .. string.format(" [ %s: %s ]", i18n("icmp_code"), icmp_info["code"])
            end
        end
    end

    return msg
end

-- ##############################################

function addBytesInfoToAlertDescr(msg, value, json_format)
    if json_format then
        if type(msg) == "string" then
            msg = {}
        end
        msg["server_traffic"] = value["srv2cli_bytes"] or 0
        msg["client_traffic"] = value["cli2srv_bytes"] or 0
    else
        msg = string.format("%s [ %s: %s | %s: %s ]", msg, i18n("server_traffic"),
            bytesToSize(value["srv2cli_bytes"] or 0), i18n("client_traffic"), bytesToSize(value["cli2srv_bytes"] or 0))
    end

    return msg
end

-- ##############################################

function addExtraFlowInfo(alert_json, value, json_format)
    local msg = ""
    msg = addHTTPInfoToAlertDescr(msg, alert_json, json_format, json_format)
    msg = addDNSInfoToAlertDescr(msg, alert_json, json_format)
    msg = addTLSInfoToAlertDescr(msg, alert_json, json_format)
    msg = addICMPInfoToAlertDescr(msg, alert_json, json_format)
    msg = addBytesInfoToAlertDescr(msg, value, json_format)

    return msg or ""
end

-- ##############################################

function hostnameIsDomain(name)
    if not isEmptyString(name) then
        local parts = string.split(name, "%.")

        if parts and #parts > 1 then
            local last = parts[#parts]
            if string.len(last) > 0 then
                return true
            end
        end
    end

    return false
end

-- ##############################################

local iec104_typeids = {
    M_SP_NA_1 = 0x01,
    M_SP_TA_1 = 0x02,
    M_DP_NA_1 = 0x03,
    M_DP_TA_1 = 0x04,
    M_ST_NA_1 = 0x05,
    M_ST_TA_1 = 0x06,
    M_BO_NA_1 = 0x07,
    M_BO_TA_1 = 0x08,
    M_ME_NA_1 = 0x09,
    M_ME_TA_1 = 0x0A,
    M_ME_NB_1 = 0x0B,
    M_ME_TB_1 = 0x0C,
    M_ME_NC_1 = 0x0D,
    M_ME_TC_1 = 0x0E,
    M_IT_NA_1 = 0x0F,
    M_IT_TA_1 = 0x10,
    M_EP_TA_1 = 0x11,
    M_EP_TB_1 = 0x12,
    M_EP_TC_1 = 0x13,
    M_PS_NA_1 = 0x14,
    M_ME_ND_1 = 0x15,
    M_SP_TB_1 = 30,
    M_DP_TB_1 = 31,
    M_ST_TB_1 = 32,
    M_BO_TB_1 = 33,
    M_ME_TD_1 = 34,
    M_ME_TE_1 = 35,
    M_ME_TF_1 = 36,
    M_IT_TB_1 = 37,
    M_EP_TD_1 = 38,
    M_EP_TE_1 = 39,
    M_EP_TF_1 = 40,
    ASDU_TYPE_41 = 41,
    ASDU_TYPE_42 = 42,
    ASDU_TYPE_43 = 43,
    ASDU_TYPE_44 = 44,
    C_SC_NA_1 = 45,
    C_DC_NA_1 = 46,
    C_RC_NA_1 = 47,
    C_SE_NA_1 = 48,
    C_SE_NB_1 = 49,
    C_SE_NC_1 = 50,
    C_BO_NA_1 = 51,
    C_SC_TA_1 = 58,
    C_DC_TA_1 = 59,
    C_RC_TA_1 = 60,
    C_SE_TA_1 = 61,
    C_SE_TB_1 = 62,
    C_SE_TC_1 = 63,
    C_BO_TA_1 = 64,
    M_EI_NA_1 = 70,
    C_IC_NA_1 = 100,
    C_CI_NA_1 = 101,
    C_RD_NA_1 = 102,
    C_CS_NA_1 = 103,
    C_TS_NA_1 = 104,
    C_RP_NA_1 = 105,
    C_CD_NA_1 = 106,
    C_TS_TA_1 = 107,
    P_ME_NA_1 = 110,
    P_ME_NB_1 = 111,
    P_ME_NC_1 = 112,
    P_AC_NA_1 = 113,
    F_FR_NA_1 = 120,
    F_SR_NA_1 = 121,
    F_SC_NA_1 = 122,
    F_LS_NA_1 = 123,
    F_FA_NA_1 = 124,
    F_SG_NA_1 = 125,
    F_DR_TA_1 = 126
}

function iec104_typeids2str(c)
    if (c == nil) then
        return
    end

    for s, v in pairs(iec104_typeids) do
        if (v == tonumber(c)) then
            return (s .. " (" .. v .. ")")
        end
    end

    return (c)
end

-- ##############################################

function format_device_name(device_ip, short_version)
    local device_name = device_ip

    if ntop.isPro() then
        device_name = hostinfo2label(hostkey2hostinfo(device_ip))

        if device_name ~= device_ip then
            if short_version then
                device_name = shortenString(device_name, 32)
            end
            device_name = string.format('%s [%s]', device_ip, device_name)
        end
    end

    return device_name
end

-- ##############################################

require "lua_utils_print"
require "lua_utils_get"
require "lua_utils_gui"

if (trace_script_duration ~= nil) then
    io.write(debug.getinfo(1, 'S').source .. " executed in " .. (os.clock() - clock_start) * 1000 .. " ms\n")
    io.write(string.format("Lua memory: =  %s\n", collectgarbage("count")))
end

