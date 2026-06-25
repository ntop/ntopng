--
-- (C) 2013-26 - ntop.org
-- Modern Vue3 bootstrap for flow details page.
-- Mirrors flow_details.lua GET parameters: flow_key, flow_hash_id
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "flow_utils"

local page_utils     = require "page_utils"
local json           = require "dkjson"
local template_utils = require "template_utils"
local auth           = require "auth"

local page       = _GET["page"]
local flow_key   = _GET["flow_key"]
local flow_hash_id = _GET["flow_hash_id"]

-- Fetch the flow (may be nil if purged/not found)
local flow = interface.findFlowByKeyAndHashId(tonumber(flow_key), tonumber(flow_hash_id))

local ifstats = interface.getStats()
local ifid    = interface.name2id(ifname)

-- Build a page title and canonical URL (mirrors original page)
local label = getFlowLabel(flow, nil, nil, nil, nil, nil, false)
local title = i18n("flow") .. ": " .. (label or "")
local url   = ntop.getHttpPrefix() .. "/lua/flow_details_new.lua"
             .. "?flow_key=" .. (flow_key or "") .. "&flow_hash_id=" .. (flow_hash_id or "")

sendHTTPContentTypeHeader('text/html')

page_utils.print_header_and_set_active_menu_entry(page_utils.menu_entries.flow_details)
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

-- ── Navbar (same tabs as original) ──────────────────────────────────
page_utils.print_navbar(title, url, {
   {
      active    = isEmptyString(page) or page == "overview",
      page_name = "overview",
      label     = "<i class=\"fas fa-lg fa-home\" data-bs-toggle=\"tooltip\" data-bs-placement=\"bottom\" title=\"" ..
                  i18n("overview") .. "\"></i>"
   },
   {
      hidden    = not flow or not (flow.modbus) or not (ntop.isEnterpriseL and ntop.isEnterpriseL()),
      active    = page == "modbus",
      page_name = "modbus",
      label     = i18n("details.label_modbus_server")
   },
   {
      hidden    = not flow or not (flow.s7comm) or not (ntop.isEnterpriseL and ntop.isEnterpriseL()),
      active    = page == "s7comm",
      page_name = "s7comm",
      label     = i18n("details.label_s7comm_server")
   },
   {
      hidden    = not flow or not (flow.profinet) or not (ntop.isEnterpriseL and ntop.isEnterpriseL()),
      active    = page == "profinet",
      page_name = "profinet",
      label     = i18n("details.label_profinet_server")
   },
})

-- ── Overview tab → Vue component ────────────────────────────────────
if isEmptyString(page) or page == "overview" then

   local context = {
      -- Routing parameters (also used by live-poll to /lua/flow_stats.lua)
      flow_key      = flow_key,
      flow_hash_id  = flow_hash_id,
      ifid          = tostring(ifid),

      -- Feature flags
      is_pro          = ntop.isPro and ntop.isPro(),
      is_enterprise_l = ntop.isEnterpriseL and ntop.isEnterpriseL(),
      is_enterprise_m = ntop.isEnterpriseM and ntop.isEnterpriseM(),
      is_nedge        = ntop.isnEdge and ntop.isnEdge(),
      is_inline       = ifstats.inline  or false,
      is_view         = interface.isView(),
      is_viewed       = ifstats.isViewed or false,
      has_vlan        = ifstats.vlan    or false,
      is_admin        = isAdministrator(),

      -- CSRF for drop-flow form
      csrf = ntop.getRandomCSRFValue(),

      -- Throughput display preference ("bps" or "pps")
      throughput_type = getThroughputType(),

      -- Full flow object (nil when not found / purged)
      flow = flow,
   }

   local json_context = json.encode(context)

   template_utils.render("pages/vue_page.template", {
      vue_page_name = "PageFlowDetails",
      page_context  = json_context,
   })

-- ── Industrial-protocol tabs → existing Vue components ──────────────
elseif page == "modbus" then
   local context = {
      flow_key     = flow_key,
      flow_hash_id = flow_hash_id,
      ifid         = tostring(ifid),
      csrf         = ntop.getRandomCSRFValue(),
   }
   template_utils.render("pages/vue_page.template", {
      vue_page_name = "PageFlowDetailsModbus",
      page_context  = json.encode(context),
   })

elseif page == "s7comm" then
   local context = {
      flow_key     = flow_key,
      flow_hash_id = flow_hash_id,
      ifid         = tostring(ifid),
      csrf         = ntop.getRandomCSRFValue(),
   }
   template_utils.render("pages/vue_page.template", {
      vue_page_name = "PageFlowDetailsS7Comm",
      page_context  = json.encode(context),
   })

elseif page == "profinet" then
   local context = {
      flow_key     = flow_key,
      flow_hash_id = flow_hash_id,
      ifid         = tostring(ifid),
      csrf         = ntop.getRandomCSRFValue(),
   }
   template_utils.render("pages/vue_page.template", {
      vue_page_name = "PageFlowDetailsProfinet",
      page_context  = json.encode(context),
   })
end

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
