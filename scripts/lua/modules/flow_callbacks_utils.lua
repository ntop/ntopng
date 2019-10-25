--
-- (C) 2014-19 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
local alerts_api = require "alerts_api"
local format_utils = require "format_utils"
local user_scripts = require "user_scripts"
local ts_utils = require("ts_utils")

local flow_callbacks_utils = {}

local ifid = interface.getId()

-- ##############################################

local function print_callbacks_config_table(descr, expert_view)
   print[[<table id="callbacks_config_table" class="table table-bordered table-striped">]]
   print[[<tr>]]
   print[[<th width=40%>]] print(i18n("flow_callbacks.callback")) print[[</th>]]
   print[[<th style="text-align: center;" width="5%">]] print(i18n("chart")) print[[</th>]]
   print[[<th width="20%">]] print(i18n("flow_callbacks.callback_config")) print[[</th>]]
   if(expert_view) then
      print[[<th>]] print(i18n("flow_callbacks.callback_function")) print[[</th>]]
   end
   print[[<th style="text-align: center;">]] print(i18n("flow_callbacks.last_duration")) print[[</th>]]
   print[[<th style="text-align: center;">]] print(i18n("flow_callbacks.last_num_calls")) print[[</th>]]
   print[[<th style="text-align: center;">]] print(i18n("flow_callbacks.last_calls_per_sec")) print[[</th>]]
   print[[</tr>]]

   print[[<form id="flow-callbacks-config" class="form-inline" method="post">]]
   print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')

   for mod_k, user_script in pairsByKeys(descr.modules, asc) do
      local hooks_benchmarks = user_script.benchmark or {}
      local num_hooks = table.len(hooks_benchmarks)
      local title
      local description
      local rowspan = ""

      if(user_script.gui) then
	 title = i18n(user_script.gui.i18n_title) or user_script.gui.i18n_title
	 description = i18n(user_script.gui.i18n_description) or user_script.gui.i18n_description
      else
	 title = user_script.key
	 description = ""
      end

      if(expert_view) then
	 rowspan = string.format(' rowspan="%d"', num_hooks)
      end

      print("<tr><td ".. rowspan .."><b>".. title .."</b><br>")
      print("<small>"..description..".</small></td>")

      print("<td ".. rowspan .." class='text-center'>")

      if(ts_utils.exists("user_script:duration", {ifid=ifid, user_script=mod_k, subdir="flow"})) then
	 print('<a href="'.. ntop.getHttpPrefix() ..'/lua/user_script_details.lua?ifid='..ifid..'&user_script='..mod_k..'&subdir=flow"><i class="fa fa-area-chart fa-lg" data-original-title="" title=""></i></a>')
      end

      print("</td>")

      print("<td ".. rowspan ..">")
      if(user_script.gui and user_script.gui.input_builder) then
	 print(user_script.gui.input_builder(user_script))
      else
	 print('<a href="'.. ntop.getHttpPrefix() ..'/lua/admin/prefs.lua?tab=alerts"><i class="fa fa-flask fa-lg"></i></a>')
      end
      print("</td>")

      if(expert_view) then
	 local ctr = 0

	 for mod_fn, mod_benchmark in pairsByKeys(hooks_benchmarks, asc) do
	    print("<td>".. mod_fn .."</td>")
	    print("<td align='center'>".. format_utils.secondsToTime(mod_benchmark["tot_elapsed"]) .."</td>")
	    print("<td align='center'>".. format_utils.formatValue(mod_benchmark["tot_num_calls"]) .."</td>")
	    print("<td align='center'>".. format_utils.formatValue(round(mod_benchmark["avg_speed"], 0)) .."</td>")

	    ctr = ctr + 1

	    if(ctr ~= num_hooks) then
	       print("</tr><tr>")
	    end
	 end
      else
	 -- Accumulate the stats for each hook
	 local total_duration = 0
	 local num_calls = 0
	 local sum_avg_speed = 0
	 local count_avg_speed = 0

	 for mod_fn, mod_benchmark in pairsByKeys(user_script.benchmark or {}, asc) do
	    total_duration = total_duration + mod_benchmark["tot_elapsed"]
	    num_calls = num_calls + mod_benchmark["tot_num_calls"]
	    sum_avg_speed = sum_avg_speed + mod_benchmark["avg_speed"]
	    count_avg_speed = count_avg_speed + 1
	 end

	 local avg_speed = (sum_avg_speed / count_avg_speed)

	 print("<td align='center'>".. format_utils.secondsToTime(total_duration) .."</td>")
	 print("<td align='center'>".. format_utils.formatValue(num_calls) .."</td>")
	 print("<td align='center'>".. format_utils.formatValue(round(avg_speed, 0)) .."</td>")
      end
   end

   print("</tr>")
   print[[</table>]]
