--
-- (C) 2013-17 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"

sendHTTPContentTypeHeader('text/html')

local prefs = ntop.getPrefs()
print [[
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 3.2//EN">
<HTML>
<HEAD>
<TITLE>Authentication Successful</TITLE>
]]

if((prefs.redirection_url ~= nil) and (prefs.redirection_url ~= "")) then
   print('<meta http-equiv="refresh" Content="0; url='..prefs.redirection_url..'"/>')
end
print [[
</HEAD>
<BODY>
Success ']] print(_GET["label"]) print [['.
<p>
]]

if((prefs.redirection_url ~= nil) and (prefs.redirection_url ~= "")) then
   print("We're redirecting you to the Internet...")
end

print [[
</BODY>
</HTML>
   ]]