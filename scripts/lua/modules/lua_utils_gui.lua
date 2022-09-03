--
-- (C) 2014-22 - ntop.org
--

--
-- Container for GUI-related stuff that used to be part of lua_utils.lua
--

local clock_start = os.clock()

local format_utils = require "format_utils"

-- ##############################################

function sendHTTPHeaderIfName(mime, ifname, maxage, content_disposition, extra_headers, status_code)
   local info = ntop.getInfo(false)
   local http_status_code_map = {
      [200] = "OK",
      [400] = "Bad Request",
      [401] = "Unauthorized",
      [403] = "Forbidden",
      [404] = "Not Found",
      [405] = "Method Not Allowed",
      [406] = "Not Acceptable",
      [408] = "Request timeout",
      [409] = "Conflict",
      [410] = "Gone",
      [412] = "Precondition Failed",
      [415] = "Unsupported Media Type",
      [423] = "Locked",
      [428] = "Precondition Required",
      [429] = "Too many requests",
      [500] = "Internal Server Error",
      [501] = "Not Implemented",
      [503] = "Service Unavailable",
   }
   local tzname = info.tzname or ''
   local cookie_attr = ntop.getCookieAttributes()
   local lines = {
      'Cache-Control: max-age=0, no-cache, no-store',
      'Server: ntopng '..info["version"]..' ['.. info["platform"]..']',
      'Set-Cookie: tzname=' .. tzname .. '; path=/' .. cookie_attr,
      'Pragma: no-cache',
      'X-Frame-Options: DENY',
      'X-Content-Type-Options: nosniff',
      'Content-Type: '.. mime,
      'Last-Modified: '..os.date("!%a, %m %B %Y %X %Z"),
   }

   local uri = _SERVER.URI

   if(starts(uri, "/lua/rest/")) then
      --
      -- Only for REST calls handle CORS (Cross-Origin Resource Sharing)
      --
      -- https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Access-Control-Allow-Origin
      -- https://web.dev/cross-origin-resource-sharing/
      --
      lines[#lines + 1] = 'Access-Control-Allow-Origin: *'
      lines[#lines + 1] = 'Access-Control-Allow-Methods: GET, POST, HEAD'
   end

   if(_SESSION ~= nil) then
      local key = "session_"..info.http_port.."_"..info.https_port
      lines[#lines + 1] = 'Set-Cookie: '..key..'='.._SESSION["session"]..'; max-age=' .. maxage .. '; path=/; ' .. cookie_attr
   end

   if(ifname ~= nil) then
      lines[#lines + 1] = 'Set-Cookie: ifname=' .. ifname .. '; path=/' .. cookie_attr
   end

   if(info.timezone ~= nil) then
      lines[#lines + 1] = 'Set-Cookie: timezone=' .. info.timezone .. '; path=/' .. cookie_attr
   end

   if(content_disposition ~= nil) then
      lines[#lines + 1] = 'Content-Disposition: '..content_disposition
   end

   if type(extra_headers) == "table" then
      for hname, hval in pairs(extra_headers) do
	 lines[#lines + 1] = hname..': '..hval
      end
   end

   if not status_code then
      status_code = 200
   end

   local status_descr = http_status_code_map[status_code]
   if not status_descr then
      status_descr = "Unknown"
   end

   -- Buffer the HTTP reply and write it in one "print" to avoid fragmenting
   -- it into multiple packets, to ease HTTP debugging with wireshark.
   print("HTTP/1.1 " .. status_code .. " " .. status_descr .. "\r\n" .. table.concat(lines, "\r\n") .. "\r\n\r\n")
end

-- ##############################################

function sendHTTPHeaderLogout(mime, content_disposition)
  sendHTTPHeaderIfName(mime, nil, 0, content_disposition)
end

-- ##############################################

function sendHTTPHeader(mime, content_disposition, extra_headers, status_code)
   sendHTTPHeaderIfName(mime, nil, 3600, content_disposition, extra_headers, status_code)
end

-- ##############################################

function sendHTTPContentTypeHeader(content_type, content_disposition, charset, extra_headers, status_code)
  local charset = charset or "utf-8"
  local mime = content_type.."; charset="..charset

  sendHTTPHeader(mime, content_disposition, extra_headers, status_code)
end

-- ##############################################

function urlencode(str)
   str = string.gsub (str, "\r?\n", "\r\n")
   str = string.gsub (str, "([^%w%-%.%_%~ ])",
		      function (c) return string.format ("%%%02X", string.byte(c)) end)
   str = string.gsub (str, " ", "+")
   return str
end

-- ##############################################

function noHtml(s)
   if s == nil then return nil end

   local gsub, char = string.gsub, string.char
   local entityMap  = {lt = "<", gt = ">" , amp = "&", quot ='"', apos = "'"}
   local entitySwap = function(orig, n, s)
      return (n == '' and entityMap[s])
	 or (n == "#" and tonumber(s)) and string.char(s)
	 or (n == "#x" and tonumber(s,16)) and string.char(tonumber(s,16))
	 or orig
   end

   local function unescape(str)
      return (gsub( str, '(&(#?x?)([%d%a]+);)', entitySwap ))
   end

   local cleaned = s:gsub("<[aA] .->(.-)</[aA]>","%1")
      :gsub("<abbr .->(.-)</abbr>","%1")
      :gsub("<span .->(.-)</span>","%1")
      :gsub("%s*<[iI].->(.-)</[iI]>","%1")
      :gsub("<.->(.-)</.->","%1") -- note: keep as last as this does not handle nested tags
      :gsub("^%s*(.-)%s*$", "%1")
      :gsub('&nbsp;', " ")

   return unescape(cleaned)
end

-- ##############################################

function addGoogleMapsScript()
   local g_maps_key = ntop.getCache('ntopng.prefs.google_apis_browser_key')
   if g_maps_key ~= nil and g_maps_key~= "" then
      g_maps_key = "&key="..g_maps_key
   else
   g_maps_key = ""
   end
   print("<script src=\"https://maps.googleapis.com/maps/api/js?v=3.exp"..g_maps_key.."\"></script>\n")
end

-- ##############################################

function addLogoLightSvg()
   return ([[
      <div id='ntopng-logo'>
         <svg
            id="ntopng-logo"
            data-name="ntopng logo"
            xmlns="http://www.w3.org/2000/svg"
            viewBox="0 0 512.74 512.84"
            height="56"
            width="56">
            <defs>
               <style>
                  .cls-1{fill:none;}
                  .cls-2{fill:#cecece;}
                  .cls-2,.cls-3,.cls-4{fill-rule:evenodd;}
                  .cls-3{fill:#b7b7b7;}
                  .cls-4{fill:#ee751b;}
               </style>
            </defs>
            <title>ntopng logo</title>
            <path class="cls-1" d="M1,513.94V1.1H513.78V513.94ZM497.86,172c0-22.84.08-44.16-.07-65.48a100.07,100.07,0,0,0-1.34-16.31c-6.87-40.3-39-71.17-81.23-71.68-105.79-1.27-211.6-.44-317.4-.35a60.46,60.46,0,0,0-14.33,1.62c-39.52,9.78-65.2,42.87-65.34,85-.24,75.82-.07,151.63,0,227.44,0,1.2.25,2.39.47,4.31,2.18-1.71,3.83-2.82,5.26-4.17,14.23-13.54,28.39-27.15,42.67-40.65,2.17-2.06,2.09-3.89,1.38-6.64-1.58-6.05-3.65-12.31-3.45-18.41.91-28.45,25.61-49.36,51.92-48.1,25.77,1.23,50.24,25.65,46.44,55.08-.59,4.64.85,6,4.18,6.6,38.67-46.29,85.62-58.59,141.88-36.58a15.05,15.05,0,0,0,1-1.31c17.37-26.37,34.78-52.72,52-79.21.92-1.42.69-4.55-.28-6.07-9.33-14.54-11.6-29.7-5.46-46.12,8.26-22.11,33.59-36,56.46-30.51,26.38,6.29,42.42,30.41,37.84,57.12-.55,3.25.22,5.15,3.1,6.94,9,5.62,17.81,11.66,26.81,17.34C485.7,165.2,491.33,168.21,497.86,172Zm-87.1,325.77c22.32,1.05,41.19-5.51,57.26-19.17,19-16.16,30.07-36.25,30-62.13-.33-67.15-.11-134.31-.11-201.46v-7.13c-2.44-1.43-4.62-2.59-6.68-3.93-17.43-11.35-34.88-22.65-52.21-34.14-3.45-2.28-6-2.68-9.66,0-10.77,7.8-23.06,9.91-36.05,7.52-3.8-.69-6,.23-8.17,3.57-11.63,18-23.54,35.89-35.31,53.83-5.55,8.46-11,17-16.52,25.5.85.9,1.39,1.52,2,2.09,36.21,34.78,46.28,81.33,27.45,127.7-1.17,2.87-.64,4.43,1.45,6.41q19.77,18.75,39.33,37.71c7.71,7.43,15.11,15.06,17.48,26.13C423.92,474.13,420.3,486.24,410.76,497.74Zm-58.57.12c-16-16.38-31-31.78-46.18-47-1-1-3.94-1.17-5.55-.57a115.89,115.89,0,0,1-53,7c-61.43-6.45-106.54-62-99.74-123.42,1-9,3.34-17.91,5.11-27.08-4.26-3.2-4.21-3.14-8.65.1-16.12,11.79-33.27,13.91-51.71,5.79-1.78-.78-5.22-.36-6.6.91-10.52,9.69-20.74,19.71-31,29.66Q37.1,360.42,19.44,377.69a5.83,5.83,0,0,0-1.3,3.83c-.07,12.5-.27,25,.06,37.48,1.09,41.31,39.69,78.85,80.9,78.85H352.19Zm-92.67-262c-40.78,2.35-73.75,18.09-93.85,55.48-4.3,8-8.56,16.21-11.36,24.81-4.59,14.08-5.25,28.73-3.21,43.46q5.52,39.68,35.05,66.66c18.62,17,40.75,26.23,65.8,28.17A98.42,98.42,0,0,0,301.13,446c3.13-1.44,4.55-1.23,6.73,1,15.72,16.08,31.71,31.91,47.27,48.14,14.32,14.93,38,15,54-1.07,12.43-12.52,12.43-37.07-.58-50.18-8.62-8.7-17.68-17-26.63-25.35-7.53-7-15.19-14-22.78-21-1.8-1.66-3.1-3.34-1.46-6,7.47-12.09,10.36-25.7,10.79-39.49,1.28-41.07-13.57-74.32-49.22-96.78-5.73-3.61-11.25-7.75-17.38-10.52C288.55,238.72,274.35,236,259.52,235.83Z" transform="translate(-1.03 -1.1)"/>
            <path class="cls-2" d="M497.86,172c-6.53-3.76-12.16-6.77-17.56-10.17-9-5.67-17.77-11.72-26.81-17.33-2.88-1.79-3.65-3.69-3.1-6.94,4.58-26.71-11.46-50.84-37.84-57.12-22.87-5.45-48.2,8.4-56.46,30.5-6.14,16.43-3.87,31.58,5.46,46.13,1,1.52,1.19,4.65.28,6.07-17.19,26.49-34.59,52.83-52,79.2a15.5,15.5,0,0,1-1,1.32c-56.27-22-103.21-9.71-141.89,36.58-3.32-.6-4.77-2-4.17-6.6,3.8-29.44-20.67-53.85-46.45-55.08-26.3-1.26-51,19.65-51.91,48.09-.2,6.11,1.87,12.37,3.45,18.42.71,2.75.79,4.58-1.39,6.64-14.27,13.5-28.43,27.11-42.66,40.64-1.43,1.36-3.09,2.47-5.26,4.18-.22-1.92-.47-3.12-.47-4.31,0-75.82-.19-151.63,0-227.44.13-42.12,25.82-75.2,65.34-85a60.46,60.46,0,0,1,14.33-1.62c105.8-.09,211.61-.92,317.4.35,42.2.5,74.36,31.38,81.23,71.67a101.41,101.41,0,0,1,1.34,16.32C497.94,127.81,497.86,149.13,497.86,172Z" transform="translate(-1.03 -1.1)"/>
            <path class="cls-3" d="M410.76,497.74c9.54-11.5,13.17-23.61,10.19-37.49-2.37-11.06-9.77-18.7-17.48-26.13q-19.61-18.92-39.33-37.71c-2.09-2-2.62-3.54-1.45-6.41,18.83-46.37,8.76-92.92-27.45-127.7-.59-.57-1.14-1.19-2-2.09,5.51-8.52,11-17,16.52-25.5,11.77-17.94,23.68-35.8,35.31-53.83,2.15-3.34,4.37-4.27,8.17-3.57,13,2.39,25.28.28,36.05-7.52,3.71-2.69,6.21-2.29,9.66,0,17.33,11.48,34.78,22.79,52.21,34.13,2.06,1.35,4.23,2.51,6.68,3.94V215c0,67.15-.22,134.31.11,201.46.12,25.88-11,46-30,62.12C452,492.23,433.08,498.79,410.76,497.74Z" transform="translate(-1.03 -1.1)"/>
            <path class="cls-3" d="M352.19,497.86H99.1c-41.21,0-79.81-37.54-80.9-78.85-.33-12.48-.13-25-.06-37.48a5.88,5.88,0,0,1,1.3-3.83q17.61-17.31,35.42-34.43c10.29-9.95,20.51-20,31-29.67,1.37-1.26,4.81-1.68,6.59-.9,18.44,8.12,35.59,6,51.72-5.79,4.43-3.24,4.39-3.3,8.64-.1-1.77,9.17-4.12,18.05-5.11,27.07-6.8,61.43,38.31,117,99.74,123.42a115.75,115.75,0,0,0,53-7c1.61-.6,4.51-.48,5.55.57C321.19,466.08,336.16,481.48,352.19,497.86Z" transform="translate(-1.03 -1.1)"/>
            <path class="cls-4" d="M259.52,235.83c14.83.18,29,2.89,42.38,8.92,6.13,2.77,11.65,6.9,17.38,10.51C354.93,277.72,369.79,311,368.5,352c-.43,13.8-3.32,27.41-10.79,39.5-1.64,2.66-.33,4.34,1.47,6,7.59,7,15.24,13.93,22.78,21,8.94,8.38,18,16.65,26.62,25.35,13,13.1,13,37.66.58,50.17-16,16.11-39.71,16-54,1.08-15.57-16.23-31.56-32.06-47.28-48.15-2.18-2.23-3.6-2.43-6.73-1A98.32,98.32,0,0,1,252,454.41c-25-1.94-47.17-11.18-65.8-28.17q-29.52-26.94-35-66.66c-2.05-14.73-1.39-29.38,3.2-43.46,2.81-8.6,7.06-16.8,11.37-24.81C185.77,253.92,218.74,238.18,259.52,235.83Zm74.75,109.92c0-41.77-33.56-74.92-75.46-75.17-43.6-.26-75,36.34-75.13,75.47-.15,42.12,33.35,75.3,75.65,75.23C301.1,421.21,334.32,387.73,334.27,345.75Z" transform="translate(-1.03 -1.1)"/>
            <path class="cls-1" d="M334.27,345.75c.05,42-33.17,75.46-74.94,75.53-42.3.07-75.8-33.11-75.65-75.23.15-39.13,31.53-75.73,75.13-75.47C300.71,270.83,334.23,304,334.27,345.75Zm-23.81-51.17C306.21,301,302,307,298.26,313.26a5.89,5.89,0,0,0,.08,5.24c7.05,10,9.43,21,8.85,33-1.21,25.15-26,50.24-57.27,44.86-27-4.64-44.41-28.79-41.21-54.87.19-1.58-.23-4.18-1.28-4.83-5.73-3.55-11.74-6.64-17.77-10-9.73,33.58,7.86,70.39,40,84.81A72.56,72.56,0,0,0,320.85,384C340.92,352,331.39,313.58,310.46,294.58ZM285.84,278.5c-24.8-13.2-67.88-1.62-82.65,22,5.81,3.19,11.73,6.18,17.36,9.64,2.33,1.43,3.62,1.13,5.61-.47,12.3-9.84,26.1-14,41.84-10.79,1.62.33,4.36-.28,5.21-1.45C277.65,291.33,281.66,284.88,285.84,278.5Z" transform="translate(-1.03 -1.1)"/>
            <path class="cls-2" d="M310.46,294.58c20.93,19,30.46,57.41,10.39,89.43a72.56,72.56,0,0,1-91.19,27.52c-32.14-14.42-49.73-51.23-40-84.81,6,3.32,12,6.41,17.77,10,1,.65,1.47,3.25,1.27,4.83-3.19,26.08,14.25,50.23,41.22,54.87,31.26,5.38,56.06-19.71,57.27-44.86.58-12-1.8-23.06-8.85-33a5.89,5.89,0,0,1-.08-5.24C302,307,306.21,301,310.46,294.58Z" transform="translate(-1.03 -1.1)"/>
            <path class="cls-2" d="M285.84,278.5c-4.18,6.38-8.19,12.83-12.63,19-.85,1.17-3.58,1.78-5.21,1.45-15.74-3.18-29.54.95-41.84,10.79-2,1.6-3.28,1.9-5.61.47-5.63-3.46-11.55-6.45-17.36-9.64C218,276.88,261,265.3,285.84,278.5Z" transform="translate(-1.03 -1.1)"/>
         </svg>
      </div>
   ]])
end

-- ##############################################

function addLogoDarkSvg()
   return ([[
      <div id='ntopng-logo'>
         <svg
            id="ntopng-logo-svg"
            data-name="ntopng logo"
            xmlns="http://www.w3.org/2000/svg"
            viewBox="0 0 512.74 512.84"
            height="56"
            width="56">
            <defs>
               <style>
                  .cls-1{fill:none;}
                  .cls-2{fill:#333;}
                  .cls-2,.cls-3{fill-rule:evenodd;}
                  .cls-3{fill:#ee751b;}
               </style>
            </defs>
            <title>ntopng logo</title>
            <path class="cls-1" d="M1,513.94V1.1H513.78V513.94ZM497.86,172c0-22.84.08-44.16-.07-65.48a100.07,100.07,0,0,0-1.34-16.31c-6.87-40.3-39-71.17-81.23-71.68-105.79-1.27-211.6-.44-317.4-.35a60.46,60.46,0,0,0-14.33,1.62c-39.52,9.78-65.2,42.87-65.34,85-.24,75.82-.07,151.63,0,227.44,0,1.2.25,2.39.47,4.31,2.18-1.71,3.83-2.82,5.26-4.17,14.23-13.54,28.39-27.15,42.67-40.65,2.17-2.06,2.09-3.89,1.38-6.64-1.58-6.05-3.65-12.31-3.45-18.41.91-28.45,25.61-49.36,51.92-48.1,25.77,1.23,50.24,25.65,46.44,55.08-.59,4.64.85,6,4.18,6.6,38.67-46.29,85.62-58.59,141.88-36.58a15.05,15.05,0,0,0,1-1.31c17.37-26.37,34.78-52.72,52-79.21.92-1.42.69-4.55-.28-6.07-9.33-14.54-11.6-29.7-5.46-46.12,8.26-22.11,33.59-36,56.46-30.51,26.38,6.29,42.42,30.41,37.84,57.12-.55,3.25.22,5.15,3.1,6.94,9,5.62,17.81,11.66,26.81,17.34C485.7,165.2,491.33,168.21,497.86,172Zm-87.1,325.77c22.32,1.05,41.19-5.51,57.26-19.17,19-16.16,30.07-36.25,30-62.13-.33-67.15-.11-134.31-.11-201.46v-7.13c-2.44-1.43-4.62-2.59-6.68-3.93-17.43-11.35-34.88-22.65-52.21-34.14-3.45-2.28-6-2.68-9.66,0-10.77,7.8-23.06,9.91-36.05,7.52-3.8-.69-6,.23-8.17,3.57-11.63,18-23.54,35.89-35.31,53.83-5.55,8.46-11,17-16.52,25.5.85.9,1.39,1.52,2,2.09,36.21,34.78,46.28,81.33,27.45,127.7-1.17,2.87-.64,4.43,1.45,6.41q19.77,18.75,39.33,37.71c7.71,7.43,15.11,15.06,17.48,26.13C423.92,474.13,420.3,486.24,410.76,497.74Zm-58.57.12c-16-16.38-31-31.78-46.18-47-1-1-3.94-1.17-5.55-.57a115.89,115.89,0,0,1-53,7c-61.43-6.45-106.54-62-99.74-123.42,1-9,3.34-17.91,5.11-27.08-4.26-3.2-4.21-3.14-8.65.1-16.12,11.79-33.27,13.91-51.71,5.79-1.78-.78-5.22-.36-6.6.91-10.52,9.69-20.74,19.71-31,29.66Q37.1,360.42,19.44,377.69a5.83,5.83,0,0,0-1.3,3.83c-.07,12.5-.27,25,.06,37.48,1.09,41.31,39.69,78.85,80.9,78.85H352.19Zm-92.67-262c-40.78,2.35-73.75,18.09-93.85,55.48-4.3,8-8.56,16.21-11.36,24.81-4.59,14.08-5.25,28.73-3.21,43.46q5.52,39.68,35.05,66.66c18.62,17,40.75,26.23,65.8,28.17A98.42,98.42,0,0,0,301.13,446c3.13-1.44,4.55-1.23,6.73,1,15.72,16.08,31.71,31.91,47.27,48.14,14.32,14.93,38,15,54-1.07,12.43-12.52,12.43-37.07-.58-50.18-8.62-8.7-17.68-17-26.63-25.35-7.53-7-15.19-14-22.78-21-1.8-1.66-3.1-3.34-1.46-6,7.47-12.09,10.36-25.7,10.79-39.49,1.28-41.07-13.57-74.32-49.22-96.78-5.73-3.61-11.25-7.75-17.38-10.52C288.55,238.72,274.35,236,259.52,235.83Z" transform="translate(-1.03 -1.1)"/>
            <path class="cls-2" d="M497.86,172c-6.53-3.76-12.16-6.77-17.56-10.17-9-5.67-17.77-11.72-26.81-17.33-2.88-1.79-3.65-3.69-3.1-6.94,4.58-26.71-11.46-50.84-37.84-57.12-22.87-5.45-48.2,8.4-56.46,30.5-6.14,16.43-3.87,31.58,5.46,46.13,1,1.52,1.19,4.65.28,6.07-17.19,26.49-34.59,52.83-52,79.2a15.5,15.5,0,0,1-1,1.32c-56.27-22-103.21-9.71-141.89,36.58-3.32-.6-4.77-2-4.17-6.6,3.8-29.44-20.67-53.85-46.45-55.08-26.3-1.26-51,19.65-51.91,48.09-.2,6.11,1.87,12.37,3.45,18.42.71,2.75.79,4.58-1.39,6.64-14.27,13.5-28.43,27.11-42.66,40.64-1.43,1.36-3.09,2.47-5.26,4.18-.22-1.92-.47-3.12-.47-4.31,0-75.82-.19-151.63,0-227.44.13-42.12,25.82-75.2,65.34-85a60.46,60.46,0,0,1,14.33-1.62c105.8-.09,211.61-.92,317.4.35,42.2.5,74.36,31.38,81.23,71.67a101.41,101.41,0,0,1,1.34,16.32C497.94,127.81,497.86,149.13,497.86,172Z" transform="translate(-1.03 -1.1)"/>
            <path class="cls-2" d="M410.76,497.74c9.54-11.5,13.17-23.61,10.19-37.49-2.37-11.06-9.77-18.7-17.48-26.13q-19.61-18.92-39.33-37.71c-2.09-2-2.62-3.54-1.45-6.41,18.83-46.37,8.76-92.92-27.45-127.7-.59-.57-1.14-1.19-2-2.09,5.51-8.52,11-17,16.52-25.5,11.77-17.94,23.68-35.8,35.31-53.83,2.15-3.34,4.37-4.27,8.17-3.57,13,2.39,25.28.28,36.05-7.52,3.71-2.69,6.21-2.29,9.66,0,17.33,11.48,34.78,22.79,52.21,34.13,2.06,1.35,4.23,2.51,6.68,3.94V215c0,67.15-.22,134.31.11,201.46.12,25.88-11,46-30,62.12C452,492.23,433.08,498.79,410.76,497.74Z" transform="translate(-1.03 -1.1)"/>
            <path class="cls-2" d="M352.19,497.86H99.1c-41.21,0-79.81-37.54-80.9-78.85-.33-12.48-.13-25-.06-37.48a5.88,5.88,0,0,1,1.3-3.83q17.61-17.31,35.42-34.43c10.29-9.95,20.51-20,31-29.67,1.37-1.26,4.81-1.68,6.59-.9,18.44,8.12,35.59,6,51.72-5.79,4.43-3.24,4.39-3.3,8.64-.1-1.77,9.17-4.12,18.05-5.11,27.07-6.8,61.43,38.31,117,99.74,123.42a115.75,115.75,0,0,0,53-7c1.61-.6,4.51-.48,5.55.57C321.19,466.08,336.16,481.48,352.19,497.86Z" transform="translate(-1.03 -1.1)"/>
            <path class="cls-3" d="M259.52,235.83c14.83.18,29,2.89,42.38,8.92,6.13,2.77,11.65,6.9,17.38,10.51C354.93,277.72,369.79,311,368.5,352c-.43,13.8-3.32,27.41-10.79,39.5-1.64,2.66-.33,4.34,1.47,6,7.59,7,15.24,13.93,22.78,21,8.94,8.38,18,16.65,26.62,25.35,13,13.1,13,37.66.58,50.17-16,16.11-39.71,16-54,1.08-15.57-16.23-31.56-32.06-47.28-48.15-2.18-2.23-3.6-2.43-6.73-1A98.32,98.32,0,0,1,252,454.41c-25-1.94-47.17-11.18-65.8-28.17q-29.52-26.94-35-66.66c-2.05-14.73-1.39-29.38,3.2-43.46,2.81-8.6,7.06-16.8,11.37-24.81C185.77,253.92,218.74,238.18,259.52,235.83Zm74.75,109.92c0-41.77-33.56-74.92-75.46-75.17-43.6-.26-75,36.34-75.13,75.47-.15,42.12,33.35,75.3,75.65,75.23C301.1,421.21,334.32,387.73,334.27,345.75Z" transform="translate(-1.03 -1.1)"/>
            <path class="cls-1" d="M334.27,345.75c.05,42-33.17,75.46-74.94,75.53-42.3.07-75.8-33.11-75.65-75.23.15-39.13,31.53-75.73,75.13-75.47C300.71,270.83,334.23,304,334.27,345.75Zm-23.81-51.17C306.21,301,302,307,298.26,313.26a5.89,5.89,0,0,0,.08,5.24c7.05,10,9.43,21,8.85,33-1.21,25.15-26,50.24-57.27,44.86-27-4.64-44.41-28.79-41.21-54.87.19-1.58-.23-4.18-1.28-4.83-5.73-3.55-11.74-6.64-17.77-10-9.73,33.58,7.86,70.39,40,84.81A72.56,72.56,0,0,0,320.85,384C340.92,352,331.39,313.58,310.46,294.58ZM285.84,278.5c-24.8-13.2-67.88-1.62-82.65,22,5.81,3.19,11.73,6.18,17.36,9.64,2.33,1.43,3.62,1.13,5.61-.47,12.3-9.84,26.1-14,41.84-10.79,1.62.33,4.36-.28,5.21-1.45C277.65,291.33,281.66,284.88,285.84,278.5Z" transform="translate(-1.03 -1.1)"/>
            <path class="cls-2" d="M310.46,294.58c20.93,19,30.46,57.41,10.39,89.43a72.56,72.56,0,0,1-91.19,27.52c-32.14-14.42-49.73-51.23-40-84.81,6,3.32,12,6.41,17.77,10,1,.65,1.47,3.25,1.27,4.83-3.19,26.08,14.25,50.23,41.22,54.87,31.26,5.38,56.06-19.71,57.27-44.86.58-12-1.8-23.06-8.85-33a5.89,5.89,0,0,1-.08-5.24C302,307,306.21,301,310.46,294.58Z" transform="translate(-1.03 -1.1)"/>
            <path class="cls-2" d="M285.84,278.5c-4.18,6.38-8.19,12.83-12.63,19-.85,1.17-3.58,1.78-5.21,1.45-15.74-3.18-29.54.95-41.84,10.79-2,1.6-3.28,1.9-5.61.47-5.63-3.46-11.55-6.45-17.36-9.64C218,276.88,261,265.3,285.84,278.5Z" transform="translate(-1.03 -1.1)"/>
         </svg>
      </div>
   ]])
end

-- ##############################################

function addLogoSvg()
   return ([[
      <div id='ntop-logo'>
      <svg
      xmlns:dc="http://purl.org/dc/elements/1.1/"
      xmlns:cc="http://creativecommons.org/ns#"
      xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
      xmlns:svg="http://www.w3.org/2000/svg"
      xmlns="http://www.w3.org/2000/svg"
      id="svg8"
      version="1.1"
      viewBox="0 0 13.758333 13.758334"
      height="52"
      width="52">
     <metadata
        id="metadata5">
       <rdf:RDF>
         <cc:Work
            rdf:about="">
           <dc:format>image/svg+xml</dc:format>
           <dc:type rdf:resource="http://purl.org/dc/dcmitype/StillImage"></dc:type>
           <dc:title></dc:title>
         </cc:Work>
       </rdf:RDF>
     </metadata>
     <g
        id="layer1">
       <g
          style="font-style:normal;font-weight:normal;font-size:16.9333px;line-height:1.25;font-family:sans-serif;letter-spacing:0px;word-spacing:0px;fill:#ff7500;fill-opacity:1;stroke:none;stroke-width:0.264583"
          id="text835"
          aria-label="n">
         <path
            d="M 2.7739989,9.5828812 V 4.216811 q 0,-0.9839173 0.3224603,-1.4552054 0.3307285,-0.4795564 1.008722,-0.4795564 0.4051424,0 0.7193345,0.2149735 Q 5.1387078,2.7037281 5.378486,3.1336751 5.808433,2.662387 6.3706715,2.4474135 6.93291,2.2324399 7.7349267,2.2324399 q 1.5792286,0 2.4143183,0.9012352 0.835089,0.9012352 0.835089,2.6210235 v 3.8281826 q 0,0.9839178 -0.330728,1.4634738 -0.330729,0.479556 -1.0087222,0.479556 -0.6779934,0 -1.0087219,-0.479556 Q 8.3054333,10.566799 8.3054333,9.5828812 V 6.5649835 q 0,-1.1162088 -0.3389967,-1.5874969 -0.3307285,-0.4795563 -1.0996723,-0.4795563 -0.7276027,0 -1.0748677,0.4960927 -0.3472649,0.4878246 -0.3472649,1.5378876 v 3.0509706 q 0,0.9839178 -0.3307285,1.4634738 -0.3307286,0.479556 -1.008722,0.479556 -0.6779935,0 -1.008722,-0.479556 Q 2.7739989,10.566799 2.7739989,9.5828812 Z"
            style="font-style:normal;font-variant:normal;font-weight:normal;font-stretch:normal;font-family:'VAGRounded BT';-inkscape-font-specification:'VAGRounded BT';fill:#ff7500;fill-opacity:1;stroke-width:0.264583"
            id="path873"></path>
       </g>
     </g>
   </svg>
      </div>
   ]])
end

-- ##############################################

function addGauge(name, url, maxValue, width, height)
  if(url ~= nil) then print('<A HREF="'..url..'">') end
  print [[
  <div class="progress">
       <div id="]] print(name) print [[" class="progress-bar bg-warning"></div>
  </div>
  ]]
  if(url ~= nil) then print('</A>\n') end
end

-- ##############################################

-- @brief Implements the logic to decide whether to show or not the url for a given `host_info`
local function hostdetails_exists(host_info, hostdetails_params)
   if not hostdetails_params then
      hostdetails_params = {}
   end

   if hostdetails_params["page"] ~= "historical" and not hostdetails_params["ts_schema"] then
      -- If the requested host_details.lua page is not the "historical" page
      -- and if no ts_schema has been requested
      -- then we check for host existance in memory, to make sure the page host_details.lua
      -- won't bring to an empty page.
      if not host_info["ipkey"] then
	 -- host_info hasn't been generated with Host::lua so we can try and
	 -- see if the host is active
	 local active_host = interface.getHostInfo(hostinfo2hostkey(host_info))
	 if not active_host then
	    return false
	 end
      end
   else
      -- If the requested page is the "historical" page, or if a ts_schema has been requested,
      -- then we assume page host_details.lua
      -- exists if the timeseries are enabled and if the requested timeseries exists for the host
      if not hostdetails_params["ts_schema"] then
	 -- Default schema for hosts
	 hostdetails_params["ts_schema"] = "host:traffic"
      end

      -- A ts_schema has been requested, let's see if it exists
      local ts_utils = require("ts_utils_core")
      local tags = table.merge(host_info, hostdetails_params)
      if not tags["ifid"] then tags["ifid"] = interface.getId() end

      -- If nIndex support is enabled, then there's no need to check for existence of the
      -- schema: nIndex flows must be visible from the historical page even when there's no timeseries
      -- associated
      if not interfaceHasClickHouseSupport() and not ts_utils.exists(hostdetails_params["ts_schema"], tags) then
	 -- If here, the requested schema, along with its hostdetails_params doesn't exist
	 return false
      end
   end
   return true
end

-- ##############################################

-- @brief Generates an host_details.lua url (if available)
-- @param host_info A lua table containing at least keys `host` and `vlan` or a full lua table generated with Host::lua
-- @param href_params A lua table containing params host_details.lua params, e.g., {page = "historical"}
-- @param href_check Performs existance checks on the link to avoid generating links to inactive hosts or hosts without timeseries
-- @return A string containing the url (if available) or an empty string when the url is not available
function hostinfo2detailsurl(host_info, href_params, href_check)
  local tag_utils = require "tag_utils"
  local res = ''

  if not href_check or hostdetails_exists(host_info, href_params) then
    local auth = require "auth"
    local url_params = table.tconcat(href_params or {}, "=", "&")

    -- Alerts pages for the host are in alert_stats.lua (Alerts menu)
    if href_params and href_params.page == "engaged-alerts" then
      if auth.has_capability(auth.capabilities.alerts) then
        res = string.format("%s/lua/alert_stats.lua?page=host&status=engaged&ip=%s%s%s",
          ntop.getHttpPrefix(),
          hostinfo2hostkey(host_info),
          tag_utils.SEPARATOR, "eq")
      end
    elseif href_params and href_params.page == "alerts" then
      if auth.has_capability(auth.capabilities.alerts) then
          res = string.format("%s/lua/alert_stats.lua?page=host&status=historical&ip=%s%s%s",
            ntop.getHttpPrefix(),
            hostinfo2hostkey(host_info),
            tag_utils.SEPARATOR, "eq")
      end
    -- All other pages are in host_details.lua
    else
      res = string.format("%s/lua/host_details.lua?%s%s%s",
        ntop.getHttpPrefix(),
        hostinfo2url(host_info),
        isEmptyString(url_params) and '' or '&',
        url_params,
        href_value)
    end
  end

  return res
end

-- ##############################################

-- @brief Generates an host_details.lua a href link (if available), starting from an `host_info` structure
-- @param host_info A lua table containing at least keys `host` and `vlan` or a full lua table generated with Host::lua
-- @param href_params A lua table containing params host_details.lua params, e.g., {page = "historical"}
-- @param href_value A string containing the visible value shown between a href tags
-- @param href_tooltip A string containing a tooltip shown when hovering the mouse on the link
-- @param href_check Performs existance checks on the link to avoid generating links to inactive hosts or hosts without timeseries
-- @param href_only_with_ts True means that a HREF is geneated only of there are timeseries for this host
-- @return A string containing the a href link or a plain string without a href
function hostinfo2detailshref(host_info, href_params, href_value, href_tooltip, href_check, href_only_with_ts, show_value_with_no_ref)
   local show_href = false
   local res = ""

   if(href_only_with_ts == true) then
      local detailLevel = ntop.getCache("ntopng.prefs.hosts_ts_creation")

      if(detailLevel == "full") then
	 local l7 = ntop.getCache("ntopng.prefs.host_ndpi_timeseries_creation")

	 if(l7 ~= "none") then
	    show_href = true
	 end
      end
   else
      show_href = true
   end

   if(show_href) then
      local hostdetails_url = hostinfo2detailsurl(host_info, href_params, href_check)

      if not isEmptyString(hostdetails_url)then
	      res = string.format("<a href='%s' data-bs-toggle='tooltip' title='%s'>%s</a>",
			                     hostdetails_url, href_tooltip or '', href_value or '')
      else
         if show_value_with_no_ref == nil or show_value_with_no_ref == true then
	         res = href_value or ''
         end
      end

      return res
   else
      return(href_value)
   end
end

-- ##############################################

-- @brief Generates an host_details.lua a href link (if available), starting from an ip and a vlan
-- @param ip A string with a valid ip address
-- @param vlan A string or a number with a VLAN or nil when VLAN information is not available
-- @param href_params A lua table containing params host_details.lua params, e.g., {page = "historical"}
-- @param href_value A string containing the visible value shown between a href tags
-- @param href_tooltip A string containing a tooltip shown when hovering the mouse on the link
-- @param href_check Performs existance checks on the link to avoid generating links to inactive hosts or hosts without timeseries
-- @return A string containing the a href link or a plain string without a href
function ip2detailshref(ip, vlan, href_params, href_value, href_tooltip, href_check)
   return hostinfo2detailshref({host = ip, vlan = tonumber(vlan) or 0}, href_params, href_value, href_tooltip, href_check)
end

-- ##############################################

function flowinfo2process(process, host_info_to_url)
   local fmt, proc_name, proc_user_name = '', '', ''

   if process then
      -- TODO: add links back once restored

      if not isEmptyString(process["name"]) then
	 local full_clean_name = process["name"]:gsub("'",'')
	 local t = split(full_clean_name, "/")

	 clean_name = t[#t]

	 proc_name = string.format("<A HREF='%s/lua/process_details.lua?%s&pid_name=%s&pid=%u'><i class='fas fa-terminal'></i> %s</A>",
				   ntop.getHttpPrefix(),
				   host_info_to_url,
				   full_clean_name,
				   process["pid"],
				   clean_name)
      end

      -- if not isEmptyString(process["user_name"]) then
      -- 	 local clean_user_name = process["user_name"]:gsub("'", '')

      -- 	 proc_user_name = string.format("<A HREF='%s/lua/username_details.lua?%s&username=%s&uid=%u'><i class='fas fa-linux'></i> %s</A>",
      -- 					ntop.getHttpPrefix(),
      -- 					host_info_to_url,
      -- 					clean_user_name,
      -- 					process["uid"],
      -- 					clean_user_name)
      -- end

      fmt = string.format("[%s]", table.concat({proc_user_name, proc_name}, ' '))
   end

   return fmt
end

-- ##############################################

function flowinfo2container(container)
   local fmt, cont_name, pod_name = '', '', ''

   if container then
      cont_name = string.format("<A HREF='%s/lua/flows_stats.lua?container=%s'><i class='fas fa-ship'></i> %s</A>",
				ntop.getHttpPrefix(),
				container["id"], format_utils.formatContainer(container))

      -- local formatted_pod = format_utils.formatPod(container)
      -- if not isEmptyString(formatted_pod) then
      -- 	 pod_name = string.format("<A HREF='%s/lua/containers_stats.lua?pod=%s'><i class='fas fa-crosshairs'></i> %s</A>",
      -- 				  ntop.getHttpPrefix(),
      -- 				  formatted_pod,
      -- 				  formatted_pod)
      -- end

      fmt = string.format("[%s]", table.concat({cont_name, pod_name}, ''))
   end

   return fmt
end

-- ##############################################

--
-- Analyze the get_info and return a new table containing the url information about an host.
-- Example: url2host(_GET)
--
function url2hostinfo(get_info)
  local host = {}

  -- Catch when the host key is using as host url parameter
  if((get_info["host"] ~= nil) and (string.find(get_info["host"],"@"))) then
    get_info = hostkey2hostinfo(get_info["host"])
  end

  if(get_info["host"] ~= nil) then
    host["host"] = get_info["host"]
    if(debug_host) then traceError(TRACE_DEBUG,TRACE_CONSOLE,"URL2HOST => Host:"..get_info["host"].."\n") end
  end

  if(get_info["vlan"] ~= nil) then
    host["vlan"] = tonumber(get_info["vlan"])
    if(debug_host) then traceError(TRACE_DEBUG,TRACE_CONSOLE,"URL2HOST => Vlan:"..get_info["vlan"].."\n") end
  else
    host["vlan"] = 0
  end

  return host
end

-- ##############################################

--
-- Catch the main information about an host from the host_info table and return the corresponding url.
-- Example:
--          hostinfo2url(host_key), return an url based on the host_key
--          hostinfo2url(host[key]), return an url based on the host value
--          hostinfo2url(flow[key],"cli"), return an url based on the client host information in the flow table
--          hostinfo2url(flow[key],"srv"), return an url based on the server host information in the flow table
--

function hostinfo2url(host_info, host_type, novlan)
   local rsp = ''
   -- local version = 0
   local version = 1

   if(host_type == "cli") then
      if(host_info["cli.ip"] ~= nil) then
	 rsp = rsp..'host='..hostinfo2hostkey(flow2hostinfo(host_info, "cli"))
      end

   elseif(host_type == "srv") then
      if(host_info["srv.ip"] ~= nil) then
	 rsp = rsp..'host='..hostinfo2hostkey(flow2hostinfo(host_info, "srv"))
      end
   else

      if((type(host_info) ~= "table")) then
	 host_info = hostkey2hostinfo(host_info)
      end

      if(host_info["host"] ~= nil) then
	 rsp = rsp..'host='..host_info["host"]
      elseif(host_info["ip"] ~= nil) then
	 rsp = rsp..'host='..host_info["ip"]
      elseif(host_info["mac"] ~= nil) then
	 rsp = rsp..'host='..host_info["mac"]
	 --Note: the host'name' is not supported (not accepted by lint)
	 --elseif(host_info["name"] ~= nil) then
	 --  rsp = rsp..'host='..host_info["name"]
      end
   end

   if(novlan == nil) then
      if((host_info["vlan"] ~= nil) and (tonumber(host_info["vlan"]) ~= 0)) then
	 if(version == 0) then
	    rsp = rsp..'&vlan='..tostring(host_info["vlan"])
	 elseif(version == 1) then
	    rsp = rsp..'@'..tostring(host_info["vlan"])
	 end
      end
   end

   if(debug_host) then traceError(TRACE_DEBUG,TRACE_CONSOLE,"HOST2URL => ".. rsp .. "\n") end

   return rsp
end

-- ##############################################

function unescapeHTML(s)
   local unesc = function (h)
      local res = string.char(tonumber(h, 16))
      return res
   end

   -- s = string.gsub(s, "+", " ")
   s = string.gsub(s, "%%(%x%x)", unesc)

   return s
end

-- ##############################################

function unescapeHttpHost(host)
   if isEmptyString(host) then
      return(host)
   end

   return string.gsub(string.gsub(host, "http:__", "http://"), "https:__", "https://")
end

 -- ##############################################

function isAdministratorOrPrintErr(isJsonResponse)
   if (isAdministrator()) then
      return(true)
   end

   local isJson = isJsonResponse or false

   if (isJson) then
      local json = require("dkjson")
      sendHTTPContentTypeHeader('application/json')
      print(json.encode({}))
   else
      local page_utils = require("page_utils")
      page_utils.print_header()
      dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")
      print("<div class=\"alert alert-danger\"><i class='fas fa-exclamation-triangle fa-lg fa-ntopng-warning'></i> Access forbidden</div>")
   end

   return(false)
end

 -- ##############################################

function formatBreed(breed, is_encrypted)
   local ret = ""

   if(breed == "Safe") then
      if(is_encrypted == false) then ret = "<i class='fas fa-thumbs-up' alt='"..i18n("breed.safe").."'></i>" end
   elseif(breed == "Acceptable") then
      -- if(is_encrypted == false) then ret = "<i class='fas fa-thumbs-up' alt='"..i18n("breed.acceptable").."'></i>" end
   elseif(breed == "Fun") then
      ret = "<i class='fas fa-smile' alt='"..i18n("breed.fun").."'></i>"
   elseif(breed == "Unsafe") then
      ret = "<i class='fas fa-thumbs-down' style='color: red' alt='"..i18n("breed.unsafe").."'></i>"
   elseif(breed == "Dangerous") then
      ret = "<i class='fas fa-exclamation-triangle' alt='"..i18n("breed.dangerous").."'></i>"
   end

   if(is_encrypted == true) then
      ret = ret .. " <i class='fas fa-lock'></i>"
   end

   return(ret)
end

-- ###############################################

function macInfoWithSymbName(mac, name)
   return(' <A HREF="' .. ntop.getHttpPrefix() .. '/lua/mac_details.lua?host='.. mac ..'">'..name..'</A> ')
end

-- ###############################################

function macInfo(mac)
  return(' <A HREF="' .. ntop.getHttpPrefix() .. '/lua/mac_details.lua?host='.. mac ..'">'..mac..'</A> ')
end

-- ###############################################

function intToIPv4(num)
   return(math.floor(num / 2^24).. "." ..math.floor((num % 2^24) / 2^16).. "." ..math.floor((num % 2^16) / 2^8).. "." ..num % 2^8)
end

-- ###############################################

function formatWebSite(site)
   return("<A class='ntopng-external-link' target=\"_blank\" href=\"http://"..site.."\">"..site.." <i class=\"fas fa-external-link-alt\"></i></A></th>")
end

-- #############################################

-- Add here the icons you guess based on the Mac address
-- TODO move to discovery stuff
local guess_icon_keys = {
  ["dell inc."] = "fas fa-desktop",
  ["vmware, inc."] = "fas fa-desktop",
  ["xensource, inc."] = "fas fa-desktop",
  ["lanner electronics, inc."] = "fas fa-desktop",
  ["nexcom international co., ltd."] = "fas fa-desktop",
  ["apple, inc."] = "fab fa-apple",
  ["cisco systems, inc"] = "fas fa-arrows-alt",
  ["juniper networks"] = "fas fa-arrows-alt",
  ["brocade communications systems, inc."] = "fas fa-arrows-alt",
  ["force10 networks, inc."] = "fas fa-arrows-alt",
  ["huawei technologies co.,ltd"] = "fas fa-arrows-alt",
  ["alcatel-lucent ipd"] = "fas fa-arrows-alt",
  ["arista networks, inc."] = "fas fa-arrows-alt",
  ["3com corporation"] = "fas fa-arrows-alt",
  ["routerboard.com"] = "fas fa-arrows-alt",
  ["extreme networks"] = "fas fa-arrows-alt",
  ["xerox corporation"] = "fas fa-print"
}

-- #############################################

function guessHostIcon(key)
   local m = string.lower(get_manufacturer_mac(key))
   local icon = guess_icon_keys[m]

   if((icon ~= nil) and (icon ~= "")) then
      return(" <i class='"..icon.." fa-lg'></i>")
   else
      return ""
   end
end

-- ###########################################

-- Note: use data-min and data-max to setup ranges
function makeResolutionButtons(fmt_to_data, ctrl_id, fmt, value, extra, max_val)
  local extra = extra or {}
  local html_lines = {}

  local divisors = {}

  -- fill in divisors
  if tonumber(value) ~= nil then
    -- foreach character in format
    string.gsub(fmt, ".", function(k)
      local v = fmt_to_data[k]
      if v ~= nil then
	 divisors[#divisors + 1] = {k=k, v=v.value}
      end
    end)
  end

  local selected = nil
  if tonumber(value) ~= 0 then
    selected = highestDivisor(divisors, value, "v")
  end

  if selected ~= nil then
    selected = divisors[selected].k
  else
    selected = string.sub(fmt, 1, 1)
  end

  local style = table.merge({display="flex"}, extra.style or {})
  html_lines[#html_lines+1] = [[<div class="btn-group ]] .. table.concat(extra.classes or {}, "") .. [[" id="]] .. ctrl_id .. [[" role="group" style="]] .. table.tconcat(style, ":", "; ", ";") .. [[">]]

  -- foreach character in format
  string.gsub(fmt, ".", function(k)

    local v = fmt_to_data[k]
    if v ~= nil then
         local line = {}

         if((max_val == nil) or (v.value < max_val)) then

            local input_name = ("opt_resbt_%s_%s"):format(k, ctrl_id)
            local input = ([[
               <input class="btn-check" data-resol="%s" value="%s" title="%s" name="%s" id="input-%s" autocomplete="off" type="radio" %s/>
                  ]]):format(k, truncate(v.value), v.label, input_name, input_name, ternary((selected == k), 'checked="checked"', ""))
            local label = ([[
               <label class="btn btn-sm %s" for="input-%s">%s</label>
            ]]):format(ternary((selected == k), "btn-primary", "btn-secondary"), input_name, v.label)

	    line[#line+1] = input
            line[#line+1] = label

            html_lines[#html_lines+1] = table.concat(line, "")
       end
    end
	       end)

  html_lines[#html_lines+1] = [[</div>]]

  -- Note: no // comment below, only /* */

  local js_init_code = [[
      var _resol_inputs = [];

      function resol_selector_get_input(a_button) {
        return $("input", $(a_button).closest(".form-group.mb-3")).last();
      }

      function resol_selector_get_buttons(an_input) {
        return $(".btn-group", $(an_input).closest(".form-group.mb-3")).first().find("input");
      }

      /* This function scales values wrt selected resolution */
      function resol_selector_reset_input_range($selected) {
        let duration = $($selected);
        let input = resol_selector_get_input(duration);

        let raw = parseInt(input.attr("data-min"));
        if (! isNaN(raw))
          input.attr("min", Math.sign(raw) * Math.ceil(Math.abs(raw) / duration.val()));

        raw = parseInt(input.attr("data-max"));
        if (! isNaN(raw))
          input.attr("max", Math.sign(raw) * Math.ceil(Math.abs(raw) / duration.val()));

        var step = parseInt(input.attr("data-step-" + duration.attr("data-resol")));
        if (! isNaN(step)) {
          input.attr("step", step);

          /* Align value */
          input.val(input.val() - input.val() % step);
        } else
          input.attr("step", "");

        resol_recheck_input_range(input);
      }

      /*
       * Remove the checked value inside the radio buttons
       * and add it only to the one selected
       */
      function resol_selector_change_callback(event) {
        $(this).parent().find('label').removeClass('btn-primary').addClass('btn-secondary');
        $(this).parent().find('input[type="radio"]').prop('checked', false);
        $(this).prop('checked', true).removeClass('btn-secondary').addClass('btn-primary');
        $(this).parent().find('label[for="' + $(this).attr('id') + '"]').removeClass('btn-secondary').addClass('btn-primary');

        resol_selector_reset_input_range($(this));
      }

      /* Function used to check the value input range */
      function resol_recheck_input_range(input) {
        let value = input.val();

        if (input[0].hasAttribute("min") && Number.isNaN(input.attr("min")))
          value = Math.max(parseInt(input.val()), !input.attr("min"));
        if (input[0].hasAttribute("max") && Number.isNaN(input.attr("max")))
          value = Math.min(parseInt(input.val()), !input.attr("max"));

        if ((input.val() != "") && (input.val() != value))
          input.val(value);
      }


      function resol_selector_on_form_submit(event) {
        var form = $(this);

        if (event.isDefaultPrevented() || (form.find(".has-error").length > 0))
          return false;

        resol_selector_finalize(form);
        return true;
      }

      function resol_selector_get_raw(input) {
         var buttons = resol_selector_get_buttons(input);
         var selected = buttons.filter(":checked");

         return parseInt(selected.val()) * parseInt(input.val());
      }

      function resol_selector_finalize(form) {
        $.each(_resol_inputs, function(i, elem) {
          /* Skip elements which are not part of the form */
          if (! $(elem).closest("form").is(form))
            return;

          var selected = $(elem).find("input[checked]");
          var input = resol_selector_get_input(selected);

          /* transform in raw units */
          var new_input = $("<input type=\"hidden\"/>");
          new_input.attr("name", input.attr("name"));
          input.removeAttr("name");
          new_input.val(resol_selector_get_raw(input));
          new_input.appendTo(form);
        });

        /* remove added input names */
        $("input[name^=opt_resbt_]", form).removeAttr("name");
      }]]

  local js_specific_code = [[
    $("#]] .. ctrl_id .. [[ input").change(resol_selector_change_callback);
    $(function() {
      var elemid = "#]] .. ctrl_id .. [[";
      _resol_inputs.push(elemid);
      var selected = $(elemid + " input[checked]");
      resol_selector_reset_input_range(selected);

      /* setup the form submit callback (only once) */
      var form = selected.closest("form");
      if (! form.attr("data-options-handler")) {
        form.attr("data-options-handler", 1);
        form.submit(resol_selector_on_form_submit);
      }
    });
  ]]

  -- join strings and strip newlines
  local html = string.gsub(table.concat(html_lines, " "), "\n", "")
  js_init_code = string.gsub(js_init_code, "", "")
  js_specific_code = string.gsub(js_specific_code, "\n", "")

  if tonumber(value) ~= nil then
     -- returns the new value with selected resolution
    return {html=html, init=js_init_code, js=js_specific_code, value=tonumber(value) / fmt_to_data[selected].value}
  else
    return {html=html, init=js_init_code, js=js_specific_code, value=nil}
  end
end

-- ###########################################

-- avoids manual HTTP prefix and /lua concatenation
function page_url(path)
  return ntop.getHttpPrefix().."/lua/"..path
end

-- extracts a page url from the path
function path_get_page(path)
   local prefix = ntop.getHttpPrefix() .. "/lua/"

   if string.find(path, prefix) == 1 then
      return string.sub(path, string.len(prefix) + 1)
   end

   return path
end

-- ###########################################

function splitUrl(url)
   local params = {}
   local parts = split(url, "?")

   if #parts == 2 then
      url = parts[1]
      parts = split(parts[2], "&")

      for _, param in pairs(parts) do
         local p = split(param, "=")

         if #p == 2 then
            params[p[1]] = p[2]
         end
      end
   end

   return {
      url = url,
      params = params,
   }
end

-- ###########################################

function visualTsKey(tskey)
   if ends(tskey, "_v4") or ends(tskey, "_v6") then
      local ver = string.sub(tskey, string.len(tskey)-1, string.len(tskey))
      local address = string.sub(tskey, 1, string.len(tskey)-3)
      local visual_addr

      if ver == "v4" then
         visual_addr = address
      else
         visual_addr = address .. " (" .. ver ..")"
      end

      return visual_addr
   end

   return tskey
end

-- ##############################################

--- Return an HTML `select` element with passed options.
--
function generate_select(id, name, is_required, is_disabled, options, additional_classes)
   local required_flag = (is_required and "required" or "")
   local disabled_flag = (is_disabled and "disabled" or "")
   local name_attr = (name ~= "" and "name='" .. name .. "'" or "")
   local parsed_options = ""
   for i, option in ipairs(options) do
      parsed_options = parsed_options .. ([[
         <option ]].. (i == 1 and "selected" or "") ..[[ value="]].. option.value ..[[">]].. option.title ..[[</option>
      ]])
   end

   return ([[
      <select id="]].. id ..[[" class="form-select ]] .. (additional_classes or "") .. [[" ]].. name_attr ..[[ ]].. required_flag ..[[ ]] .. disabled_flag ..[[>
         ]].. parsed_options ..[[
      </select>
   ]])
end

-- ###########################################

function build_query_url(excluded)

   local query = "?"

   for key, value in pairs(_GET) do
      if not(table.contains(excluded, key)) then
         query = query .. string.format("%s=%s&", key, value)
      end
   end

   return query
end

-- ###########################################

function build_query_params(params)

    local query = "?"
    local t = {}

    for key, value in pairs(params) do
        t[#t+1] = string.format("%s=%s", key, value)
    end

    return query .. table.concat(t, '&')
end

-- ###########################################

function buildHostHREF(ip_address, vlan_id, page)
   local stats

   if(stats == nil) then
      stats = interface.getHostInfo(ip_address, vlan_id)
   else
      stats = stats.stats
   end

   if(stats == nil) then
      return(ip_address)
   else
      local hinfo = hostkey2hostinfo(ip_address)
      local name  = hostinfo2label(hinfo)
      local res

      if((name == nil) or (name == "")) then name = ip_address end
      res = '<A HREF="'..ntop.getHttpPrefix()..'/lua/host_details.lua?host='..ip_address
      if(vlan_id and (vlan_id ~= 0)) then res = res .. "@"..vlan_id end
      res = res  ..'&page='..page..'">'..name..'</A>'

      return(res)
   end
end

-- ###########################################

local _cache_map_href = {}

function buildMapHREF(service_peer, map, page)

   -- cache information in order to speed-up things
   if(_cache_map_href[service_peer.ip] ~= nil) then
      return(_cache_map_href[service_peer.ip])
   end
   
  -- Getting minimal stats to know if the host is still present in memory
  local name
  local vlan = service_peer.vlan
  service_peer.vlan = nil
  local map_url = ntop.getHttpPrefix()..'/lua/pro/enterprise/network_maps.lua?map=' .. map .. '&page=' .. page .. '&' ..hostinfo2url(service_peer)
  local host_url = ''
  local host_icon

  if vlan then
    map_url = map_url .. '&vlan_id=' .. vlan
  end

  -- Getting stats and formatting initial href
  if (service_peer.ip or service_peer.host) and not service_peer.is_mac then
    -- Host URL only if the host is active
    host_url = hostinfo2detailsurl({host = service_peer.ip or service_peer.host, vlan = vlan}, nil, true --[[ check of the host is active --]])

    local hinfo = interface.getHostMinInfo(service_peer.ip or service_peer.host, vlan)

    name = hostinfo2label(hinfo or service_peer)
    host_icon = "fa-laptop"
  else
    local minfo = interface.getMacInfo(service_peer.host)

    -- The URL only if the MAC is active
    if minfo and table.len(minfo) > 0 then
      host_url = ntop.getHttpPrefix()..'/lua/mac_details.lua?'..hostinfo2url(service_peer)
    end

    if (service_peer.ip and service_peer.is_mac) or not service_peer.is_mac  then
        local hinfo = interface.getHostMinInfo(service_peer.ip or service_peer.host, vlan)
        name = hostinfo2label(hinfo or service_peer)
    else
        name = mac2label(service_peer.host)
    end

    if isMacAddress(name) then
      name = get_symbolic_mac(name, true)
    end

    host_icon = "fa-microchip"
  end

  -- Getting the name if present
  name = name or service_peer.host

  if vlan and tonumber(vlan) ~= 0 then
    name = name .. '@' .. getFullVlanName(vlan)
  end

  local res
  if not isEmptyString(host_url) then
    res = string.format('<a href="%s">%s</a> <a href="%s"><i class="fas %s"></i></a>', map_url, name, host_url, host_icon)
  else
    res = string.format('<a href="%s">%s</a>', map_url, name)
  end

  _cache_map_href[service_peer.ip] = res
  return res
end

-- #####################

-- Used by REST v1
function formatAlertAHref(key, value, label)
   return "<a class='tag-filter' data-tag-key='" .. key .. "' title='" .. value .. "' data-tag-value='" .. value .. "' data-tag-label='" .. label .. "' href='#'>" .. label .. "</a>"
end

function add_historical_flow_explorer_button_ref(extra_params)
   if (ntop.getPrefs()["is_dump_flows_to_clickhouse_enabled"]) == false then
      return ''
   end

   local base_url = ntop.getHttpPrefix() .. "/lua/pro/db_search.lua?"

   for k, v in pairs(extra_params) do
      base_url = base_url .. k .. "=" .. v["value"] .. ";" .. v["operator"]
   end

   local button = '<a href="' .. base_url .. '" data-placement="bottom" class="btn btn-sm btn-primary" title="Historical Flow Explorer"><i class="fas fa-search-plus"></i></a>'

   return button
end

function add_delete_obs_point_button()
   local button = ''
   if isAdministrator() then
      button = '<a href="#delete_obs_point_stats" data-placement="bottom" data-bs-toggle="modal" class="btn btn-sm btn-danger" title="Remove"><i class="fas fa fa-trash"></i></a>'
   end

   return button
end

-- ##############################################

local _snmp_devices = {}

-- @brief This function format the SNMP interface name.
-- @params device_ip: snmp device ip
--         portidx:   number or string, interface index to format
--         short_version: boolean, long formatting version (e.g. flow info) or short version (e.g. dropdown menu)
function format_portidx_name(device_ip, portidx, short_version, shorten_string)
   local idx_name = portidx

   -- SNMP is available only with Pro version at least
   if ntop.isPro() then
      local cached_dev = _snmp_devices[device_ip]

      if(cached_dev == nil) then
	 local snmp_cached_dev = require "snmp_cached_dev"

	 cached_dev = snmp_cached_dev:get_interface_names(device_ip)
	 _snmp_devices[device_ip] = cached_dev
      end

      if (cached_dev) and (cached_dev["interfaces"]) then
	 local port_info = cached_dev["interfaces"][tostring(portidx)]

	 if port_info then
	    package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
	    snmp_location = require "snmp_location"

	    if not port_info["id"] then
	       port_info["id"] = portidx
	       port_info["snmp_device_ip"] = cached_dev["host_ip"]
	    end

	    if short_version then
	       local name = port_info["name"]
	       if shorten_string then
		  name = shortenString(name)
	       end
	       idx_name = string.format('%s', name);
	    else
	       idx_name = string.format('%s',
					i18n("snmp.interface_device_2", {
						interface=snmp_location.snmp_port_link(port_info, true),
						--device=snmp_location.snmp_device_link(cached_dev["host_ip"])
					})
	       )
	    end
	 end
      end
   end

   return idx_name
end

-- ##############################################

-- @brief Given a table of values, if available, it's going to format the values with the standard
--        info and then return the same table formatted
function format_dns_query_info(dns_info)
  if dns_info.last_query_type then
    dns_info.last_query_type = string.format('<span class="badge bg-info">%s</span>', dns_utils.getQueryType(dns_info.last_query_type))
  end

  if dns_info.last_return_code then
    local badge = get_badge(dns_info.last_return_code)
    dns_info.last_return_code = string.format('<span class="badge bg-%s">%s</span>', badge, dns_utils.getResponseStatusCode(dns_info.last_return_code))
  end

  if dns_info.last_query then
    local url = dns_info["last_query"]
    url = string.gsub(url, " ", "") -- Clean the URL from spaces and %20, spaces in html
    if not string.find(url, '*') then
      dns_info.last_query = i18n("external_link_url", { proto = 'https', url = url, url_name = dns_info["last_query"] })
    end
  end

  return dns_info
end

-- ##############################################

function format_tls_info(tls_info)
  if tls_info.notBefore then
    tls_info.notBefore = formatEpoch(tls_info.notBefore)
  end

  if tls_info.notAfter then
    tls_info.notAfter = formatEpoch(tls_info.notAfter)
  end

  if tls_info.notBefore and tls_info.notAfter then
    tls_info["tls_certificate_validity"] = string.format("%s - %s", tls_info.notBefore, tls_info.notAfter)
    tls_info.notBefore = nil
    tls_info.notAfter = nil
  end

  if tls_info.tls_version then
    if tls_info.tls_version > 0 then
      tls_info["tls_version"] = ntop.getTLSVersionName(tls_info.tls_version)
    else
      tls_info["tls_version"] = nil
    end
  end

  if tls_info.client_requested_server_name then
    local url = tls_info["client_requested_server_name"]
    url = string.gsub(url, " ", "") -- Clean the URL from spaces and %20, spaces in html
    if not string.find(url, '*') then
      tls_info["client_requested_server_name"] = i18n("external_link_url", { proto = 'https', url = url, url_name = url})
    end
  end

  if tls_info["ja3.server_cipher"] then
    tls_info["ja3.server_cipher"] = nil
  end

  if tls_info["ja3.server_unsafe_cipher"] then
    local badge = get_badge(tls_info["ja3.server_unsafe_cipher"] == "safe")
    tls_info["ja3.server_unsafe_cipher"] = string.format('<span class="badge bg-%s">%s</span>', badge, tls_info["ja3.server_unsafe_cipher"])
  end

  if tls_info["ja3.server_hash"] then
    tls_info["ja3.server_hash"] = i18n("copy_button", { full_name = tls_info["ja3.server_hash"], name = tls_info["ja3.server_hash"] })
  end

  if tls_info["ja3.client_hash"] then
    tls_info["ja3.client_hash"] = i18n("copy_button", { full_name = tls_info["ja3.client_hash"], name = tls_info["ja3.client_hash"] })
  end

  if tls_info["server_names"] then
    tls_info["server_names"] = i18n("copy_button", { full_name = tls_info["server_names"], name = shortenString(tls_info["server_names"],128) })
  end

  return tls_info
end

-- ##############################################

function format_icmp_info(icmp_info)
  local icmp_utils = require "icmp_utils"

  if icmp_info.code then
    icmp_info.code = icmp_utils.get_icmp_code(icmp_info.type, icmp_info.code)
  end

  if icmp_info.type then
    icmp_info.type = icmp_utils.get_icmp_type(icmp_info.type)
  end

  return icmp_info
end

-- ##############################################

function format_http_info(http_info)
  if http_info["last_return_code"] then
    local badge = get_badge(http_info.last_return_code == 200)
    http_info["last_return_code"] = string.format('<span class="badge bg-%s">%s</span>', badge, http_utils.getResponseStatusCode(http_info["last_return_code"]))
  end

  if http_info["last_method"] then
    http_info["last_method"] = string.format('<span class="badge bg-info">%s</span>', http_info["last_method"])
  end

  if http_info["last_url"] then
    local url = http_info["last_url"]

    if string.find(http_info["last_url"], '^/') then
      url = (http_info["server_name"] or "") .. http_info["last_url"]
    end
    url = string.gsub(url, " ", "") -- Clean the URL from spaces and %20, spaces in html
    if not string.find(url, '*') then
      http_info["last_url"] = i18n("external_link_url", { proto = 'http', url = url, url_name = url})
    end
  end

  if http_info["server_name"] then
    http_info["server_name"] = i18n("copy_button", { full_name = http_info["server_name"], name = shortenString(http_info["server_name"], 32)})
  end

  return http_info
end

-- ##############################################

function format_common_info(flow_info, formatted_info)
  local predominant_bytes = i18n("traffic_srv_to_cli")

  if (tonumber(flow_info["cli2srv_bytes"] or 0)) > (tonumber(flow_info["srv2cli_bytes"] or 0)) then
    predominant_bytes = i18n("traffic_cli_to_srv")
  end

  formatted_info["predominant_direction"] = predominant_bytes
  formatted_info["server_traffic"] = bytesToSize(flow_info["srv2cli_bytes"] or 0)
  formatted_info["client_traffic"] = bytesToSize(flow_info["cli2srv_bytes"] or 0)

  return formatted_info
end

-- ##############################################

function format_proto_info(proto_info)
  local proto_details = {}

  for key, value in pairs(proto_info) do
    if type(value) ~= "table" then
      proto_info[key] = nil
    end
  end

  for proto, info in pairs(proto_info or {}) do
    if proto == "tls" then
      proto_details[proto] = format_tls_info(info)
    elseif proto == "dns" then
      proto_details[proto] = format_dns_query_info(info)
    elseif proto == "http" then
      proto_details[proto] = format_http_info(info)
    elseif proto == "icmp" then
      proto_details[proto] = format_icmp_info(info)
    end

    break
  end

  return proto_details
end

-- ##############################################

-- @brief  This function, given an IP and a vlan return the concat of host@vlan
-- @params host_ip: A string containing the IP
--         vlan:    A string or a number containing the vlan id
-- @return A string IP@vlan
function format_ip_vlan(ip, vlan)
  local host = ip

  if (vlan) and (tonumber(vlan) ~= 0) then
    host = host .. '@' .. (tonumber(vlan) or vlan)
  end

  return host
end

-- ##############################################

-- @brief  This function, given an alert and "cli" or "srv" string is going to return the formatted hostname
-- @params alert:   A table with the alert infos
--         cli_srv: A string "cli" or "srv" used to get the required info
-- @return A string hostname@vlan
function format_alert_hostname(alert, cli_srv)
  local host = alert[cli_srv .. "_name"]

  if(isEmptyString(host)) then
    host = alert[cli_srv .. "_ip"]
  end

  return format_ip_vlan(shortenString(host, 26), alert["vlan"])
end

-- ##############################################

-- @brief  This function format the info field used in tables
-- @params info: A string containing the info field
--         no_html: A boolean, true if no_html is requested (e.g. Download in CSV format),
--                  false otherwise
-- @return A string containing the info field formatted
function format_external_link(url, name, no_html, proto)
   local external_field = url
   proto = ternary(((proto) and (proto == 'http')), 'http', 'https')

   if no_html == false then
     if not isEmptyString(url) and not string.find(url, '*') then
        url = string.gsub(url, " ", "") -- Clean the URL from spaces and %20, spaces in html
            external_field = i18n("external_link_url", { proto = proto, url = url, url_name = name})
     end
   end

   return external_field
end

-- ##############################################

function format_confidence_badge(confidence, shorten_string)
  local badge = ""

  if confidence == 0 then
    badge = "<span class=\"badge bg-warning\" title=\"" .. get_confidence(confidence) .. "\">" .. get_confidence(confidence, shorten_string) .. "</span>"
  elseif confidence then
    badge = "<span class=\"badge bg-success\" title=\"" .. get_confidence(confidence) .. "\">" .. get_confidence(confidence, shorten_string) .. "</span>"
  end

  return badge
end

-- ##############################################

function format_query_direction(op, val)
  local historical_flow_utils = require "historical_flow_utils"
  local direction_where = ""
  if val == "0" then
    direction_where = "(" .. historical_flow_utils.get_flow_column_by_tag("cli_location") .. " "  .. op .. " '0' AND " ..
                             historical_flow_utils.get_flow_column_by_tag("srv_location") .. " "  .. op .. " '0')"
  elseif val == "1" then
    direction_where = "(" .. historical_flow_utils.get_flow_column_by_tag("cli_location") .. " "  .. op .. " '1' AND " ..
                             historical_flow_utils.get_flow_column_by_tag("srv_location") .. " "  .. op .. " '1')"
  elseif val == "2" then
    direction_where = "(" .. historical_flow_utils.get_flow_column_by_tag("cli_location") .. " "  .. op .. " '0' AND " ..
                             historical_flow_utils.get_flow_column_by_tag("srv_location") .. " "  .. op .. " '1')"
  elseif val == "3" then
    direction_where = "(" .. historical_flow_utils.get_flow_column_by_tag("cli_location") .. " "  .. op .. " '1' AND " ..
                             historical_flow_utils.get_flow_column_by_tag("srv_location") .. " "  .. op .. " '0')"
  end

  return direction_where
end

-- ##############################################

function format_confidence_from_json(record)
  local json = require "dkjson"
  local alert_json = {}
  local confidence = nil

  if record["ALERT_JSON"] then
    alert_json = json.decode(record["ALERT_JSON"])
  elseif record["json"] then
    alert_json = json.decode(record["json"])
  end

  if (alert_json) and
     (alert_json.proto) and
     (alert_json.proto.confidence) and
     (not isEmptyString(alert_json.proto.confidence)) then
    confidence = get_confidence(alert_json.proto.confidence)
  end

  return confidence
end

-- ##############################################

function format_location_badge(location)
  local loc = string.lower(location) or ""

  if loc == "l" then
    loc = i18n("details.label_short_local_host_badge")
  elseif loc == "r" then
    loc = i18n("details.label_short_remote_host_badge")
  end

  return loc
end

-- ##############################################

function format_name_value(name, value, shorten)
  local formatted_name_value = value

  if not isEmptyString(name) and name ~= value then
    if (shorten) and (shorten == true) then
      formatted_name_value = shortenString(name) .. " [" .. value .. "]"
    else
      formatted_name_value = name .. " [" .. value .. "]"
    end
  end

  return formatted_name_value
end

-- ##############################################

function format_utils.formatSNMPInterface(snmpdevice, interface_index)
  local interface_name = format_portidx_name(snmpdevice, interface_index)

  return string.format('%s (%s)', interface_index, (interface_name))
end

-- ##############################################

function map_score_to_severity(score)
  if score ~= nil then
    return ntop.mapScoreToSeverity(score)
  end

  return ntop.mapScoreToSeverity(0)
end

-- ##############################################

-- Note that ifname can be set by Lua.cpp so don't touch it if already defined
if((ifname == nil) and (_GET ~= nil)) then
   ifname = _GET["ifid"]

   if(ifname ~= nil) then
      if(ifname.."" == tostring(tonumber(ifname)).."") then
	 -- ifname does not contain the interface name but rather the interface id
	 ifname = getInterfaceName(ifname, true)
	 if(ifname == "") then ifname = nil end
      end
   end

   if(debug_session) then traceError(TRACE_DEBUG,TRACE_CONSOLE, "Session => Session:".._SESSION["session"]) end

   if((ifname == nil) and (_SESSION ~= nil)) then
      if(debug_session) then traceError(TRACE_DEBUG,TRACE_CONSOLE, "Session => set ifname by _SESSION value") end
      ifname = _SESSION["ifname"]
      if(debug_session) then traceError(TRACE_DEBUG,TRACE_CONSOLE, "Session => ifname:"..ifname) end
   else
      if(debug_session) then traceError(TRACE_DEBUG,TRACE_CONSOLE, "Session => set ifname by _GET value") end
   end
end


--
-- IMPORTANT
-- Leave it at the end so it can use the functions
-- defined in this file
--
http_lint = require "http_lint"

if(trace_script_duration ~= nil) then
   io.write(debug.getinfo(1,'S').source .." executed in ".. (os.clock()-clock_start)*1000 .. " ms\n")
end
