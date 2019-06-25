--
-- (C) 2013-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
local ts_utils = require("ts_utils")
local callback_utils = require("callback_utils")
local json = require("dkjson")  
local page_utils = require("page_utils")
local format_utils = require("format_utils")

local info = ntop.getInfo() 

sendHTTPContentTypeHeader('text/html')

page_utils.print_header(i18n("about.about_x", { product=info.product }))

active_page = "about"
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

-- https://www.d3-graph-gallery.com/graph/bubble_template.html

local show_remote  = true
local local_hosts  = { }
local remote_hosts = {}
local max_r = 0

function processHost(hostname, host)
   -- io.write("================================\n")
   -- io.write(hostname.."\n")
   -- tprint(host)
   
   local host_name = hostinfo2hostkey(host)

   if((host_name == nil) or (host_name == "")) then host_name = hostname end
   local line = { link = hostname, label = host_name, x = host["total_flows.as_server"], y = host["total_flows.as_client"], r = host["bytes.sent"]+host["bytes.rcvd"] }
   if(line.r > max_r) then max_r = line.r end
   
   if(host.localhost) then
      table.insert(local_hosts, line)
   else
      table.insert(remote_hosts, line)
   end
end

if(show_remote == true) then
   callback_utils.foreachHost(ifname, os.time() + 60, processHost)
else
   callback_utils.foreachLocalHost(ifname, os.time() + 60, processHost)
end

local max_radius_px = 30
local min_radius_px = 3
local ratio         = max_r / max_radius_px

for i,v in pairs(local_hosts)  do local_hosts[i].r  = math.floor(min_radius_px+local_hosts[i].r / ratio) end

if(show_remote == true) then
   for i,v in pairs(remote_hosts) do remote_hosts[i].r = math.floor(min_radius_px+remote_hosts[i].r / ratio) end
end

local local_js  = json.encode(local_hosts)
local remote_js = json.encode(remote_hosts)
   
print [[ 

 <script type="text/javascript" src="/js/Chart.bundle.min.js"></script>

<div class="container" width="200" height="200>
  <div class="row">
    <div class="col-1">
      <canvas id="canvas" height="200"></canvas>
    </div>
  </div>
</div>

<script>
 var ctx = document.getElementById("canvas");
 var data = {
 datasets: [{
	       label: 'Local Hosts',
	       data: ]] print(local_js) print [[,
               backgroundColor: "#FF6384" 
              },
]]

if(show_remote == true) then
print [[
   {
	       label: 'Remote Hosts',
	       data: ]] print(remote_js) print [[,
               backgroundColor: "#63FF84" 
              }
]]
end

print [[
            ]
 };

 var chart = new Chart(ctx, {
   data: data,
   type: "bubble",
       options: {
         scales: { xAxes: [{ display: true, scaleLabel: { display: true, labelString: 'Flows as Server' } }],
                    yAxes: [{ display: true, scaleLabel: { display: true, labelString: 'Flows as Client' } }]
                 },

		 elements: {
			      points: {
					   borderWidth: 1,
					       borderColor: 'rgb(0, 0, 0)'
					       }
			      },
		     onClick: function(e) {
			       var element = this.getElementAtEvent(e);
			       // If you click on at least 1 element ...
			      if (element.length > 0) {
				 // Logs it
				 // console.log(element[0]);
				 var datasetLabel = this.config.data.datasets[element[0]._datasetIndex].label;
				 var data = this.config.data.datasets[element[0]._datasetIndex].data[element[0]._index];
				 // console.log(data);
                                 window.location.href = "/lua/host_details.lua?host="+data.link; // Jump to this host
			       }
		     },

tooltips: {
      callbacks: {
        title: function(tooltipItem, data) {
          return data['labels'][tooltipItem[0]['index'] ];
},

   label: function(tooltipItem, data) {
	 var dataset = data['datasets'][0];
         var host = dataset['data'][tooltipItem['index'] ];
	 return(host.label);
         },
      }
}
     }
   });

</script>  
]]


dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
