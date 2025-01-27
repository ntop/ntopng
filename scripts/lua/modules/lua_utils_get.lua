--
-- (C) 2014-24 - ntop.org
--

if(pragma_once_lua_utils_get == true) then
   -- io.write(debug.traceback().."\n")
   -- avoid multiple inclusions
   return
end

pragma_once_lua_utils_get = true

require "ntop_utils"
require "label_utils"
require "check_redis_prefs"

local clock_start = os.clock()

-- ##############################################

function getInterfaceUrl(ifid)
    if (not ifid) then
        return ("")
    end

    return ntop.getHttpPrefix() .. "/lua/if_stats.lua?ifid=" .. ifid
end

-- ##############################################

function getFirstInterfaceId()
    local ifid = interface.getFirstInterfaceId()

    if ifid ~= nil then
        return ifid, getInterfaceName(ifid)
    end

    return -1, ""
end

-- ##############################################

local function urlencode(str)
    str = string.gsub(str, "\r?\n", "\r\n")
    str = string.gsub(str, "([^%w%-%.%_%~ ])", function(c)
        return string.format("%%%02X", string.byte(c))
    end)
    str = string.gsub(str, " ", "+")
    return str
end

-- ##############################################

function getPageUrl(base_url, params)
    if table.empty(params) then
        return base_url
    end

    local encoded = {}

    for k, v in pairs(params) do
        encoded[k] = urlencode(v)
    end

    local delim = "&"
    if not string.find(base_url, "?") then
        delim = "?"
    end

    return base_url .. delim .. table.tconcat(encoded, "=", "&")
end

-- ##############################################

function getProbesName(flowdevs, show_vlan, shorten_len)
    local probes_list = {}
    for interface, devices in pairs(flowdevs or {}) do
        local device_list = {} 
        if table.len(devices or {}) > 0 then
            for id, device_info in pairsByKeys(devices or {}, asc) do
                device_list[device_info.exporter_ip] = getProbeName(device_info.exporter_ip, show_vlan, shorten_len)
            end
            probes_list[interface] = device_list
        end
    end

    return probes_list
end

-- ##############################################

function getProbeName(exporter_ip, show_vlan, shorten_len)
    local cached_device_name
    local snmp_cached_dev
    local probe_alias = getFlowDevAlias(exporter_ip, true)

    -- In case an alias is set to the flow exporter, directly use the alias
    if not isEmptyString(probe_alias) and probe_alias ~= exporter_ip then
        return probe_alias
    end

    -- No alias set, let's try with the SNMP
    if ntop.isPro() then
        local dirs = ntop.getDirs()
        package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
        snmp_cached_dev = require "snmp_cached_dev"
    end

    if snmp_cached_dev then
        cached_device_name = snmp_cached_dev:create(exporter_ip)
    end

    if cached_device_name then
        cached_device_name = cached_device_name["name"]
    else
        local hinfo = hostkey2hostinfo(exporter_ip)
        local exporter_label = hostinfo2label(hinfo, show_vlan, shorten_len)

        if not isEmptyString(exporter_label) then
            cached_device_name = exporter_label
        end
    end

    return cached_device_name
end

-- ##############################################

function getCategoriesWithProtocols()
    local protocol_categories = interface.getnDPICategories()

    for k, v in pairsByKeys(protocol_categories) do
        protocol_categories[k] = {
            id = v,
            protos = interface.getnDPIProtocols(tonumber(v)),
            count = 0
        }

        for proto, _ in pairs(protocol_categories[k].protos) do
            protocol_categories[k].count = protocol_categories[k].count + 1
        end
    end

    return protocol_categories
end

-- ##############################################

-- Return the first 'howmany' hosts
function getTopInterfaceHosts(howmany, localHostsOnly)
    hosts_stats = interface.getHostsInfo()
    hosts_stats = hosts_stats["hosts"]
    ret = {}
    sortTable = {}
    n = 0
    for k, v in pairs(hosts_stats) do
        if ((not localHostsOnly) or ((v["localhost"] == true) and (v["ip"] ~= nil))) then
            sortTable[v["bytes.sent"] + v["bytes.rcvd"] + n] = k
            n = n + 0.01
        end
    end

    n = 0
    for _v, k in pairsByKeys(sortTable, rev) do
        if (n < howmany) then
            ret[k] = hosts_stats[k]
            n = n + 1
        else
            break
        end
    end

    return (ret)
