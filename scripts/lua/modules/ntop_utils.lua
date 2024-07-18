--
-- (C) 2021-24 - ntop.org
--
-- This file contains a small set of utility functions
-- ###############################################
if (pragma_once_ntop_utils == true) then
    -- io.write(debug.traceback().."\n")
    -- avoid multiple inclusions
    return
end

pragma_once_ntop_utils = true

-- This is required because it simply adds the tracing functions, like traceError
require "lua_trace"

local clock_start = os.clock()

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

function ends(String, End)
    return End == '' or string.sub(String, -string.len(End)) == End
end

-- ##############################################

function string.starts(String, Start)
    if type(String) ~= 'string' or type(Start) ~= 'string' then
        return false
    end
    return string.sub(String, 1, string.len(Start)) == Start
end

-- ##############################################

function string.ends(String, End)
    if type(String) ~= 'string' or type(End) ~= 'string' then
        return false
    end
    return End == '' or string.sub(String, -string.len(End)) == End
end

-- ##############################################

-- @Brief Checks if a dotted-decimal SNMP OID starts with another dotted-decimal SNMP OID
-- @param oid_string The string-encoded dotted-decimal SNMP OID to check
-- @param oid_string_start A string-encoded dotted-decimal SNMP OID prefix
-- @return True if `oid_string` starts with `oid_string_start` or false otherwise
function string.oid_starts(oid_string, oid_string_start)
    if type(oid_string) ~= 'string' or type(oid_string_start) ~= 'string' then
        return false
    end

    -- Make sure both OIDs end with a dot, to avoid
    -- considering 1.3.6.1.4.1.99 starting with 1.3.6.1.4.1.9
    if not string.ends(oid_string, ".") then
        oid_string = oid_string .. "."
    end

    if not string.ends(oid_string_start, ".") then
        oid_string_start = oid_string_start .. "."
    end

    return string.sub(oid_string, 1, string.len(oid_string_start)) == oid_string_start
end

-- ##############################################

-- Print contents of `tbl`, with indentation.
-- You can call it as tprint(mytable)
-- The other two parameters should not be set
function tprint(s, l, i)
    -- io.write(debug.traceback().."\n")

    l = (l) or 1000;
    i = i or ""; -- default item limit, indent string
    if (l < 1) then
        io.write("ERROR: Item limit reached.\n");
        return l - 1
    end
    local ts = type(s);
    if (ts ~= "table") then
        io.write(i .. ' ' .. ts .. ' ' .. tostring(s) .. '\n');
        return l - 1
    end
    io.write(i .. ' ' .. ts .. '\n');
    for k, v in pairs(s) do
        local indent = ""

        if (i ~= "") then
            indent = i .. "."
        end
        indent = indent .. tostring(k)

        l = tprint(v, l, indent);
        if (l < 0) then
            break
        end
    end

    return l
end

-- ##############################################

function splitNetworkPrefix(net)
    if not net then
        tprint(debug.traceback())
    end
    local prefix = tonumber(net:match("/(.+)"))
    local address = net:gsub("/.+", "")
    return address, prefix
end

-- ##############################################

