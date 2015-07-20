--
-- (C) 2013-15 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "graph_utils"

page = _GET["page"]
if(page == nil) then page = "overview" end

host_ip = _GET["host"]

sendHTTPHeader('text/html; charset=iso-8859-1')
ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

if(host_ip == nil) then
   print("<div class=\"alert alert-danger\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png> Host parameter is missing (internal error ?)</div>")
   return
end

interface.select(ifname)
host = interface.getAggregatedHostInfo(host_ip)

if(host == nil) then
   print("<div class=\"alert alert-danger\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png> Unable to find "..host_ip.." (data expired ?)</div>")
   return
else
print [[
<div class="bs-docs-example">
            <nav class="navbar navbar-default" role="navigation">
              <div class="navbar-collapse collapse">
<ul class="nav navbar-nav">
]]


url=ntop.getHttpPrefix().."/lua/aggregated_host_details.lua?host="..host_ip

print("<li><a href=\"#\">"..host_ip.." </a></li>\n")

if(page == "overview") then
  print("<li class=\"active\"><a href=\"#\">Overview</a></li>\n")
else
  print("<li><a href=\""..url.."&page=overview\">Overview</a></li>")
end

num = 0
if(host.contacts ~= nil) then
   for k,v in pairs(host["contacts"]["client"]) do num = num + 1 end
   for k,v in pairs(host["contacts"]["server"]) do num = num + 1 end
end

if(num > 0) then
   if(page == "contacts") then
      print("<li class=\"active\"><a href=\"#\">Contacts</a></li>\n")
   else
      print("<li><a href=\""..url.."&page=contacts\">Contacts</a></li>")
   end
end


print [[

<li><a href="javascript:history.go(-1)"><i class='fa fa-reply'></i></a></li>
</ul>
</div>
</nav>
</div>
   ]]

