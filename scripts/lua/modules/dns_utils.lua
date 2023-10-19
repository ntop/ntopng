--
-- (C) 2014-22 - ntop.org
--

local dns_utils = {}

local clock_start = os.clock()

function dns_utils.getResponseStatusCode(return_code)
  return(i18n("dns_info.return_codes." .. tostring(return_code)) or return_code)
end

function dns_utils.getQueryType(query_type)
  return(i18n("dns_info.query_types." .. tostring(query_type)) or query_type)
end

if(trace_script_duration ~= nil) then
   io.write(debug.getinfo(1,'S').source .." executed in ".. (os.clock()-clock_start)*1000 .. " ms\n")
end

return dns_utils
