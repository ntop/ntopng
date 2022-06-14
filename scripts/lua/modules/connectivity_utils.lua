--
-- (C) 2021 - ntop.org
--

local connectivity_utils = {}

-- #################################

connectivity_utils.DEFAULT_URL = "https://github.com"

-- Check internet connectivity
-- @return true on success, false otherwise
function connectivity_utils.checkConnectivity()
   local max_retry = 2
   local timeout   = 3 -- seconds
   local success   = false
   local url_key = "ntopng.prefs.connectivity_check_url"
   local url = ntop.getCache(url_key)

   if not url or url == '' then
      url = connectivity_utils.DEFAULT_URL
   end

   local i = 0
   while i < max_retry and not success do
      local rsp = ntop.httpGet(url, "", "", timeout)

      if not rsp['RESPONSE_CODE'] or rsp['RESPONSE_CODE'] == 0 then
         -- Timeout
         i = i + 1
      else
         --traceError(TRACE_NORMAL, TRACE_CONSOLE, "Online (" .. url .. " is reachable)")
         success = true
      end
   end

   return success
end

-- #################################

return connectivity_utils
