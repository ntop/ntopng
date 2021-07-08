--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/alert_store/?.lua;" .. package.path

local alert_utils = require "alert_utils"
local alert_consts = require "alert_consts"
local alert_entities = require "alert_entities"
local rest_utils = require("rest_utils")
local system_alert_store = require "system_alert_store".new()

--
-- Read alerts data
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{}' http://localhost:3000/lua/rest/v2/acknowledge/system/alerts.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

local rc = rest_utils.consts.success.ok
local res = {}

interface.select(getSystemInterfaceId())

-- Add filters
system_alert_store:add_request_filters()

system_alert_store:acknowledge(_GET["label"])

rest_utils.answer(rc)

