--
-- (C) 2026 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/notifications/?.lua;" .. package.path

--
-- Context of the Notifications SPA page (page-notifications.vue): channel types with their
-- params, filter options and shell scripts. Only raw values (i18n keys, no labels).
-- Example: curl -u admin:admin "http://localhost:3000/lua/rest/v2/get/notification/page_context.lua"
--

-- lua_utils (~14 ms) is loaded anyway: endpoints.get_types() loads the channel modules
-- (notifications/endpoints/*.lua), which require it
require "lua_utils"
local rest_utils = require "rest_utils"

if not isAdministrator() then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

local endpoints = require "endpoints"
local recipients = require "recipients"
local alert_severities = require "alert_severities"
local alert_categories = require "alert_categories"
local alert_entities = require "alert_entities"
local am_utils = require "am_utils"
local host_pools = require "host_pools":create()
local tag_badge_utils = require "tag_badge_utils"

local function params_list(params)
   local res = {}
   for _, param in ipairs(params or {}) do
      if param.param_name then
         res[#res + 1] = { name = param.param_name, optional = param.optional or false }
      end
   end
   return res
end

-- Channel types (builtin DB store excluded: it can not be created)
local types = {}
for key, endpoint in pairsByKeys(endpoints.get_types(true --[[ exclude builtin ]])) do
   types[#types + 1] = {
      key = key,
      name = endpoint.name,
      endpoint_params = params_list(endpoint.endpoint_params),
      recipient_params = params_list(endpoint.recipient_params),
   }
end

local severities = {}
for key, severity in pairs(alert_severities) do
   severities[#severities + 1] = { id = severity.severity_id, key = key }
end
table.sort(severities, function(a, b) return a.id < b.id end)

local categories = {}
for _, category in pairs(alert_categories) do
   categories[#categories + 1] = { id = category.id, i18n_title = category.i18n_title }
end
table.sort(categories, function(a, b) return a.id < b.id end)

local entities = {}
for key, entity in pairs(alert_entities) do
   entities[#entities + 1] = { id = entity.entity_id, key = key, i18n_label = entity.i18n_label }
end
table.sort(entities, function(a, b) return a.id < b.id end)

local notification_types = {}
for key in pairsByKeys(recipients.get_notification_types()) do
   notification_types[#notification_types + 1] = key
end

local pools = {}
for _, pool in pairs(host_pools:get_all_pools()) do
   pools[#pools + 1] = { id = pool.pool_id, name = pool.name }
end
table.sort(pools, function(a, b) return a.id < b.id end)

local am_hosts = {}
for key, am_host in pairsByKeys(am_utils.getHosts()) do
   local m_info = am_utils.getMeasurementInfo(am_host.measurement)
   am_hosts[#am_hosts + 1] = {
      id = key,
      label = am_host.label,
      measurement_i18n = m_info and m_info.i18n_label or nil,
   }
end

local tags = {}
for _, tag in ipairs(tag_badge_utils.getTags()) do
   tags[#tags + 1] = { id = tag.id, name = tag.name, color = tag.color }
end

-- Scripts the Shell channel can run (same folders as shell.runScript)
local shell_scripts = {}
for _, dir in ipairs({ "/usr/share/ntopng/scripts/shell/", dirs.installdir .. "/scripts/shell/" }) do
   for name in pairsByKeys(ntop.readdir(dir) or {}) do
      if name:match("%.sh$") or name:match("%.py$") then
         shell_scripts[#shell_scripts + 1] = name
      end
   end
end

rest_utils.answer(rest_utils.consts.success.ok, {
   types = types,
   severities = severities,
   categories = categories,
   entities = entities,
   notification_types = notification_types,
   -- Alerts recipients can deliver issues instead (Enterprise XXL+ with the issues enabled)
   delivery_modes = recipients.can_deliver_issues() and
      { recipients.DELIVERY_MODES.alerts, recipients.DELIVERY_MODES.issues } or nil,
   host_pools = pools,
   am_hosts = am_hosts,
   tags = tags,
   shell_scripts = shell_scripts,
})
