--
-- (C) 2021 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

local categories_utils = require("categories_utils")
local rest_utils = require "rest_utils"

-- ################################################

local ifid = _GET["ifid"] or interface.getId()
interface.select(ifid)

-- ################################################

local items = interface.getnDPICategories()
local res = {}

for item_name, item_id in pairs(items) do
  local hosts_list = categories_utils.getCustomCategoryHosts(item_id)
  local num_hosts = #hosts_list
  local num_protocols = table.len(interface.getnDPIProtocols(tonumber(item_id)))

  items[item_name] = { name = item_name, id = item_id, num_hosts = num_hosts, hosts_list = hosts_list , num_protocols = num_protocols }

  local record = {}

  record["column_category_id"] = item_id
  record["column_category_name"] = getCategoryLabel(item_name, item_id)
  record["column_num_hosts"] = tostring(num_hosts)
  record["column_num_protos"] = string.format('<a href="%s/lua/admin/edit_categories?tab=protocols&category=cat_%u">%s</a>', ntop.getHttpPrefix(), item_id, tostring(num_protocols))
  record["column_category_hosts"] = table.concat(hosts_list, ",")

  res[#res + 1] = record
end

-- ################################################

rest_utils.answer(rest_utils.consts.success.ok, res)
