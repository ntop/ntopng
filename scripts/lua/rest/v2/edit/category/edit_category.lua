--
-- (C) 2013-22 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local categories_utils = require "categories_utils"
local lists_utils = require "lists_utils"
local rest_utils = require "rest_utils"

-- #################################

-- Checking root privileges
if not isAdministrator() then
  rest_utils.answer(rest_utils.consts.err.not_granted)
  return
end

local category_id = tonumber(split(_POST["category"], "cat_")[2])
local hosts_list = _POST["custom_hosts"]
local category_alias = _POST["category_alias"]
local hosts_ok = {}

local hosts = split(hosts_list, ",")

for _, host in ipairs(hosts) do
  if not isEmptyString(host) then
    local matched_category = ntop.matchCustomCategory(host)

    if not ((matched_category ~= nil) and (matched_category ~= category_id)) then
      hosts_ok[#hosts_ok + 1] = host
    end
  end
end

categories_utils.updateCustomCategoryHosts(category_id, hosts_ok)
categories_utils.updateCategoryName(category_id, category_alias)

lists_utils.reloadLists()

rest_utils.answer(rest_utils.consts.success.ok)
