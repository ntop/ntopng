--
-- (C) 2013-23 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

sendHTTPContentTypeHeader('text/html')

print [[<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 3.2//EN">
<html>
<head>
<title>]] print(i18n("login.auth_success")) print[[</title>
]]

local redirection_url = ntop.getPref("ntopng.prefs.redirection_url")

if isEmptyString(redirection_url) then
  -- Redirect to the original URL
  redirection_url = _GET["referer"]
end

if isEmptyString(redirection_url) then
   -- Last resort, using www.ntop.org
   redirection_url = "www.ntop.org"
end

if not isEmptyString(redirection_url) then
   if not starts(redirection_url, "http") then
      redirection_url = "http://" .. redirection_url
   end

   print('<meta http-equiv="refresh" Content="0; url='..redirection_url..'"/>')
end

print [[
</head>
<body>
Success]]

if _GET["label"] ~= nil then
   print(" ".._GET["label"])
end

print [[.
<p>
]]

if not isEmptyString(redirection_url) then
   print(i18n("login.internet_redirecting"))
end

print [[
</body>
</html>]]
