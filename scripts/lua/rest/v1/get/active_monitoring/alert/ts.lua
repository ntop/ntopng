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
local am_alert_store = require "am_alert_store".new()

--
-- Read alerts count by time
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{ }' http://localhost:3000/lua/rest/v1/get/active_monitoring/alert/ts.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

local rc = rest_utils.consts.success.ok
local res = {}

interface.select(getSystemInterfaceId())

local count_by_time = am_alert_store:count_by_time()

rest_utils.answer(rc, {series = {{ data = count_by_time, name = i18n("alerts_dashboard.alerts") }}})
