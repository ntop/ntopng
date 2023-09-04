--
-- (C) 2013-23 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/pro/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/pro/enterprise/modules/?.lua;" .. package.path

local rest_utils = require "rest_utils"
local os_utils = require "os_utils"
local dashboard_utils = require "dashboard_utils"

--
-- Get list of components for a dashboard template
-- Example: curl -u admin:admin "http://localhost:3000/lua/pro/rest/v2/get/dashboard/template/data.lua?template=default"
--

if not ntop.isEnterpriseL() then
   rest_utils.answer(rest_utils.consts.err.not_granted, {})
   return
end

local template_id = _GET["template"]

local page = "dashboard"

if isEmptyString(template_id) then
   template_id = "default"
end

local rc = rest_utils.consts.success.ok

local res = {}
local components = {}

local templates_path = os_utils.fixPath(dirs.installdir .. "/scripts/templates/" .. page)
local templates = dashboard_utils.get_templates(templates_path)
local template = templates[template_id];
if template and template.components then
   components = template.components
end

----------------------------------
-- Component Definition Example --
----------------------------------
--[[

components[#components+1] = {
   -- Component type
   component = "simple-table",

   -- Component name
   id = "top_local_talkers",

   -- Component title
   i18n_name = "report.top_local_hosts", -- "dashboard.top_local_talkers",

   -- Background color
   -- - Accepted colors: primary, secondary, success, danger, warning, info, light, dark, white
   -- color = "success",

   -- Width/Height
   -- - Grid is divided into 12 units, we support 4/8/12 as size for components
   width  = 4,
   height = 4,

   -- Time Window
   -- - Configured here on Dashboard - with a default if not specified
   -- - User-selectable on Reports from the range picker
   -- - Accepted values: '5_min', '30_min', 'hour', '2_hours', '12_hours', 'day', 'week', 'month', 'year'
   time_window = '',

   -- Time Offset (optional)
   -- - Configured here both on Dashboard and Reports - e.g. show 1 week before
   -- - Accepted values: 'hour', 'day', 'week', 'month', 'year'
   time_offset = '',

   -- Interface ID (optional - use current ifid by default)
   --ifid = 1,

   -- Component-specific parameters
   params = {
      -- Rest URL (note: prefix is added by the component at runtime)
      url = "/lua/pro/rest/v2/get/interface/top/local/talkers.lua",
      url_params = {}, -- Array of (fixed) params to be passed to the REST URL (in addition to runtime params)
      table_type = 'throughput',
      columns = {
         { id = 'name', i18n_name = "host_details.host" },
         { id = 'throughput', i18n_name = "dashboard.actual_traffic" },
      },
   }
}

--]]
----------------------------------

res.list = components

rest_utils.answer(rest_utils.consts.success.ok, res)
