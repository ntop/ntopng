--
-- (C) 2014-22 - ntop.org
--

local http_utils = {}

local clock_start = os.clock()

function http_utils.getResponseStatusCode(return_code)
  return(i18n("http_info.return_codes." .. tostring(return_code)) or return_code)
end

if(trace_script_duration ~= nil) then
   io.write(debug.getinfo(1,'S').source .." executed in ".. (os.clock()-clock_start)*1000 .. " ms\n")
end

return http_utils
