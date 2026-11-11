--
-- (C) 2026 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

--
-- Adds a host (e.g. www.example.com) to a custom category (applied at once) or to an application
-- (protos file: applied after a restart) (administrators). JSON POST with the CSRF token: host +
-- category_id | application_id. rsp.restart_needed: true for an application.
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{"host": "example.com", "category_id": 14}' http://localhost:3000/lua/rest/v2/add/category/host_rule.lua
--

require "http_lint"
local rest_utils = require "rest_utils"

if not isAdministrator() then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

local host = _POST["host"]
local category_id = tonumber(_POST["category_id"])
local application_id = tonumber(_POST["application_id"])

-- A host name: no spaces or control characters (the value ends in the category lists and protos file)
if isEmptyString(host) or host:find("[%s%c]") or ((category_id == nil) == (application_id == nil)) then
   rest_utils.answer(rest_utils.consts.err.invalid_args)
   return
end

-- The id must be one of the nDPI categories / applications
local function is_known(list, id)
   for _, v in pairs(list or {}) do
      if tonumber(v) == id then return true end
   end
   return false
end

if category_id then
   local categories_utils = require "categories_utils"
   if not is_known(interface.getnDPICategories(), category_id) then
      rest_utils.answer(rest_utils.consts.err.invalid_args)
      return
   end
   if not categories_utils.addCustomCategoryHost(category_id, host) then
      -- Already in the category
      rest_utils.answer(rest_utils.consts.err.bad_content)
      return
   end
   require("lists_utils").reloadLists()
   rest_utils.answer(rest_utils.consts.success.ok, { restart_needed = false })
else
   local protos_utils = require "protos_utils"
   local app_name = interface.getnDPIProtoName(application_id)
   if not is_known(interface.getnDPIProtocols(), application_id) or not protos_utils.hasProtosFile() then
      rest_utils.answer(rest_utils.consts.err.invalid_args)
      return
   end
   if not protos_utils.addAppRule(app_name, { match = "host", value = host }) then
      rest_utils.answer(rest_utils.consts.err.bad_content)
      return
   end
   rest_utils.answer(rest_utils.consts.success.ok, { restart_needed = true })
end
