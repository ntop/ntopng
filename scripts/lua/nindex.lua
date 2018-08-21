--
-- (C) 2013-18 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

sendHTTPContentTypeHeader('text/html')

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

select     = _GET["select_clause"]
where      = _GET["where_clause"]
maxhits    = _GET["maxhits_clause"]
begin_time = _GET["begin_time_clause"]
end_time   = _GET["end_time_clause"]

if(_GET["flow_clause"] == "aggregated_flows") then
   aggregated_flows = true
else
   aggregated_flows = false
end

if(where == nil)  then
   where = ""
end

if((select == nil) or (select == "")) then
   select = "*"
end

if((maxhits == nil) or (maxhits == "")) then
   maxhits = "10"
end

if((begin_time == nil) or (begin_time == "")) then
   begin_time = "now-1h"
end

if((end_time == nil) or (end_time == "")) then
   end_time = "now"
end

-- Zap spaces
select = select:gsub("%s+", "")
-- where = where:gsub("%s+", "")


print('<p align=right>[ <A HREF="nindex_topk.lua')

if(_GET["where_clause"] ~= nil) then
   print("?where_clause="..urlencode(_GET["where_clause"]))
end

print('">TopK</A> ]</P>')

print [[
  <form method=get action=nindex.lua>

  <fieldset class="form-group"> 
  <div class="form-group form-row">
    <label for="inputSelect3" class="col-sm-2 col-form-label">Select</label>
    <div class="col-sm-10">
      <input name="select_clause" type="text" class="form-control" id="exampleInputSelect1" aria-describedby="selectHelp" placeholder="Enter select term" value="]] print(select) print [[">
      <small id="selectHelp" class="form-text text-muted">Use * for all fields or field1,field2....</small>
    </div>
  </div>
 </fieldset>

  <fieldset class="form-group">
  <div class="form-group form-row">
    <label for="inputWhere3" class="col-sm-2 col-form-label">Where</label>
    <div class="col-sm-10  col-xs-2">
      <input name="where_clause" type="text" class="form-control" id="exampleInputWhere1" aria-describedby="whereHelp" placeholder="Enter where term" value="]] print(where) print [[">
      <small id="whereHelp" class="form-text text-muted">Use field &lt;operatore&gt; where operator could be &lt;, &gt;, =, !=</small>
    </div>
  </div>
  </fieldset>

  <fieldset class="form-group">
    <div class="form-group form-row">
      <label for="inputFlowDB" class="col-sm-2 col-form-label">Time Range</label> 
      <div class="col-sm-10">
        <div class="form-check col-xs-2">
          <label> Begin Time </label>
          <input class="form-control  col-xs-2" type="text" name="begin_time_clause" value="]] print(begin_time) print [[">
        </div>
        <div class="form-check  col-xs-2">
          <label> End Time </label>
          <input class="form-control" type="text" name="end_time_clause" value="]] print(end_time) print [[">
        </div>
      </div>
    </div>
  </fieldset>


  <fieldset class="form-group">
    <div class="form-group form-row">
      <label for="inputFlowDB" class="col-sm-2 col-form-label">Database</label> 
      <div class="col-sm-10">
        <div class="form-check">
          <input class="form-check-input" type="radio" name="flow_clause" id="gridRadios1" value="flows" ]] if(aggregated_flows == false) then print("checked") end print [[>
          <label class="form-check-label" for="gridRadios1">Flows</label>
        </div>
        <div class="form-check">
          <input class="form-check-input" type="radio" name="flow_clause" id="gridRadios2" value="aggregated_flows" ]] if(aggregated_flows == true) then print("checked") end print [[>
          <label class="form-check-label" for="gridRadios2">Aggregated Flows</label>
        </div>
      </div>
    </div>
  </fieldset>

  <fieldset class="form-group">
  <div class="form-group">
    <label for="inputMaxhits3" class="col-sm-2 col-form-label">Max Results</label>
    <div class="form-check col-xs-2">
      <select name="maxhits_clause" class="form-control" id="exampleFormControlSelect1" id="exampleInputMaxhits1" aria-describedby="maxhitsHelp" placeholder="Enter maxhits condition">
        <option]] if(maxhits == "10") then print(" selected") end print [[>10</option>
        <option]] if(maxhits == "100") then print(" selected") end print [[>100</option>
        <option]] if(maxhits == "1000") then print(" selected") end print [[>1000</option>
      </select>
    </div>
  </div>
  </fieldset>




  <button type="submit" class="btn btn-primary">Run query</button>
</form>
]]


res = interface.nIndexSelect(aggregated_flows, begin_time, end_time, select, where, 0, tonumber(maxhits))

-- tprint(res)

if(res) then
   if(res.info.duration == 0) then
      res.info.duration = " &lt; 1"
   end
   
   print("<p><small>Query perfomed in "..res.info.duration.." msec</small><br>")
   
   print("<p><table class=\"table table-bordered table-striped\">\n")

   print("<tr>")
   for k, row in pairs(res.columns) do      
      print("<th>"..row.."</th>")     
   end
   print("</tr>\n")
   
   for k, row in pairs(res.results) do
      print("<tr>")
      -- print("<tr><th>"..k.."</th>")
      
      for k, v in pairs(row) do
	 print("<td>"..v.."</td>")
      end
      
      print("</tr>\n")
   end
   
   print("</table>\n")
else
   print("No result")
end
