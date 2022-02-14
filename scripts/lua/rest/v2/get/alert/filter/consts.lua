--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/alert_store/?.lua;" .. package.path

local rest_utils = require("rest_utils")
local alert_entities = require "alert_entities"
local alert_store_utils = require "alert_store_utils"
local alert_store_instances = alert_store_utils.all_instances_factory()

--
-- Get list of available filters
-- Example: curl -u admin:admin http://localhost:3000/lua/rest/v2/get/alert/filter/consts.lua?page=flow
--

local page = _GET["page"] or 'all'

local rc = rest_utils.consts.success.ok
local res = {}

local alert_store_instance

if alert_entities[page] and alert_store_instances[alert_entities[page].alert_store_name] then
   alert_store_instance = alert_store_instances[alert_entities[page].alert_store_name]
else
   alert_store_instance = require "all_alert_store".new()
end

res = alert_store_instance:get_available_filters()

rest_utils.answer(rest_utils.consts.success.ok, res)
