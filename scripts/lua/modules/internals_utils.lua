--
-- (C) 2019-26 - ntop.org
--

local format_utils = require("format_utils")
local internals_utils = {}
local json = require "dkjson"
local dirs = ntop.getDirs()
local checks = require "checks"
local periodic_activities_utils = require "periodic_activities_utils"
local ts_utils = require "ts_utils_core"
local graph_utils = require "graph_utils"

-- ###########################################

function internals_utils.getHashTablesFillBar(first_fill_pct, second_fill_pct, third_fill_pct)
   local code = [[<div class="progress">]]

   if first_fill_pct > 0 then
      code = code..[[<div class="progress-bar" role="progressbar" title="]] ..i18n("if_stats_overview.active").. [[" style="width: ]]..first_fill_pct..[[%" aria-valuenow="]]..first_fill_pct..[[" aria-valuemin="0" aria-valuemax="100">]]..i18n("if_stats_overview.active")..[[</div>]]
   end

   if second_fill_pct > 0 then
      code = code..[[<div class="progress-bar bg-success" role="progressbar" title="]] ..i18n("flow_checks.idle").. [[" style="width: ]]..second_fill_pct..[[%" aria-valuenow="]]..second_fill_pct..[[" aria-valuemin="0" aria-valuemax="100">]]..i18n("flow_checks.idle")..[[</div>]]
   end

   if third_fill_pct > 0 then
      code = code..[[<div class="progress-bar bg-success" role="progressbar" title="]] ..i18n("available").. [[" style="width: ]]..third_fill_pct..[[%" aria-valuenow="]]..third_fill_pct..[[" aria-valuemin="0" aria-valuemax="100">]]..i18n("available")..[[</div>]]
   end

   code = code..[[</div>]]

   return code
end


-- ###########################################

function internals_utils.getPeriodicActivitiesFillBar(busy_pct, available_pct)
   local code = [[<div class="progress">]]

   if busy_pct > 0 then
      code = code..[[<div class="progress-bar" role="progressbar" title="]] ..i18n("busy").. [[" style="width: ]]..busy_pct..[[%" aria-valuenow="]]..busy_pct..[[" aria-valuemin="0" aria-valuemax="100">]]..i18n("busy")..[[</div>]]
   end

   if available_pct > 0 then
      code = code..[[<div class="progress-bar bg-success" role="progressbar" title="]] ..i18n("available").. [[" style="width: ]]..available_pct..[[%" aria-valuenow="]]..available_pct..[[" aria-valuemin="0" aria-valuemax="100">]]..i18n("available")..[[</div>]]
   end

   code = code..[[</div>]]

   return code
end

-- ###########################################

return internals_utils
