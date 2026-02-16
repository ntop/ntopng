--
-- (C) 2019-26 - ntop.org
--
-- This module provides helper utilities to manage
-- Flow Exporters, Probes and their Interfaces.
-- It is mainly used by the ntopng Enterprise UI.
--
-- Retrieve ntop directories
dirs = ntop.getDirs()

-- Extend Lua module search path with standard ntop modules
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

-- Load common GUI and GET helpers
require "ntop_utils"
require "lua_utils_gui"
require "lua_utils_get"

-- SNMP utilities are only available in the Pro version
local snmp_utils = nil
if ntop.isPro() then
   package.path = dirs.installdir .. "/scripts/lua/pro/modules/?.lua;" .. package.path
   snmp_utils = require "snmp_utils"
end

-- Public module table
local exporters_utils = {}

-- ################################################
-- Interface data formatting helper
-- ################################################

---
-- Format interface statistics for a given exporter and append them to a result list.
--
-- @param exporter_ip string Exporter IP address
-- @param new_ports_list table List of interface statistics (ports)
-- @param res table Destination table where formatted entries are appended
-- @param uuid_list table Contains probe_uuid, exporter_uuid and ifid
-- @param add_role_to_interfaces boolean Whether to enrich interfaces with SNMP role
--
local function formatInterfaceData(exporter_ip, new_ports_list, res, uuid_list, add_role_to_interfaces)
   -- Iterate over all port groups
   for _, v in pairs(new_ports_list or {}) do
      -- Sort interfaces by total bytes (descending)
      for id, info in pairsByField(v, "bytes.total", rev) do
         local role = nil

         -- Resolve interface name from exporter IP and interface ID
         local interface_name = format_portidx_name(exporter_ip, tostring(id), true)

         -- Resolve exporter display name
         local exporter_name = getProbeName(exporter_ip, true, true, false)

         -- Optionally retrieve interface role via SNMP
         if (add_role_to_interfaces) then
            role = snmp_utils.get_snmp_interface_role(exporter_ip, id)
         end

         -- Append formatted interface entry
         res[#res + 1] = {
            interface_id = id,
            interface_name = interface_name,
            exporter_ip = exporter_ip,
            exporter_name = exporter_name,
            exporter_uuid = uuid_list.exporter_uuid,
            probe_uuid = uuid_list.probe_uuid,
            ifid = uuid_list.ifid, -- ntop interface ID
            bytes_sent = info["bytes.out_bytes"],
            bytes_rcvd = info["bytes.in_bytes"],
            total_bytes = info["bytes.total"],
            role = role
         }
      end
   end
end

-- ################################################
-- Exporters Interfaces
-- ################################################

---
-- Retrieve the list of all exporter interfaces across all probes.
--
-- @param add_role_to_interfaces boolean Whether to add SNMP interface roles
-- @return table List of exporter interfaces
--
function exporters_utils.getAllInterfacesList(add_role_to_interfaces)
   local list = {}

   -- Global interface statistics
   local ifstats = interface.getStats()

   -- Iterate over all probes grouped by interface ID
   for ifid, probe_list in pairs(ifstats.probes or {}) do
      for _, probe_info in pairsByKeys(probe_list or {}) do
         local source_id = probe_info["probe.source_id"]
         local probe_ip = probe_info["probe.ip"]

         -- Ensure probe has a valid source_id
         if (source_id) then
            if (table.len(probe_info.exporters) == 0) then
               -- Packet probe (no exporters, traffic captured locally)
               local ports_table = interface.getFlowDeviceInfo(source_id, true)
               local exporter_ip = probe_info["remote.if_addr"]

               formatInterfaceData(exporter_ip, ports_table, list, {
                  probe_source_id = source_id,
                  exporter_source_id = source_id,
                  ifid = ifid
               }, add_role_to_interfaces)
            else
               -- Collector probe (NetFlow / IPFIX / sFlow)
               for exporter_ip, exporter_info in pairsByKeys(probe_info.exporters or {}) do
                  local ports_table = interface.getFlowDeviceInfo(exporter_info.unique_source_id, true)

                  formatInterfaceData(exporter_ip, ports_table, list, {
                     probe_source_id = source_id,
                     exporter_source_id = unique_source_id,
                     ifid = ifid
                  }, add_role_to_interfaces)
               end
            end
         end
      end
   end

   return list
