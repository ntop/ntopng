--
-- (C) 2023 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/vulnerability_scan/?.lua;" .. package.path

require "lua_utils"
require "lua_utils_get"
local os_utils = require "os_utils"
local rest_utils = require "rest_utils"
local lua_path_utils = require "lua_path_utils"
local file_utils = require "file_utils"
local json = require "dkjson"
local vs_utils = require "vs_utils"
local prefs = ntop.getPrefs()

local dashboard_utils = {}

-- ##############################################

local function is_clickhouse_available()
   return prefs.is_dump_flows_to_clickhouse_enabled
end

dashboard_utils.module_available = {
   ['historical_flows']   = is_clickhouse_available,
   ['vulnerability_scan'] = vs_utils.is_available
}

-- ##############################################

-- Get all configured dashboard templates
function dashboard_utils.get_templates(templates_dir)
   local templates = {}
   local info = ntop.getInfo()

   local templates_names = ntop.readdir(templates_dir)

   for template_name in pairs(templates_names) do
      if not ends(template_name, ".json") then
         goto continue
      end

      local template_path = os_utils.fixPath(templates_dir .. "/" .. template_name)

      local template = file_utils.read_json_file(template_path)

      if not template then
         goto continue
      end

      if template.requires then
         if template.requires.model then
            local model = template.requires.model
            if     model == 'pro' and not info['pro.release']                   then goto continue
            elseif model == 'm'   and not info['version.enterprise_m_edition']  then goto continue
            elseif model == 'l'   and not info['version.enterprise_l_edition']  then goto continue
            elseif model == 'xl'  and not info['version.enterprise_xl_edition'] then goto continue
            end
         end

         if template.requires.modules then
            for _, module in ipairs(template.requires.modules) do
               if not dashboard_utils.module_available[module] or
                  not dashboard_utils.module_available[module]() then
                  goto continue
               end
            end
         end
      end

      template_name = template_name:sub(1, #template_name - 5)

      if template ~= nil then
         template.id = template_name
         templates[template_name] = template
      end

      ::continue::
   end

   return templates
end

-- #################################################################

return dashboard_utils