end

-- #################################

function getIpUrl(ip)
    if isIPv6(ip) then
        -- https://www.ietf.org/rfc/rfc2732.txt
        return "[" .. ip .. "]"
    end
    return ip
end

-- #################################

function getApplicationIcon(name)
    local icon = ""
    if (name == nil) then
        name = ""
    end

    if (findString(name, "Skype")) then
        icon = '<i class=\'fab fa-skype\'></i>'
    elseif (findString(name, "Unknown")) then
        icon = '<i class=\'fas fa-question\'></i>'
    elseif (findString(name, "Twitter")) then
        icon = '<i class=\'fab fa-twitter\'></i>'
    elseif (findString(name, "DropBox")) then
        icon = '<i class=\'fab fa-dropbox\'></i>'
    elseif (findString(name, "Spotify")) then
        icon = '<i class=\'fab fa-spotify\'></i>'
    elseif (findString(name, "Apple")) then
        icon = '<i class=\'fab fa-apple\'></i>'
    elseif (findString(name, "Google") or findString(name, "Chrome")) then
        icon = '<i class=\'fab fa-google-plus-g\'></i>'
    elseif (findString(name, "FaceBook")) then
        icon = '<i class=\'fab fa-facebook\'></i>'
    elseif (findString(name, "Youtube")) then
        icon = '<i class=\'fab fa-youtube\'></i>'
    elseif (findString(name, "thunderbird")) then
        icon = '<i class=\'fas fa-paper-plane\'></i>'
    end

    return (icon)
end

-- #################################

function getApplicationLabel(name, maxlen)
    local icon = getApplicationIcon(name)

    if (maxlen == nil) then
        maxlen = 12
    end

    -- Do not convert to upper case, keep the nDPI case
    -- name = name:gsub("^%l", string.upper)

    if (icon == "") then
        return (shortenString(name, maxlen))
    else
        return (icon .. " " .. shortenString(name, maxlen))
    end
end

-- #################################

function getCategoryLabel(cat_name, cat_id)
    local categories_utils = require 'categories_utils'
    return categories_utils.getCustomCategoryName(cat_id, cat_name)
end

-- ###########################################

function getItemsNumber(n)
    tot = 0
    for k, v in pairs(n) do
        -- io.write(k.."\n")
        tot = tot + 1
    end

    -- io.write(tot.."\n")
    return (tot)
end

-- ###########################################

function getHostCommaSeparatedList(p_hosts)
    hosts = {}
    hosts_size = 0
    for i, host in pairs(split(p_hosts, ",")) do
        hosts[i] = host
        hosts_size = hosts_size + 1
    end
    return hosts, hosts_size
end

-- ##############################################

function getFirstIpFromMac(host_addr)
    local mac_resolved = host_addr
    -- Transforming the MAC into the ip address
    local mac_hosts = interface.getMacHosts(mac_resolved) or {}

    -- Mapping mac with ip and setting up the right href
    for _, h in pairsByKeys(mac_hosts, rev) do
        if (h.broadcast_domain_host) or (table.len(mac_hosts) == 1) then
            mac_resolved = h.ip
            break
        end
    end

    return mac_resolved
end

-- ##############################################

function getHostNotesKey(host_key)
    if (host_key == nil) then
        return (nil)
    end
    return "ntopng.cache.host_notes." .. host_key
end

-- ##############################################

function getHostNotes(host_info)
    local host_key

    if type(host_info) == "table" then
        host_key = host_info["host"]
    else
        host_key = host_info
    end

    local notes = ntop.getCache(getHostNotesKey(host_key))

    if isEmptyString(notes) and type(host_info) == "table" and host_info["vlan"] then
        -- Check if there is an alias for the host@vlan
        host_key = hostinfo2hostkey(host_info)
        notes = ntop.getCache(getHostNotesKey(host_key))
    end

    if not isEmptyString(notes) then
        notes = string.lower(notes)
    end

    return notes
end

-- ##############################################

