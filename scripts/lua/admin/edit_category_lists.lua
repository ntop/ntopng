--
-- (C) 2021 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local graph_utils = require "graph_utils"
local template = require "template_utils"
local categories_utils = require "categories_utils"
local lists_utils = require "lists_utils"
local page_utils = require("page_utils")
local json = require("dkjson")
local format_utils = require("format_utils")

sendHTTPContentTypeHeader('text/html')


if not isAdministratorOrPrintErr() then
  return
end

page_utils.set_active_menu_entry(page_utils.menu_entries.category_lists)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

local currentPage = _POST["currentPage"]
if(currentPage == nil) then
   currentPage = 1
else
   currentPage = tonumber(currentPage)
end

local base_url = ntop.getHttpPrefix() .. "/lua/admin/edit_category_lists.lua"
local enabled_status = _GET["enabled_status"] or "enabled"
local page_params = {
  category = _GET["category"],
  enabled_status = enabled_status,
  currentPage = currentPage,
}

local lists = lists_utils.getCategoryLists()

if _POST["action"] == "edit" then
  local enabled = not isEmptyString(_POST["list_enabled"])
  local list_name = _POST["list_name"]
  local category = tonumber(split(_POST["category"], "_")[2])
  local url = _POST["url"]
  local list_update = tonumber(_POST["list_update"])

  url = string.gsub(url, "http:__", "http://")
  url = string.gsub(url, "https:__", "https://")

  lists_utils.editList(list_name, {
    enabled = enabled,
    category = category,
    url = url,
    update_interval = list_update,
  })
elseif _POST["action"] == "update" then
  local list_name = _POST["list_name"]
  lists_utils.updateList(list_name)

  print('<div class="alert alert-success alert-dismissable">'..
    i18n('category_lists.list_will_be_updated', {name=list_name}) .. '<button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button></div>')
end

print[[
  <form id="list-update-form" method="post">
    <input type="hidden" name="csrf" value="]] print(ntop.getRandomCSRFValue()) print[[" />
    <input type="hidden" name="currentPage" value="]] print(currentPage) print  [[" />
    <input type="hidden" name="action" value="update" />
    <input id="list_to_update" type="hidden" name="list_name" />
  </form>

  <!-- Modal -->
  <div id="editListModal" class="modal fade in" role="dialog">
    <div class="modal-dialog">

      <!-- Modal content-->
      <div class="modal-content">
        <div class="modal-header">
          <h5 class="modal-title">]] print(i18n("category_lists.edit_list")) print[[</h5>
          <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
        </div>
        <form id="edit-list-form" method="post" data-bs-toggle="validator">
        <div class="modal-body">
          <div class="container-fluid">
              <input type="hidden" name="csrf" value="]] print(ntop.getRandomCSRFValue()) print[[" />
              <input type="hidden" name="currentPage" value="]] print(currentPage) print  [[" />
              <input type="hidden" name="action" value="edit" />

              <div class="row form-group mb-3 has-feedback">
                <div class="col col-md-12">
                  <label class="form-label">]] print(i18n("name")) print[[</label>
                  <input name="list_name" id="form-edit-name" class="form-control" type="text" readonly />
                </div>
              </div>

              <div class="row form-group mb-3 has-feedback">
                <div class="col col-md-12">
                  <label class="form-label">]] print(i18n("flow_details.url")) print[[</label>
                  <input name="url" class="form-control" type="text" readonly />
                </div>
              </div>

              <div class="row form-group mb-3">
                <div class="col col-md-12">
                  <label class="form-label">]] print(i18n("category_lists.enabled")) print[[: </label>
                  <div class="custom-control custom-switch d-inline">
                    <input class="custom-control-input" name="list_enabled" type="checkbox" id="form-edit-enable" />
                    <label class="custom-control-label" for="form-edit-enable"></label>
                  </div>
                </div>
              </div>

              <div class="row form-group mb-3">
                <div class="col col-md-6">
                  <label class="form-label">]] print(i18n("category")) print[[</label>
                  <select name="category" class="form-select" readonly disabled="disabled">]]

                  for cat_name, cat_id in pairsByKeys(interface.getnDPICategories()) do
                    print(string.format([[<option value="cat_%s">%s</option>]], cat_id, getCategoryLabel(cat_name)))
                  end

                  print[[</select>
                </div>
                <div class="col col-md-6">
                  <label class="form-label">]] print(i18n("category_lists.update_frequency")) print[[</label>
                  <select name="list_update" class="form-select">
                    <option value="86400">]] print(i18n("alerts_thresholds_config.daily")) print[[</option>
                    <option value="3600">]] print(i18n("alerts_thresholds_config.hourly")) print[[</option>
                    <option value="0">]] print(i18n("alerts_thresholds_config.manual")) print[[</option>
                  </select>
                </div>
              </div>
            </div>
            </div>
            <div class='modal-footer'>
            <div class="form-group mb-3">
                <button type="submit" class="btn btn-primary btn-block">]] print(i18n("category_lists.edit_list")) print[[</button>
              </div>
            </div>
          </form>
      </div>
    </div>
  </div>
]]