end

-- #################################

function flow_callbacks_utils.print_callbacks_config()
   local show_advanced_prefs = false

   if(_GET["show_advanced_prefs"] == "1") then
      show_advanced_prefs = true
   end

   local ifid = interface.getId()
   local descr = user_scripts.load(user_scripts.script_types.flow, ifid, "flow", nil, true --[[ also return disabled ]])

   print [[

<br>]]

   if table.len(_POST) > 0 then
      for mod_key, user_script in pairs(descr.modules) do
         local pref_key = "enabled_" .. mod_key
         local val = _POST[pref_key]

         if(val ~= nil) then
            if(val == "on") then
               user_scripts.enableModule(ifid, "flow", mod_key)
               user_script.enabled = true
            else
               user_scripts.disableModule(ifid, "flow", mod_key)
               user_script.enabled = false
            end
         end
      end
   end

   print_callbacks_config_table(descr, show_advanced_prefs)

   print[[<input type=hidden name="show_advanced_prefs" value="]]if show_advanced_prefs then print("true") else print("false") end print[["/>]]
   print[[<button class="btn btn-primary" style="float:right; margin-right:1em;" type="submit">]] print(i18n("save_configuration")) print[[</button>]]
   print[[</form>]]
   print[[

<form>
  <input type=hidden name="page" value="callbacks" />
  <input type=hidden name="tab" value="flows" />
  <input type=hidden name="ifid" value="]] print(string.format("%d", ifid)) print[[" />
  <input type=hidden name="show_advanced_prefs" value="]]if show_advanced_prefs then print("0") else print("1") end print[["/>

  <div class="btn-group btn-toggle">
]]

   local cls_on      = "btn btn-sm"
   local cls_off     = cls_on

   if show_advanced_prefs then
      cls_on  = cls_on..' btn-primary active'
      cls_off = cls_off..' btn-default'
   else
      cls_on = cls_on..' btn-default'
      cls_off = cls_off..' btn-primary active'
   end

   print('<button type="submit" class="'..cls_on..'">'..i18n("prefs.expert_view")..'</button>')
   print('<button type="submit" class="'..cls_off..'">'..i18n("prefs.simple_view")..'</button>')

   print[[
  </div>
</form>

<script>
</script>
]]

   print("<div style='margin-top:4em;'><b>" .. i18n("flow_callbacks.notes") .. ":</b><ul>")

   print("<li>" .. i18n("flow_callbacks.note_flow_lifecycle") .. "</li>")

   print("<li>" .. i18n("flow_callbacks.note_create_custom_scripts", {url = "https://github.com/ntop/ntopng/blob/dev/doc/README.developers.flow_lua_callbacks.md"}) .. "</li>")
   print("<li>" .. i18n("flow_callbacks.note_add_custom_scripts", {url = ntop.getHttpPrefix().."/lua/directories.lua", product=ntop.getInfo()["product"]}) .. "</li>")

   print("</ul></div>")
end

return flow_callbacks_utils
