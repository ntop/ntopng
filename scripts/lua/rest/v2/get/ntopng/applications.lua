--
-- (C) 2013-23 - ntop.org
--
dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local protos_utils = require("protos_utils")
local rest_utils = require("rest_utils")

-- Table parameters
local ifid = _GET["ifid"] or interface.getId()
local proto_filter = _GET["l7proto"]
local category_filter = _GET["category"]

local sortPrefs = "ndpi_application_category"
local custom_protos = protos_utils.parseProtosTxt()
local proto_to_num_rules = {}
local applications = interface.getnDPIProtocols()

for proto, rules in pairs(custom_protos) do
    proto_to_num_rules[proto] = #rules
end

local function makeApplicationHostsList(appname)
    local hosts_list = {}

    for _, rule in ipairs(custom_protos[appname] or {}) do
        if rule.match ~= 'port' then
            hosts_list[#hosts_list + 1] = rule.match .. ":" .. rule.value
        else
            hosts_list[#hosts_list + 1] = rule.value
        end
    end

    return table.concat(hosts_list, ",")
end

interface.select(ifid)

local categories = interface.getnDPICategories()

local result = {}

for app_name, app_id in pairs(applications) do
    local record = {}
    local category = ntop.getnDPIProtoCategory(tonumber(app_id))
    record["application_id"] = app_id
    record["category_id"] = category.id
    record["application"] = app_name
    record["num_hosts"] = proto_to_num_rules[app_name] or 0
    record["custom_rules"] = makeApplicationHostsList(app_name)
    record["is_custom"] = ntop.isCustomApplication(tonumber(app_id))
    record["category"] = getCategoryLabel(category.name, category.id)

    result[#result + 1] = record
end

rest_utils.answer(rest_utils.consts.success.ok, result)