-- A function to give a useful device name
function getDeviceName(device_mac, skip_manufacturer)
    local name = mac2label(device_mac)

    if name == device_mac then
        -- Not found, try with first host
        local info = interface.getHostsInfo(false, nil, 1, 0, nil, nil, nil, tonumber(vlan), nil, nil, device_mac)

        if (info ~= nil) then
            for x, host in pairs(info.hosts) do
                -- Make sure the IP is in the broadcast domain to avoid setting up names to MACs such as the gateway
                if host.broadcast_domain_host and not isEmptyString(host.name) and host.name ~= host.ip and host.name ~=
                    "NoIP" then
                    name = host.name
                elseif host.ip ~= "0.0.0.0" then
                    name = ip2label(host.ip)
                    if name == host.ip then
                        name = nil
                    end
                end
                break
            end
        else
            name = nil
        end
    end

    if(isEmptyString(name) and (device_mac ~= nil)) then
       if (not skip_manufacturer) then
	  name = get_symbolic_mac(device_mac, true)
       else
	  -- last resort
	  name = device_mac
       end
    end
    
    if isEmptyString(name) or name == device_mac then
        return ''
    end

    return name
end

-- ############################################
-- Redis Utils
-- ############################################

-- Inpur:     General prefix (i.e ntopng.pref)
-- Output:  User based prefix, if it exists
--
-- Examples:
--                With user:  ntopng.pref.user_name
--                Without:    ntopng.pref
function getRedisPrefix(str)
    if _SESSION and not (isEmptyString(_SESSION["user"])) then
        -- Login enabled
        return (str .. '.' .. _SESSION["user"])
    else
        -- Login disabled
        return (str)
    end
end

-----  End of Redis Utils  ------

-- ##############################################

-- Table preferences

function getDefaultTableSort(table_type)
    local table_key = getRedisPrefix("ntopng.sort.table")
    local value = nil

    if (table_type ~= nil) then
        value = ntop.getHashCache(table_key, "sort_" .. table_type)
    end
    if ((value == nil) or (value == "")) then
        value = 'column_'
    end
    return (value)
end

-- ##############################################

function getDefaultTableSortOrder(table_type, force_get)
    local table_key = getRedisPrefix("ntopng.sort.table")
    local value = nil

    if (table_type ~= nil) then
        value = ntop.getHashCache(table_key, "sort_order_" .. table_type)
    end
    if ((value == nil) or (value == "")) and (force_get ~= true) then
        value = 'desc'
    end
    return (value)
end

-- ##############################################

function getDefaultTableSize()
    table_key = getRedisPrefix("ntopng.sort.table")
    value = ntop.getHashCache(table_key, "rows_number")
    if ((value == nil) or (value == "")) then
        value = 10
    end
    return (tonumber(value))
end

-- ##############################################

function getInterfaceSpeed(ifid)
    local ifname = getInterfaceName(ifid)
    local ifspeed = ntop.getCache('ntopng.prefs.ifid_' .. tostring(ifid) .. '.speed')
    if not isEmptyString(ifspeed) and tonumber(ifspeed) ~= nil then
        ifspeed = tonumber(ifspeed)
    else
        ifspeed = interface.getMaxIfSpeed(ifid)
    end

    return ifspeed
end

-- ##############################################

function getCustomnDPIProtoCategoriesKey()
    return "ntop.prefs.custom_nDPI_proto_categories"
end

-- ##############################################

function setCustomnDPIProtoCategory(app_id, new_cat_id)
    ntop.setnDPIProtoCategory(app_id, new_cat_id)

    local key = getCustomnDPIProtoCategoriesKey()

    -- NOTE: when the ndpi struct changes, the custom associations are
    -- reloaded by Ntop::loadProtocolsAssociations
    ntop.setHashCache(key, tostring(app_id), tostring(new_cat_id));
end

-- ##############################################

function removeCustomnDPIProtoCategory(app_id)
    local key = getCustomnDPIProtoCategoriesKey()

    -- NOTE: when the ndpi struct changes, the custom associations are
    -- reloaded by Ntop::loadProtocolsAssociations
    ntop.delHashCache(key, tostring(app_id));
end

-- ##############################################

function getKeysSortedByValue(tbl, sortFunction)
    local keys = {}
    for key in pairs(tbl) do
        table.insert(keys, key)
    end

    table.sort(keys, function(a, b)
        return sortFunction(tbl[a], tbl[b])
    end)

    return keys
end

-- ##############################################

function getKeys(t, col)
    local keys = {}
    for k, v in pairs(t) do
        keys[tonumber(v[col])] = k
    end
    return keys
end

-- ##############################################

