--
-- (C) 2013-16 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
-- io.write ("Session:".._SESSION["session"].."\n")
require "lua_utils"


sendHTTPHeader('text/html; charset=iso-8859-1')

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")
-- Alerts 

-- ============================
dofile(dirs.installdir .. "/scripts/lua/modules/traffic_stats.lua")
		       	  
getTalkers(ifname, 0, "packets", "both", 10, "desc")

-- Interfaces 
function interfaces(div_name) 
print [[

<div class='chart'>
<div id=']] print(div_name) print [['></div>
</div>
]]


local ifnames = {}

for v,k in pairs(names) do
   interface.select(k)
   _ifstats = aggregateInterfaceStats(interface.getStats())

   ifnames[_ifstats.id] = _ifstats.name
   --print(_ifstats.name.."=".._ifstats.id.." ")
end

for k,v in pairsByKeys(ifnames, asc) do
   print("      <li>")
   
   --print(k.."="..v.." ")

   if(v == ifname) then
      print("<a href=\""..ntop.getHttpPrefix().."/lua/if_stats.lua?if_name="..v.."\">")
   else
      print("<a href=\""..ntop.getHttpPrefix().."/lua/set_active_interface.lua?id="..k.."\">")
   end
   
   if(v == ifname) then print("<i class=\"fa fa-check\"></i> ") end
   if (isPausedInterface(v)) then  print('<i class="fa fa-pause"></i> ') end

   
   print(getHumanReadableInterfaceName(v))
   print("</a>\tTRAFFIC\tGRAFICO</li>\n")
end
--	print ("</script>")


end



-- Body


function pieChart(div_name, url) 
print [[

<div class='chart'>
<div id=']] print(div_name) print [['></div>
</div>

<script>
var ]] print(div_name) print [[ = c3.generate({
    bindto: '#]] print(div_name) print [[',
    transition: { duration: 0 },
    color: { pattern: ['#1f77b4', '#aec7e8', '#ff7f0e', '#ffbb78', '#2ca02c', '#98df8a' ] },

    data: {
        columns: [ ],
        type : 'donut',
    }
});

function update_]] print(div_name) print [[() {
    $.ajax({
      type: 'GET',
        url: ']] print(url) print [[',
	  data: {  },
          success: function(content) {
	      try {
   	         data = jQuery.parseJSON(content);
	         ]] print(div_name) print [[.load({ columns: data })
	        } catch(e) {
		     console.log(e);
  	        }
          }
      });
}

$(document).ready(function () { update_]] print(div_name) print [[(); });
setInterval(function() { update_]] print(div_name) print [[(); }, 3000);
</script>
]]

end

print [[
<div class="container-fluid">

<div class="row">
  <div class="col-md-4">
     <div class="panel panel-default">
        <div class="panel-heading">Top Receivers</div>
        <div class="panel-body">]] pieChart("top_test", "/lua/iface_hosts_list_rcvd.lua?ajax_format=c3")   print [[</div>
     </div>
  </div>

  <div class="col-md-4">
     <div class="panel panel-default">
        <div class="panel-heading">Interfaces</div>
        <div class="panel-body">]] interfaces("listInterfaces")   print [[</div>
     </div>
  </div>

  <div class="col-md-4">
     <div class="panel panel-default">
        <div class="panel-heading">Alerts</div>
        <div class="panel-body">@@@@ ALERTS @@@@</div>
     </div>
  </div>
</div>
<div class="row">
  <div class="col-md-4">
     <div class="panel panel-default">
        <div class="panel-heading">Top Senders</div>
        <div class="panel-body">]] pieChart("top_senders", "/lua/iface_hosts_list_sent.lua?ajax_format=c3")   print [[</div>
     </div>
  </div>

  <div class="col-md-4">
     <div class="panel panel-default">
        <div class="panel-heading">Empty</div>
        <div class="panel-body">Body</div>
     </div>
  </div>
  <div class="col-md-4">
     <div class="panel panel-default">
        <div class="panel-heading">Empty</div>
        <div class="panel-body">Body</div>
     </div>
  </div>

</div>


</div>
]]


-- Footer
dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")

