--
-- (C) 2013-17 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"

sendHTTPContentTypeHeader('text/html')

local prefs = ntop.getPrefs()
print [[<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 3.2//EN">
<html>
<head>
<title>]] print(i18n("login.auth_success")) print[[</title>
]]

if not isEmptyString(prefs.redirection_url) then
  -- Use the supplied URL if available
  redirection_url = prefs.redirection_url
else
  -- Redirect to the original URL
  redirection_url = _GET["referer"]

  if not isEmptyString(redirection_url) and not starts(redirection_url, "http") then
    redirection_url = "http://" .. redirection_url
  end
end

if not isEmptyString(redirection_url) then
   print('<meta http-equiv="refresh" Content="0; url='..redirection_url..'"/>')
end
print [[
</head>
<body>
Success ']] print(_GET["label"]) print [['.
<p>
]]

if not isEmptyString(redirection_url) then
   print(i18n("login.internet_redirecting"))
end

print [[
</body>
</html>]]
