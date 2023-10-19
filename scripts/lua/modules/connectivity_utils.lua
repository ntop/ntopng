--
-- (C) 2021-22 - ntop.org
--

--
-- This module is used at startup to check if
-- ntopng can freely access the Internet
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
   local url_key   = "ntopng.prefs.connectivity_check_url"
   local url       = ntop.getCache(url_key)
   local debug     = false

   if not url or url == '' then
      url = connectivity_utils.DEFAULT_URL
   end

   if(debug) then
      traceError(TRACE_NORMAL, TRACE_CONSOLE, "[CONNECTIVITY CHECK] Checking "..url.." reachability ["..timeout.." sec timeout]")
   end

   local i = 0
   while i < max_retry and not success do
      local rsp = ntop.httpGet(url, "", "", timeout)

      if not rsp['RESPONSE_CODE'] or rsp['RESPONSE_CODE'] == 0 then
         -- Timeout
	 if(debug) then
           traceError(TRACE_NORMAL, TRACE_CONSOLE, "[CONNECTIVITY CHECK] Test "..i.."/"..max_retry.." failed")
	 end
         i = i + 1
      else
	 if(debug) then
           traceError(TRACE_NORMAL, TRACE_CONSOLE, "[CONNECTIVITY CHECK] URL " .. url .. " is reachable")
	 end
         success = true
      end
   end

   if(debug) then
      local msg

      if(success) then
      	msg = "success"
      else
        msg = "failed"
      end

      traceError(TRACE_NORMAL, TRACE_CONSOLE, "[CONNECTIVITY CHECK] Result: " .. msg)
   else
     if(not(success)) then
       traceError(TRACE_WARNING, TRACE_CONSOLE, "Connectivity check failed [Used " .. url .. "]")
     end
   end

   return success
end

-- #################################

return connectivity_utils
