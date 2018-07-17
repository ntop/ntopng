--
-- (C) 2017-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

if(ntop.isPro()) then
    package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
    require "snmp_utils"
    shaper_utils = require "shaper_utils"
end

require "lua_utils"
require "graph_utils"
require "alert_utils"
local host_pools_utils = require "host_pools_utils"
local template = require "template_utils"
local ts_utils = require "ts_utils"

local have_nedge = ntop.isnEdge()

local pool_id     = _GET["pool"]
local page        = _GET["page"]

if (not ntop.isPro()) then
  return
end

interface.select(ifname)
local ifstats = interface.getStats()
local ifId = ifstats.id
local pool_name = host_pools_utils.getPoolName(ifId, pool_id)
local username = host_pools_utils.poolIdToUsername(pool_id)

if _POST["reset_quotas"] ~= nil then
  host_pools_utils.resetPoolsQuotas(ifId, tonumber(pool_id))
end

sendHTTPContentTypeHeader('text/html')
ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

local base_url = ntop.getHttpPrefix()..'/lua/pool_details.lua'
local page_params = {}

page_params["ifid"] = ifId
page_params["pool"] = pool_id
page_params["page"] = page

if(pool_id == nil) then
   print("<div class=\"alert alert alert-danger\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png> "
	    ..i18n("pool_details.pool_parameter_missing_message")
	    .."</div>")
    return
end

print [[
<div class="bs-docs-example">
  <nav class="navbar navbar-default" role="navigation">
    <div class="navbar-collapse collapse">
      <ul class="nav navbar-nav">
]]

print("<li><a href=\"#\">"
	 ..i18n(ternary(have_nedge, "nedge.user", "pool_details.host_pool"))
	 ..": "..pool_name.."</A> </li>")

local go_page_params = table.clone(page_params)

if page == "historical" then
  print("<li class=\"active\"><a href=\"#\"><i class='fa fa-area-chart fa-lg'></i>\n")
else
  go_page_params["page"] = "historical"
  print("<li><a href=\""..getPageUrl(base_url, go_page_params).."\"><i class='fa fa-area-chart fa-lg'></i>\n")
end

if (ntop.isEnterprise() or ntop.isnEdge()) and ifstats.inline and pool_id ~= host_pools_utils.DEFAULT_POOL_ID then
  if page == "quotas" then
    print("<li class=\"active\"><a href=\"#\">"..i18n("quotas").."</i>\n")
  else
    go_page_params["page"] = "quotas"
    print("<li><a href=\""..getPageUrl(base_url, go_page_params).."\">"..i18n("quotas").."\n")
  end
end

print [[
<li><a href="javascript:history.go(-1)"><i class='fa fa-reply'></i></a></li>
      </ul>
    </div>
  </nav>
</div>
]]

local pools_stats = interface.getHostPoolsStats()
local pool_stats = pools_stats and pools_stats[tonumber(pool_id)]

if (ntop.isEnterprise() or ntop.isnEdge()) and pool_id ~= host_pools_utils.DEFAULT_POOL_ID and ifstats.inline and (page == "quotas") and (pool_stats ~= nil) then
  print(
    template.gen("modal_confirm_dialog.html", {
      dialog={
        id      = "reset_quotas_dialog",
        action  = "$('#reset_quotas_form').submit()",
        title   = i18n("host_pools.reset_quotas"),
        message = i18n("host_pools.confirm_reset_pool_quotas", {pool=pool_name}),
        confirm = i18n("host_pools.reset_quotas"),
      }
    })
  )

  print[[<form id="reset_quotas_form" method="POST">
    <input name="csrf" value="]] print(ntop.getRandomCSRFValue()) print[[" type="hidden"/>
    <input name="reset_quotas" value="" type="hidden" />
  </form>]]

  host_pools_utils.printQuotas(pool_id, nil, page_params)

  print[[
  <button class="btn btn-default" data-toggle="modal" data-target="#reset_quotas_dialog" style="float:right;">]] print(i18n("host_pools.reset_quotas")) print[[</button>]]
  if ntop.isnEdge() then
    print[[<a href="]] print(ntop.getHttpPrefix()) print[[/lua/pro/nedge/admin/nf_edit_user.lua?page=categories&username=]] print(username)
    print[["><button class="btn btn-default" type="button" style="float:right; margin-right:1em;">]] print(i18n("nedge.edit_quotas")) print[[</button></a>]]
  end
  print[[<br/><br/>]]
  
elseif page == "historical" then
  if(not ts_utils.exists("host_pool:traffic", {ifid=ifId, pool=pool_id})) then
    print("<div class=\"alert alert alert-danger\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png> "..i18n("pool_details.no_available_data_for_host_pool_message",{pool_name=pool_name}))
    print(" "..i18n("pool_details.host_pool_timeseries_enable_message",{url=ntop.getHttpPrefix().."/lua/admin/prefs.lua?tab=on_disk_ts",icon_flask="<i class=\"fa fa-flask\"></i>"})..'</div>')
  else
    local schema = _GET["ts_schema"] or "host_pool:traffic"
    local selected_epoch = _GET["epoch"] or ""
    local url = getPageUrl(base_url, page_params)

    local tags = {
      ifid = ifId,
      pool = pool_id,
      protocol = _GET["protocol"],
    }

    drawGraphs(ifId, schema, tags, _GET["zoom"], url, selected_epoch, {
      top_protocols = "top:host_pool:ndpi",
      timeseries = {
        {schema="host_pool:traffic",           label=i18n("traffic")},
        {schema="host_pool:blocked_flows",     label=i18n("graphs.blocked_flows")},
      },
    })
  end
end

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
