--
-- (C) 2020 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json          = require("dkjson")
local rest_utils    = require("rest_utils")
local tracker       = require("tracker")

local rc = rest_utils.consts.success.ok
local res = {}

-- TODO: collect real statistics about the running ntopng instance
res = {
    total_traffic = {up = 100, down = 100},
    host_number = 10,
    flow_number = 20,
    alert_number = 300,
    version = "v1"
}


local origin        = _SERVER["origin"] or '*'
local extra_headers = { 'Access-Control-Allow-Origin: '..origin }

rest_utils.answer(rc, res, extra_headers)
