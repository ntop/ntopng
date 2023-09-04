--
-- (C) 2023 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "lua_utils_get"
local os_utils = require "os_utils"
local rest_utils = require "rest_utils"
local lua_path_utils = require "lua_path_utils"
local file_utils = require "file_utils"
local json = require "dkjson"

local dashboard_utils = {}

-- ##############################################

-- Get all configured dashboard templates
function dashboard_utils.get_templates(templates_dir)
   local templates = {}

   local templates_names = ntop.readdir(templates_dir)

   for template_name in pairs(templates_names) do
      if not ends(template_name, ".json") then
         goto continue
      end

      local template_path = os_utils.fixPath(templates_dir .. "/" .. template_name)

      local template = file_utils.read_json_file(template_path)

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

