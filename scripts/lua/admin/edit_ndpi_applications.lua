--
-- (C) 2017 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

sendHTTPContentTypeHeader('text/html')

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

print [[
<hr>
  <div id="table-edit-ndpi-applications"></div>
  <script type="text/javascript">

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
	       showPagination: true,
               rowCallback: function(row){
                 var app_id = $("td:eq(0)", row[0]).text();
                 var cat_id = $("td:eq(1)", row[0]).text();

                 var app_cat_name_span_id   = "cat_name_app_" + app_id;
                 var app_cat_name_select_id = "select_category_app_id_" + app_id;

                 $("td:eq(3)", row[0]).wrapInner("<span id='"+ app_cat_name_span_id +"'></span>")


                 /* ADD AN HIDDEN DROPDOWN */
                 var selectList = document.createElement("select");
                 $(selectList)
                  .width("280px")
                  .addClass("form-control");
                 $(selectList).change(function(){
                   var new_cat_id = $(this).val();

                   $.ajax({
                     type: 'POST',]] print("url: '"..ntop.getHttpPrefix().."/lua/admin/change_ndpi_category.lua',") print [[
                     data: { l7proto: app_id, ndpi_new_cat_id: new_cat_id, ndpi_old_cat_id: cat_id, csrf: change_cat_csrf},
                     error: function(content) { console.log(content); },
                     success: function(content) {
                       $('#' + app_cat_name_span_id).text(select_data[new_cat_id]).show();
                       $(selectList).hide();
                       $(edit_category).show();
                       $(undo_edit).hide();
                       change_cat_csrf = content.new_csrf;
                     }
                   });
                 }).hide();
                 selectList.id = app_cat_name_select_id;

                 $("td:eq(3)", row[0]).append(selectList);

                 $.each(select_data, function(_cat_id, _cat_name){
                   var option = document.createElement("option");
                   option.value = _cat_id;
                   option.text = _cat_name;
                   if(_cat_id == cat_id) {
                     option.selected = "true";
                   }
                   selectList.appendChild(option);
                 });

                 /* PREPARE THE ACTION BUTTONS */
                 var edit_category = document.createElement("a");
                 var undo_edit = document.createElement("a");

                 $(edit_category).attr("href", "javascript:void(0)")
                                 .addClass("add-on btn")
                                 .attr("role", "button")
                                 .click(function(){
                                   $('#' + app_cat_name_span_id).hide();
                                   $(selectList).show();
                                   $(this).hide();
                                   $(undo_edit).show();
                                 })
                                 .append($(document.createElement("span"))
                                                   .addClass("label label-info")
                                                   .text("Edit"));

                 $(undo_edit).attr("href", "javascript:void(0)")
                              .addClass("add-on btn")
                              .hide()
                              .attr("role", "button")
                              .click(function(){
                                $('#' + app_cat_name_span_id).show();
                                $(selectList).hide();
                                $(this).hide();
                                $(edit_category).show();
                              })
                              .append($(document.createElement("span"))
                                                .addClass("label label-default")
                                                .text("Undo"));

                 $("td:eq(4)", row[0]).append(edit_category);
                 $("td:eq(4)", row[0]).append(undo_edit);

                 return row;
               },
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
            },{
              title: "]] print(i18n("actions")) print[[",
              field: "column_actions",
              sortable: false,
                css: {
                  textAlign: 'center'
              }
            }
          ]
  });


       </script>

]]

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
