--
-- (C) 2017 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

sendHTTPContentTypeHeader('text/html')

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

if not haveAdminPrivileges() then
  return
end

if not table.empty(_POST) then
  local custom_categories = getCustomnDPIProtoCategories(ifname)

  for k, new_cat in pairs(_POST) do
    if starts(k, "proto_") then
      local id = split(k, "proto_")[2]
      local old_cat
      new_cat = tonumber(split(new_cat, "cat_")[2])

      -- get the current category
      if custom_categories[id] ~= nil then
        old_cat = custom_categories[id]
      else
        old_cat = interface.getnDPIProtoCategory(tonumber(id))
        old_cat = old_cat and old_cat.id or 0
      end

      if old_cat ~= new_cat then
        -- io.write("Changing nDPI category for " .. id .. ": " .. old_cat .. " -> " .. new_cat .. "\n")
        setCustomnDPIProtoCategory(ifname, tonumber(id), new_cat)
      end
    end
  end
end

print [[
<hr>
  <form id="protos_cat_form" lass="form-inline" style="margin-bottom: 0px;" method="post">
    <input type="hidden" name="csrf" value="]] print(ntop.getRandomCSRFValue()) print[[">
    <div id="table-edit-ndpi-applications"></div>
    <button class="btn btn-primary" style="float:right; margin-right:1em;" disabled="disabled" type="submit">]] print(i18n("save_settings")) print[[</button>
  </form>
  <br/><br/>

  <script type="text/javascript">
    aysHandleForm("#protos_cat_form", {
      handle_datatable: true,
    });

  var change_cat_csrf = "]] print(ntop.getRandomCSRFValue()) print[[";

  var select_data = {
]]

for cat_name, cat_id in pairsByKeys(interface.getnDPICategories()) do
   print(cat_id..": '"..cat_name.."', ")
end

print[[

  };

  var url_update = "]] print (ntop.getHttpPrefix()) print [[/lua/admin/get_ndpi_applications.lua";

  $("#table-edit-ndpi-applications").datatable({
    url: url_update ,
    class: "table table-striped table-bordered table-condensed",
]]

print('title: "' .. i18n("applications") .. '",')

-- Set the preference table
local preference = tablePreferences("rows_number",_GET["perPage"])
if (preference ~= "") then print ('perPage: '..preference.. ",\n") end

-- Automatic default sorted. NB: the column must exist.
print ('sort: [ ["' .. getDefaultTableSort("ndpi_application_category") ..'","' .. getDefaultTableSortOrder("ndpi_application_category").. '"] ],')


print [[
         tableCallback: function() {
          aysResetForm("#protos_cat_form");
         }, showPagination: true,
	        columns: [
           {
              title: "",
              field: "column_ndpi_application_id",
              hidden: true,
              sortable: false,
            },{
              title: "",
              field: "column_ndpi_application_category_id",
              hidden: true,
              sortable: false,
            },{
              title: "]] print(i18n("application")) print[[",
              field: "column_ndpi_application",
              sortable: true,
                css: {
                  width: '30%',
                  textAlign: 'left'
              }
            },{
              title: "]] print(i18n("categories_page.traffic_category")) print[[",
              field: "column_ndpi_application_category",
              sortable: true,
                css: {
                  textAlign: 'left'
              }
            }
          ]
  });


       </script>

]]

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
