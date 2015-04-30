--
-- (C) 2013-15 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

if(mode ~= "embed") then
   sendHTTPHeader('text/html; charset=iso-8859-1')
   ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")
   active_page = "hosts"
   dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")
end

print("<h2>Top Hosts Traffic</H2>")
print [[
		<style>

                svg {
                 font: 10px sans-serif;
                }

                .axis path, .axis line {
                  fill: none;
                  stroke: #000;
                  shape-rendering: crispEdges;
                }

                sup, sub {
                  line-height: 0;
                }

		.background {
		  fill: #eee;
		}
		line {
		  stroke: #fff;
		}
		text.active {
		  font-size: 12px;
		  fill: red;
		}
		article, aside { display:inline-block; vertical-align:top;}
		
		#tooltip{
		    display: none;
		    position: absolute;
		    color : #fff;
		  	/*background-color: #333;*/
		    border-radius: 4px;
		    z-index: 1000;
		}
		
		
		tr { background-color: #333; }
		</style>
	]]
	print("<section>")
		print("<header><h3></h3></header>")
		print('<div id="tooltip">')
		print [[
			<table class="table table-bordered">
				<thead>
					<th style="text-align: center;">Host</th>
					<th style="text-align: center;">Sent</th>
					<th style="text-align: center;">Rcvd</th>
				</thead>
				<tbody>
				</tbody>
			</table>
		]]
		print('</div>')
	  	print("<article class=\"gr\"></article>")
		print [[
		<aside style="margin-top: 90px; margin-left: 10px;>"
			<p><h4>Sort by: </h4><select id="order">
				<option value="name">Name</option>
				<option value="count">Frequency</option>
				<option value="group">Cluster</option>
				<option value="flow_sent">Traffic Sent</option>
				<option value="flow_rcvd">Traffic Rcvd</option>
				<option value="flow_tot">Total Traffic</option>
				</select>
			</p>
			<div id="legend" style="">
				<h4>Legend:</h4>
				<svg width="100" height="198">
					  <defs>
					    <linearGradient id="local"
					                    x1="0%" y1="0%"
					                    x2="100%" y2="100%"
					                    spreadMethod="pad">
					      <stop offset="0%"   stop-color="#1f77b4" stop-opacity="1"/>
					      <stop offset="100%" stop-color="#1f77b4" stop-opacity=".25"/>
					    </linearGradient>
					    <linearGradient id="remote"
					                    x1="0%" y1="0%"
					                    x2="100%" y2="100%"
					                    spreadMethod="pad">
					      <stop offset="0%"   stop-color="#ff7f0e" stop-opacity="1"/>
					      <stop offset="100%" stop-color="#ff7f0e" stop-opacity=".25"/>
					    </linearGradient>
					     <linearGradient id="none"
					                    x1="0%" y1="0%"
					                    x2="100%" y2="100%"
					                    spreadMethod="pad">
					      <stop offset="0%"   stop-color="#333" stop-opacity="1"/>
					      <stop offset="100%" stop-color="#333" stop-opacity=".25"/>
					    </linearGradient>
					  </defs>
					<g transform="translate(0,0)">
						<rect rx="3" ry="3" width="100" height="30" style="fill: url(#local);"></rect>
						<text x="50" y="15" dy="0.35em" text-anchor="middle">local</text>
					</g>
					<g transform="translate(0,33)">
						<rect rx="3" ry="3" width="100" height="30" style="fill: url(#remote);"></rect>
						<text x="50" y="15" dy="0.35em" text-anchor="middle">remote</text>
					</g>
					<g transform="translate(0,66)">
						<rect rx="3" ry="3" width="100" height="30" style="fill: url(#none);"></rect>
						<text x="50" y="15" dy="0.35em" text-anchor="middle">local &lt;-&gt; remote</text>
					</g>
				</svg>
			</div>
		</aside>
		]]
	print("</section>")
	print ('<script>')

print [[
var margin = {top: 140, right: 0, bottom: 10, left: 140},
    width = 620, height = 500;

var h = d3.scale.ordinal().rangeBands([0, width]),
    z = d3.scale.linear().domain([0, 4]).clamp(true),
    c = d3.scale.category10().domain(d3.range(10));

var svg = d3.select(".gr").append("svg")
    .attr("width", width + margin.left + margin.right)
    .attr("height", height + margin.top + margin.bottom)
    .style("margin-left", margin.left/7 + "px")
  	.append("g")
    .attr("transform", "translate(" + margin.left + "," + margin.top + ")");

    d3.json("]]
print (ntop.getHttpPrefix())
print [[/lua/get_host_traffic_matrix.lua]]

	    if(_GET["host"] ~= nil) then
	       print("?host=".._GET["host"])
	    end
	    print('",function(dati) {\n')

	ntop.dumpFile(dirs.installdir .. "/httpdocs/js/matrix_volume.js")
	print ('</script>')
		--[[print ('<script src="/js/matrix_volume.js"></script>')]]--

if(mode ~= "embed") then
dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
end
