--
-- (C) 2013-21 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require ("dkjson")
local page_utils = require("page_utils")
local tracker = require("tracker")
local storage_utils = require("storage_utils")
local graph_utils = require("graph_utils")

if not isAllowedSystemInterface() then
   sendHTTPContentTypeHeader('text/html')

   page_utils.print_header()
   dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")
   print("<div class=\"alert alert-danger\"><i class='fas fa-exclamation-triangle fa-lg fa-ntopng-warning'></i> "..i18n("error_not_granted").."</div>")
   return
end

sendHTTPContentTypeHeader('application/json')

local info = {}

if not ntop.isWindows() then
   local storage_info = storage_utils.storageInfo()

   if not storage_info then
      goto out
   end

   local storage_items = {}

   local classes = { "primary", "info", "warning", "success", "secondary" }
   local colors = { "blue", "salmon", "seagreen", "cyan", "green", "magenta", "orange", "red", "violet" }

   -- interfaces
   local col = 1
   local num_items = 0

   for if_id, if_info in pairsByField(storage_info.interfaces, 'total', rev) do
      local item = {
	    title = getInterfaceName(if_id),
	    value = if_info.total,
	    link = ntop.getHttpPrefix() .. "/lua/if_stats.lua?ifid=" .. if_id
      }
      if num_items < #classes then
         item.class = classes[num_items+1]
      else
         item.style = "background-image: linear-gradient(to bottom, "..colors[col].." 0%, dark"..colors[col].." 100%)"
         col = col + 1
         if col > #colors then col = 1 end
      end
      table.insert(storage_items, item)
      num_items = num_items + 1
   end

   -- system
   local item = {
      title = i18n("system"),
      value = storage_info.other,
      link = ""
   }
   item.style = "background-image: linear-gradient(to bottom, grey 0%, darkgrey 100%)"
   table.insert(storage_items, item)

   info.storage =
      "<span>"..i18n("volume")..": "..dirs.workingdir.." ("..storage_info.volume_dev..")</span><br />"..
      graph_utils.stackedProgressBars(storage_info.volume_size, storage_items, i18n("available"), bytesToSize, "", true)

   if storage_info.pcap_volume_dev ~= nil then
      storage_items = {}

      -- interfaces
      col = 1
      num_items = 0
      for if_id, if_info in pairs(storage_info.interfaces) do
         local item = {
            title = getInterfaceName(if_id),
            value = if_info.pcap,
            link = ntop.getHttpPrefix() .. "/lua/if_stats.lua?ifid=" .. if_id
         }
         if num_items < #classes then
            item.class = classes[num_items+1]
         else
            item.style = "background-image: linear-gradient(to bottom, "..colors[col].." 0%, dark"..colors[col].." 100%)"
            col = col + 1
            if col > #colors then col = 1 end
         end
         table.insert(storage_items, item)
         num_items = num_items + 1
      end

      -- system
      local item = {
         title = i18n("system"),
         value = storage_info.pcap_other,
         link = ""
      }
      item.style = "background-image: linear-gradient(to bottom, grey 0%, darkgrey 100%)"
      table.insert(storage_items, item)

      info.pcap_storage =
        "<span>"..i18n("volume")..": "..dirs.workingdir.." ("..storage_info.pcap_volume_dev..")</span><br />"..
        graph_utils.stackedProgressBars(storage_info.pcap_volume_size, storage_items, i18n("available"), bytesToSize)
   end

   ::out::
end

print(json.encode(info, nil))
