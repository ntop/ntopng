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
    <link type="text/css" rel="stylesheet" href="]] print(http_prefix) print[[/css/rickshaw.css">
    <link type="text/css" rel="stylesheet" href="]] print(http_prefix) print[[/css/jquery-ui.css">
    <link href="]] print(http_prefix) print[[/css/dc.css" rel="stylesheet">
<style>
.flag {
	width: 16px;
	height: 11px;
	margin-top: -5px;
	background:url(]] print(http_prefix) print[[/img/flags.png) no-repeat
}
</style>
    <link href="]] print(http_prefix) print[[/css/flags.css" rel="stylesheet">
    <link href="]] print(http_prefix) print[[/css/pie-chart.css" rel="stylesheet">
    <link href="]] print(http_prefix) print[[/css/rickshaw.css" rel="stylesheet">
    <!-- http://kamisama.github.io/cal-heatmap/v2/ -->
    <link href="]] print(http_prefix) print[[/css/cal-heatmap.css" rel="stylesheet">
    <link href="]] print(http_prefix) print[[/css/nv.d3.css" rel="stylesheet">
    <link href="]] print(http_prefix) print[[/css/bootstrap-duallistbox.css" rel="stylesheet">
    <link href="]] print(http_prefix) print[[/css/bootstrap-slider.css" rel="stylesheet">
    <link href="]] print(http_prefix) print[[/css/bootstrap-nav-wizard.css" rel="stylesheet">

    <!--[if lt IE 9]>
      <script src="]] print(http_prefix) print[[/js/html5shiv.js"></script>
    <![endif]-->

    <link href="]] print(http_prefix) print[[/css/ntopng.css?]] print(startup_epoch) print[[" rel="stylesheet">
    <link rel="stylesheet" href="]] print(http_prefix) print[[/css/bootstrap-datetimepicker.css" />

    <link href="]] print(http_prefix) print[[/css/custom_theme.css?]] print(startup_epoch) print[[" rel="stylesheet">
    <script type="text/javascript" src="]] print(http_prefix) print[[/js/jquery_bootstrap.min.js?]] print(startup_epoch) print[["></script>
    <script type="text/javascript" src="]] print(http_prefix) print[[/js/deps.min.js?]] print(startup_epoch) print[["></script>
    <script type="text/javascript" src="]] print(http_prefix) print[[/js/ntop.min.js?]] print(startup_epoch) print[["></script>
  </head>
<body>

  <div class="container-narrow">
]]
