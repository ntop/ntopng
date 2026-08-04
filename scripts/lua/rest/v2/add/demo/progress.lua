--
-- (C) 2013-26 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local rest_utils = require "rest_utils"
local demo_utils = require "demo_utils"

--
-- Update a user's progress on a demo tour: advance a step, mark complete, or dismiss ("never show again")
-- Example: curl -u admin:admin -X POST --data-urlencode "id=ntopng_overview" \
--   --data-urlencode "action=step" --data-urlencode "step_index=2" \
--   http://localhost:3000/lua/rest/v2/add/demo/progress.lua
--
-- action: "step" (requires step_index) | "complete" | "dismiss" | "reset" (replay from scratch)
--

local res = {}

local demo_id = _POST["id"]
local action = _POST["action"]
local step_index = _POST["step_index"]
local username = _SESSION and _SESSION["user"]

if isEmptyString(demo_id) or isEmptyString(action) then
   rest_utils.answer(rest_utils.consts.err.invalid_args, res)
   return
end

if isEmptyString(username) then
   rest_utils.answer(rest_utils.consts.err.not_granted, res)
   return
end

if action == "step" then
   demo_utils.set_step(username, demo_id, tonumber(step_index) or 0)
elseif action == "complete" then
   local config = demo_utils.get_demo_config(demo_id)
   demo_utils.mark_complete(username, demo_id, config and config.version or 1)
elseif action == "dismiss" then
   demo_utils.dismiss(username, demo_id)
elseif action == "reset" then
   -- Manual replay is explicit user intent
   demo_utils.save_progress(username, demo_id, { first_seen_at = 0 })
else
   rest_utils.answer(rest_utils.consts.err.invalid_args, res)
   return
end

rest_utils.answer(rest_utils.consts.success.ok, res)
