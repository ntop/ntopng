--
-- (C) 2014-15-15 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "graph_utils"

page        = _GET["page"]
hosts_ip     = _GET["hosts"]

-- Default values
if(page == nil) then 
  page = "overview"
end

active_traffic = true
active_packets = false
active_ndpi = false
show_aggregation = true

active_page = "hosts"
sendHTTPContentTypeHeader('text/html')
ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")


if(hosts_ip == nil) then
   print("<div class=\"alert alert-danger\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png> "..i18n("hosts_comparison.hosts_parameter_missing_message").."</div>")
   return
end


print [[
  <nav class="navbar navbar-default" role="navigation">
  <div class="navbar-collapse collapse">
    <ul class="nav navbar-nav">
]]

url=ntop.getHttpPrefix().."/lua/hosts_comparison.lua?hosts="..hosts_ip

hosts_ip_tab_name = string.gsub(hosts_ip, ',', " <i class=\"fa fa-exchange fa-lg\"></i> ")

print("<li><a href=\"#\">"..i18n("flows_page.hosts")..": "..hosts_ip_tab_name.." </a></li>\n")

if((page == "overview") or (page == nil)) then
  print("<li class=\"active\"><a href=\"#\"><i class=\"fa fa-home fa-lg\"></i></a></li>\n")
else
  print("<li><a href=\""..url.."&page=overview\"><i class=\"fa fa-home fa-lg\"></i></a></li>")
end

if(page == "traffic") then
   print("<li class=\"active\"><a href=\"#\">"..i18n("traffic").."</a></li>\n")
else
   if(active_traffic) then
      print("<li><a href=\""..url.."&page=traffic\">"..i18n("traffic").."</a></li>")
   end
end

if(page == "packets") then
   print("<li class=\"active\"><a href=\"#\">"..i18n("packets").."</a></li>\n")
else
   if(active_packets) then
      print("<li><a href=\""..url.."&page=packets\">"..i18n("packets").."</a></li>")
   end
end

if(page == "ndpi") then
  print("<li class=\"active\"><a href=\"#\">"..i18n("protocols").."</a></li>\n")
else
   if(active_ndpi) then
      print("<li><a href=\""..url.."&page=ndpi\">"..i18n("protocols").."</a></li>")
   end
end

print [[
<li><a href="javascript:history.go(-1)"><i class='fa fa-reply'></i></a></li>
</ul>
</div>
</nav>
   ]]

-- =========================== Tab Menu =================

if (page == "overview") then


if(show_aggregation) then
   print [[
<div class="btn-group">
  <button class="btn btn-default btn-sm dropdown-toggle" data-toggle="dropdown">]] print(i18n("aggregation")) print[[ <span class="caret"></span></button>
  <ul class="dropdown-menu">
]]

print('<li><a  href="'..url .. '&aggregation=ndpi">'.. i18n("application") ..'</a></li>\n')
print('<li><a  href="'..url .. '&aggregation=l4proto">'.. i18n("flows_page.l4_proto") ..'</a></li>\n')
print('<li><a  href="'..url .. '&aggregation=port">'.. i18n("port") ..'</a></li>\n')
print [[
  </ul>
</div><!-- /btn-group -->


]]



print('&nbsp;'..i18n("refresh")..':  <div class="btn-group">\n')
 print[[
 <button id="graph_refresh" class="btn btn-default btn-sm">
    <i rel="tooltip" data-toggle="tooltip" data-placement="top" data-original-title="]] print(i18n("index_page.refresh_graph_popup_msg")) print[[" class="glyphicon glyphicon-refresh"></i></button>
]]
print [[
</div>
</div>
<br/>
]]

print[[
<script>
   $("#graph_refresh").click(function() {
    sankey();
  });

  $(window).load(function() 
  {
   // disabled graph interval
   clearInterval(sankey_interval);
  });  
</script>

]]
end -- End if(show_aggregation)

-- =========================== Aggregation Menu =================
print("<center>")
print('<div class="row">')
print("  <div>")
dofile(dirs.installdir .. "/scripts/lua/inc/sankey.lua")
print("  </div>")

print("</div>")
print("</center><br/>")


elseif(page == "traffic") then

if(show_aggregation) then
   print [[
<div class="btn-group">
  <button id="aggregation_bubble_displayed" class="btn btn-default btn-sm dropdown-toggle" data-toggle="dropdown">]] print(i18n("aggregation")) print[[ <span class="caret"></span></button>
  <ul class="dropdown-menu" id="aggregation_bubble">
    <li><a>]] print(i18n("application")) print[[</a></li>
    <li><a>]] print(i18n("l4_protocol")) print[[</a></li>
    <li><a>]] print(i18n("port")) print[[</a></li>
  </ul>
</div><!-- /btn-group -->


]]

print('&nbsp;'..i18n("refresh")..':  <div class="btn-group">\n')
 print[[
 <button id="graph_refresh" class="btn btn-default btn-sm">
    <i rel="tooltip" data-toggle="tooltip" data-placement="top" data-original-title="]] print(i18n("index_page.refresh_graph_popup_msg")) print[[" class="glyphicon glyphicon-refresh"></i></button>
]]
print [[
</div>
</div>
<br/>
]]

end -- End if(show_aggregation)

-- =========================== Aggregation Menu =================

print("<center>")
print("<div class=\"row-fluid\">")
print('<div id="bubble_chart"></div>')
print("</div>")
print("</center>")
print [[
  <link href="/css/bubble-chart.css" rel="stylesheet">
  <script src="/js/bubble-chart.js"></script>

<script>
  var bubble = do_bubble_chart("bubble_chart", ']]
print (ntop.getHttpPrefix())
print [[/lua/hosts_comparison_bubble.lua', { hosts:]]
  print("\""..hosts_ip.."\" }, 10); \n")

print [[
  bubble.stopInterval();

  </script>
]]


print [[
  <script>
   $("#graph_refresh").click(function() {
    bubble.forceUpdate();
  });

  $('#aggregation_bubble li > a').click(function(e){
    $('#aggregation_bubble_displayed').html(this.innerHTML+' <span class="caret"></span>');

    if (this.innerHTML == "Application") {
      bubble_aggregation= "ndpi"
    } else if (this.innerHTML == "L4 Protocol") {
      bubble_aggregation = "l4proto";
    } else  {
      bubble_aggregation = "port";
    }
    //alert(this.innerHTML + "-" + bubble_aggregation);
    bubble.setUrlParams({ aggregation: bubble_aggregation, hosts:]]
    print("\""..hosts_ip.."\" }") print [[ );
    bubble.forceUpdate();
    }); 
</script>

]]



elseif(page == "packets") then


elseif(page == "ndpi") then


end -- End if page == ...
dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")

