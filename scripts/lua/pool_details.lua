--
-- (C) 2017-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path

if(ntop.isPro()) then
    package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
    local snmp_utils = require "snmp_utils"
    shaper_utils = require "shaper_utils"
end

require "lua_utils"
local graph_utils = require "graph_utils"
local alert_utils = require "alert_utils"
local page_utils = require("page_utils")

local host_pools_nedge
if ntop.isnEdge() then
   host_pools_nedge = require "host_pools_nedge"
end
local host_pools = require "host_pools"
-- Instantiate host pools
local host_pools_instance = host_pools:create()

local template = require "template_utils"

local have_nedge = ntop.isnEdge()

local pool_id     = _GET["pool"]
local page        = _GET["page"]

if (not ntop.isPro()) then
  return
end

interface.select(ifname)
local ifstats = interface.getStats()
local ifId = ifstats.id
local pool_name = host_pools_instance:get_pool_name(pool_id)


if ntop.isnEdge() then
   if _POST["reset_quotas"] ~= nil then
      host_pools_nedge.resetPoolsQuotas(tonumber(pool_id))
   end
end

sendHTTPContentTypeHeader('text/html')


page_utils.set_active_menu_entry(page_utils.menu_entries.host_pools)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

if(pool_id == nil) then
   print("<div class=\"alert alert alert-danger\"><i class='fas fa-exclamation-triangle fa-lg fa-ntopng-warning'></i> "
	    ..i18n("pool_details.pool_parameter_missing_message")
	    .."</div>")
   dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
   return
end

local base_url = ntop.getHttpPrefix()..'/lua/pool_details.lua?pool='..pool_id
local page_params = {}

page_params["ifid"] = ifId
page_params["pool"] = pool_id
page_params["page"] = page

local title = i18n(ternary(have_nedge, "nedge.user", "pool_details.host_pool"))..": "..pool_name

   page_utils.print_navbar(title, base_url,
			   {
			      {
				 active = page == "historical" or not page,
				 page_name = "historical",
				 label = "<i class='fas fa-lg fa-chart-area'></i>",
			      },
			      {
				 hidden = not ntop.isEnterpriseM() or not ntop.isnEdge() or not ifstats or pool_id == host_pools_instance.DEFAULT_POOL_ID,
				 active = page == "quotas",
				 page_name = "quotas",
				 label = i18n("quotas"),
			      },
			   }
   )

local pools_stats = interface.getHostPoolsStats()
local pool_stats = pools_stats and pools_stats[tonumber(pool_id)]

if (ntop.isEnterpriseM() or ntop.isnEdge()) and pool_id ~= host_pools_instance.DEFAULT_POOL_ID and ifstats.inline and (page == "quotas") and (pool_stats ~= nil) then
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

  host_pools_nedge.printQuotas(pool_id, nil, page_params)

  print[[
  <button class="btn btn-secondary" data-bs-toggle="modal" data-target="#reset_quotas_dialog" style="float:right;">]] print(i18n("host_pools.reset_quotas")) print[[</button>]]
  if ntop.isnEdge() then
    local username = host_pools_nedge.poolIdToUsername(pool_id)
    print[[<a href="]] print(ntop.getHttpPrefix()) print[[/lua/pro/nedge/admin/nf_edit_user.lua?page=categories&username=]] print(username)
    print[["><button class="btn btn-secondary" type="button" style="float:right; margin-right:1em;">]] print(i18n("nedge.edit_quotas")) print[[</button></a>]]
  end
  print[[<br/><br/>]]
  
elseif page == "historical" then
  if(not areHostPoolsTimeseriesEnabled(ifId)) then
    print("<div class=\"alert alert alert-danger\"><i class='fas fa-exclamation-triangle fa-lg fa-ntopng-warning'></i> "..i18n("pool_details.no_available_data_for_host_pool_message",{pool_name=pool_name}))
    print(" "..i18n("pool_details.host_pool_timeseries_enable_message",{url=ntop.getHttpPrefix().."/lua/admin/prefs.lua?tab=on_disk_ts",icon_flask="<i class=\"fas fa-flask\"></i>"})..'</div>')
  else
    local schema = _GET["ts_schema"] or "host_pool:traffic"
    local selected_epoch = _GET["epoch"] or ""
    local url = getPageUrl(base_url, page_params)

    local tags = {
      ifid = ifId,
      pool = pool_id,
      protocol = _GET["protocol"],
    }

    graph_utils.drawGraphs(ifId, schema, tags, _GET["zoom"], url, selected_epoch, {
      top_protocols = "top:host_pool:ndpi",
      timeseries = {
        {schema="host_pool:traffic",           label=i18n("traffic"), split_directions = true --[[ split RX and TX directions ]]},
        {schema="host_pool:blocked_flows",     label=i18n("graphs.blocked_flows")},
        {schema="host_pool:hosts",             label=i18n("graphs.active_hosts")},
        {schema="host_pool:devices",           label=i18n("graphs.active_devices")},
      },
    })
  end
end

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
