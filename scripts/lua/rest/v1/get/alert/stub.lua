--
-- (C) 2013-21 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

local json = require "dkjson"
local rest_utils = require("rest_utils")
local alert_utils = require "alert_utils"

local recordsTotal = 0
local recordsFiltered = 0

local answer = {
    records = {}
}

rest_utils.extended_answer(rest_utils.consts.success.ok, answer, {
    ["draw"] = tonumber(_GET["draw"]),
    ["recordsFiltered"] = recordsFiltered,
    ["recordsTotal"] = recordsTotal
})