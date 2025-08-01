--
-- (C) 2019-24 - ntop.org
--
dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

local json = require "dkjson"
local rest_utils = require "rest_utils"
local lists_utils = require "lists_utils"
local auth = require "auth"

-- ################################################
--
-- Hot reload enabled blacklists in ntopng
-- Example: curl -X POST -u admin:admin http://localhost:3000/lua/rest/v2/blacklist/reload.lua
--
local is_nedge = ntop.isnEdge()

local rc = rest_utils.consts.success.ok
local result = {}

-- pcall for error catching
local success, err = pcall(lists_utils.reloadLists)

if success then
    -- update last_update timestamp for all enabled lists
    local lists = lists_utils.getCategoryLists()
    local now = os.time()
    local updated = false
    
    for list_name, list in pairs(lists) do
        if list.enabled then
            list.status.last_update = now
            updated = true
        end
    end
    
    if updated then
        -- update last updated timestamp to now (for GUI)
        -- like in lists_utils.saveListsStatusToRedis()

        local status = {}
        for list_name, list in pairs(lists) do
            status[list_name] = list.status
        end
        
        local STATUS_KEY = "ntopng.cache.category_lists.status"
        ntop.setPref(STATUS_KEY, json.encode(status))
    end
end

-- to drop active flows in nedge after reloading the blacklists
if is_nedge then
    interface.updateFlowsShapers() 
end

result.success = success

if not success then
  result.error = err
end

-- ################################################

rest_utils.answer(rc, result)