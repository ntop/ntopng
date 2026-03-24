--
-- (C) 2026 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/pro/modules/?.lua;" .. package.path

require "lua_utils"
local rest_utils   = require "rest_utils"
local presets_utils = require "presets_utils"

--
-- Return all nDPI protocols with their device policies for a given device type.
-- Example: curl -u admin:admin http://localhost:3000/lua/rest/v2/get/device/protocol_policies.lua?device_type=0
--

local rc  = rest_utils.consts.success.ok
local res = {}

if not isAdministrator() then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

local device_type   = _GET["device_type"] or "0"
local policy_filter = _GET["policy_filter"] or ""
local proto_filter  = _GET["l7proto"] or ""
local category_filter = _GET["category"] or ""

interface.select(ifname)
presets_utils.init()

local device_policies = presets_utils.getDevicePolicies(device_type)
local all_protocols   = interface.getnDPIProtocols(nil, true)

local protocols = {}

for proto_name, proto_id in pairs(all_protocols) do
   local pid = tonumber(proto_id)

   -- Proto filter
   if not isEmptyString(proto_filter) and proto_filter ~= proto_id then
      goto continue
   end

   -- Category filter
   local cat = ntop.getnDPIProtoCategory(pid)
   if not isEmptyString(category_filter) and category_filter ~= cat.name then
      goto continue
   end

   local conf        = device_policies[pid]
   local client_pol  = (conf ~= nil and conf.clientActionId ~= nil) and conf.clientActionId or presets_utils.DEFAULT_ACTION
   local server_pol  = (conf ~= nil and conf.serverActionId ~= nil) and conf.serverActionId or presets_utils.DEFAULT_ACTION

   -- Policy filter
   if not isEmptyString(policy_filter) then
      if policy_filter ~= client_pol and policy_filter ~= server_pol then
         goto continue
      end
   end

   protocols[#protocols + 1] = {
      id            = proto_id,
      name          = proto_name,
      category      = cat.name,
      client_policy = client_pol,
      server_policy = server_pol,
   }

   ::continue::
end

-- Build actions list
local actions = {}
for _, action in ipairs(presets_utils.actions) do
   -- Strip HTML from icon, expose just the fa class name
   local icon_class = string.match(action.icon, 'fa%-([%w%-]+)') or "circle"
   actions[#actions + 1] = {
      id         = action.id,
      name       = action.name,
      text       = action.text,
      icon_class = "fas fa-" .. icon_class,
   }
end

-- Build categories list from all protocols for the filter UI
local categories_set = {}
for proto_name, proto_id in pairs(all_protocols) do
   local cat = ntop.getnDPIProtoCategory(tonumber(proto_id))
   if cat and cat.name and not categories_set[cat.name] then
      categories_set[cat.name] = true
   end
end
local categories = {}
for cat_name in pairs(categories_set) do
   categories[#categories + 1] = cat_name
end
table.sort(categories)

res = {
   protocols      = protocols,
   actions        = actions,
   categories     = categories,
   default_action = presets_utils.DEFAULT_ACTION,
}

rest_utils.extended_answer(rc, res, {
   recordsTotal    = #protocols,
   recordsFiltered = #protocols,
})