function getFlag(country)
    if ((country == nil) or (country == "")) then
        return ("")
    else
        return (" <a href='" .. ntop.getHttpPrefix() .. "/lua/hosts_stats.lua?country=" .. country .. "'><img src='" ..
                   ntop.getHttpPrefix() .. "/dist/images/blank.gif' class='flag flag-" .. string.lower(country) ..
                   "'></a> ")
    end
end

-- ##############################################

function getUsernameInputPattern()
    -- maximum len must be kept in sync with MAX_PASSWORD_LEN
    return [[^[a-zA-Z0-9._@!-?]{3,30}$]]
end

-- ##############################################

function getPasswordInputPattern()
    -- maximum len must be kept in sync with MAX_PASSWORD_LEN
    return [[^[\w\$\\!\/\(\)= \?\^\*@_\-\u0000-\u0019\u0021-\u00ff]{5,128}$]]
end

-- ##############################################

-- NOTE: keep in sync with validateLicense()
function getLicensePattern()
    return [[^[a-zA-Z0-9\+/=]+$]]
end

-- ##############################################

function getIPv4Pattern()
    return "^(?:(?:25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])\\.){3}(?:25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])$"
end

-- ##############################################

function getACLPattern()
    local ipv4 =
        "(?:(?:25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])\\.){3}(?:25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])"
    local netmask = "(\\/([0-9]|[1-2][0-9]|3[0-2]))"
    local cidr = ipv4 .. netmask
    local yesorno_cidr = "[\\+\\-]" .. cidr
    return "^" .. yesorno_cidr .. "(," .. yesorno_cidr .. ")*$"
end

-- ##############################################

function getMacPattern()
    return "^([0-9a-fA-F][0-9a-fA-F]:){5}[0-9a-fA-F]{2}$"
end

-- ##############################################

function getURLPattern()
    return "^https?://.+$"
end

-- ##############################################

function getURLPathPattern()
    return "^\\/lua\\/(?:[^\\/]+\\/)*[^\\/]+\\.lua(/?.*)?$"
end

-- ##############################################

function getRestUrl(script, is_pro, is_enterprise)
    if is_enterprise then
        return (ntop.getHttpPrefix() .. "/lua/enterprise/rest/v2/get/" .. script)
    elseif is_pro then
        return (ntop.getHttpPrefix() .. "/lua/pro/rest/v2/get/" .. script)
    else
        return (ntop.getHttpPrefix() .. "/lua/rest/v2/get/" .. script)
    end
end

-- ##############################################

-- get_mac_classification
function get_mac_classification(m, extended_name)
    local short_extended = ntop.getMacManufacturer(m) or {}

    if extended_name then
        return short_extended.extended or short_extended.short or m
    else
        return short_extended.short or m
    end

    return m
end

-- ##############################################

local magic_macs = {
    ["00:00:00:00:00:00"] = "",
    ["FF:FF:FF:FF:FF:FF"] = "Broadcast",
    ["01:00:0C:CC:CC:CC"] = "CDP",
    ["01:00:0C:CC:CC:CD"] = "CiscoSTP",
    ["01:80:C2:00:00:00"] = "STP",
    ["01:80:C2:00:00:00"] = "LLDP",
    ["01:80:C2:00:00:03"] = "LLDP",
    ["01:80:C2:00:00:0E"] = "LLDP",
    ["01:80:C2:00:00:08"] = "STP",
    ["01:1B:19:00:00:00"] = "PTP",
    ["01:80:C2:00:00:0E"] = "PTP"
}

local magic_short_macs = {
    ["01:00:5E"] = "IPv4mcast",
    ["33:33:"] = "IPv6mcast"
}

-- ###############################################

