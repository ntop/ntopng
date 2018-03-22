--
-- (C) 2013-18 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

sendHTTPContentTypeHeader('text/html')


ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")
local active_page = "hosts"
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

interface.select(ifname)
local interface_refresh_rate = getInterfaceRefreshRate(getInterfaceId(ifname)) or 3

local hosts_stats = interface.getLocalHostsInfo()
local hosts_stats = hosts_stats["hosts"]

--io.write(ifname.."/"..total.."\n")
local max_num = 25
local localhosts = {}
local found = false
local num = 0
for key, value in pairs(hosts_stats) do
   --print(hosts_stats[key]["name"].."<p>\n")

   if((hosts_stats[key]["localhost"] == true) and (hosts_stats[key]["ip"] ~= nil)) then
      localhosts[key] = hosts_stats[key]["packets.sent"]+hosts_stats[key]["packets.rcvd"]
      found = true
      num = num + 1
   end
end

if(found) then

print [[

<div class="page-header">
<h2>]] print(i18n("top_hosts.top_hosts_local")) print[[</H2>
</div>

<script type="text/javascript">
  var http_prefix = "]] print(ntop.getHttpPrefix()) print [[";
</script>

<script src="]] print(ntop.getHttpPrefix()) print [[/js/cubism_ntop.v1.js"></script>
<div id="tophosts"></div>

<script>

var beginning =  (new Date).getTime();
var prev = {};

function fetchData(name, symname) {
	var value = 0,
	values = [],	
	i = 0,
	last;
	return context.metric(function(start, stop, step, callback) {
	    start = +start, stop = +stop;
	    if (isNaN(last)) last = start;
	    while (last < stop) {
	      last += step;
	      if(stop < beginning) {
		value = 0;
	      values.push(value);
	      } else {
		d3.json("]]
print (ntop.getHttpPrefix())
print [[/lua/get_host_traffic.lua?host="+name, function(data) {
		    if(!data) return callback(new Error("unable to load data"));
		    if(prev[name] != undefined) {
		      values.push(data.value - prev[name]);
		    }
		    prev[name] = data.value;
		  });

	      }	     
	    }
	    callback(null, values = values.slice((start - stop) / step));
	  }, symname);
      }

var width = 800;
var context = cubism.context()
.serverDelay(0)
.clientDelay(0) // specifies how long a delay we are prepared to wait before querying the server for new data points
.step(]] print(tostring(interface_refresh_rate)) print[[000)
.size(width);


]]

sortTable = {}
for k,v in pairs(localhosts) do sortTable[v]=k end

num = 0
for _v,k in pairsByKeys(sortTable, rev) do key = k   
   if(num < max_num) then
      symname = getResolvedAddress(hostkey2hostinfo(key))
      print('var host'..num..' = fetchData("' .. key ..'", "'.. symname .. '");\n');
      num = num+1
   end
end

num_local_hosts = num

print [[

d3.select("#tophosts").call(function(div) {
    div.append("div")
      .attr("class", "axis")
      .call(context.axis().orient("top"));
    div.selectAll(".horizon")
    .data([
]]

for num=0,num_local_hosts-1 do
   if(num > 0) then print(",") end
   print(' host'..num)
   num = num+1
end

print [[
])
      .enter().append("div")
      .attr("class", "horizon")
      .call(context.horizon().extent([-20, 20])
	    .height(15) // Bar height
	 );

    div.append("div")
      .attr("class", "rule")
      .call(context.rule());
  });

// On mousemove, reposition the chart values to match the rule.
context.on("focus", function(i) {
        d3.selectAll(".value").style("right", i == null ? null : context.size() -i + "px");
  });


</script>

]]
else 
   print("<div class=\"alert alert-danger\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png> " .. i18n("no_results_found") .. "</div>")
end

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
