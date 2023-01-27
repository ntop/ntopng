--
-- (C) 2019-22 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local redis_api = require "redis_api"
local rest_utils = require("rest_utils")

local stats = redis_api.getStats()

rest_utils.answer(rest_utils.consts.success.ok, stats)
