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
    <link type="text/css" rel="stylesheet" href="]] print(http_prefix) print[[/tempusdominus/css/tempusdominus-bootstrap-4.css">
    <link href="]] print(http_prefix) print[[/fontawesome-free-5.11.2-web/css/fontawesome.css" rel="stylesheet">
    <link href="]] print(http_prefix) print[[/fontawesome-free-5.11.2-web/css/brands.css" rel="stylesheet">
    <link href="]] print(http_prefix) print[[/fontawesome-free-5.11.2-web/css/solid.css" rel="stylesheet">
    <link type="text/css" rel="stylesheet" href="]] print(http_prefix) print[[/css/rickshaw.css">
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

    <!--[if lt IE 9]>
      <script src="]] print(http_prefix) print[[/js/html5shiv.js"></script>
    <![endif]-->

    <link href="]] print(http_prefix) print[[/css/ntopng.css?]] print(startup_epoch) print[[" rel="stylesheet">

    <link href="]] print(http_prefix) print[[/css/custom_theme.css?]] print(startup_epoch) print[[" rel="stylesheet">
    <script type="text/javascript" src="]] print(http_prefix) print[[/js/jquery_bootstrap.min.js?]] print(startup_epoch) print[["></script>

    <script type="text/javascript" src="]] print(http_prefix) print[[/popper-1.12.9/js/popper.js?]] print(startup_epoch) print[[" crossorigin="anonymous"></script>
    <script type="text/javascript" src="]] print(http_prefix) print[[/bootstrap-4.4.0-dist/js/bootstrap.min.js?]] print(startup_epoch) print[[" integrity="sha384-3qaqj0lc6sV/qpzrc1N5DC6i1VRn/HyX4qdPaiEFbn54VjQBEU341pvjz7Dv3n6P" crossorigin="anonymous"></script>
    <script type="text/javascript" src="]] print(http_prefix) print[[/js/deps.min.js?]] print(startup_epoch) print[["></script>
    <script type="text/javascript" src="]] print(http_prefix) print[[/js/push.min.js?]] print(startup_epoch) print[["></script>
    <script type="text/javascript" src="]] print(http_prefix) print[[/js/ntop.min.js?]] print(startup_epoch) print[["></script>
    <script type="text/javascript" src="]] print(http_prefix) print[[/tempusdominus/js/tempusdominus-bootstrap-4.js?]] print(startup_epoch) print[["></script>
  </head>
<body>

  <div class="container-narrow">
]]
end

-- #################################

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
    <link href="]] print(http_prefix) print[[/bootstrap-4.4.0-dist/css/bootstrap.min.css" rel="stylesheet" integrity="sha384-SI27wrMjH3ZZ89r4o+fGIJtnzkAnFs3E4qz9DIYioCQ5l9Rd/7UAa8DHcaL8jkWt" crossorigin="anonymous">
    <link href="]] print(http_prefix) print[[/fontawesome-free-5.11.2-web/css/fontawesome.css" rel="stylesheet">
    <link href="]] print(http_prefix) print[[/fontawesome-free-5.11.2-web/css/brands.css" rel="stylesheet">
    <link href="]] print(http_prefix) print[[/fontawesome-free-5.11.2-web/css/solid.css" rel="stylesheet">
    <script type="text/javascript" src="]] print(http_prefix) print[[/js/jquery_bootstrap.min.js?]] print(startup_epoch) print[["></script>
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

function page_utils.print_navbar(title, base_url, items_table)
   print[[

<nav class="navbar navbar-expand-lg navbar-light bg-light">
  <a class="navbar-brand" href="#"><small>]] print(title) print[[</small></a>
  <button class="navbar-toggler" type="button" data-toggle="collapse" data-target="#navbarNav" aria-controls="navbarNav" aria-expanded="false" aria-label="Toggle navigation">
    <span class="navbar-toggler-icon"></span>
  </button>
  <div class="collapse navbar-collapse" id="navbarNav">
    <ul class="navbar-nav">]]

   for _, item in ipairs(items_table) do
      if not item["hidden"] then
	 local badge = ''
	 if tonumber(item["badge_num"]) and tonumber(item["badge_num"]) > 0 then
	    badge = string.format(' <span class="badge badge-pill badge-secondary" style="float:right;margin-bottom:-10px;">%u</span>', tonumber(item["badge_num"]))

	 end

	 if item["active"] then
	    print(string.format("<li class=\"nav-item active\">%s<a class=\"nav-link active\" href=\"#\">%s</a></li>", badge, item["label"]))
	 else
	    print(string.format("<li class=\"nav-item\">%s<a class=\"nav-link\" href=\"%s&page=%s\">%s</a></li>", badge, base_url, item["page_name"], item["label"]))
	 end
      end
   end
   print[[
    </ul>
  </div>
</nav>
<p>
]]
end

-- #################################

return page_utils

