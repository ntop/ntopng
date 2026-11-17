--
-- (C) 2013-26 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require("ntop_utils")
require("lua_utils_gui")
local format_utils = require("format_utils")

-- ######################################

--- Utilities for formatting BGP/BMP information
-- into the structure expected by the GUI.
local bgp_utils = {}

-- ######################################

--- Formats raw BGP/BMP information into a GUI-friendly structure.
--
-- Input format:
-- {
--   ["1.1.1.0/24"] = {
--     ["185.54.80.3"] = {
--       asn = 202032,
--       origin = "igp",
--       next_hop = "185.54.80.3",
--       as_path = {13335},
--       communities = {"20203:2003"},
--       med = 0,
--       local_pref = 305,
--       best_entry = true
--     }
--   }
-- }
--
-- Output format:
-- {
--   { name = "bgp_prefix", value = "1.1.1.0/24" },
--   { name = "bgp_peer_id", value = {...} },
--   ...
-- }
--
-- @param bgp_info table Raw BGP/BMP information indexed by prefix.
-- @return table Formatted data suitable for GUI rendering.
function bgp_utils.formatBgpBmpInfo(bgp_info)
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

		-- Convert peer map into an iterable list.
		for bgp_id, info in pairs(peers) do
			peer_list[#peer_list + 1] = {
				id = bgp_id,
				info = info,
			}
		end

		-- Build GUI fields for every peer advertising the prefix.
		for _, peer in ipairs(peer_list) do
			peer_id[#peer_id + 1] = {
				name = formatNextHop(peer.id),
				value = peer.id,
				is_best_path = (peer.info.best_entry or false),
			}

			asn_list[#asn_list + 1] = {
				name = format_utils.formatASN(peer.info.asn, false, true),
				url = string.format("%s/lua/hosts_stats.lua?asn=%s", ntop.getHttpPrefix(), peer.info.asn),
				value = peer.info.asn,
			}

			bgp_origin[#bgp_origin + 1] = {
				name = string.upper(peer.info["origin"] or ""),
				value = peer.info["origin"] or "",
			}

			bgp_next_hop[#bgp_next_hop + 1] = {
				name = peer.info["next_hop"] or "",
				value = peer.info["next_hop"] or "",
			}

			med_list[#med_list + 1] = {
				name = ((peer.info["med"] ~= nil) and tostring(peer.info["med"]) or ""),
			}

			local_pref_list[#local_pref_list + 1] = {
				name = ((peer.info["local_pref"] ~= nil) and tostring(peer.info["local_pref"]) or ""),
			}

			-- Format AS path entries as clickable ASN links.
			if peer.info["as_path"] and #peer.info["as_path"] > 0 then
				for _, asn in ipairs(peer.info["as_path"]) do
					as_path[#as_path + 1] = {
						name = format_utils.formatASN(asn, false, true),
						url = string.format("%s/lua/hosts_stats.lua?asn=%s", ntop.getHttpPrefix(), asn),
						value = asn,
					}
				end
			end

			-- Format BGP communities.
			if peer.info["communities"] and #peer.info["communities"] > 0 then
				for _, c in ipairs(peer.info["communities"]) do
					communities[#communities + 1] = {
						name = c,
						value = c,
					}
				end
			end
		end

		-- Prefix-level information.
		rsp[#rsp + 1] = {
			name = "bgp_prefix",
			value = prefix,
		}

		rsp[#rsp + 1] = {
			name = "bgp_peer_id",
			value = peer_id,
		}

		rsp[#rsp + 1] = {
			name = "bgp_peer_asn",
			value = asn_list,
		}

		rsp[#rsp + 1] = {
			name = "bgp_origin",
			value = bgp_origin,
		}

		rsp[#rsp + 1] = {
			name = "bgp_next_hop",
			value = bgp_next_hop,
		}

		rsp[#rsp + 1] = {
			name = "bgp_as_path",
			value = as_path,
		}

		-- Show extended attributes only when multiple
		-- prefixes or peers are available.
		if not ((#bgp_info == 1) and (#peer_list > 0)) then
			rsp[#rsp + 1] = {
				name = "bgp_med",
				value = med_list,
			}

			rsp[#rsp + 1] = {
				name = "bgp_local_pref",
				value = local_pref_list,
			}

			rsp[#rsp + 1] = {
				name = "bgp_communities",
				value = communities,
			}
		end
	end

	return rsp
end

-- ######################################

--- Extracts and formats BGP/BMP information associated with a flow.
--
-- The flow can contain BGP/BMP metadata for both source and destination
-- endpoints, stored as JSON strings in:
--   - flow.bgp.src
--   - flow.bgp.dst
--
-- Each JSON payload is decoded and converted into the GUI-friendly format
-- produced by @{bgp_utils.formatBgpBmpInfo}.
--
-- Returned structure:
-- {
--   client_info = { ... },
--   server_info = { ... }
-- }
--
-- @param flow table Flow record containing optional BGP metadata.
-- @return table Table containing formatted source and destination
--         BGP/BMP information.
function bgp_utils.formatFlowBgpBmpInfo(flow)
	local client_info = {}
	local server_info = {}

	-- Extract and format source-side BGP information.
	if flow and flow.bgp then
		if flow.bgp.src then
			local bgp_info = json.decode(flow.bgp.src)
			client_info = bgp_utils.formatBgpBmpInfo(bgp_info)
		end

		-- Extract and format destination-side BGP information.
		if flow.bgp.dst then
			local bgp_info = json.decode(flow.bgp.dst)
			server_info = bgp_utils.formatBgpBmpInfo(bgp_info)
		end
	end

--[[
	-- Test helper.
	-- Useful when BGP/BMP pcaps are unavailable and GUI development
	-- requires sample data.

	client_info = bgp_utils.getDummyTestInfo()
	server_info = bgp_utils.getDummyTestInfo()
]]

	local bgp_info = {
		client_info = client_info,
		server_info = server_info,
	}

	return bgp_info
end

-- ######################################

--- Returns a static sample dataset useful for
-- GUI development and testing.
--
-- @return table Example BGP information already formatted
--         for GUI consumption.
function bgp_utils.getDummyTestInfo()
	local dummyInfo = {
		{
			name = "bgp_prefix",
			value = "1.1.1.0/24",
		},
		{
			name = "bgp_peer_id",
			value = { {
				name = "<a href=/lua/host_details.lua?host=185.54.80.3>185.54.80.3</a></a>",
			} },
		},
		{
			name = "bgp_peer_asn",
			value = {
				{
					name = "202032 (GOLINE - GOLINE SA)",
					url = "/lua/hosts_stats.lua?asn=202032",
				},
			},
		},
		{
			name = "bgp_origin",
			value = { {
				name = "IGP",
			} },
		},
		{
			name = "bgp_next_hop",
			value = { {
				name = "185.54.80.3",
			} },
		},
		{
			name = "bgp_as_path",
			value = {
				{
					name = "CLOUDFLARENET - Cloudflare",
					url = "/lua/hosts_stats.lua?asn=13335",
				},
			},
		},
		{
			name = "bgp_med",
			value = { {
				name = "",
			} },
		},
		{
			name = "bgp_local_pref",
			value = { {
				name = "305",
			} },
		},
		{
			name = "bgp_communities",
			value = { {
				name = "20203:2003",
			} },
		},
	}

	return dummyInfo
end

return bgp_utils
