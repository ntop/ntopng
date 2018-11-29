--
-- (C) 2013-18 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local info = ntop.getInfo()
local http_prefix = ntop.getHttpPrefix()
local startup_epoch = ntop.getStartupEpoch()
local title = i18n("welcome_to", { product=info.product })

if active_page_title ~= nil then
  title = info.product .. " - " .. active_page_title
end

print [[<!DOCTYPE html>
<html>
  <head>
    <title>]] print(title) print[[</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <link href="]] print(http_prefix) print[[/bootstrap/css/bootstrap.css" rel="stylesheet">
    <link href="]] print(http_prefix) print[[/bootstrap/css/bootstrap-theme.css" rel="stylesheet">
    <link href="]] print(http_prefix) print[[/font-awesome/css/font-awesome.css" rel="stylesheet">
    <script src="]] print(http_prefix) print[[/js/jquery.js"></script>
    <script src="]] print(http_prefix) print[[/js/jquery-ui.js"></script>
    <script src="]] print(http_prefix) print[[/js/bootstrap.js"></script>
    <link type="text/css" rel="stylesheet" href="]] print(http_prefix) print[[/css/jquery-ui.css">
    <link type="text/css" rel="stylesheet" href="]] print(http_prefix) print[[/css/rickshaw.css">
    <script src="]] print(http_prefix) print[[/js/validator.js"></script>
<style>
.flag {
	width: 16px;
	height: 11px;
	margin-top: -5px;
	background:url(]] print(http_prefix) print[[/img/flags.png) no-repeat
}
</style>
    <link href="]] print(http_prefix) print[[/css/ntopng.css" rel="stylesheet">
  </head>
<body>

  <div class="container-narrow">
]]
