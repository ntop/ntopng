--
-- (C) 2013-24 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "ntop_utils"
require "lua_utils_get"
local rest_utils = require "rest_utils"
local lists_utils = require "lists_utils"

local rsp = {}
local category_filter = _GET["category"]
local enabled_status = _GET["enabled_status"]
local lists = lists_utils.getCategoryLists()

-- ################################################

local function getListStatusLabel(list)
    if not list.enabled then
        return "disabled"
    end

    if list.status.last_error then
        return "error"
    end

    return "enabled"
end

-- ################################################

for list_name, list in pairs(lists) do
    local catname = interface.getnDPICategoryName(tonumber(list.category))

    if ((not isEmptyString(category_filter)) and (category_filter ~= catname)) then
        goto continue
    end

    if enabled_status == "disabled" and list.enabled then
        goto continue
    elseif enabled_status == "enabled" and not list.enabled then
        goto continue
    end

    rsp[#rsp + 1] = {
        name = list_name,
        status = getListStatusLabel(list),
        category = getCategoryLabel(catname, list.category),
        update_frequency = list.update_interval,
        last_update = list.status.last_update,
        entries = list.status.num_hosts,
        hits = list.status.num_hits.current,
        url = list.url,
        category_id = list.category
    }

    ::continue::
end

rest_utils.extended_answer(rest_utils.consts.success.ok, rsp, {
    ["recordsTotal"] = 0
})
