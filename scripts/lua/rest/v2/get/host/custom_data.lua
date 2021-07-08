--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require ("dkjson")
local tracker = require("tracker")
local rest_utils = require("rest_utils")

--
-- Read information about a host and maps host fields into custom fields
-- Example: curl -s -u admin:admin -H "Content-Type: application/json"  -H "Content-Type: application/json" -d '{"host": "192.168.2.222", "ifid":"0"}' http://localhost:3000/lua/rest/v2/get/host/custom_data.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

local rc = rest_utils.consts.success.ok
local res = {}
local field_aliases = {}

local ifid = _GET["ifid"]
local fields = _GET["field_alias"]

if isEmptyString(ifid) then
   rest_utils.answer(rest_utils.consts.err.invalid_interface)
   return
end

interface.select(ifid)

-- Valid fields:
-- 1)     All: {"field_alias": "all"} - Dump all host stats.
--        -- Or --
--        All: Omit the "field_alias" parameter.
-- 2) Aliases: {"field_alias": "bytes.sent=tdb,packets.sent=tdp"}
-- 3)   Mixed: {"field_alias": "bytes.sent=tdb,packets.sent,ndpi=dpi"}
--
-- If the 'fields' parameter is missing 'all' host stat
-- fields will be dumped...
if (fields == nil) then
   field_aliases[#field_aliases + 1] = "all=all"
else
   --
   -- Invalid field alias...
   if isEmptyString(fields) then
      rest_utils.answer(rest_utils.consts.err.invalid_args)
      return
   end
   --
   -- Build host stats fields to use with potential aliases...
   local field = fields:split(",") or {fields}
   for _, fa in pairs(field) do
      local comp = fa:split("=")
      if (comp ~= nil) then
         --
         -- Field and alias...
         field_aliases[#field_aliases + 1] = comp[1] .. "=" .. comp[2]
      else
         --
         -- Alias same as field...
         field_aliases[#field_aliases + 1] = fa .. "=" .. fa
      end
   end
end

local hostparam = _GET["host"]
if ((hostparam ~= nil) or (not isEmptyString(hostparam))) then
   --
   -- Single host:
   local host_info = url2hostinfo(_GET)
   local host = interface.getHostInfo(host_info["host"], host_info["vlan"])
   if not host then
      rest_utils.answer(rest_utils.consts.err.not_found)
      return
   else
      --
      -- Check for 'all' host stat fields...
      if (field_aliases[1] == "all=all") then
         res = host
      else
         --
         -- Process selective host stat fields...
         for _, fa in pairs(field_aliases) do
            local comp = fa:split("=")
            local field = comp[1]
            local alias = comp[2]
            if (host[field] ~= nil) then
               --
               -- Add host field stat with potential alias name...
               res[alias] = host[field]
            end
         end
      end
      tracker.log("get_host_custom_data_json", {ifid, host_info["host"], host_info["vlan"], field_aliases})
      rest_utils.answer(rc, res)
      return
   end
else
   --
   -- All hosts:
   local hosts_stats = interface.getHostsInfo()
   hosts_stats = hosts_stats["hosts"]
   for key, value in pairs(hosts_stats) do
      local host = interface.getHostInfo(key)
      if (host ~= nil) then
         local hdata = {}
         if (field_aliases[1] == "all=all") then
            hdata = host
         else
            for _, fa in pairs(field_aliases) do
               local comp = fa:split("=")
               local field = comp[1]
               local alias = comp[2]
               if (host[field] ~= nil) then
                  hdata[alias] = host[field]
               end
            end
         end
         res[#res + 1] = hdata
      end
   end
   tracker.log("get_host_custom_data_json", {ifid, "All Hosts", field_aliases})
   rest_utils.answer(rc, res)
   return
end
