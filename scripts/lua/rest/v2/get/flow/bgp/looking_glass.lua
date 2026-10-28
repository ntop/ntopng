--
-- (C) 2013-26 - ntop.org
--
-- BGP Looking Glass: the routes (one row per prefix and peer) of the RIB entry of an IP.
-- Raw values only, the page (page-bgp-looking-glass.vue) formats them.
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "ntop_utils"
local json = require "dkjson"
local rest_utils = require "rest_utils"

-- ################################################

local rsp = {}
local host_to_find = _GET["host"]

if isEmptyString(host_to_find) or not(isIPv4(host_to_find) or isIPv6(host_to_find)) then
    rest_utils.answer(rest_utils.consts.success.ok, rsp)
    return
end

-- ################################################

local rib = ntop.ribFind(host_to_find)
-- DEBUG
--[[
local rib =
    '{"1.1.1.0\\/24": {"212.74.82.15": {"asn":8220,"origin":"igp","as_path": [8220,13335],"next_hop":"87.241.16.133","med":0,"local_pref":200,"communities": ["8220:65000","8220:65060","8220:65401"]},"185.54.80.4": {"asn":202032,"origin":"igp","as_path": [13335],"next_hop":"185.54.80.4","local_pref":305,"communities": ["20203:2004"]},"185.54.80.3": {"asn":202032,"origin":"igp","as_path": [13335],"next_hop":"185.54.80.3","local_pref":305,"communities": ["20203:2003"]},"38.28.1.11": {"asn":174,"origin":"igp","as_path": [174,13335],"next_hop":"149.11.89.168","med":0,"local_pref":200,"communities": ["174:21101","174:22004"]},"193.221.216.30": {"asn":5398,"origin":"igp","as_path": [5398,13335],"next_hop":"77.220.74.109","local_pref":200,"communities": ["5398:12051"]}}}'
]]

if not isEmptyString(rib) then
    rib = json.decode(rib)
end

if not table.empty(rib or {}) then
    local cache_utils = require "cache_utils"
    local site_utils -- loaded only for peers in a local network (~27 ms)
    -- ASN of the searched IP (for the RPKI check of the page)
    local host_asn = (ntop.getHostASN(host_to_find) or {}).asn
    local as_cache = {}

    -- Site of a peer in a local network (the others are in the default site)
    local function peer_site(ip)
        if not (ntop.isPro() and (tonumber(interface.getIPNetworkId(ip)) or -1) >= 0) then return nil end
        site_utils = site_utils or require "site_utils"
        return site_utils.mapHostToSite(ip).name
    end

    -- { asn, name }: the same AS is often in many paths
    local function as_info(asn)
        asn = tonumber(asn)
        if not asn then return nil end
        local info = as_cache[asn]
        if not info then
            local as_name = ntop.getASNameFromASN(asn)
            info = { asn = asn, name = as_name and (as_name.description or as_name.handle) or nil }
            as_cache[asn] = info
        end
        return info
    end

    for prefix, peers in pairs(rib) do
        for peer, info in pairs(peers or {}) do
            local name = cache_utils.gethostname(peer)
            local as_path = {}

            for _, asn in ipairs(info.as_path or {}) do
                as_path[#as_path + 1] = as_info(asn)
            end

            rsp[#rsp + 1] = {
                prefix = prefix,
                asn = host_asn,
                peer = peer,
                -- Resolved name of the peer (e.g. a flow exporter), when it has one
                peer_name = (not isEmptyString(name) and name ~= peer) and name or nil,
                peer_site = peer_site(peer),
                is_best_path = (info.best_entry == true),
                peer_asn = as_info(info.asn),
                origin = info.origin,
                as_path = as_path,
                next_hop = info.next_hop,
                med = tonumber(info.med),
                local_pref = tonumber(info.local_pref),
                communities = info.communities or {},
            }
        end
    end
end

-- ################################################

rest_utils.answer(rest_utils.consts.success.ok, rsp)
