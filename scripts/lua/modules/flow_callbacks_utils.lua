--
-- (C) 2014-19 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
local alerts_api = require "alerts_api"

local CALLBACK_EVENTS = {
   application_detected = {
      cb = "protocolDetected",
      i18n = "flow_callbacks.application_detected"},
   status_changed = {
      cb = "statusChanged",
      i18n = "flow_callbacks.status_changed",},
   periodic_update = {
      cb = "periodicUpdate",
      i18n = "flow_callbacks.periodic_update"},
   idle = {
      cb = "idle",
      i18n = "flow_callbacks.idle"}
}

local flow_callbacks_utils = {}

-- #################################

local function print_callbacks_config_tab(tab, tab_contents, selected_tab)
   if tab == selected_tab then
      print("\t<li class=active>") else print("\t<li>")
   end

   print("<a href=\""..ntop.getHttpPrefix().."/lua/if_stats.lua?page=flow_callbacks&tab="..tab)
   for param, value in pairs(page_params or {}) do
      print("&"..param.."="..value)
   end

   print("\">"..i18n(tab_contents.i18n).."</a></li>\n")
end

-- #################################

function flow_callbacks_utils.print_callbacks_config()
   local tab = _GET["tab"] or "application_detected"
   local descr = alerts_api.load_flow_check_modules(entity_type)

   print('<ul class="nav nav-tabs">')

   for cur_k, cur_tab in pairsByKeys(CALLBACK_EVENTS or {}) do
      print_callbacks_config_tab(cur_k, cur_tab, tab)
   end

   print('</ul>')

   print [[

<br>
<table id="callbacks_config_table" class="table table-bordered table-striped" style="clear: both">
<thead></thead>
<tbody>]]
   print[[<tr><th width=30%>]] print(i18n("flow_callbacks.callback")) print[[</th><th>]] print(i18n("flow_callbacks.callback_config"))
   print[[</th></tr>]]
   print[[<form method="post">]]
   print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')

   local has_modules = false
   for _, check_module in pairsByKeys(descr, asc) do
      if check_module[CALLBACK_EVENTS[tab]["cb"]] and check_module.gui then
	 if not has_modules then
	    has_modules = true
	 end

         print("<tr><td><b>".. i18n(check_module.gui.i18n_title) .."</b><br>")
         print("<small>"..i18n(check_module.gui.i18n_description)..".</small>\n")

	 print("</td><td>")

	 print(check_module.gui.input_builder(check_module.gui, nil --[[ current key --]], nil --[[ current val for key --]]))

	 print("</td></tr>")
      end
   end

   if not has_modules then
      print("<tr><td colspan=2><i>"..i18n("flow_callbacks.no_callbacks_defined", {cb = CALLBACK_EVENTS[tab]["cb"]})..".</i></td></tr>")
   end
   
   print[[</form>]]
   print[[</tbody></table>]]
end

return flow_callbacks_utils