end

-- ################################################
-- Probes List
-- ################################################

---
-- Retrieve the list of all probes and exporters.
--
-- @return table List of probes/exporters metadata
--
function exporters_utils.getAllProbesList()
   local ifnames = interface.getIfNames()
   local ifstats = interface.getStats()
   local list = {}

   -- Iterate over all probes
   for ifid, probe_list in pairs(ifstats.probes or {}) do
      for _, probe_info in pairsByKeys(probe_list or {}) do
         local source_id = probe_info["probe.source_id"]
         local probe_ip = probe_info["probe.ip"]

         -- Flow-based probes (NetFlow / sFlow)
         if probe_info.exporters and table.len(probe_info.exporters) > 0 then
            for exporter_ip, exporter_info in pairsByKeys(probe_info.exporters or {}, asc) do
               local name = getProbeName(exporter_ip, true, false, false)

               if ifstats.isView then
                  name = name .. " [ " .. ifnames[tostring(ifid)] .. "]"
               end

               list[#list + 1] = {
                  name = name,
                  ip = exporter_ip,
                  unique_source_id = exporter_info.unique_source_id,
                  ifid = ifid
               }
            end
         else
            -- Packet probe
            local name = getProbeName(probe_ip, true, false, false)

            if ifstats.isView then
               name = name .. " [ " .. ifnames[tostring(ifid)] .. "]"
            end

            list[#list + 1] = {
               name = name,
               unique_source_id = source_id,
               ip = probe_ip,
               ifid = ifid
            }
         end
      end
   end

   return list
end

-- ################################################
-- Exporter UUID resolution (with cache)
-- ################################################

-- Cache: exporter_ip -> { exporter_source_id, ifid }
local _exporter_source_id = {}

---
-- Retrieve exporter UUID and interface ID from exporter IP.
--
-- @param exporter_ip string
-- @return string exporter_source_id
-- @return number ifid
--
function exporters_utils.getExporterID(exporter_ip)
   local ret = _exporter_source_id[exporter_ip]
   if (ret ~= nil) then
      return ret
   end

   if not isEmptyString(exporter_ip) then
      local flow_exporters = interface.getFlowDevices()

      for ifid, info in pairs(flow_exporters or {}) do
         for exporter_source_id, exporter_info in pairs(info or {}) do
            if exporter_info.exporter_ip == exporter_ip then
               _exporter_source_id[exporter_ip] = {exporter_source_id, ifid}
               return exporter_source_id, ifid
            end
         end
      end
   end

   return nil, nil
end

-- ################################################
-- Probe ID resolution (with cache)
-- ################################################

-- Cache: exporter_ip -> { probe_source_id, ifid }
local _probe_source_id = {}

---
-- Retrieve probe ID associated with a given exporter IP.
--
-- @param exporter_ip string
-- @return string probe_source_id
-- @return number ifid
--
function exporters_utils.getProbeID(exporter_ip)
   local ret = _probe_source_id[exporter_ip]
   if (ret ~= nil) then
      return ret
   end

   if not isEmptyString(exporter_ip) then
      local exporter_source_id = nil
      local flow_exporters = interface.getFlowDevices()

      -- Resolve exporter ID
      for ifid, info in pairs(flow_exporters or {}) do
         for source_id, exporter_info in pairs(info or {}) do
            if exporter_info.exporter_ip == exporter_ip then
               exporter_source_id = source_id
               goto uuid_found
            end
         end
      end
      ::uuid_found::

      -- Map exporter ID to probe ID
      if (exporter_source_id) then
         local ifstats = interface.getStats()

         for ifid, probe_list in pairs(ifstats.probes or {}) do
            for probe_source_id, probe_info in pairsByKeys(probe_list or {}) do
               if tostring(probe_source_id) == tostring(exporter_source_id) then
                  -- Packet probe
                  _probe_source_id[exporter_ip] = {probe_source_id, ifid}
                  return probe_source_id, ifid
               end

               for _, exporter_info in pairs(probe_info.exporters or {}) do
                  if tostring(exporter_info.unique_source_id) == tostring(exporter_source_id) then
                     -- Flow exporter
                     _probe_source_id[exporter_ip] = {probe_source_id, ifid}
                     return probe_source_id, ifid
                  end
               end
            end
         end
      end
   end

   return nil, nil
