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
-- Get list of dashboard templates
-- Example: curl -u admin:admin "http://localhost:3000/lua/pro/rest/v2/get/dashboard/template/list.lua"
--

if not ntop.isEnterpriseL() then
   rest_utils.answer(rest_utils.consts.err.not_granted, {})
   return
end

local page = "dashboard"

local rc = rest_utils.consts.success.ok

local res = {}

local templates_path = os_utils.fixPath(dirs.installdir .. "/scripts/templates/" .. page)
local templates = dashboard_utils.get_templates(templates_path)

local templates_list = {}

for name, template in pairs(templates) do
   templates_list[#templates_list+1] = {
      name = name
   }
end

----------------------------------

res.list = templates_list

rest_utils.answer(rest_utils.consts.success.ok, res)
