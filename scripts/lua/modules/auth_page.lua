--
-- (C) 2013-26 - ntop.org
--
-- Frame of the pages served without a session (login, logout): brand panel with the
-- animated scene (pro/http_src/auth.js, dist/auth.js) and the panel of the page content.
-- The form is plain Bootstrap (dark theme) like the rest of ntopng; dist/auth.js has the CSS of the brand panel.
--

local json = require "dkjson"

local auth_page = {}

-- The scenes of the animation, in the order of the titles
local SCENE_TITLES = { "login.scene_probes", "login.scene_flows", "login.scene_attack" }

-- Opens the page, up to the content panel: the caller prints its content, then auth_page.print_end()
-- context: extra data for dist/auth.js (read as JSON from #auth-context)
function auth_page.print_begin(title, context)
  local dirs = ntop.getDirs()
  local info = ntop.getInfo()
  local http_prefix = ntop.getHttpPrefix()
  local epoch = ntop.getStaticFileEpoch() .. ""

  -- Custom favicon in pro/nEdge
  local favicon_url = http_prefix .. "/favicon.ico"
  if ((ntop.isPro and ntop.isPro()) or (ntop.isnEdge and ntop.isnEdge()))
     and ntop.exists(dirs.installdir .. "/httpdocs/img/custom_favicon.ico") then
    favicon_url = http_prefix .. "/img/custom_favicon.ico"
  end

  context = context or {}
  context.alert_text = i18n("login.flow_alert")
  context.score_text = i18n("login.flow_score")
  context.scene_titles = {}
  for i, key in ipairs(SCENE_TITLES) do
    context.scene_titles[i] = i18n(key)
  end
  -- Inside a <script> element: "<" escaped so that a "</script>" in a value cannot close it
  local context_json = (json.encode(context):gsub("<", "\\u003c"))

  print([[<!DOCTYPE html>
<html data-theme="dark" data-bs-theme="dark">
<head>
  <meta charset="utf-8">
  <title>]] .. title .. " - " .. info.product .. [[</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <link href="]] .. http_prefix .. "/dist/third-party.css?" .. epoch .. [[" rel="stylesheet">
  <link href="]] .. http_prefix .. "/dist/ntopng.css?" .. epoch .. [[" rel="stylesheet">
  <link href="]] .. http_prefix .. "/dist/white-mode.css?" .. epoch .. [[" rel="stylesheet">
  <link href="]] .. http_prefix .. "/dist/dark-mode.css?" .. epoch .. [[" rel="stylesheet">
  <link href="]] .. favicon_url .. [[" rel="icon">
  <script type="text/javascript" src="]] .. http_prefix .. "/dist/auth.js?" .. epoch .. [[" defer></script>
</head>
<body class="body dark dark-mode">
  <div class="auth-shell">
    <aside class="auth-brand">
      <div class="auth-brand__logo"><img id="auth-logo" alt="]] .. info.product .. [["></div>
      <svg class="auth-scene" viewBox="0 0 600 400" aria-hidden="true"></svg>
      <ul class="auth-feed" id="auth-feed" aria-hidden="true"></ul>
      <h1 class="auth-brand__title" id="auth-title"></h1>
      <div class="auth-brand__dots"><span></span><span></span><span></span></div>
    </aside>
    <main class="auth-panel">
      <div class="auth-panel__inner">
]])

  -- Printed here so that auth.js finds it when it runs
  print([[<script type="application/json" id="auth-context">]] .. context_json .. [[</script>]])
end

function auth_page.print_end()
  print([[
      </div>
    </main>
  </div>
</body>
</html>
]])
end

return auth_page