--
-- Concatenates table keys to values with separators
--
-- Parameters
--    keys_values: the table which contains the items
--    kv_sep: a string to be put between a key and a value
--    group_sep: a string to be put between key-value groups
--    last_sep: a string to be put after last value, if table is not empty
--    value_quote: a string to be used to quote values
--
function table.tconcat(keys_values, kv_sep, group_sep, last_sep, value_quote)
    local groups = {}
    kv_sep = kv_sep or ""
    group_sep = group_sep or ""
    last_sep = last_sep or ""
    value_quote = value_quote or ""

    for k, v in pairs(keys_values) do
        local parts = {k, kv_sep, value_quote, v, value_quote}
        groups[#groups + 1] = table.concat(parts, "")
    end

    if #groups > 0 then
        return table.concat(groups, group_sep) .. last_sep
    else
        return ""
    end
end

-- ##############################################

-- NOTE: on index based tables using #table is much more performant
function table.len(tbl)
    local count = 0

    if tbl == nil then
        -- io.write("ERROR: table expected, got nil\n")
        -- io.write(debug.traceback().."\n")
        return 0
    end

    if type(tbl) ~= "table" then
        io.write("ERROR: table expected, got " .. type(tbl) .. "\n")
        io.write(debug.traceback() .. "\n")
        return 0
    end

    for k, v in pairs(tbl) do
        count = count + 1
    end

    return count
end

-- ##############################################

function table.slice(tbl, first, last, step)
    local sliced = {}

    for i = first or 1, last or #tbl, step or 1 do
        sliced[#sliced + 1] = tbl[i]
    end

    return sliced
end

-- ##############################################

function table.empty(tbl)
    if (tbl == nil) then
        return true
    end

    if next(tbl) == nil then
        return true
    end

    return false
end

-- ##############################################

function isIPv4(address)
    if (address == nil) then
        return false
    end

    -- Reuse the for loop to check the address validity
    local checkAddress = (function(chunks)
        for _, v in pairs(chunks) do
            if (tonumber(v) < 0) or (tonumber(v) > 255) then
                return false
            end
        end
        return true
    end)

    local chunks = {address:match("^(%d+)%.(%d+)%.(%d+)%.(%d+)$")}
    local chunksWithPort = {address:match("^(%d+)%.(%d+)%.(%d+)%.(%d+)%:(%d+)$")}

    if #chunks == 4 then
        return checkAddress(chunks)
    elseif #chunksWithPort == 5 then
        table.remove(chunksWithPort, 5)
        return checkAddress(chunksWithPort)
    end

    return false
end

-- ##############################################

function isIPv6(ip)
    return ((not isEmptyString(ip)) and ntop.isIPv6(ip))
end

-- ##############################################

-- Check if address is a CIDR
-- strict (optional) do not accept subnets without the '/<mask>'
function isIPv4Network(address, strict)
    -- Check for @ VLAN
    local parts = split(address, "@")
    if #parts == 2 then
        address = parts[1]
    end

    -- Parse CIDR
    parts = split(address, "/")
    if #parts == 2 then
        local prefix = tonumber(parts[2])

        if (prefix == nil) or (math.floor(prefix) ~= prefix) or (prefix < 0) or (prefix > 32) then
            return false
        end

    elseif #parts == 1 and strict then
        return false

        -- Check empty
    elseif #parts ~= 1 then
        return false
    end

    -- Check IP
    return isIPv4(parts[1])
end

-- ##############################################

-- Check if address is a CIDR
-- strict (optional) do not accept subnets without the '/<mask>'
function isIPv6Network(address, strict)
    -- Check for @ VLAN
    local parts = split(address, "@")
    if #parts == 2 then
        address = parts[1]
    end

    -- Parse CIDR
    parts = split(address, "/")
    if #parts == 2 then
        local prefix = tonumber(parts[2])

        if (prefix == nil) or (math.floor(prefix) ~= prefix) or (prefix < 0) or (prefix > 128) then
            return false
        end

    elseif #parts == 1 and strict then
        return false

        -- Check empty
    elseif #parts ~= 1 then
        return false
    end

    -- Check IPv6
    return isIPv6(parts[1])
end

-- ##############################################

function firstToUpper(str)
    str = tostring(str)
    return (str:gsub("^%l", string.upper))
end

-- ##############################################

function pairsByKeys(t, f)
    local a = {}
    if t == nil then
        io.write(debug.traceback() .. "\n")
    end
    for n in pairs(t) do
        table.insert(a, n)
    end
    table.sort(a, f)
    local i = 0 -- iterator variable
    local iter = function() -- iterator function
        i = i + 1
        if a[i] == nil then
            return nil
        else
            return a[i], t[a[i]]
        end
    end
    return iter
end

-- ##############################################

function pairsByValues(t, f)
    local a = {}
    if t == nil then
        io.write(debug.traceback() .. "\n")
    end
    for n in pairs(t) do
        table.insert(a, n)
    end
    table.sort(a, function(x, y)
        return f(t[x], t[y])
    end)
    local i = 0 -- iterator variable
    local iter = function() -- iterator function
        i = i + 1
        if a[i] == nil then
            return nil
        else
            return a[i], t[a[i]]
        end
    end
    return iter
end

-- ##############################################

-- @brief Sorted iteration of a table whose keys are strings in dotted decimal format
--        Can be used to sort dotted-decimal IPs, SNMP oids, etc.
-- @param t The table to be iterated
-- @param f The sort function, either `asc` or `rev`
-- @return An iterator
function pairsByDottedDecimalKeys(t, f)
    local sorter = {}

    -- Build a support array for the actual sorting
    for key, value in pairs(t) do
        local key_sorter = key:split("%.") or {key} -- An array that will be used to sort
        local splitted = key_sorter[#key_sorter]:split("@") or {}
        -- This example handles the VLAN, if no VLAN is present, add 0, in case
        -- a comparison between an host with VLAN and one without is performed
        key_sorter[#key_sorter] = splitted[1]
        key_sorter[#key_sorter + 1] = splitted[2] or 0

        sorter[#sorter + 1] = {
            sorter = key_sorter,
            key = key, -- Original key
            value = value -- Original value
        }
    end

    table.sort(sorter, function(left, right)
        -- The minimum of the two lengths, used to to the comparisons
        local len = math.min(#left.sorter, #right.sorter)

        for i = 1, len do
            -- Convert elements to numbers
            local left_number, right_number = tonumber(left.sorter[i]), tonumber(right.sorter[i])

            if left_number ~= right_number then
                -- If numbers are different, compare them using the sort function
                return f(left_number, right_number)
            elseif i == len then
                -- This is the lat time we do the comparison:
                -- When lengths are not equal, legths are used at tie breaker
                return f(#left.sorter, #right.sorter)
            end
        end
    end)

    local i = 0
    local iter = function()
        i = i + 1

        if sorter[i] == nil then
            return
        end

        return sorter[i].key, sorter[i].value
    end

    return iter
end

-- ##############################################

function pairsByField(t, field, f)
    local a = {}
    for n in pairs(t) do
        table.insert(a, n)
    end

    table.sort(a, function(x, y)
        return f(t[x][field], t[y][field])
    end)
    local i = 0 -- iterator variable
    local iter = function() -- iterator function
        i = i + 1
        if a[i] == nil then
            return nil
        else
            return a[i], t[a[i]]
        end
    end
    return iter
end

-- ##############################################

function asc(a, b)
    if a == nil or b == nil then
        return false
    elseif type(a) ~= type(b) then
        traceError(TRACE_WARNING, TRACE_CONSOLE,
            "Bad types in asc(): " .. a .. " (" .. type(a) .. ") vs " .. b .. " (" .. type(b) .. ")")
        return false
    end

    return (a < b)
end

-- ##############################################

function rev(a, b)
    if a == nil or b == nil then
        return false
    elseif type(a) ~= type(b) then
        traceError(TRACE_WARNING, TRACE_CONSOLE,
            "Bad types in rev(): " .. a .. " (" .. type(a) .. ") vs " .. b .. " (" .. type(b) .. ")")
        tprint(debug.traceback())
        return false
    end

    return (a > b)
end

-- ##############################################

function asc_insensitive(a, b)
    if type(a) ~= "string" then
        return asc(a, b)
    end
    return (string.lower(a) < string.lower(b))
end

-- ##############################################

function rev_insensitive(a, b)
    if type(a) ~= "string" then
        return rev(a, b)
    end
    return (string.lower(a) > string.lower(b))
end

-- ##############################################

function string.split(s, p)
    local temp = {}
    local index = 0

    if s == nil then
        io.write(debug.traceback() .. "\n")
    end

    local last_index = string.len(s)

    while true do
        local i, e = string.find(s, p, index)

        if i and e then
            local next_index = e + 1
            local word_bound = i - 1
            table.insert(temp, string.sub(s, index, word_bound))
            index = next_index
        else
            if index > 0 and index <= last_index then
                table.insert(temp, string.sub(s, index, last_index))
            elseif index == 0 then
                temp = nil
            end
            break
        end
    end

    return temp
end

-- ##############################################

function isMacAddress(address)
    local v
    local addr

    if (address == nil) then
        return false
    end

    v = string.split(address, "@")

    if (v ~= nil) then
        addr = v[1]
    else
        addr = address
    end

    if (string.ends(addr, "_v4") or string.ends(addr, "_v6") or
        (string.match(addr, "^%x%x:%x%x:%x%x:%x%x:%x%x:%x%x$") ~= nil) or
        (string.match(addr, "^%x%x:%x%x:%x%x:%x%x:%x%x:%x%x%@%d+$") ~= nil)) then
        return true
    end
    return false
end

function isCommunityId(address)
    local c
    if (address == nil) then
        return false
    end

    c = string.split(address, ":")
    if (c ~= nil and #c == 2) then
        return true
    end

    return false
end

function isJA3(address)
    if (address == nil) then
        return false
    end
    if (string.find(address, "%.") or string.find(address, ":")) then
        return false
    end
    return true
end

-- ##############################################

function isEmptyString(str)
    if ((str == nil) or (str == "") or (str == " ")) then
        return true
    else
        return false
    end
end

-- ##############################################

function ternary(cond, T, F)
    if cond then
        return T
    else
        return F
    end
end

-- ##############################################

function isAdministrator()
    return ntop.isAdministrator()
end

-- ##############################################

function isNoLoginUser()
    return _SESSION["user"] == ntop.getNologinUser()
end

-- ##############################################

function getSystemInterfaceId()
    -- NOTE: keep in sync with SYSTEM_INTERFACE_ID in ntop_defines.h
    -- This must be a string as it is passed in interface.select
    return "-1"
end

-- ##############################################

function getSystemInterfaceName()
    -- NOTE: keep in sync with SYSTEM_INTERFACE_NAME in ntop_defines.h
    return "__system__"
end

-- ###########################################

function hasHighResolutionTs()
    local active_driver = ntop.getPref("ntopng.prefs.timeseries_driver")

    -- High resolution timeseries means dumping the host timeseries
    -- every 60 seconds instead of 300 seconds.
    return ((active_driver == "influxdb") and (ntop.getPref("ntopng.prefs.ts_resolution") ~= "300"))
end

if (trace_script_duration ~= nil) then
    io.write(debug.getinfo(1, 'S').source .. " executed in " .. (os.clock() - clock_start) * 1000 .. " ms\n")
end

-- ##############################################

function getInterfaceId(interface_name)
    if (interface_name == getSystemInterfaceName()) then
        return (getSystemInterfaceId())
    end

    local ifnames = interface.getIfNames()

    for if_id, if_name in pairs(ifnames) do
        if if_name == interface_name then
            return tonumber(if_id)
        end
    end

    return (-1)
end

-- ###########################################

function visualTsKey(tskey)
    if ends(tskey, "_v4") or ends(tskey, "_v6") then
        local ver = string.sub(tskey, string.len(tskey) - 1, string.len(tskey))
        local address = string.sub(tskey, 1, string.len(tskey) - 3)
        local visual_addr

        if ver == "v4" then
            visual_addr = address
        else
            visual_addr = address .. " (" .. ver .. ")"
        end

        return visual_addr
    end

    return tskey
end

-- ##############################################

-- @brief Performs a difference between the current metric value and
-- the previous saved value and saves the current value for next call.
-- @param reg lua C context pointer to the alertable entity storage
-- @param metric_name name of the metric to retrieve
-- @param granularity the granularity number
-- @param curr_val the current metric value
-- @param skip_first if true, 0 will be returned when no cached value is present
-- @return the difference between current and previous value
function delta_val(reg, metric_name, granularity, curr_val, skip_first)
    -- This require is okay, alert_granularities is just a struct
    local alert_granularities = require "alert_granularities"

    local granularity_num = alert_granularities[granularity] or 0
    if granularity_num ~= 0 and not isEmptyString(granularity_num) then
        granularity_num = granularity_num.granularity_id
    end

    local key = string.format("%s:%d", metric_name, granularity_num)

    -- Read cached value and purify it
    local prev_val
    local prev = reg.getCachedAlertValue(key, granularity_num)
    if prev == nil or type(prev) == "table" then -- Safety check and debug
        -- traceError(TRACE_ERROR, TRACE_CONSOLE, "Bad prev val")
        -- tprint(prev)
        -- tprint(debug.traceback())
    else
        prev_val = tonumber(prev)
    end

    -- Save the value for the next round
    reg.setCachedAlertValue(key, tostring(curr_val), granularity_num)

    if ((skip_first == true) and (prev_val == nil)) then
        return (0)
    else
        return (curr_val - (prev_val or 0))
    end
end

-- ##############################################

--
-- Members supported format
-- 192.168.1.10/32@10
-- 00:11:22:33:44:55
--

-- ##############################################

-- Check if this is a valid pool member (MAC or CIDR@VLAN)
-- @param fix_relaxed Fix relaxed notation (IP without net mask or vlan)
function checkPoolMember(member, fix_relaxed)
    if isEmptyString(member) then
        return nil
    end

    if isMacAddress(member) then
        return member
    end

    -- VLAN
    local vlan_id
    local vlan_idx = string.find(member, "@")
    if vlan_idx == nil then
        if fix_relaxed then
            vlan_id = 0 -- default vlan: 0
        else
            return nil -- no vlan
        end
    elseif vlan_idx == 1 then
        return nil -- bad format
    else
        local other = string.sub(member, 1, vlan_idx - 1)
        vlan_id = tonumber(string.sub(member, vlan_idx + 1))
        if vlan_id == nil or vlan_id < 0 then
            return nil
        end
        member = other
    end

    -- prefix is mandatory here
    local address, prefix = splitNetworkPrefix(member)
    if address == nil then
        return nil -- bad format
    elseif prefix == nil then
        if fix_relaxed then
            if isIPv4(address) then
                prefix = '32' -- default mask: 32
            elseif isIPv6(address) then
                prefix = '128' -- default mask: 128
            else
                return nil -- bad format
            end
        else
            return nil -- no mask
        end
    end

    if isIPv4(address) and (tonumber(prefix) >= 0) and (tonumber(prefix) <= 32) then
        -- ok
    elseif isIPv6(address) and (tonumber(prefix) >= 0) and (tonumber(prefix) <= 128) then
        -- ok
    else
        return nil -- bad format
    end

    return address .. '/' .. prefix .. '@' .. vlan_id
end

-- ##############################################

-- Check if this is a valid pool member (MAC or CIDR@VLAN)
-- @param relaxed Allow relaxed notation (IP without net mask or vlan)
function isValidPoolMember(member, relaxed)
    if checkPoolMember(member, relaxed) then
        return true
    else
        return false
    end
end

-- ##############################################

function fixPoolMemberFormat(member)
    return checkPoolMember(member, true)
end

-- #################################################################

function bit(p)
    return 2 ^ (p - 1) -- 1-based indexing
end

-- ##############################################

-- Typical call:  if hasbit(x, bit(3)) then ...
function hasbit(x, p)
    return x % (p + p) >= p
end

-- ##############################################

function setbit(x, p)
    return hasbit(x, p) and x or x + p
end

-- ##############################################

function clearbit(x, p)
    return hasbit(x, p) and x - p or x
end

-- ###########################################

function getHttpHost()
    local ntopng_info = ntop.getInfo()
    local ntopng_host_info = ntop.getHostInformation() or {}

    -- Read configured ntopng host name or IP
    local ntopng_host_ip = ntop.getPref("ntopng.prefs.ntopng_host_address")
    if isEmptyString(ntopng_host_ip) then
        -- fallback: managegemt IP
        ntopng_host_ip = ntopng_host_info.ip
    end
    if isEmptyString(ntopng_host_ip) then
        -- last resort: dummy IP
        ntopng_host_ip = '127.0.0.1'
    end

    local http_host
    if starts(ntopng_host_ip, 'http') then
        http_host = ntopng_host_ip
    else
        -- Computing URL adding protocol and port
        local ntopng_protocol = "http://"
        local ntopng_port = ntopng_info.http_port

        if not ntop.isnEdge() and ntopng_info.https_port and tonumber(ntopng_info.https_port) ~= 0 then
            ntopng_protocol = "https://"
            ntopng_port = ntopng_info.https_port
        end

        http_host = ntopng_protocol .. ntopng_host_ip .. ":" .. ntopng_port
    end

    return http_host
end

-- ##############################################

function starts(String, Start)
    if ((String == nil) or (Start == nil)) then
        return (false)
    end

    return string.sub(String, 1, string.len(Start)) == Start
end

-- ##############################################

function getNetFlowExportersUnifiedStats()
    local flowdevs = interface.getFlowDevices()
    local unified_exporters = {}
    for interface_id, device_list in pairs(flowdevs or {}) do
        for device_id, exporter_info in pairs(device_list, asc) do
            local exporter_ip = exporter_info.exporter_ip
            if not unified_exporters[exporter_ip] then
                unified_exporters[exporter_ip] = {}
            end
            local ports_table = interface.getFlowDeviceInfo(exporter_ip)
            for _, ports in pairs(ports_table) do
                for port_idx, port_info in pairs(ports) do
                    if not unified_exporters[exporter_ip][port_idx] then
                        unified_exporters[exporter_ip][port_idx] = port_info
                    else
                        local tmp = unified_exporters[exporter_ip][port_idx]
                        tmp["throughput"] = port_info["throughput"] + (tmp["throughput"] or 0)
                        tmp["bytes.in_bytes"] = port_info["bytes.in_bytes"] + (tmp["bytes.in_bytes"] or 0)
                        tmp["bytes.out_bytes"] = port_info["bytes.out_bytes"] + (tmp["bytes.out_bytes"] or 0)
                        if not tmp.ndpi then
                            tmp["ndpi"] = {}
                        end
                        for proto, proto_info in pairs(port_info.ndpi or {}) do
                            if not tmp["ndpi"][proto] then
                                tmp["ndpi"][proto] = {}
                            end
                            for field, value in pairs(proto_info or {}) do
                                tmp["ndpi"][proto][field] = value + (tmp["ndpi"][proto][field] or 0)
                            end
                        end
                        unified_exporters[exporter_ip][port_idx] = tmp
                    end
                end
            end
        end
    end

    return unified_exporters
end