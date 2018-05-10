--
-- (C) 2013-18 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local lists_utils = require "lists_utils"

if(ntop.isPro()) then
   package.path = dirs.installdir .. "/pro/scripts/callbacks/system/?.lua;" .. package.path
   pcall(require, 'daily')
end

-- ########################################################

-- Delete JSON files older than a 30 days
-- TODO: make 30 configurable
harvestJSONTopTalkers(30)

lists_utils.reloadLists()