--print("<b>".._GET["page"].."</b>")
if(page == "overview") then
   print("<table class=\"table table-bordered table-striped\">\n")
   print("<tr><th>Name</th><td>")
   host["family_name"] = interface.getNdpiProtoName(host["family"])

   if(host["family_name"] == "Operating System") then
      print(host["name"])
   else
      print("<A HREF=http://" .. host["name"].. ">".. host["name"].."</A> <i class=\"fa fa-external-link fa-lg\"></i>")
   end
   print("</td></tr>\n")
   print("<tr><th>Family</th><td>" .. host["family_name"].. "</td></tr>\n")
   print("<tr><th>First Seen</th><td>" .. formatEpoch(host["seen.first"]) ..  " [" .. secondsToTime(os.time()-host["seen.first"]) .. " ago]" .. "</td></tr>\n")
   print("<tr><th>Last Seen</th><td><div id=last_seen>" .. formatEpoch(host["seen.last"]) .. " [" .. secondsToTime(os.time()-host["seen.last"]) .. " ago]" .. "</div></td></tr>\n")

   print("<tr><th>Contacts Number</th><td><span id=contacts>" .. formatValue(host["queries.rcvd"]) .. "</span> <span id=contacts_trend></span></td></tr>\n")

   vol = host["bytes.sent"]+host["bytes.rcvd"]

   if(vol > 0) then
      print("<tr><th>Traffic Volume</th><td><span id=traffic_volume>".. bytesToSize(host["bytes.sent"]+host["bytes.rcvd"]).."</span></td></tr>\n")
   end

   print [[
	    <tr><th>Activity Map</th><td>
	    <span id="sentHeatmap"></span>
	    <button id="sent-heatmap-prev-selector" style="margin-bottom: 10px;" class="btn btn-default btn-sm"><i class="fa fa-angle-left fa-lg"></i></button>
	    <button id="heatmap-refresh" style="margin-bottom: 10px;" class="btn btn-default btn-sm"><i class="fa fa-refresh fa-lg"></i></button>
	    <button id="sent-heatmap-next-selector" style="margin-bottom: 10px;" class="btn btn-default btn-sm"><i class="fa fa-angle-right fa-lg"></i></button>
	    <p><span id="heatmapInfo"></span>

	    <script type="text/javascript">

	 var sent_calendar = new CalHeatMap();
        sent_calendar.init({
		       itemSelector: "#sentHeatmap",
		       data: "]]
     print(ntop.getHttpPrefix().."/lua/get_host_activitymap.lua?aggregated=1&host="..host_ip..'",\n')

     timezone = get_timezone()

     now = ((os.time()-5*3600)*1000)
     today = os.time()
     today = today - (today % 86400) - 2*3600
     today = today * 1000

     print("/* "..timezone.." */\n")
     print("\t\tstart:   new Date("..now.."),\n") -- now-3h
     print("\t\tminDate: new Date("..today.."),\n")
     print("\t\tmaxDate: new Date("..(os.time()*1000).."),\n")
		     print [[
   		       domain : "hour",
		       range : 6,
		       nextSelector: "#sent-heatmap-next-selector",
		       previousSelector: "#sent-heatmap-prev-selector",
			   onClick: function(date, nb) {
				  if(nb === null) { 
				     ("#heatmapInfo").html(""); 
				  } else {
				     $("#heatmapInfo").html(date + ": detected traffic for <b>" + nb + "</b> seconds ("+ Math.round((nb*100)/60)+" % of time).");
				  }
			       }
				    });

	    $(document).ready(function(){
			    $('#heatmap-refresh').click(function(){
							      sent_calendar.update(]]
									     print(ntop.getHttpPrefix().."\"/lua/get_host_activitymap.lua?aggregated=1&host="..host_ip..'\");\n')
									     print [[
						    });
				      });

   </script>

	    </td></tr>
      ]]




   print("</table>\n")

elseif(page == "contacts") then


if(num > 0) then
print("<table class=\"table table-bordered table-striped\">\n")
print("<tr><th>Top Peers</th><th>Query Number</th></tr>\n")

-- Client
sortTable = {}
for k,v in pairs(host["contacts"]["client"]) do sortTable[v]=k end

for _v,k in pairsByKeys(sortTable, rev) do
   name = interface.getHostInfo(k)
   v = host["contacts"]["client"][k]
   if(name ~= nil) then
      if(name["name"] == nil) then name["name"] = ntop.getResolvedAddress(name["ip"]) end
      url = "<A HREF=\""..ntop.getHttpPrefix().."/lua/host_details.lua?host="..k.."\">"..name["name"].."</A>"
   else
      url = k
   end
   print("<tr><th>"..url.."</th><td class=\"text-right\"><div id=\""..string.gsub(k, '%.', '_').."\">" .. formatValue(v) .. "</div></td></tr>\n")
end
print("</table></td>\n")


print("</table>\n")
else
   print("No contacts for this host")
end


else
   print(page)
end
end


print("<script>\nvar contacts = 0;")
print [[

setInterval(function() {
	  $.ajax({
		    type: 'GET',
		    url: ']]
print(ntop.getHttpPrefix())
print [[/lua/get_aggregated_host_info.lua',
		    data: { ifname: "]] print(ifname) print [[", name: "]] print(host_ip) print [[" },
		    /* error: function(content) { alert("JSON Error: inactive host purged or ntopng terminated?"); }, */
		    success: function(content) {
			var rsp = jQuery.parseJSON(content);
			$('#last_seen').html(rsp.last_seen);
			$('#contacts').html(addCommas(rsp.num_queries));
			$('#traffic_volume').html(rsp.traffic_volume);
			if(contacts == rsp.num_queries) {
			   $('#contacts_trend').html("<i class=\"fa fa-minus\"></i>");
			} else {
			   $('#contacts_trend').html("<i class=\"fa fa-arrow-up\"></i>");
			}
			contacts = rsp.num_queries;

			for (var i = 0; i < rsp.contacts.length; i++) {
			   var key = '#'+rsp.contacts[i].key.replace(/\./g, '_');
			   $(key).html(addCommas(rsp.contacts[i].value));
			}
		     }
	           });
		 }, 3000);
</script>
		      ]]
dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