-- get_symbolic_mac
function get_symbolic_mac(mac_address, no_href, add_extra_info)
   if (magic_macs[mac_address] ~= nil) then
      return (magic_macs[mac_address])
   else
      local m = string.sub(mac_address, 1, 8)
      local t = string.sub(mac_address, 10, 17)

      if (magic_short_macs[m] ~= nil) then
	 if (add_extra_info == true) then
	    return (magic_short_macs[m] .. "_" .. t .. " (" .. macInfo(mac_address) .. ")")
	 else
	    if no_href then
	       return (magic_short_macs[m] .. "_" .. t)
	    else
	       return (macInfoWithSymbName(mac_address, magic_short_macs[m] .. "_" .. t))
	    end
	 end
      else
	 local s = get_mac_classification(m)

	 if (m == s) then
	    if no_href then
	       return get_mac_classification(m) .. ":" .. t
	    else
	       return '<a href="' .. ntop.getHttpPrefix() .. '/lua/mac_details.lua?host=' .. mac_address .. '">' ..
		  get_mac_classification(m) .. ":" .. t .. '</a>'
	    end
	 else
	    local href = ""
	    local href_end = ""

	    if not no_href then
	       href = '<a href="' .. ntop.getHttpPrefix() .. '/lua/mac_details.lua?host=' .. mac_address .. '">'
	       href_end = "</a>"
	    end

	    if (add_extra_info == true) then
	       return (href .. get_mac_classification(m) .. "_" .. t .. " (" .. macInfo(mac_address) .. ")" ..
		       href_end)
	    else
	       return (href .. get_mac_classification(m) .. "_" .. t .. href_end)
	    end
	 end
      end
   end
end

-- ##############################################

function get_mac_url(mac)
    local m = get_symbolic_mac(mac, true)

    if isEmptyString(m) then
        return ""
    end

    local url = ntop.getHttpPrefix() .. "/lua/mac_details.lua?host=" .. mac

    return string.format('[ <a href=\"%s\">%s</a> ]', url, m)
end

-- ##############################################

function get_manufacturer_mac(mac_address)
    local m = string.sub(mac_address, 1, 8)
    local ret = get_mac_classification(m, true --[[ extended name --]] )

    if (ret == m) then
        ret = "n/a"
    end

    if ret and ret ~= "" then
        ret = ret:gsub("'", " ")
    end

    return ret or "n/a"
end

-- ##############################################

-- getservbyport
function getservbyport(port_num, proto)
    if not port_num then return '' end
    port_num = tonumber(port_num)
    if not port_num then return '' end

    if not proto then proto = "TCP" end
    proto = string.lower(proto)

    -- io.write(port_num.."@"..proto.."\n")
    return (ntop.getservbyport(port_num, proto))
end

-- ##############################################

function getFlowMaxRate(cli_max_rate, srv_max_rate)
    cli_max_rate = tonumber(cli_max_rate)
    srv_max_rate = tonumber(srv_max_rate)

    if ((cli_max_rate == 0) or (srv_max_rate == 0)) then
        max_rate = 0
    elseif ((cli_max_rate == -1) and (srv_max_rate > 0)) then
        max_rate = srv_max_rate
    elseif ((cli_max_rate > 0) and (srv_max_rate == -1)) then
        max_rate = cli_max_rate
    else
        max_rate = math.min(cli_max_rate, srv_max_rate)
    end

    return (max_rate)
end

-- ####################################################

-- Functions to set/get a device type of user choice

local function getCustomDeviceKey(mac)
    return "ntopng.prefs.device_types." .. string.upper(mac)
end

-- ##############################################

function getCustomDeviceType(mac)
    return tonumber(ntop.getPref(getCustomDeviceKey(mac)))
end

-- #############################################

function setCustomDeviceType(mac, device_type)
    ntop.setPref(getCustomDeviceKey(mac), tostring(device_type))
end

-- ##############################################

-- @brief Compute and return the difference, in seconds, between the local time of this instance and GMT
-- @return A positive or negative number corresponding to the seconds between local time and GMT
local function get_server_timezone_diff_seconds()
    if not server_timezone_diff_seconds then
        local tmp_time = os.time()
        local d1 = os.date("*t", tmp_time)
        local d2 = os.date("!*t", tmp_time)
        -- Forcefully set isdst to false otherwise difference won't work during DST
        d1.isdst = false
        -- Use a minus to have the difference between local time and GMT, rather than between GMT and loca ltime
        server_timezone_diff_seconds = -os.difftime(os.time(d1), os.time(d2))
    end

    return server_timezone_diff_seconds
end

-- ####################################################

-- @brief Get the frontend timezone offset in seconds
-- @return The offset of the frontend timezone
function getFrontendTzSeconds()
    local frontend_tz_offset = nil

    if _COOKIE and _COOKIE.tzoffset then
        -- The timezone offset can be passed from the client as a cookie.
        -- This allows to format the dates in the frontend timezone.
        frontend_tz_offset = tonumber(_COOKIE.tzoffset)
    end

    if frontend_tz_offset == nil then
        -- If timezone is not available in the client _COOKIE,
        -- server timezone is used as fallback
        return -get_server_timezone_diff_seconds()
    end

    return frontend_tz_offset
