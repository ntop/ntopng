--
-- (C) 2021 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local template = require "template_utils"
local categories_utils = require "categories_utils"
local lists_utils = require "lists_utils"
local ui_utils = require "ui_utils"

local category_filter = _GET["l7proto"]
local ifId = getInterfaceId(ifname)

if not isAdministratorOrPrintErr() then
  return
end

local category_warnings = {}

if _POST["action"] == "edit" then
  local category_id = tonumber(split(_POST["category"], "cat_")[2])
  local hosts_list = _POST["custom_hosts"]
  local hosts_ok = {}

  local hosts = split(hosts_list, ",")

  for _, host in ipairs(hosts) do
    if not isEmptyString(host) then
      local matched_category = ntop.matchCustomCategory(host)

      if (matched_category ~= nil) and (matched_category ~= category_id) then
        -- NOTE: this check is not comprehensive
        category_warnings[#category_warnings + 1] = {
          type = "warning",
          text = i18n("custom_categories.similar_host_found", {
            host = host,
            category = interface.getnDPICategoryName(matched_category),
          })
        }
      end

      hosts_ok[#hosts_ok + 1] = host
    end
  end

  categories_utils.updateCustomCategoryHosts(category_id, hosts_ok)
  lists_utils.reloadLists()
end

printMessageBanners(category_warnings)

print(
  template.gen("modal_confirm_dialog.html", {
    dialog={
      id      = "edit_category_rules",
      action  = "editCategory()",
      title   = i18n("custom_categories.edit_custom_rules"),
      custom_alert_class = "",
      custom_dialog_class = "dialog-body-full-height",
      message = [[<p style='margin-bottom:5px;'>]] .. i18n("custom_categories.the_following_is_a_list_of_hosts", {category='<i id="selected_category_name"></i>'}) .. [[:</p>
  <textarea id="category-hosts-list" spellcheck="false" style='width:100%; height:14em;'></textarea>
  ]].. ui_utils.render_notes({
    {content = i18n("custom_categories.each_host_separate_line")},
    {content = i18n("custom_categories.host_domain_or_cidr")},
    {content = i18n("custom_categories.domain_names_substrings", {s1="ntop.org", s2="mail.ntop.org", s3="ntop.org.example.com"})}
  }),
      confirm = i18n("save"),
      cancel = i18n("cancel"),
    }
  })
)

print [[
<table><tbody><tr>
]]

if not isEmptyString(category_filter) then
  local cat_name = interface.getnDPICategoryName(tonumber(category_filter))

  print[[<td>
    <form>
      <input type="hidden" name="tab" value="categories" />
      <button type="button" class="btn btn-secondary btn-sm" onclick="$(this).closest('form').submit();">
        <i class="fas fa-times fa-lg" aria-hidden="true" data-original-title="" title=""></i> ]] print(cat_name) print[[
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
      action      = ntop.getHttpPrefix() .. "/lua/admin/edit_categories.lua",
      parameters  = {
        tab = "categories",
      },
      json_key    = "key",
      query_field = "l7proto",
      query_url   = ntop.getHttpPrefix() .. "/lua/find_category.lua",
      query_title = i18n("nedge.search_categories"),
      style       = "margin-left:1em; width:25em;",
    }
  })
)

print[[
  </td>
  </tr>
</table>

<form id="custom-cat-form" lass="form-inline" style="margin-bottom: 0px;" method="post">
  <input type="hidden" name="csrf" value="]] print(ntop.getRandomCSRFValue()) print[[">
  <div id="table-custom-cat-form"></div>
  <button class="btn btn-primary" style="float:right; margin-right:1em; margin-left: auto" disabled="disabled" type="submit">]] print(i18n("save_settings")) print[[</button>
</form>

<script>
  var selected_category_id = null;

  function editCategory() {
    var unique_hosts = [];

    /* Remove duplicate hosts */
    $.each($("#category-hosts-list").val().split("\n"), function(i, host) {
      var whitelisted = (host.charAt(0) === '!');
      host = NtopUtils.cleanCustomHostUrl(host);
      if (whitelisted) host = "!" + host;

      if($.inArray(host, unique_hosts) === -1)
        unique_hosts.push(host);
    });

    var params = {};
    params.category = "cat_" + selected_category_id;
    params.action = "edit";
    params.custom_hosts = unique_hosts.join(',');
    params.csrf = "]] print(ntop.getRandomCSRFValue()) print[[";

    NtopUtils.paramsToForm('<form method="post"></form>', params).appendTo('body').submit();
  }

  function clearCategory() {
    var params = {};
    params.category = "cat_" + selected_category_id;
    params.action = "clear";
    params.csrf = "]] print(ntop.getRandomCSRFValue()) print[[";

    NtopUtils.paramsToForm('<form method="post"></form>', params).appendTo('body').submit();
  }

  function loadCategories(category_id) {
    var data = $("#table-custom-cat-form").data('datatable').resultset;
    var hosts_list = data.data.filter(function(item) {
      return item.column_category_id == category_id;
    })[0].column_category_hosts;

    $("#category-hosts-list").val(hosts_list.split(",").join("\n"));
  }

  $("#table-custom-cat-form").datatable({
    url: "]] print (ntop.getHttpPrefix()) print [[/lua/admin/get_custom_categories_hosts.lua?l7proto=]] print(category_filter or "") print[[",
    class: "table table-striped table-bordered table-sm",
    ]]

-- Set the preference table
local preference = tablePreferences("rows_number", _GET["perPage"])
if (preference ~= "") then print ('perPage: '..preference.. ",\n") end

-- Automatic default sorted. NB: the column must exist.
print ('sort: [ ["' .. getDefaultTableSort("custom_categories_hosts") ..'","' .. getDefaultTableSortOrder("custom_categories_hosts").. '"] ],')


print [[
    title:"",
    columns: [
     {
        field: "column_category_id",
        hidden: 1,
      },{
        title: "]] print(i18n("category")) print[[",
        field: "column_category_name",
        sortable: true,
      },{
        title: "]] print(i18n("users.num_protocols")) print[[",
        field: "column_num_protos",
        sortable: true,
        css: {
            width: '20%',
            textAlign: 'center'
        }
      },{
        title: "]] print(i18n("custom_categories.custom_hosts")) print[[",
        field: "column_num_hosts",
        sortable: true,
          css: {
            width: '20%',
            textAlign: 'center'
        }
      },{
        title: "]] print(i18n("actions")) print[[",
        field: "column_actions",
        sortable: false,
          css: {
            textAlign: 'center',
            width: '15%',
        }
      }, {
        field: "column_category_hosts",
        hidden: 1,
      }
    ], rowCallback: function(row, data) {
      var category_id = data.column_category_id;
      var category_name = data.column_category_name;
      var actions_td_idx = 5;

/*
      if(data.column_num_protos != 0)
        datatableAddLinkButtonCallback.bind(row)(actions_td_idx,
          "]] print(ntop.getHttpPrefix()) print[[/lua/admin/edit_ndpi_applications.lua?category=cat_" + category_id, "]] print(i18n("host_pools.view")) print[[");
*/

      datatableAddActionButtonCallback.bind(row)(actions_td_idx,
        "loadCategories("+ data.column_category_id +"); $('#selected_category_name').html('"+ category_name +"'); selected_category_id = "+ category_id +"; $('#edit_category_rules').modal('show')", "<i class='fas fa-edit'></i>");

      return row;
     }
  });
</script>
]]

