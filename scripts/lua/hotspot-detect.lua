--
-- (C) 2013-17 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
-- io.write ("Session:".._SESSION["session"].."\n")
require "lua_utils"

sendHTTPHeader('text/html; charset=iso-8859-1')

print [[
<html>
<head>
<title>ntopng hotspot detect</title>
<meta http-equiv="refresh" Content="0; url=]] 

print(ntop.getHttpPrefix().."/lua/captive_portal.lua")

if(_SERVER["REFERER"] ~= "") then
   print("?referer=".._SERVER["REFERER"])
end

print [[">
<meta http-equiv="pragma" content="no-cache">
<meta http-equiv="expires" content="-1">
</head>
<body>

<!--
<?xml version="1.0" encoding="UTF-8"?>
<WISPAccessGatewayParam xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="http://www.wballiance.net/wispr_2_0.xsd">
<Redirect>
<MessageType>100</MessageType>
<ResponseCode>0</ResponseCode>
<VersionHigh>2.0</VersionHigh>
<VersionLow>1.0</VersionLow>
<AccessProcedure>1.0</AccessProcedure>
<AccessLocation>ntopng Captive Portal</AccessLocation>
<LocationName>captive.ntopng.ntop.org</LocationName>
<LoginURL>]] print(ntop.getHttpPrefix().."/lua/captive_portal.lua") print [[</LoginURL>
</Redirect>
</WISPAccessGatewayParam>
-->
</body>
</html>
]]