end

-- ##############################################

function getTopFlowPeers(hostname_vlan, max_hits, detailed, other_options)
    local detailed = detailed or false

    local paginator_options = {
        sortColumn = "column_thpt",
        a2zSortOrder = false,
        detailedResults = detailed,
        maxHits = max_hits
    }

    if other_options ~= nil then
        paginator_options = table.merge(paginator_options, other_options)
    end

    local res = interface.getFlowsInfo(hostname_vlan, paginator_options)
    if ((res ~= nil) and (res.flows ~= nil)) then
        return res.flows
    else
        return {}
    end
end

-- ##############################################

function getSafeChildIcon()
    return ("&nbsp;<font color='#5cb85c'><i class='fas fa-lg fa-child' aria-hidden='true'></i></font>")
end

-- ###########################################

function getNtopngRelease(ntopng_info, verbose)
    local release

    if ntopng_info.oem or ntopng_info["version.nedge_edition"] then
        release = ""
    elseif (ntopng_info["version.enterprise_xl_edition"]) then
        release = "Enterprise XL"
    elseif (ntopng_info["version.enterprise_l_edition"]) then
        release = "Enterprise L"
    elseif (ntopng_info["version.enterprise_m_edition"]) then
        release = "Enterprise M"
    elseif (ntopng_info["version.enterprise_edition"]) or (ntopng_info["version.nedge_enterprise_edition"]) then
        release = "Enterprise"
    elseif (ntopng_info["pro.release"]) then
        release = "Professional"
    else
        release = "Community"
    end

    if not isEmptyString(release) and ntopng_info["version.embedded_edition"] then
        release = release .. " (Embedded)"
    end

    -- E.g., ntopng edge v.4.3.210112 (Ubuntu 16.04.6 LTS)
    local res = string.format("%s %s v.%s (%s)", ntopng_info.product, release, ntopng_info.version, ntopng_info.OS)

    if verbose and ntopng_info.revision then
        res = string.format("%s %s v.%s rev.%s (%s)", ntopng_info.product, release, ntopng_info.version,
            ntopng_info.revision, ntopng_info.OS)
    end

    if not ntopng_info.oem then
        local vers = string.split(ntopng_info["version.git"], ":")

        if vers and vers[2] then
            local ntopng_git_url = "<A HREF=\"https://github.com/ntop/ntopng/commit/" .. vers[2] ..
                                       "\"><i class='fab fa-github'></i></A>"

            res = string.format("%s | %s", res, ntopng_git_url)
        end
    end

    return res
end

-- ###########################################

-- A redis hash mac -> first_seen
function getDevicesHashMapKey(ifid)
    return "ntopng.checks.device_connection_disconnection.ifid_" .. ifid
end

-- ###########################################

function getHideFromTopSet(ifid)
    return "ntopng.prefs.iface_" .. ifid .. ".hide_from_top"
end

-- ###########################################

function getGwMacsSet(ifid)
    return "ntopng.prefs.iface_" .. ifid .. ".gw_macs"
end

-- ###########################################

function getDeviceProtocolPoliciesUrl(params_str)
    local url, sep

    if ntop.isnEdge() then
        url = "/lua/pro/nedge/admin/nf_edit_user.lua?page=device_protocols"
        sep = "&"
    else
        url = "/lua/admin/edit_device_protocols.lua"
        sep = "?"
    end

    if not isEmptyString(params_str) then
        return ntop.getHttpPrefix() .. url .. sep .. params_str
    end

    return ntop.getHttpPrefix() .. url
end

-- ###########################################

