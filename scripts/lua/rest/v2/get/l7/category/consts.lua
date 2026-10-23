--
-- (C) 2013-21 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

-- No lua_utils: pairsByKeys/asc_insensitive come from ntop_utils, the
-- category label from categories_utils (what getCategoryLabel() calls)
require "ntop_utils"
local rest_utils = require "rest_utils"
local categories_utils = require "categories_utils"

--
-- Read all the defined L7 application categories
-- Example: curl -u admin:admin -H "Content-Type: application/json" http://localhost:3000/lua/rest/v2/get/l7/category/consts.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

local rc = rest_utils.consts.success.ok
local res = {}
local app_list = {}

local categories = interface.getnDPICategories()

for category, cat_id in pairs(categories) do

    local tmp_app_list = {}

    -- Get the list of the current cat_id

    for tmp_proto_name, tmp_proto_id in pairsByKeys(interface.getnDPIProtocols(tonumber(cat_id)), asc_insensitive) do
        tmp_app_list[#tmp_app_list + 1] = {
            name = tmp_proto_name,
            id = tmp_proto_id
        }
    end

    -- Create the record for the cat_id
    res[#res + 1] = {
        name = categories_utils.getCustomCategoryName(cat_id, category),
        cat_id = tonumber(cat_id),
        app_list = tmp_app_list
    }
end

rest_utils.answer(rc, res)