end

-- ################################################
-- Navbar helpers
-- ################################################

---
-- Build the navigation bar title with breadcrumbs.
--
-- @param ip string Exporter IP
-- @param nprobe_info table Probe metadata
-- @return string HTML title
--
local function build_navbar_title(ip, nprobe_info)
   local navbar_title = i18n("flow_devices.nprobe_instances")
   
   local overview_url = ntop.getHttpPrefix() .. "/lua/pro/enterprise/nprobe.lua?page=overview"
   navbar_title = "<a href='".. overview_url .."'>" .. navbar_title .. "</a>"
   
   if nprobe_info then
      local breadcrumb = "<span> | "
      local probe_ip = nprobe_info["probe.ip"]
      local probe_name = getProbeName(probe_ip, true, true, false)

      if not isEmptyString(ip) and ip ~= probe_ip then
         local probe_source_id = tostring(nprobe_info["probe.source_id"])
         local exporters_url = ntop.getHttpPrefix()
                                 .. "/lua/pro/enterprise/exporters.lua?probe_source_id=" .. probe_source_id

         breadcrumb = breadcrumb .. "<a href='".. exporters_url .."'>"
                                 .. i18n("flow_devices.probe") .. " " .. probe_name .. "</a>"

         local exporter_name = getProbeName(ip, true, true, false)
         breadcrumb = breadcrumb .. " / " .. i18n("flow_devices.exporter") .. " " .. exporter_name
         if exporter_name ~= ip then
            breadcrumb = breadcrumb .. " (" .. ip .. ") "
         end
      else
         -- clickable probe IP in the breadcrumb
         local probe_source_id = tostring(nprobe_info["probe.source_id"])
         local exporters_url = ntop.getHttpPrefix()
                                 .. "/lua/pro/enterprise/exporters.lua?probe_source_id=" .. probe_source_id

         breadcrumb = breadcrumb .. "<a href='".. exporters_url .."'>"
                                 .. i18n("flow_devices.probe") .. " " .. probe_name .. "</a>"
      end

      breadcrumb = breadcrumb .. "</span>"
      navbar_title = navbar_title .. breadcrumb
   end

   return navbar_title
end

-- ################################################
-- Navbar rendering
-- ################################################

