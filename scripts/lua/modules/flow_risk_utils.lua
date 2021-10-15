--
-- (C) 2017-21 - ntop.org
--

local flow_risk_utils = {}

-- ##############################################

function flow_risk_utils.get_documentation_link(risk_id)
   local url = string.format("https://www.ntop.org/guides/nDPI/flow_risks.html#risk-%.3u", risk_id)
   local link = string.format('<a href="%s" target="_blank"><i class="fas fa-lg fa-question-circle"></i></a>', url)

   return link
end

-- ##############################################

--@brief Returns a table with all available risk strings, keyed by risk id.
function flow_risk_utils.get_risks_info()
   local res = {}

   for risk_id = 1,127 do
      local risk_str = ntop.getRiskStr(risk_id)
      if risk_id == tonumber(risk_str) then
	 break
      end

      -- Use string keys to avoid tricking lua into thinking it is processing an array
      res[tostring(risk_id)] = {label = risk_str, id = risk_id}
   end

   tprint(res)
   return res
end

-- ##############################################

return flow_risk_utils
