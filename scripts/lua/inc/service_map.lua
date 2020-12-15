--
-- (C) 2013-20 - ntop.org
--

require "flow_utils"
local lua_utils = require "lua_utils"

print('<link href="'.. ntop.getHttpPrefix()..'/datatables/datatables.min.css" rel="stylesheet"/>')

print ('<div class="d-flex justify-content-start"><H3>' .. i18n("service_map") .. "</H3>")

if(_GET["host"] ~= nil) then
   print('&nbsp; <A HREF="/lua/if_stats.lua?page=service_map"><span class="fas fa-ethernet"></span></A>')
end

local p = interface.serviceMap() or {}
local host_ip = _GET["host"]

--
-- Draw service map
--

local nodes = {}
local nodes_id = {}
local proto_number = {}
local num_services = 0

-- tprint(iec)

for k,v in pairs(p) do
   local key = ""
   if((host_ip == nil) or (v.client == host_ip) or (v.server == host_ip) ) then
      num_services = num_services + 1

      nodes[v["client"]] = true
      nodes[v["server"]] = true

      key = v["client"] .. "," .. v["server"]
      if proto_number[key] == nil then
         proto_number[key] = { 1, v.l7_proto}
      else
         proto_number[key][1] = proto_number[key][1] + 1
         if proto_number[key][1] <= 3 then
            proto_number[key][2] = proto_number[key][2] .. ", " .. v.l7_proto
         end
      end
   end
end

if num_services > 0 then
   print [[ </div> <div> <script type="text/javascript" src="/js/vis-network.min.js"></script>

   <div style="width:100%; height:30vh; " id="services_map"></div><p>

   <script type="text/javascript">
      var nodes = null;
      var edges = null;
      var network = null;

      function draw() {
      // create people.
      // value corresponds with the age of the person
      nodes = [
   ]]
      local i = 1

   for k,_ in pairs(nodes) do
      local hinfo = hostkey2hostinfo(k)
      local label = shortenString(hostinfo2label(hinfo), 16)

      if isBroadcastMulticast(k) == true then
         print('{ id: '..i..', value: \"' .. k .. '\", label: \"'..label..'\", color: "#7BE141"},\n')
      else
         print("{ id: "..i..", value: \"" .. k .. "\", label: \""..label.."\" },\n")
      end
      
      nodes_id[k] = i
      i = i + 1
   end

   print [[
   ];

      // create connections between people
      // value corresponds with the amount of contact between two people
      edges = [
   ]]

   for k,v in pairs(proto_number) do
      local keys = split(k, ",")
      local title = v[2]

      if v[1] > 3 then
         title = title .. ", other " .. v[1] - 3 .. "..."
      end
      
      print("{ from: " .. nodes_id[keys[1]] .. ", to: " .. nodes_id[keys[2]] .. ", value: " .. "1" .. ", title: \"" .. title .. "\", arrows: \"to\" },\n")
   end

   print [[
      ];

      // Instantiate our network object.
	  var container = document.getElementById("services_map");
	  var data = {
	  nodes: nodes,
	  edges: edges,
	  };
	  
	  var options = {
	  autoResize: true,
	  nodes: {
            shape: "dot",
            scaling: {
         label: false,
         min: 30,
         max: 30,
            },
            shadow: true,
	    // smooth: true,
	  },
	  };
	  network = new vis.Network(container, data, options);

   network.on("doubleClick", function (params) {
      const target = params.nodes[0];
      const node_selected = nodes.find(n => n.id == target);
      console.log(node_selected);
      window.location.href = http_prefix + '/lua/host_details.lua?host=' + node_selected.value + '&page=service_map';
   });

}

   draw();

   </script>
      ]]
end

--
-- End service map draw
--

print [[
</div>
<div class='table-responsive'>
<table id="service_map" class="table table-bordered table-striped w-100">
        <thead>
            <tr>
                <th>]] print(i18n("protocol")) print [[</th>
                <th>]] print(i18n("client")) print [[</th>
                <th>]] print(i18n("server")) print [[</th>
                <th>]] print(i18n("vlan_id")) print [[</th>
                <th>]] print(i18n("port")) print [[</th>
                <th>]] print(i18n("num_uses")) print [[</th>
                <th>]] print(i18n("last_seen")) print [[</th>
                <th>]] print(i18n("info")) print [[</th>
            </tr>
        </thead>
</table>
</div>
]]

if(isAdministrator()) then
   if(_GET["action"] == "reset") then
      interface.flushServiceMap()
   end


   if(ifid ~= nil) then
     print [[
<div class="d-flex justify-content-start">
<form>
	      <input type=hidden name="ifid" value="]] print(ifid.."") print [[">
<input type=hidden name="page" value="service_map">
<input type=hidden name="action" value="reset">

<button id="btn-factory-reset" data-target='#reset-modal' data-toggle="modal" class="btn btn-danger" onclick="return confirm(']] print(i18n("data_flush_confirm")) print [[')">
 <i class="fas fa-undo-alt"></i> ]] print(i18n("flush_service_map_data")) print [[
</button>
</form>
&nbsp;
<a href="]] print(ntop.getHttpPrefix()) print [[ /lua/get_service_map.lua" target="_blank" class="btn btn-primary" role="button" aria-disabled="true"><i class="fas fa-download"></i></a>
</div>
]]
     end
   end

print [[
<script>
$(document).ready(function() {
  const filters = [
]]

local keys = {}
local keys_regex = {}

for k,v in pairs(p) do
   if((host_ip == nil)
	 or (v.client == host_ip)
      or (v.server == host_ip) ) then
      local k = "^".. getL4ProtoName(v.l4_proto) .. ":" .. v.l7_proto .."$"

      keys_regex[v.l7_proto] = k

      k = v.l7_proto
      if(keys[k] == nil) then
	 keys[k] = 0
      end
      keys[k] = keys[k] + 1
   end
end

local id = 0
for k,v in pairsByKeys(keys, asc) do
   print("{ key: 'filter_"..id.."', regex: '"..keys_regex[k].."', label: '"..k.." ("..v..")', countable: false },\n")
   id = id + 1
end

print [[
   ];
  let url    = ']] print(ntop.getHttpPrefix()) print [[/lua/get_service_map.lua]]

if(_GET["host"] ~= nil) then print("?host=".._GET["host"]) end

print [[';
  let config = DataTableUtils.getStdDatatableConfig( [ {
            text: '<i class="fas fa-sync"></i>',
            action: function(e, dt, node, config) {
                $serviceTable.ajax.reload();
            }
        } ]);

  config = DataTableUtils.setAjaxConfig(config, url, 'data');

  config["initComplete"] = function(settings, rows) {
    const tableAPI = settings.oInstance.api();
  }

  const $serviceTable = $('#service_map').DataTable(config);
  const columnProtocolIndex = 0; /* Filter on protocol column */

  const periodicityMenuFilters = new DataTableFiltersMenu({
    filterTitle: "]] print(i18n("protocol")) print[[",
    tableAPI: $serviceTable,
    filters: filters,
    filterMenuKey: 'protocol',
    columnIndex: columnProtocolIndex
  });

} );

 i18n.all = "]] print(i18n("all")) print [[";
 i18n.showing_x_to_y_rows = "]] print(i18n('showing_x_to_y_rows', {x='_START_', y='_END_', tot='_TOTAL_'})) print[[";

</script>

]]
