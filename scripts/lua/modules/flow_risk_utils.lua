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

return flow_risk_utils
