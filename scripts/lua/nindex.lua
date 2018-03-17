--
-- (C) 2013-17 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

sendHTTPContentTypeHeader('text/html')

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

select  = _GET["select_clause"]
where   = _GET["where_clause"]
maxhits = _GET["maxhits_clause"]

if(_GET["flow_clause"] == "flows") then
   aggregated_flows = false
else
   aggregated_flows = true
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

-- Zap spaces
select = select:gsub("%s+", "")
where = where:gsub("%s+", "")

print [[
  <form method=get action=nindex.lua>

  <div class="form-group row">
    <label for="inputSelect3" class="col-sm-2 col-form-label">Select</label>
    <div class="col-sm-10">
      <input name="select_clause" type="text" class="form-control" id="exampleInputSelect1" aria-describedby="selectHelp" placeholder="Enter select term" value="]] print(select) print [[">
      <small id="selectHelp" class="form-text text-muted">Use * for all fields or field1,field2....</small>
    </div>
  </div>

  <div class="form-group row">
    <label for="inputWhere3" class="col-sm-2 col-form-label">Where</label>
    <div class="col-sm-10">
      <input name="where_clause" type="text" class="form-control" id="exampleInputWhere1" aria-describedby="whereHelp" placeholder="Enter where term" value="]] print(where) print [[">
      <small id="whereHelp" class="form-text text-muted">Use field &lt;operatore&gt; where operator could be &lt;, &gt;, =, !=</small>
    </div>
  </div>

  <div class="form-group row">
    <label for="inputMaxhits3" class="col-sm-2 col-form-label">Max Results</label>
    <div class="col-sm-10">
      <select name="maxhits_clause" class="form-control" id="exampleFormControlSelect1" id="exampleInputMaxhits1" aria-describedby="maxhitsHelp" placeholder="Enter maxhits condition">
        <option>10</option>
        <option>100</option>
        <option>1000</option>
      </select>
    </div>
  </div>

  <fieldset class="form-group">
    <div class="row">
<label for="inputMaxhits3" class="col-sm-2 col-form-label">Max Results</label> 
      <div class="col-sm-10">
        <div class="form-check">
          <input class="form-check-input" type="radio" name="flow_clause" id="gridRadios1" value="flows" checked>
          <label class="form-check-label" for="gridRadios1">
            Flows
          </label>
        </div>
        <div class="form-check">
          <input class="form-check-input" type="radio" name="flow_clause" id="gridRadios2" value="aggregated_flows">
          <label class="form-check-label" for="gridRadios2">
            Aggregated Flows
          </label>
        </div>
      </div>
    </div>
  </fieldset>



  <button type="submit" class="btn btn-primary">Run query</button>
</form>
]]


res = interface.nIndexSelect(aggregated_flows, "now-2h", "now", select, where, 0, tonumber(maxhits))

--tprint(res)

if(res) then
   print("<p><table class=\"table table-bordered table-striped\">\n")
   
   for k, row in pairs(res) do
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
