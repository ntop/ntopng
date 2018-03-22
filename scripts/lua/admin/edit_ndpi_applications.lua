--
-- (C) 2017-18 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local template = require "template_utils"
sendHTTPContentTypeHeader('text/html')

local proto_filter = _GET["l7proto"]

local ifId = interface.name2id(ifname)

if not haveAdminPrivileges() then
  return
end

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

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

print [[<hr>
<table><tbody><tr>
  <td style="white-space:nowrap; padding-right:1em;">
    <h2>]] print(i18n("protocols")) print[[</h2>
  </td>]]

if not isEmptyString(proto_filter) then
  local proto_name = interface.getnDPIProtoName(tonumber(proto_filter))

  print[[<td style="padding-top: 15px;">
    <form>
      <button type="button" class="btn btn-default btn-sm" onclick="$(this).closest('form').submit();">
        <i class="fa fa-close fa-lg" aria-hidden="true" data-original-title="" title=""></i> ]] print(proto_name) print[[
      </button>
    </form>
  </td>]]
end

print[[
<td style="width:100%"></td>
<td>
]]

print(
  template.gen("typeahead_input.html", {
    typeahead={
      base_id     = "t_app",
      action      = ntop.getHttpPrefix() .. "/lua/admin/edit_ndpi_applications.lua",
      parameters  = {
                      ifid = tostring(ifId),
                    },
      json_key    = "key",
      query_field = "l7proto",
      query_url   = ntop.getHttpPrefix() .. "/lua/find_app.lua",
      query_title = i18n("categories_page.search_application"),
      style       = "margin-left:1em; width:25em;",
    }
  })
)

print[[
  </td>
  </tr>
  </table>
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

  var url_update = "]] print (ntop.getHttpPrefix()) print [[/lua/admin/get_ndpi_applications.lua]]
  if not isEmptyString(proto_filter) then
    print("?l7proto=" .. proto_filter)
  end
  print[[";

  $("#table-edit-ndpi-applications").datatable({
    url: url_update ,
    class: "table table-striped table-bordered table-condensed",
]]

-- Set the preference table
local preference = tablePreferences("rows_number",_GET["perPage"])
if (preference ~= "") then print ('perPage: '..preference.. ",\n") end

-- Automatic default sorted. NB: the column must exist.
print ('sort: [ ["' .. getDefaultTableSort("ndpi_application_category") ..'","' .. getDefaultTableSortOrder("ndpi_application_category").. '"] ],')


print [[
         tableCallback: function() {
          aysResetForm("#protos_cat_form");
         }, showPagination: true, title:"",
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
