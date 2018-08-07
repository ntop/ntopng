--
-- (C) 2014-15 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

local pr = nil

local function initPrefs()
   if pr == nil then
      pr = ntop.getPrefs()
   end
end

function isFlowAggregationEnabled()
   initPrefs()
   return pr["is_flow_aggregation_enabled"]
end

function flowAggregationFrequency()
   initPrefs()
   return pr["flow_aggregation_frequency"]
end

function useAggregatedFlows()
   local aggr_pref = isFlowAggregationEnabled()
   local aggr_freq_secs = flowAggregationFrequency()

   local aggr = (aggr_pref == true)

   if aggr and _GET ~= nil then
      -- even if the aggregation is enabled, we may still need to use raw
      -- flows (e.g., when searching by src/dst port, info, and l4 protocol,
      -- or when searching in a time range that has not yet been included in an aggregation)
      if not isEmptyString(_GET["l4proto"])
         or not isEmptyString(_GET["port"])
	 or not isEmptyString(_GET["profile"])
         or not isEmptyString(_GET["info"]) then
	    -- tprint("coercing aggr to false")
	    aggr = false
      end

      -- also make sure aggregation has been dumped for the selected range
      -- in other words, the current time minus the aggregation frequency
      -- must be greater than any timestamp specified. This guarantees the
      -- aggregated flows have been dumped
      if aggr then
	 local now = os.time()
	 local what = {"period_end_str", "period_begin_str", "epoch_begin", "epoch_end"}
	 for _, w in pairs(what) do
	    if not isEmptyString(_GET[w]) then
	       local period
	       if w:ends("_str") then
		  period = tonumber(makeTimeStamp(_GET[w], _GET["timezone"]))
	       else
		  period = tonumber(_GET[w])
	       end

	       if now - aggr_freq_secs < period then
		  -- tprint("coercing aggr to false")
		  aggr = false
		  break
	       end
	    end
	 end
      end
   end

   return aggr
end
