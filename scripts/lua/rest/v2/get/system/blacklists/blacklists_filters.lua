--
-- (C) 2013-24 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils_get"
local rest_utils = require "rest_utils"
local lists_utils = require "lists_utils"

local rsp = {}
local lists = lists_utils.getCategoryLists()
local list = {{
   key = "enabled_status",
   value = "enabled",
   label = i18n("category_lists.enabled")
}, {
   key = "enabled_status",
   value = "disabled",
   label = i18n("disabled")
}, {
   key = "enabled_status",
   value = "all",
   label = i18n("all")
}}

rsp[#rsp + 1] = {
   action = "enabled_status",
   label = i18n("status"),
   name = "enabled_status",
   value = list
}

list = {{
   key = "category",
   value = "",
   label = i18n("all")
}}
local category_list = {}
for list_name, list in pairsByKeys(lists) do
   local catname = interface.getnDPICategoryName(tonumber(list.category))
   local category = getCategoryLabel(catname, list.category)
   category_list[category] = (category_list[category] or 0) + 1
end

for category, _ in pairs(category_list) do
   list[#list + 1] = {
      key = "category",
      value = category,
      label = category
   }
end

rsp[#rsp + 1] = {
   action = "category",
   label = i18n("category"),
   name = "category",
   value = list
}

rest_utils.answer(rest_utils.consts.success.ok, rsp)
