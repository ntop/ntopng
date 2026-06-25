--
-- (C) 2013-26 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "label_utils"
require "ntop_utils"
require "http_lint"
require "mac_utils"
require "lua_utils_gui"
require "lua_utils"
local discover = require "discover_utils"

local rest_utils = require "rest_utils"
local format_utils = require "format_utils"

-- Table parameters
local all = _GET["all"]
local sort_order = _GET["order"]
local devices_mode  = _GET["devices_mode"]
local manufacturer  = _GET["manufacturer"]
local location  = _GET["location"] or ""
local device_type   = tonumber(_GET["device_type"])

-- ########################################
-- Pagination/sort/search parameters sent by table.vue
--   start: row offset (toSkip)
--   length: page size (maxHits)
--   sort: column id == data_field of the JSON column
--   order: "asc" | "desc"
--   map_search: free-text search string
local start_offset = tonumber(_GET["start"])  or 0
local page_length = tonumber(_GET["length"]) or 0
local sort_field = _GET["sort"]
local map_search = _GET["map_search"]
if isEmptyString(map_search) then map_search = nil end

-- Map the frontend column id (data_field) to the C++ sorter understood by
-- NetworkInterface::sortMacs(). Only the columns flagged "sortable" in
-- macs_list.json can ever reach here; anything else falls back to column_mac.
local sort_column_map = {
   mac = "column_mac",
   manufacturer = "column_manufacturer",
   hosts = "column_hosts",
   arp = "column_arp_total",
   seen_since = "column_since",
   throughput = "column_thpt",
   traffic = "column_traffic",
}
local sort_column = sort_column_map[sort_field] or "column_mac"

-- ########################################

-- Set used to map a device_type string id to the boolean flag consumed by the
-- Vue frontend. Replaces the long if/elseif ladder (one table lookup per row).
local known_device_types = {
   printer = true, video = true, workstation = true, laptop = true,
   tablet = true, phone = true, tv = true, networking = true,
   wifi = true, nas = true, multimedia = true, iot = true,
}

-- ########################################

-- Picks the IP to display in the "name" column for a MAC without a symbolic
-- name. ip_tbl is the subtable filled by interface.addMacsIpAddresses(): its
-- keys are host IPs, its values the IP version (4 or 6).
local function pick_representative_ip(ip_tbl)
   local best_local_v4, best_v4, best_any
   for ip, ipver in pairs(ip_tbl) do
      if (best_any == nil) or (ip < best_any) then best_any = ip end
      if ipver == 4 then
         if (best_v4 == nil) or (ip < best_v4) then best_v4 = ip end
         -- vlan
         local addr = ip:match("^([^@]+)") or ip
         if isLocal(addr) and ((best_local_v4 == nil) or (ip < best_local_v4)) then
            best_local_v4 = ip
         end
      end
   end
   return best_local_v4 or best_v4 or best_any
end

-- ########################################

local throughput_type = getThroughputType()

-- Sort direction. table.vue sends order=asc|desc.
local a2z_sort_order = true
if (sort_order == "desc") then
   a2z_sort_order = false
end

-- The "seen_since" column displays the *elapsed time* since first seen, not
-- the raw timestamp, so the visual order is the inverse of the timestamp
-- order. The previous client-side sorter inverted r0/r1 for this reason; we
-- replicate that here so the arrow direction keeps matching what the user sees.
if (sort_field == "seen_since") then
   a2z_sort_order = not a2z_sort_order
end

local source_macs_only   = false
local inactive_macs_only = false

if devices_mode == "source_macs_only" then
   source_macs_only = true
elseif devices_mode == "inactive_macs_only" then
   source_macs_only = true
   inactive_macs_only = true
end

if manufacturer == "" then manufacturer = nil end
if device_type == "" then device_type = nil end

-- ########################################
-- Retrieve only the page we need

-- array of MAC records to actually render (the page)
local page_macs
local effective_total

local maxHits = (page_length > 0) and page_length or nil  -- nil => all
local macs_stats = interface.getMacsInfo(sort_column, maxHits, start_offset,
                                         a2z_sort_order, source_macs_only,
                                         manufacturer, nil, device_type,
                                         location, nil, map_search)
