--
-- (C) 2017-26 - ntop.org
--

local flow_risk_utils = {}

local clock_start = os.clock()

-- ##############################################

-- The link only depends on (risk_id, source): memoize it
local remediation_links_cache = {}

function flow_risk_utils.get_remediation_documentation_link(risk_id, source)
   local cache_key = tostring(source) .. ":" .. tostring(risk_id)
   local link = remediation_links_cache[cache_key]

   if link then
      return link
   end

   local url = ""
   if (source == "ntopng") then
      url = string.format("https://www.ntop.org/guides/ntopng/user_interface/shared/alerts/remediations/ntopng_flow_risks.html?utm_source=ntopng#risk-%.3u", risk_id)
   else
      url = string.format("https://www.ntop.org/guides/ntopng/user_interface/shared/alerts/remediations/ndpi_flow_risks.html?utm_source=ntopng#risk-%.3u", risk_id)
   end

   link = string.format('<a href="%s" target="_blank"><i class="fa-solid fa-lg fa-briefcase-medical"></i></a>', url)
   remediation_links_cache[cache_key] = link

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

   return res
end

-- ##############################################

if(trace_script_duration ~= nil) then
  io.write(debug.getinfo(1,'S').source .." executed in ".. (os.clock()-clock_start)*1000 .. " ms\n")
end

return flow_risk_utils
