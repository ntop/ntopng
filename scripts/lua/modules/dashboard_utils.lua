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
   return ntop.isClickHouseEnabled()
end

dashboard_utils.module_available = {
   ['historical_flows']   = is_clickhouse_available,
   ['vulnerability_scan'] = vs_utils.is_available
}

-- ##############################################

-- Get all configured dashboard templates
local function get_templates_from_dir(templates_dir)
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

-- ##############################################

-- Get all configured dashboard templates
function dashboard_utils.get_templates(templates_dirs)
   local templates = {}

   if type(templates_dirs) == "string" then
      templates = get_templates_from_dir(templates_dirs)
   else -- array of dir
      for _, dir in ipairs(templates_dirs) do
          local dir_templates = get_templates_from_dir(dir)
          templates = table.merge(templates, dir_templates)
      end
   end

   return templates
end

-- #################################################################

function dashboard_utils.get_widgets_definitions()
   local path = os_utils.fixPath(dirs.installdir .. "/scripts/templates/widgets.json")

   local definitions = file_utils.read_json_file(path)

   if not definitions or not definitions.widgets then
      return {}
   end

   return definitions.widgets
end

-- #################################################################

function dashboard_utils.get_widgets_definitions_by_id()
   local widgets = dashboard_utils.get_widgets_definitions()

   local widgets_by_id = {}
   for _, c in ipairs(widgets) do
      widgets_by_id[c.id] = c
   end

   return widgets_by_id
end

-- #################################################################

return dashboard_utils