page_utils.print_page_title(i18n("category_lists.category_lists"))
print[[
<div class='card'>
  <div class="card-header">
    <ul class="nav nav-tabs card-header-tabs">
      <li class="nav-item">
        <a class="nav-link ]] print(ternary(enabled_status == "all", "active", "")) print[[" href="]] print(ntop.getHttpPrefix()) print[[/lua/admin/edit_category_lists.lua?enabled_status=all">]] print(i18n("all")) print[[</a>
      </li>
      <li class="nav-item">
        <a class="nav-link ]] print(ternary(enabled_status == "enabled", "active", "")) print[[" href="]] print(ntop.getHttpPrefix()) print[[/lua/admin/edit_category_lists.lua?enabled_status=enabled">]] print(i18n("enabled")) print[[</a>
      </li>
      <li class="nav-item">
        <a class="nav-link ]] print(ternary(enabled_status == "disabled", "active", "")) print[[" href="]] print(ntop.getHttpPrefix()) print[[/lua/admin/edit_category_lists.lua?enabled_status=disabled">]] print(i18n("disabled")) print[[</a>
      </li>
    </ul>
  </div>
<div class='card-body'>

<div id="table-edit-lists-form"></div>
</div>
]]

local stats = ntop.getCache("ntopng.cache.category_lists.load_stats")
if(stats) then
  stats = json.decode(stats)

  if(stats) then
    print([[<div class='card-footer'>]])
    print(i18n("category_lists.loading_stats", {
      when = format_utils.formatPastEpochShort(stats.begin),
      num_hosts = stats.num_hosts,
      num_ips = stats.num_ips,
      num_ja3 = stats.num_ja3,
      duration = secondsToTime(stats.duration),
    }))
    print([[</div>]])
  end
end

print[[
</div>
]]



print[[
<script>
  var url_update = "]] print(getPageUrl(ntop.getHttpPrefix()..[[/lua/admin/get_category_lists.lua]], page_params)) print[[";

  $("#table-edit-lists-form").datatable({
    url: url_update,
    currentPage: ]] print(currentPage) print [[,
    class: "table table-striped table-bordered",
    title:"",
    buttons: []]


local categories = {}

for _, list in pairs(lists) do
  local catid = tostring(list.category)
  categories[catid] = categories[catid] or 0
  categories[catid] = categories[catid] + 1
end

  graph_utils.printCategoryDropdownButton(false, page_params.category, base_url, page_params, function (catid, catname)
    return(categories[catid] or 0)
  end)

print[[],
    columns: [
      {
        title: "]] print(i18n("name")) print[[",
        field: "column_label",
        sortable: true,
      }, {
        title: "]] print(i18n("status")) print[[",
        field: "column_status",
        sortable: true,
        css: {
            textAlign: 'center',
        }
      }, {
        title: "]] print(i18n("category")) print[[",
        field: "column_category_name",
        sortable: true,
      }, {
        title: "",
        field: "column_update_interval",
        sortable: false,
        hidden: true,
      }, {
        title: "]] print(i18n("category_lists.update_frequency")) print[[",
        field: "column_update_interval_label",
        sortable: true,
      }, {
        title: "]] print(i18n("category_lists.last_update")) print[[",
        field: "column_last_update",
        sortable: true,
        css: {
          textAlign: 'center',
        }
      }, {
        title: "]] print(i18n("graphs.metrics_prefixes.num_hosts")) print[[",
        field: "column_num_hosts",
        sortable: true,
        css: {
            textAlign: 'center',
        }
      }, {
        title: "]] print(i18n("actions")) print[[",
        field: "column_actions",
        sortable: false,
          css: {
            textAlign: 'center',
        }
      }, {
        field: "column_category",
        hidden: 1,
      }, {
        field: "column_name",
        hidden: 1,
      }
    ], rowCallback: function(row, data) {
      var list_name = data.column_name;
      var enabled = data.column_enabled;
      var actions_td_idx = 8;

      datatableAddActionButtonCallback.bind(row)(actions_td_idx, "prepareEditListModal('" + list_name + "'); $('#editListModal').modal('show');", "<i class='fas fa-edit'></i>");

      datatableAddActionButtonCallback.bind(row)(actions_td_idx, "$('#list_to_update').val('" + list_name + "'); $('#list-update-form').submit()", "<i class='fas fa-sync-alt'></i>", enabled);

      return row;
     }, tableCallback: function() {
       var currentPage = this.resultset.currentPage;
       var form = $("#list-update-form");
       form.find("[name='currentPage']").val(currentPage);
       var form = $("#edit-list-form");
       form.find("[name='currentPage']").val(currentPage);
     }
  });

  function prepareEditListModal(list_name) {
    var data = datatableGetColumn($("#table-edit-lists-form"), "column_name", list_name);
    var form = $("#edit-list-form");

    form.find("[name='list_name']").val(data.column_name);
    form.find("[name='list_enabled']").prop('checked', data.column_enabled);
    form.find("[name='url']").val(data.column_url);
    form.find("[name='category']").val(data.column_category);
    form.find("[name='list_update']").val(data.column_update_interval);
  }
</script>

]]

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
