--
-- (C) 2019-21 - ntop.org
--
dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local rest_utils = require("rest_utils")

-- ################################################

if(_POST["ifid"] == nil) then
  rest_utils.answer(rest_utils.consts.err.invalid_args)
  return
end

local score = _POST["score"]
local ifid  = _POST["ifid"]

local alert_score_cached = "ntopng.alert.score.ifid_" .. ifid .. ""
local hour_timer = 3600

if not score or isEmptyString(score) then
  ntop.delCache(alert_score_cached)
else
  score = score
  ntop.setCache(alert_score_cached, score, hour_timer)
end

rest_utils.answer(rest_utils.consts.success.ok)
