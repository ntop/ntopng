--
-- (C) 2013-18 - ntop.org
--

local dirs = ntop.getDirs()
local info = ntop.getInfo()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local page_utils = {}

function page_utils.print_header(title)
  local http_prefix = ntop.getHttpPrefix()
  local startup_epoch = ntop.getStartupEpoch()

  local page_title = i18n("welcome_to", { product=info.product })
  if title ~= nil then
    page_title = info.product .. " - " .. title
  end

  print [[<!DOCTYPE html>
<html>
  <head>
    <title>]] print(page_title) print[[</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <link href="]] print(http_prefix) print[[/bootstrap-4.4.0-dist/css/bootstrap.min.css" rel="stylesheet" integrity="sha384-SI27wrMjH3ZZ89r4o+fGIJtnzkAnFs3E4qz9DIYioCQ5l9Rd/7UAa8DHcaL8jkWt" crossorigin="anonymous">
<!--    <link href="]] print(http_prefix) print[[/bootstrap/css/bootstrap.css" rel="stylesheet"> -->
<!--    <link href="]] print(http_prefix) print[[/bootstrap/css/bootstrap-theme.css" rel="stylesheet"> -->
    <link href="]] print(http_prefix) print[[/font-awesome/css/font-awesome.css" rel="stylesheet">
    <link type="text/css" rel="stylesheet" href="]] print(http_prefix) print[[/css/rickshaw.css">
<!--    <link type="text/css" rel="stylesheet" href="]] print(http_prefix) print[[/css/jquery-ui.css"> -->
    <link href="]] print(http_prefix) print[[/css/dc.css" rel="stylesheet">
    <link href="]] print(http_prefix) print[[/css/heatmap.css" rel="stylesheet">
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
<!--    <link href="]] print(http_prefix) print[[/css/bootstrap-slider.css" rel="stylesheet"> -->
<!--    <link href="]] print(http_prefix) print[[/css/bootstrap-nav-wizard.css" rel="stylesheet"> -->

    <!--[if lt IE 9]>
      <script src="]] print(http_prefix) print[[/js/html5shiv.js"></script>
    <![endif]-->

    <link href="]] print(http_prefix) print[[/css/ntopng.css?]] print(startup_epoch) print[[" rel="stylesheet">
    <link rel="stylesheet" href="]] print(http_prefix) print[[/css/bootstrap-datetimepicker.css" />

    <link href="]] print(http_prefix) print[[/css/custom_theme.css?]] print(startup_epoch) print[[" rel="stylesheet">
    <script type="text/javascript" src="]] print(http_prefix) print[[/js/jquery_bootstrap.min.js?]] print(startup_epoch) print[["></script>
    <script type="text/javascript" src="]] print(http_prefix) print[[/popper-1.12.9/js/popper.js?]] print(startup_epoch) print[[" crossorigin="anonymous"></script>
    <script type="text/javascript" src="]] print(http_prefix) print[[/bootstrap-4.4.0-dist/js/bootstrap.min.js?]] print(startup_epoch) print[[" integrity="sha384-3qaqj0lc6sV/qpzrc1N5DC6i1VRn/HyX4qdPaiEFbn54VjQBEU341pvjz7Dv3n6P" crossorigin="anonymous"></script>
    <script type="text/javascript" src="]] print(http_prefix) print[[/js/deps.min.js?]] print(startup_epoch) print[["></script>
    <script type="text/javascript" src="]] print(http_prefix) print[[/js/push.min.js?]] print(startup_epoch) print[["></script>
    <script type="text/javascript" src="]] print(http_prefix) print[[/js/ntop.min.js?]] print(startup_epoch) print[["></script>
  </head>
<body>

  <div class="container-narrow">
]]
end

function page_utils.print_header_minimal(title)
  local http_prefix = ntop.getHttpPrefix()

  local page_title = i18n("welcome_to", { product=info.product })
  if title ~= nil then
    page_title = info.product .. " - " .. title
  end

  print [[<!DOCTYPE html>
<html>
  <head>
    <title>]] print(page_title) print[[</title>
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
end

-- #################################

return page_utils