local page_macs = macs_stats and macs_stats["macs"] or {}
local effective_total = (macs_stats and macs_stats["numMacs"]) or #page_macs


local rsp = {}

-- MACs that have no symbolic name but do have hosts: we need a representative
-- host IP for the name column. Instead of walking the whole hosts hash table
-- once per MAC, we collect them here and resolve all IPs with a single
-- hosts-table walk via interface.addMacsIpAddresses().
local macs_needing_ip = {}
local pending_name = {}

for _, value in ipairs(page_macs) do
   local record = {}
   record["mac"] = value["mac"]

   local mac_manufacturer = value["manufacturer"]
   if (mac_manufacturer == nil) then
      mac_manufacturer = ""
   end
   if ntop.isnEdge and ntop.isnEdge() then
      record["location"] = value.location
   end
   if (value["model"] ~= nil) then
      local _model = discover.apple_products[value["model"]] or value["model"]
      mac_manufacturer = mac_manufacturer .. " [ " .. shortenString(_model) .. " ]"
   end
   record["manufacturer"] = mac_manufacturer

   local device_type_string = discover.devtype2stringId(value["devtype"])
   local device_type_label = discover.devtype2string(value["devtype"])
   local device_type = {
      device_type_label = device_type_label
   }
   if known_device_types[device_type_string] then
      device_type[device_type_string] = true
   end
   record["device_type"] = device_type

   -- Name resolution.
   -- Fast path: a symbolic device name is available -> no host lookup needed.
   -- Slow path (no name): defer to the bulk IP resolution below, and only
   -- when the MAC actually has associated hosts (num_hosts > 0).
   local name_device = {name = getDeviceName(value["mac"], true), has_name = true}
   if (isEmptyString(name_device.name)) then
      local num_hosts = value["num_hosts"] or 0
      name_device = {has_name = false, num_hosts = num_hosts, host_label = ""}

      if num_hosts > 0 then
         macs_needing_ip[value["mac"]] = {}
         pending_name[#pending_name + 1] = { mac = value["mac"], name_device = name_device }
      end
   end
   record["name"] = name_device

   record["hosts"] = value["num_hosts"]

   if (value["arp_requests.sent"] == None) then
      record["arp"] = 0
   else
      record["arp"] = format_utils.formatValue(value["arp_requests.sent"] + value["arp_replies.sent"] +
                       value["arp_requests.rcvd"] + value["arp_replies.rcvd"])
   end

   record["seen_since"] = value["seen.first"]
   if ((value["bytes.sent"] == None) and (value.sent ~= None)) then
      value["bytes.sent"] = value.sent.bytes
      value["bytes.rcvd"] = value.rcvd.bytes
      value["throughput_bps"] = 0
   end

   record["breakdown"] = ""
   local total_bytes = value["bytes.sent"] + value["bytes.rcvd"]
   record["bytes_sent"] = value["bytes.sent"]
   record["bytes_rcvd"] = value["bytes.rcvd"]

   if (throughput_type == "pps") then
      record["throughput"] = value["throughput_pps"]
      record["throughput_type"] = "pps"
   else
      record["throughput"] = value["throughput_bps"]
      record["throughput_type"] = "bps"
   end
   record["traffic"] = value["bytes.sent"] + value["bytes.rcvd"]
   rsp[#rsp + 1] = record
end

-- ########################################
-- Single bulk resolution of MAC -> host IP addresses.
-- One walk over the hosts hash table fills the "ip" subtable of every MAC
-- present in macs_needing_ip. With server-side pagination this now runs on at
-- most "page_length" MACs instead of the whole table.
if next(macs_needing_ip) ~= nil then
   interface.addMacsIpAddresses(macs_needing_ip)
   for _, p in ipairs(pending_name) do
      local entry = macs_needing_ip[p.mac]
      local ip = entry and entry.ip and pick_representative_ip(entry.ip)

      if ip ~= nil then
         p.name_device.host_label = ip
      else
         p.name_device.num_hosts = 0
      end
   end
end

-- ########################################
rest_utils.extended_answer(rest_utils.consts.success.ok, rsp, {
   ["recordsTotal"] = effective_total,
   ["recordsFiltered"] = effective_total,
})
