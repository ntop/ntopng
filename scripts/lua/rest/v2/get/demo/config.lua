--
-- (C) 2013-26 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local rest_utils = require "rest_utils"
local demo_utils = require "demo_utils"

--
-- Get the full step config for a demo tour, plus the current user's saved progress
-- Example: curl -u admin:admin "http://localhost:3000/lua/rest/v2/get/demo/config.lua?id=ntopng_overview"
--

local res = {}

local demo_id = _GET["id"]
local username = _SESSION and _SESSION["user"]

if isEmptyString(demo_id) then
   rest_utils.answer(rest_utils.consts.err.invalid_args, res)
   return
end

if isEmptyString(username) then
   rest_utils.answer(rest_utils.consts.err.not_granted, res)
   return
end

local config = demo_utils.get_demo_config(demo_id)

if config == nil then
   rest_utils.answer(rest_utils.consts.err.not_found, res)
   return
end

res.config = config
res.progress = demo_utils.get_progress(username, demo_id)

rest_utils.answer(rest_utils.consts.success.ok, res)