-- Returns the size of a folder (size is in bytes)
-- ! @param path the path to compute the size for
-- ! @param timeout the maxium time to compute the size. If nil, it defaults to 15 seconds.
function getFolderSize(path, timeout)
    local os_utils = require "os_utils"
    local folder_size_key = "ntopng.cache.folder_size"
    local now = os.time()
    local expiration = 30 -- sec
    local size = nil

    if ntop.isWindows() then
        size = 0 -- TODO
    else
        local MAX_TIMEOUT = tonumber(timeout) or 15 -- default
        -- Check if timeout is present on the system to cap the execution time of the subsequent du,
        -- which may be very time consuming, especially when the number of files is high
        local has_timeout = ntop.getCache("ntopng.cache.has_gnu_timeout")

        if isEmptyString(has_timeout) then
            -- Cache the timeout
            -- Check timeout existence with which. If no timeout is found, command will return nil
            has_timeout = (os_utils.execWithOutput("which timeout >/dev/null 2>&1") ~= nil)
            ntop.setCache("ntopng.cache.has_gnu_timeout", tostring(has_timeout), 3600)
        else
            has_timeout = has_timeout == "true"
        end

        -- Check the cache for a recent value
        local time_size = ntop.getHashCache(folder_size_key, path)
        if not isEmptyString(time_size) then
            local values = split(time_size, ',')
            if #values >= 2 and tonumber(values[1]) >= (now - expiration) then
                size = tonumber(values[2])
            end
        end

        if size == nil then
            size = 0
            -- Read disk utilization
            local periodic_activities_utils = require "periodic_activities_utils"
            if ntop.isdir(path) and not periodic_activities_utils.have_degraded_performance() then
                local du_cmd = string.format("du -s %s 2>/dev/null", path)
                if has_timeout then
                    du_cmd = string.format("timeout %u%s %s", MAX_TIMEOUT, "s", du_cmd)
                end

                -- use POSIXLY_CORRECT=1 to guarantee results is returned in 512-byte blocks
                -- both on BSD and Linux
                local line = os_utils.execWithOutput(string.format("POSIXLY_CORRECT=1 %s", du_cmd))
                local values = split(line, '\t')
                if #values >= 1 then
                    local used = tonumber(values[1])
                    if used ~= nil then
                        size = math.ceil(used * 512)

                        -- Cache disk utilization
                        ntop.setHashCache("ntopng.cache.folder_size", path, now .. "," .. size)
                    end
                end
            end
        end
    end

    return size
end

-- ###########################################

function getHttpUrlPrefix()
    if starts(_SERVER["HTTP_HOST"], 'https://') then
        return "https://"
    else
        return "http://"
    end
end

-- ##############################################

function getPoolName(pool_id)
    if isEmptyString(pool_id) or pool_id == "0" then
        return "Default"
    else
        local key = "ntopng.prefs.host_pools.details." .. pool_id

        return ntop.getHashCache(key, "name")
    end
end

-- ##############################################

function get_version_update_msg(info, latest_version)
    if info then
        local version_elems = split(info["version"], " ")
        local new_version = version2int(latest_version)
        local this_version = version2int(version_elems[1])

        if (new_version > this_version) then
            return i18n("about.new_major_available", {
                product = info["product"],
                version = latest_version,
                url = "http://www.ntop.org/get-started/download/"
            })
        end
    end

    return ""
end

-- ##############################################

function getFlowDevAliasKey()
    return "ntopng.flow_dev_aliases"
end

-- ##############################################

function getFlowDevAlias(flowdev_ip, add_id)
    local alias = ntop.getHashCache(getFlowDevAliasKey(), flowdev_ip)
    local ret

    if not isEmptyString(alias) then
        if (add_id == true) then
            ret = flowdev_ip .. " [" .. alias .. "]"
        else
            ret = alias
        end
    else
        ret = tostring(flowdev_ip)
    end

    return ret
end

-- ##############################################

function getFullFlowDevName(flowdev_ip, compact, add_id)
    local alias = getFlowDevAlias(flowdev_ip, add_id)

    if not isEmptyString(flowdev_ip) then
        if not isEmptyString(flowdev_ip) and alias ~= tostring(flowdev_ip) then
            if compact then
                alias = shortenString(alias)
                return string.format("%s", alias)
            else
                return string.format("%s [%s]", flowdev_ip, alias)
            end
        end
    end

    return flowdev_ip
end

-- ##############################################

function getObsPointAliasKey()
    return "ntopng.observation_point_aliases"
end

-- ##############################################

function getObsPointAlias(observation_point_id, add_id, add_href)
    local alias = ntop.getHashCache(getObsPointAliasKey(), observation_point_id)
    local ret

    if not isEmptyString(alias) then
        if (add_id == true) then
            ret = observation_point_id .. " [" .. alias .. "]"
        else
            ret = alias
        end
    else
        ret = tostring(observation_point_id)
    end

    if (add_href == true) then
        ret = "<A HREF=\"" .. ntop.getHttpPrefix() .. "/lua/pro/enterprise/observation_points.lua\">" .. ret .. "</A>"
    end

    return ret
