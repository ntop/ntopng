--
-- (C) 2013-21 - ntop.org
--


print('<link href="'.. ntop.getHttpPrefix()..'/datatables/datatables.min.css" rel="stylesheet"/>')

print ('<div class="d-flex justify-content-start"><H3>' .. i18n("periodicity_map") .. "</H3>")

if(_GET["host"] ~= nil) then
   print('&nbsp; <A HREF="/lua/if_stats.lua?page=periodicity_map"><span class="fas fa-ethernet"></span></A>')
end

print [[
</div>
<table id="periodicity_info" class="table table-bordered table-striped w-100">
        <thead>
            <tr>
                <th>]] print(i18n("protocol")) print [[</th>
                <th>]] print(i18n("client")) print [[</th>
                <th>]] print(i18n("server")) print [[</th>
                <th>]] print(i18n("port")) print [[</th>
                <th>]] print(i18n("observations")) print [[</th>
                <th>]] print(i18n("frequency")) print [[</th>
                <th>]] print(i18n("last_seen")) print [[</th>
                <th>]] print(i18n("info")) print [[</th>
            </tr>
        </thead>
</table>
<p>
]]

if(isAdministrator()) then
   if(_GET["action"] == "reset") then
      interface.flushPeriodicityMap()
   end


   if(ifid ~= nil) then
     print [[

<div class="d-flex justify-content-start">

<form>
<input type=hidden name="ifid" value="]] print(ifid.."") print [[">
<input type=hidden name="page" value="periodicity_map">
<input type=hidden name="action" value="reset">

<button id="btn-factory-reset" data-target='#reset-modal' data-toggle="modal" class="btn btn-danger" onclick="return confirm(']] print(i18n("data_flush_confirm")) print [[')">
 <i class="fas fa-undo-alt"></i> ]] print(i18n("flush_periodicity_map_data")) print [[
</button>
</form>
&nbsp;
<a href="]] print(ntop.getHttpPrefix()) print [[ /lua/get_periodicity_map.lua" target="_blank" class="btn btn-primary" role="button" aria-disabled="true"><i class="fas fa-download"></i></a>
</div>
]]
     end
   end

print [[
<script>
$(document).ready(function() {
  const filters = [
]]

local p = interface.periodicityMap() or {}

local keys = {}

for k,v in pairs(p) do
   if(keys[v.l7_proto] == nil) then
      keys[v.l7_proto] = 0
   end
   keys[v.l7_proto] = keys[v.l7_proto] + 1
end

local id = 0
for k,v in pairsByKeys(keys, asc) do
   print("{ key: 'filter_"..id.."', regex: '"..k.."', label: '"..k.." ("..v..")', countable: false },\n")
   id = id + 1
end

print [[
   ];
  let url    = ']] print(ntop.getHttpPrefix()) print [[/lua/get_periodicity_map.lua]]

if(_GET["host"] ~= nil) then print("?host=".._GET["host"]) end

print [[';
  let config = DataTableUtils.getStdDatatableConfig( [ {
            text: '<i class="fas fa-sync"></i>',
            action: function(e, dt, node, config) {
                $periodicityTable.ajax.reload();
            }
        } ]);

  config     = DataTableUtils.setAjaxConfig(config, url, 'data');

  config["columnDefs"] = [
   { targets: [ 5 /* Observations */], className: 'dt-body-right', "fnCreatedCell": function ( cell ) { cell.scope = 'row'; }, "render": function ( data, type, row ) { return (type == "sort" || type == 'type') ? data : data+" sec"; }  },
   { targets: [ 4 /* Frequency */], className: 'dt-body-right', "fnCreatedCell": function ( cell ) { cell.scope = 'row'; } }
  ];

  config["initComplete"] = function(settings, rows) {
    const tableAPI = settings.oInstance.api();
  }

  const $periodicityTable = $('#periodicity_info').DataTable(config);
  const columnProtocolIndex = 0; /* Filter on protocol column */
  const protocolMenuFilters = new DataTableFiltersMenu({
      filterTitle: "]] print(i18n("protocol")) print[[",
      tableAPI: $periodicityTable,
      filters: filters,
      filterMenuKey: 'periodicity-status',
      columnIndex: columnProtocolIndex
   });

} );

 i18n.all = "]] print(i18n("all")) print [[";
 i18n.showing_x_to_y_rows = "]] print(i18n('showing_x_to_y_rows', {x='_START_', y='_END_', tot='_TOTAL_'})) print[[";

</script>
]]
