--
-- (C) 2013-26 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "ntop_utils"
require "lua_utils_gui"

-- ######################################

local bgp_utils = {}

-- ######################################

function bgp_utils.formatBgpBmpInfo(rib)
    local result = {}

    for prefix, peers in pairs(rib) do
        for peer_ip, peer_data in pairs(peers) do

            -- ASN number and name
            local asn_num = tonumber(peer_data.asn)
            local asn_entry = {
                raw  = peer_data.asn,
                name = string.format("%s (%s)", peer_data.asn, ntop.getASNameFromASN(asn_num))
            }

            -- AS path as value and name
            local as_path = {}
            for _, asn in ipairs(peer_data.as_path or {}) do
                local n = tonumber(asn)
                as_path[#as_path + 1] = {
                    raw  = asn,
                    name = string.format("%d (%s)", n, ntop.getASNameFromASN(n))
                }
            end

            -- communities is array of names 
            local communities = {}
            for _, community in ipairs(peer_data.communities or {}) do
                local left, right = community:match("^(%d+):(%d+)$")
                if left and right then
                    communities[#communities + 1] = {
                        raw   = community,
                        left  = {
                            raw  = left,
                            name = string.format("%s (%s)", left, ntop.getASNameFromASN(tonumber(left))),
                            url  = string.format("%s/lua/hosts_stats.lua?asn=%s", ntop.getHttpPrefix(), left)
                        },
                        right = {
                            raw  = right,
                            name = string.format("%s (%s)", right, ntop.getASNameFromASN(tonumber(right))),
                            url  = string.format("%s/lua/hosts_stats.lua?asn=%s", ntop.getHttpPrefix(), right)
                        },
                    }
                else
                    communities[#communities + 1] = { raw = community }
                end
            end

            local entry = {
                peer_ip     = peer_ip,
                asn         = asn_entry,
                origin      = string.upper(peer_data.origin or ""),
                as_path     = as_path,
                next_hop    = peer_data.next_hop,
                med         = peer_data.med,
                local_pref  = peer_data.local_pref,
                communities = communities,
            }

            result[#result + 1] = entry
        end
    end

    return result
end
 
function bgp_utils.formatBgpBmpInfo_old(bgp_info)
    local rsp = {}

    for prefix, peers in pairs(bgp_info or {}) do
        local peer_list = {}
        local peer_id = {}
        local asn_list = {}
        local bgp_origin = {}
        local bgp_next_hop = {}
        local as_path = {}
        local communities = {}
        local med_list = {}
        local local_pref_list = {}
        for bgp_id, info in pairs(peers) do
            peer_list[#peer_list + 1] = {
                id = bgp_id,
                info = info
            }
        end
        local max_len = (#peer_list > 2) and 8 or 32
        for _, peer in ipairs(peer_list) do
            peer_id[#peer_id + 1] = {
                name = formatNextHop(peer.id)
            }
            asn_list[#asn_list + 1] = {
                name = string.format("%s (%s)", peer.info.asn, ntop.getASNameFromASN(tonumber(peer.info.asn))),
                url = string.format("%s/lua/hosts_stats.lua?asn=%s", ntop.getHttpPrefix(), peer.info.asn)
            }
            bgp_origin[#bgp_origin + 1] = {
                name = string.upper(peer.info["origin"] or "")
            }
            bgp_next_hop[#bgp_next_hop + 1] = {
                name = peer.info["next_hop"] or ""
            }
            med_list[#med_list + 1] = {
                name = ((peer.info["med"] ~= nil) and tostring(peer.info["med"]) or "")
            }
            local_pref_list[#local_pref_list + 1] = {
                name = ((peer.info["local_pref"] ~= nil) and tostring(peer.info["local_pref"]) or "")
            }

            -- Formatting AS Path list
            if peer.info["as_path"] and #peer.info["as_path"] > 0 then
                local parts = {}
                for _, asn in ipairs(peer.info["as_path"]) do
                    as_path[#as_path + 1] = {
                        name = string.format("%d (%s)", tonumber(asn), ntop.getASNameFromASN(tonumber(asn))),
                        url = string.format("%s/lua/hosts_stats.lua?asn=%s", ntop.getHttpPrefix(), asn)
                    }
                end
            end

            -- Formatting Communities list
            if peer.info["communities"] and #peer.info["communities"] > 0 then
                for _, c in ipairs(peer.info["communities"]) do
                    communities[#communities + 1] = {
                        name = c
                    }
                end
            end
        end
        rsp[#rsp + 1] = {
            name = "bgp_prefix",
            value = prefix
        }
        rsp[#rsp + 1] = {
            name = "bgp_peer_id",
            value = peer_id
        }
        rsp[#rsp + 1] = {
            name = "bgp_peer_asn",
            value = asn_list
        }
        rsp[#rsp + 1] = {
            name = "bgp_origin",
            value = bgp_origin
        }
        rsp[#rsp + 1] = {
            name = "bgp_next_hop",
            value = bgp_next_hop
        }
        rsp[#rsp + 1] = {
            name = "bgp_as_path",
            value = as_path
        }
        if not ((#bgp_info == 1) and (#peer_list > 0)) then
            rsp[#rsp + 1] = {
                name = "bgp_med",
                value = med_list
            }
            rsp[#rsp + 1] = {
                name = "bgp_local_pref",
                value = local_pref_list
            }
            rsp[#rsp + 1] = {
                name = "bgp_communities",
                value = communities
            }
        end
    end
    return rsp
end

-- ######################################

return bgp_utils