---
-- Print the exporters navigation bar.
--
-- @param ifid number Interface ID
-- @param page string Active page
-- @param ip string Exporter IP
-- @param probe_source_id string Probe ID
--
function exporters_utils.printNavbar(ifid, page, ip, probe_source_id, num_exporters)
   local page_utils = require("page_utils")
   -- URLs and state flags initialization
   local interfaces_url = ntop.getHttpPrefix() .. "/lua/pro/enterprise/exporter_interfaces.lua"
   local exporter_url = ntop.getHttpPrefix() .. "/lua/pro/enterprise/exporters.lua"
   local exporter_map_url
   local snmp_available = false
   local nprobe_info = nil
   local probe_ip = nil
   local conf_url = ""
   local timeseries_url = ""
   local snmp_url = ""

   probe_source_id = probe_source_id or ""
   exporter_map_url = ntop.getHttpPrefix() .. "/lua/pro/enterprise/exporters_map.lua?probe_source_id="..probe_source_id

   if(num_exporters == nil) then num_exporters = 0 end

   -- Resolve probe information if available
   if not isEmptyString(probe_source_id) then
      nprobe_info = getProbeFromID(probe_source_id)
      if isEmptyString(ip) and nprobe_info then
         ip = nprobe_info["probe.ip"]
      end
   else
      if not isEmptyString(ip) then
         local probe,_ = exporters_utils.getProbeID(ip)
         if probe then
            nprobe_info = getProbeFromID(probe)
         end
      end
   end

   if nprobe_info then
      probe_ip = nprobe_info["probe.ip"]
   end

   local title_navbar = build_navbar_title(ip, nprobe_info)

   -- Check SNMP availability
   snmp_available = exporters_utils.isSNMPAvailable(ip)
   snmp_url = ntop.getHttpPrefix() .. "/lua/pro/enterprise/snmp_device_details.lua?host=" .. ip

   -- Append parameters
   if not isEmptyString(probe_source_id) then
      interfaces_url = interfaces_url .. "?probe_source_id=" .. probe_source_id
      exporter_url = exporter_url .. "?probe_source_id=" .. probe_source_id

      if not isEmptyString(ip) then
         local _, tmp1 = exporters_utils.getProbeID(ip)
         if not isEmptyString(tmp1) then
            -- tmp1 is not available in case no exporter is available,
            -- e.g. nprobe not currently exporting flows
            conf_url = ntop.getHttpPrefix() .. "/lua/pro/enterprise/exporter_interfaces.lua?ip=" .. ip .. "&ifid=" .. tmp1 ..
                          "&page=config&probe_source_id=" .. probe_source_id
            timeseries_url = ntop.getHttpPrefix() .. "/lua/pro/enterprise/exporter_details.lua?ip=" .. ip .. "&ifid=" .. tmp1 ..
                                "&page=historical&probe_source_id=" .. probe_source_id
         end
      end
   end

   -- Render navbar
   page_utils.print_navbar(title_navbar, ntop.getHttpPrefix() .. "/lua/pro/enterprise/nprobe.lua", {{
      url = exporter_url,
      page_name = "exporters",
      active = (page == "exporters"),
      label = i18n("flow_devices.flow_exporters")
   }, {
      url = interfaces_url,
      page_name = "interfaces",
      active = page == "interfaces",
      label = i18n("flow_devices.exporters_interfaces")
   }, {
      url = exporter_map_url,
      hidden = (num_exporters < 2) or not(isASNModeEnabled()),
      hidden = false, page ~= "exporters" or num_exporters < 2 or not(isASNModeEnabled()),
      page_name = "exporter_map",
      active = page == "exporter_map",
      label = "<i class=\"fas fa-lg fa-map\" data-bs-toggle=\"tooltip\" " .. "title=\"" .. i18n("exporter_sites_page.exporters_map") .. "\"></i>"
   }, {
      hidden = not snmp_available or isEmptyString(ip),
      url = snmp_url,
      page_name = "snmp",
      label = i18n("if_stats_overview.snmp")
   }, {
      active = page == "historical",
      page_name = "historical",
      hidden = isEmptyString(ip) or (probe_ip == ip),
      url = timeseries_url,
      label = "<i class=\"fas fa-lg fa-chart-area\" data-bs-toggle=\"tooltip\" " .. "title=\"" .. i18n("prefs.timeseries") .. "\"></i>"
   }, {
      active = page == "config",
      page_name = "config",
      hidden = isEmptyString(ip) or (probe_ip == ip),
      url = conf_url,
      label = "<i class=\"fas fa-lg fa-cog\" data-bs-toggle=\"tooltip\" " .. "title=\"" .. i18n("flow_checks.callback_config") .. "\"></i>"
   },{
      page_name = "sites",
      hidden = page ~= "exporter_map" and page ~= "exporter_sites_map",
      active = page == "exporter_sites_map",
      url = ntop.getHttpPrefix() .. "/lua/pro/enterprise/exporters_sites_map.lua?site_mode=1&probe_source_id=" .. probe_source_id,
      label = i18n("exporter_sites_page.sites")
   }})
end

-- ################################################

--
-- Check whether SNMP information is available for a given device.
--
-- This function verifies if SNMP system information for the specified
-- device IP is present in the SNMP cache. If system data exists, SNMP
-- is considered available for that device.
--
-- @brief Check SNMP availability for a device
-- @param device_ip string The IP address of the device to check
-- @return boolean true if SNMP data is available, false otherwise
--
function exporters_utils.isSNMPAvailable(device_ip)
   -- Ensure the device IP is valid and not empty
   if not isEmptyString(device_ip) then
      local snmp_cached_dev = require "snmp_cached_dev"

      -- Retrieve cached SNMP system information for the device
      -- NOTE: cached_system_info is expected to always be a table
      local cached_system_info = snmp_cached_dev:get_system(device_ip) or {}

      -- cached_system_info.system contains SNMP system data
      -- If it has at least one entry, SNMP is considered available
      -- The comment below assumes that cached_system_info is never nil
      if table.len(cached_system_info.system) > 0 then
         return true
      end
   end

   -- SNMP data not available or invalid device IP
   return false
end

-- ################################################

-- Return public module
return exporters_utils
