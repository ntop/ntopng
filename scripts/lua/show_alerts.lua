--
-- (C) 2013-16 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

interface.select(ifname)

sendHTTPHeader('text/html; charset=iso-8859-1')
ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")

if(_GET["csrf"] ~= nil) then
   if(_GET["id_to_delete"] ~= nil) then
      if(_GET["id_to_delete"] == "__all__") then
	 interface.flushAllQueuedAlerts()
	 if _GET["alerts_impl"] == "new" then
	    if _GET["engaged"] == "true" then
	       interface.deleteAlerts(true)
	    else
	       interface.deleteAlerts(false)
	    end
	 end
	 print("")
      else
	 local id_to_delete = tonumber(_GET["id_to_delete"])
	 if id_to_delete ~= nil then
	    interface.deleteQueuedAlert(id_to_delete)
	    if _GET["alerts_impl"] == "new" then
	       if _GET["engaged"] == "true" then
		  interface.deleteAlerts(true, id_to_delete)
	       else
		  interface.deleteAlerts(false, id_to_delete)
	       end
	    end
	 end
      end
   end
end

active_page = "alerts"
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

if ntop.getPrefs().are_alerts_enabled == false then
   print("<div class=\"alert alert alert-warning\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png> Alerts are disabled. Please check the preferences page to enable them.</div>")
--return
else

print [[
      <hr>
      <div id="table-alerts"></div>
	 <script>
	 $("#table-alerts").datatable({
			url: "]]
print (ntop.getHttpPrefix())
print [[/lua/get_alerts_data.lua",
	       showPagination: true,
]]

if(_GET["currentPage"] ~= nil) then print("currentPage: ".._GET["currentPage"]..",\n") end
if(_GET["perPage"] ~= nil)     then print("perPage: ".._GET["perPage"]..",\n") end

print [[
	        title: "Queued Alerts",
      columns: [
	 {
	    title: "Action",
	    field: "column_key",
	    css: { 
	       textAlign: 'center'
	    }
	 },
	 
	 {
	    title: "Date",
	    field: "column_date",
	    css: { 
	       textAlign: 'center'
	    }
	 },
	 {
	    title: "Severity",
	    field: "column_severity",
	    css: { 
	       textAlign: 'center'
	    }
	 },
	 
	 {
	    title: "Type",
	    field: "column_type",
	    css: { 
	       textAlign: 'center'
	    }
	 },

	 {
	    title: "Description",
	    field: "column_msg",
	    css: { 
	       textAlign: 'left'
	    }
	 }
      ]
   });
   </script>
]]

local alert_items = {}

if interface.getNumAlerts(true --[[ engaged --]]) > 0 then
   alert_items[#alert_items + 1] = {["label"] = "Currently Engaged Alerts", ["div-id"] = "table-engaged-alerts",  ["status"] = "engaged", ["date"] = "First Seen"}
end

if interface.getNumAlerts(false --[[ NOT engaged --]]) > 0 then
   alert_items[#alert_items +1] = {["label"] = "Alerts History", ["div-id"] = "table-alerts-history",  ["status"] = "historical", ["date"] = "Time"}
end

alert_items = {} --[[ TEMPORARILY DISABLED --]]

for k, t in ipairs(alert_items) do
   print [[
      <div id="]] print(t["div-id"]) print[["></div>
	 <script>
	 $("#]] print(t["div-id"]) print[[").datatable({
			url: "]]
print (ntop.getHttpPrefix())
print [[/lua/get_alerts_data.lua?alerts_impl=new&alert_status=]] print(t["status"]) print[[",
	       showPagination: true,
]]

if(_GET["currentPage"] ~= nil) then print("currentPage: ".._GET["currentPage"]..",\n") end
if(_GET["perPage"] ~= nil)     then print("perPage: ".._GET["perPage"]..",\n") end

print [[
	        title: "]] print(t["label"]) print[[",
      columns: [
	 {
	    title: "Action",
	    field: "column_key",
	    css: { 
	       textAlign: 'center'
	    }
	 },

	 {
	    title: "]] print(t["date"]) print[[",
	    field: "column_date",
	    css: { 
	       textAlign: 'center'
	    }
	 },
	 {
	    title: "Severity",
	    field: "column_severity",
	    css: { 
	       textAlign: 'center'
	    }
	 },

	 {
	    title: "Type",
	    field: "column_type",
	    css: { 
	       textAlign: 'center'
	    }
	 },

	 {
	    title: "Description",
	    field: "column_msg",
	    css: { 
	       textAlign: 'left'
	    }
	 }
      ]
   });
   </script>
	      ]]

end

if(interface.getNumQueuedAlerts() > 0) then
   print [[

<a href="#myModal" role="button" class="btn btn-default" data-toggle="modal"><i type="submit" class="fa fa-trash-o"></i> Purge All Alerts</button></a>
 
<!-- Modal -->
<div class="modal fade" id="myModal" tabindex="-1" role="dialog" aria-labelledby="myModalLabel" aria-hidden="true">
  <div class="modal-dialog">
    <div class="modal-content">
      <div class="modal-header">
    <button type="button" class="close" data-dismiss="modal" aria-hidden="true">X</button>
    <h3 id="myModalLabel">Confirm Action</h3>
  </div>
  <div class="modal-body">
    <p>Do you really want to purge all alerts?</p>
  </div>
  <div class="modal-footer">

    <form class=form-inline style="margin-bottom: 0px;" method=get action="#"><input type=hidden name=id_to_delete value="__all__">
      ]]

print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')

print [[
    <button class="btn btn-default" data-dismiss="modal" aria-hidden="true">Close</button>
    <button class="btn btn-primary" type="submit">Purge All</button>
</form>
  </div>
  </div>
</div>
</div>

      ]]
end

end -- closes if ntop.getPrefs().are_alerts_enabled == false then

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
