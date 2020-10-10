--
-- (C) 2013-20 - ntop.org
--


print('<link href="'.. ntop.getHttpPrefix()..'/datatables/datatables.min.css" rel="stylesheet"/>')

print ("<H3>" .. i18n("service_map"))
print [[ </H3>
<p>
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
<p>
<form>
]]

if(isAdministrator()) then
   if(_GET["action"] == "reset") then
      interface.flushServiceMap()
   end


   if(ifid ~= nil) then
print [[
<input type=hidden name="ifid" value="]] print(ifid.."") print [[">
<input type=hidden name="page" value="service_map">
<input type=hidden name="action" value="reset">

<button id="btn-factory-reset" data-target='#reset-modal' data-toggle="modal" class="btn btn-danger">
 <i class="fas fa-undo-alt"></i> ]] print(i18n("flush_service_map_data")) print [[
</button>
</form>
]]
end
   end

print [[
<script>
$(document).ready(function() {
  const filters = [
]]

local p = interface.serviceMap() or {}

local keys = {}

local host_ip = _GET["host"]

for k,v in pairs(p) do
   if((host_ip == nil)
	 or (v.client == host_ip)
      	 or (v.server == host_ip) ) then
      if(keys[v.l7_proto] == nil) then
	 keys[v.l7_proto] = 0
      end
      keys[v.l7_proto] = keys[v.l7_proto] + 1
   end
end

local id = 0
for k,v in pairsByKeys(keys, asc) do
   print("{ key: 'filter_"..id.."', regex: '"..k.."', label: '"..k.." ("..v..")', countable: false },\n")
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
