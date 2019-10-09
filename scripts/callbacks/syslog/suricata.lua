--
-- (C) 2019 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
require "alert_utils"
local json = require ("dkjson")
local alerts_api = require("alerts_api")
local check_modules = require("check_modules")
local alert_consts = require("alert_consts")

-- #################################################################

-- The function below ia called once (#pragma once)
function setup(name)
   -- tprint(name..".setup()")
end

-- #################################################################

-- The function below is called for each received alert
function handleAlert(alert_json)
   -- local alert = json.decode(alert_json)
   -- tprint(alert)
end 

-- #################################################################

-- The function below ia called once (#pragma once)
function teardown()

end

-- #################################################################
