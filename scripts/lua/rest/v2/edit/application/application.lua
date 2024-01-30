--
-- (C) 2013-24 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path

require "lua_utils"
local protos_utils = require("protos_utils")
local rest_utils = require("rest_utils")

-- ##################################################

-- Checking root privileges
if not isAdministrator() then
    rest_utils.answer(rest_utils.consts.err.not_granted)
    return
end

-- ##################################################

local rc = rest_utils.consts.success.ok
local res = {}
local rules_list = _GET["custom_rules"] or ""
local l7_proto_name = (_GET["protocol_alias"] or '')
local l7_proto_id = _GET["l7_proto_id"]
local l7_category = tonumber(_GET["category"] or 0)
local applications = interface.getnDPIProtocols()
local rules = string.split(rules_list, "_") or {ternary(rules_list ~= "", rules_list, nil)}
local rules_to_add = {}
local existing_app = nil
local has_protos_file = protos_utils.hasProtosFile()

-- ##################################################

if isEmptyString(l7_proto_id) and isEmptyString(l7_proto_name) then
    rc = rest_utils.consts.err.invalid_args
    rest_utils.answer(rc, res)
    return
end

if has_protos_file then
    for _, _rule in ipairs(rules) do
        -- TODO implement match logic on existing rules to avoid duplicates
        local rule = protos_utils.getProtosTxtRule(_rule)
        if rule ~= nil then
            rules_to_add[#rules_to_add + 1] = rule
        end
    end

    protos_utils.overwriteAppRules(l7_proto_name, rules_to_add)
end

if l7_proto_id then
    l7_proto_id = tonumber(l7_proto_id)
    local old_category = ntop.getnDPIProtoCategory(l7_proto_id)

    if old_category.id ~= l7_category then
        -- traceError(TRACE_NORMAL, TRACE_CONSOLE, "Changing nDPI category for " .. l7_proto_id .. ": " .. old_category.id .. " -> " .. l7_category .. "\n")
        setCustomnDPIProtoCategory(l7_proto_id, l7_category)
    end
end

rest_utils.answer(rc, res)
