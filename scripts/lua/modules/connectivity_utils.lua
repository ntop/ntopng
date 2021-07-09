--
-- (C) 2021 - ntop.org
--

local connectivity_utils = {}

-- #################################

-- Check internet connectivity
-- @return true on success, false otherwise
function connectivity_utils.checkConnectivity()
   local max_retry = 3
   local timeout = 3 -- seconds
   local success = false

   local i = 0
   while i < max_retry and not success do   

      local rsp = ntop.httpGet("https://version.ntop.org", "", "", timeout)

      if not rsp['RESPONSE_CODE'] or rsp['RESPONSE_CODE'] == 0 then
         -- Timeout
         i = i + 1
      else
         success = true
      end
   end

   return success
end

-- #################################

return connectivity_utils

