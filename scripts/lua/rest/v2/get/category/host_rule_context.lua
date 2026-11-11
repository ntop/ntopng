--
-- (C) 2026 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

--
-- Context of the "custom host rule" dialog of the flow details (administrators): the host name
-- suggested for a server name/URL, the custom category that already matches it, and the
-- categories and applications it can be added to (applications only with a protos file).
-- Example: curl -u admin:admin "http://localhost:3000/lua/rest/v2/get/category/host_rule_context.lua?ifid=0&host=www.example.com"
--

require "http_lint"
local rest_utils = require "rest_utils"

if not isAdministrator() then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

local ifid = _GET["ifid"]
local host = _GET["host"]

if isEmptyString(ifid) or isEmptyString(host) then
   rest_utils.answer(rest_utils.consts.err.invalid_args)
   return
end

interface.select(ifid)
if tostring(interface.getId()) ~= tostring(ifid) then
   rest_utils.answer(rest_utils.consts.err.invalid_interface)
   return
end

require "lua_utils_generic"
local categories_utils = require "categories_utils"
local protos_utils = require "protos_utils"

local categories = {}
for name, id in pairs(interface.getnDPICategories() or {}) do
   categories[#categories + 1] = { id = tonumber(id), name = name }
end

local applications
if protos_utils.hasProtosFile() then
   applications = {}
   for name, id in pairs(interface.getnDPIProtocols() or {}) do
      applications[#applications + 1] = { id = tonumber(id), name = name }
   end
end

local matched = ntop.matchCustomCategory(host)

rest_utils.answer(rest_utils.consts.success.ok, {
   host = categories_utils.getSuggestedHostName(host),
   matched_category = matched and { id = matched, name = interface.getnDPICategoryName(matched) } or nil,
   categories = categories,
   applications = applications,
})
