--
-- (C) 2013-17 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"

sendHTTPContentTypeHeader('text/html')

print [[
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 3.2//EN">
<HTML>
<HEAD>
<TITLE>Authentication Successful</TITLE>
<meta http-equiv="refresh" Content="5; url=http://www.ntop.org"/>
</HEAD>
<BODY>
Success ']] print(_GET["label"]) print [['.
<p>
We're redirecting you to the Internet...
</BODY>
</HTML>
   ]]