--
-- (C) 2014-19 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
local alerts_api = require "alerts_api"
local format_utils = require "format_utils"

local flow_callbacks_utils = {}

-- #################################

function flow_callbacks_utils.print_callbacks_config()
   local tab = _GET["tab"] or "application_detected"
   local descr = alerts_api.load_flow_check_modules(entity_type)

   print [[

<br>
<table id="callbacks_config_table" class="table table-bordered table-striped" style="clear: both">
<thead></thead>
<tbody>]]
   print[[<tr>]]
   print[[<th colspan=2></th>]]
   print[[<th colspan=4  style="text-align: center;">]] print(i18n("flow_callbacks.callback_latest_run")) print[[</th>]]
   print[[</tr>]]

   print[[<tr>]]
   print[[<th width=30%>]] print(i18n("flow_callbacks.callback")) print[[</th>]]
   print[[<th>]] print(i18n("flow_callbacks.callback_config")) print[[</th>]]
   print[[<th>]] print(i18n("flow_callbacks.callback_function")) print[[</th>]]
   print[[<th style="text-align: center;">]] print(i18n("flow_callbacks.callback_function_duration")) print[[</th>]]
   print[[<th style="text-align: center;">]] print(i18n("flow_callbacks.callback_function_num_flows")) print[[</th>]]
   print[[<th style="text-align: right;">]] print(i18n("flow_callbacks.callback_function_throughput")) print[[</th>]]
   print[[</tr>]]

   print[[<form id="flow-callbacks-config" class="form-inline" method="post">]]
   print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')

   local has_modules = false

   for _, check_module in pairsByKeys(descr["all"], asc) do
      if check_module.gui then
	 if not has_modules then
	    has_modules = true
	 end

	 local rowspan = 1
	 if check_module.benchmark and table.len(check_module.benchmark) > 0 then
	    rowspan = table.len(check_module.benchmark)
	 end


	 print("<tr><td rowspan="..rowspan.."><b>".. i18n(check_module.gui.i18n_title) .."</b><br>")
	 print("<small>"..i18n(check_module.gui.i18n_description)..".</small>\n")

	 print("</td><td rowspan="..rowspan..">")
	 print(check_module.gui.input_builder(check_module))
	 print("</td>")

	 print("<td>")

	 local num = 1
	 if check_module.benchmark and table.len(check_module.benchmark) > 0 then
	    for mod_fn, mod_benchmark in pairsByKeys(check_module.benchmark, asc) do
	       local avg_fps = mod_benchmark["num"] / mod_benchmark["elapsed"]

	       if avg_fps ~= avg_fps or not avg_fps or avg_fps < 0.01 then
		  avg_fps = "< 0.01"
	       else
		  avg_fps = format_utils.formatValue(format_utils.round(avg_fps, 0))
	       end

	       local trtd, slash_tdtr = "<tr><td>", "</td></tr>"
	       if num == 1 then
		  trtd = ''
	       end

	       print(string.format("%s %s </td><td align='center'>%s</td><td align='center'>%s</td><td align='right'>%s %s<br>%s",
				   trtd,
				   mod_fn,
				   format_utils.secondsToTime(mod_benchmark["elapsed"]),
				   format_utils.formatValue(mod_benchmark["num"]),
				   avg_fps,
				   i18n("flow_callbacks.callback_elapsed_time_avg"),
				   slash_tdtr))

	       num = num + 1
	    end
	 else
	    print("</td><td></td><td></td><td></td></tr>")
	 end
      end
   end

   if not has_modules then
      print("<tr><td colspan=6><i>"..i18n("flow_callbacks.no_callbacks_defined")..".</i></td></tr>")
   end

   print[[</tbody></table>]]

   if has_modules then
      print[[<button class="btn btn-primary" style="float:right; margin-right:1em;" type="submit">]] print(i18n("save_configuration")) print[[</button>]]
   end

   print[[</form>]]

   print[[
<script>
</script>
]]

   print("<div style='margin-top:4em;'><b>" .. i18n("flow_callbacks.notes") .. ":</b><ul>")

   print("<li>" .. i18n("flow_callbacks.note_flow_lifecycle") .. "</li>")

   print("</ul></div>")
end

return flow_callbacks_utils