end

-- ##############################################

function getFullObsPointName(observation_point_id, compact, add_id)
    local alias = getObsPointAlias(observation_point_id, add_id)

    if not isEmptyString(observation_point_id) then
        if not isEmptyString(observation_point_id) and alias ~= tostring(observation_point_id) then
            if compact then
                alias = shortenString(alias)
                return string.format("%s", alias)
            else
                return string.format("%u [%s]", observation_point_id, alias)
            end
        end
    end

    return observation_point_id
end

-- ##############################################

function getExtraFlowInfoTLSIssuerDN(alert_json)
    if alert_json and alert_json["proto"] and alert_json["proto"]["tls"] and
        not isEmptyString(alert_json["proto"]["tls"]["issuerDN"]) then
        return alert_json["proto"]["tls"]["issuerDN"]
    end
    return nil
end

-- ##############################################

function getExtraFlowInfoServerName(alert_json)
    if alert_json then
        if alert_json["proto"] and alert_json["proto"]["http"] and
            not isEmptyString(alert_json["proto"]["http"]["server_name"]) then
            return alert_json["proto"]["http"]["server_name"]
        elseif alert_json["proto"] and alert_json["proto"]["dns"] and
            not isEmptyString(alert_json["proto"]["dns"]["last_query"]) then
            return alert_json["proto"]["dns"]["last_query"]
        elseif alert_json["proto"] and alert_json["proto"]["tls"] and
            not isEmptyString(alert_json["proto"]["tls"]["client_requested_server_name"]) then
            return alert_json["proto"]["tls"]["client_requested_server_name"]
        end
    end
    return nil
end

-- ##############################################

function getExtraFlowInfoURL(alert_json)
    if alert_json then
        if alert_json["proto"] and alert_json["proto"]["http"] and
            not isEmptyString(alert_json["proto"]["http"]["last_url"]) then
            return alert_json["proto"]["http"]["last_url"]
        end
    end
    return getExtraFlowInfoServerName(alert_json)
end

-- ##############################################

function get_badge(info)
    local badge = 'success'

    if info ~= true and info ~= 0 then
        badge = 'danger'
    end

    return badge
end

-- ##############################################

function get_confidence(confidence_id, shorten_string)
    local tag_utils = require "tag_utils"
    local confidence_name = confidence_id

    if confidence_id and tonumber(confidence_id) then
        confidence_id = tonumber(confidence_id)

        for _, confidence in pairs(tag_utils.confidence or {}) do
            if confidence.id == confidence_id then
                confidence_name = confidence.label

                break
            end
        end
    end

    return confidence_name
end

-- ##############################################

local services = nil

local function readServices()
   if(services == nil) then
      local file = io.open("/etc/services", "r")
      if not file then return services end
      
      services = {}
      
      for line in file:lines() do
	 if((line ~= "") and (not(string.starts(line, "#")))) then
	    line = line:gsub("\t", " ")
	    line = line:gsub("  ", " ")
	    local elems = split(line, " ")
	    local label = elems[1]
	    local value
	    local i = 2
	    
	    while(elems[i] ~= nil) do
	       if(elems[i] ~=  "") then
		  value = elems[i]
		  break
	       end

	       i = i + 1
	    end
	    
	    services[value] = label
	    -- print(label.." = "..value.."<br>\n")
	 end
      end
      
      file:close()
   end

   return(services)
end

-- Example mapServiceName(80, "tcp")
function mapServiceName(port, protocol)
   readServices()
   local key = tostring(port).."/"..protocol

   return(services[key])
end

-- ##############################################

function getExporterList()
    local flowdevs = interface.getFlowDevices()
    local unified_exporters = {}
    for interface_id, device_list in pairs(flowdevs or {}) do
        for device_id, exporter_info in pairs(device_list, asc) do
            local exporter_ip = exporter_info.exporter_ip
            if not unified_exporters[exporter_ip] then
                unified_exporters[exporter_ip] = exporter_info
            end
        end
    end

    return unified_exporters
end

-- ##############################################

if (trace_script_duration ~= nil) then
    io.write(debug.getinfo(1, 'S').source .. " executed in " .. (os.clock() - clock_start) * 1000 .. " ms\n")
end
