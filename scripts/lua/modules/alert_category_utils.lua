--
-- (C) 2019-24 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

-- This is just a struct, try to keep this file without requires except for structs
local alert_categories = require "alert_categories"
local alert_category_utils = {}

-- ##############################################

-- @brief Given a category found in a user script, this method checks whether the category is valid
-- and, if not valid, it assigns to the script a default category
function alert_category_utils.checkCategory(category)
   if not category or not category["id"] then
      return alert_categories.other
   end

   for cat_k, cat_v in pairs(alert_categories) do
      if category["id"] == cat_v["id"] then
	 return cat_v
      end
   end

   return alert_categories.other
end

-- ##############################################

function alert_category_utils.getCategoryById(id)
   for cat_k, cat_v in pairs(alert_categories) do
      if cat_v["id"] == id then
	 return cat_v
      end
   end

   return alert_categories.other
end

-- ##############################################

return alert_category_utils