--
-- (C) 2017-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local ui_utils = require "ui_utils"
local graph_utils = require "graph_utils"
local template = require "template_utils"

local proto_filter = _GET["l7proto"]
local category_filter = _GET["category"]
local protos_utils = require("protos_utils")
local info = ntop.getInfo()
local has_protos_file = protos_utils.hasProtosFile()

local ifId = getInterfaceId(ifname)

if not isAdministratorOrPrintErr() then
  return
end

local base_url = ntop.getHttpPrefix() .. "/lua/admin/edit_categories.lua"
local page_params = {
  l7proto = proto_filter,
  category = category_filter,
  tab = "protocols"
}

local catid = nil

if not isEmptyString(category_filter) then
  catid = split(category_filter, "cat_")[2]
end

local app_warnings = {}
local action = _POST["action"]

if((action == "add") or (action == "edit") or (action == "delete")) then
  local hosts_list = _POST["custom_hosts"] or ""
  local application = _POST["new_application"] or _POST["l7proto"]
  local hosts = string.split(hosts_list, ",") or {ternary(hosts_list ~= "", hosts_list, nil)}
  local rules = {}

  -- Preliminary check
  local applications = interface.getnDPIProtocols()
  local lower_app = string.lower(application)
  local existing_app = nil

  -- case insensitive search for applications
  for k in pairs(applications) do
    if string.lower(k) == lower_app then
      existing_app = k
      break
    end
  end

  if((action == "edit") and (existing_app == nil)) then
    app_warnings[#app_warnings + 1] = {
      type = "danger",
      text = i18n("custom_categories.application_not_exists", {
        app = application,
      })
    }
  elseif((action == "add") and (existing_app ~= nil)) then
    app_warnings[#app_warnings + 1] = {
      type = "danger",
      text = i18n("custom_categories.application_exists", {
        app = existing_app,
      })
    }
  elseif(action == "delete") then
    if protos_utils.deleteAppRules(application) then
      app_warnings[#app_warnings + 1] = {
        type = "success",
        text = i18n("custom_categories.app_deleted", {product=info.product, app = application})
      }
    else
      app_warnings[#app_warnings + 1] = {
        type = "danger",
        text = i18n("custom_categories.app_delete_error", {product=info.product, app = application})
      }
    end
  else
    for _, host in ipairs(hosts) do
      -- TODO implement match logic on existing hosts to avoid duplicates
      local rule = protos_utils.getProtosTxtRule(host)

      if rule == nil then
        app_warnings[#app_warnings + 1] = {
          type = "warning",
          text = i18n("custom_categories.invalid_rule", {
            rule = host,
          })
        }
      end

      rules[#rules + 1] = rule
    end

    if protos_utils.overwriteAppRules(application, rules) then
      if action == "add" then
        app_warnings[#app_warnings + 1] = {
          type = "success",
          text = i18n("custom_categories.new_app_added", {product=info.product, app = application})
        }
      else
        app_warnings[#app_warnings + 1] = {
          type = "success",
          text = i18n("custom_categories.protos_reboot_necessary", {product=info.product})
        }
      end
    else
      app_warnings[#app_warnings + 1] = {
        type = "danger",
        text = i18n("custom_categories.protos_unexpected_error", {product=info.product})
      }
    end
  end
elseif not table.empty(_POST) then
  local custom_categories = getCustomnDPIProtoCategories()

  for k, new_cat in pairs(_POST) do
    if starts(k, "proto_") then
      local id = split(k, "proto_")[2]
      local old_cat
      new_cat = tonumber(split(new_cat, "cat_")[2])

      -- get the current category
      if custom_categories[id] ~= nil then
        old_cat = custom_categories[id]
      else
        old_cat = ntop.getnDPIProtoCategory(tonumber(id))
        old_cat = old_cat and old_cat.id or 0
      end

      if old_cat ~= new_cat then
        -- io.write("Changing nDPI category for " .. id .. ": " .. old_cat .. " -> " .. new_cat .. "\n")
        setCustomnDPIProtoCategory(tonumber(id), new_cat)
      end
    end
  end
end

printMessageBanners(app_warnings)

local function makeApplicationEditor(area_id, required)
  return [[
  <textarea class='form-control' id="]] .. area_id .. [[" spellcheck="false" style='width:100%; height:14em;' ]] .. ternary(required, "required", "") .. [[></textarea>
  ]].. ui_utils.render_notes({
    {content = i18n("custom_categories.each_host_separate_line")},
    {content = i18n("custom_categories.host_domain_or_port")},
    {content = i18n("custom_categories.example_port_range", {example1="udp:443", example2="tcp:1230-1235"})},
    {content = i18n("custom_categories.domain_names_substrings", {s1="ntop.org", s2="mail.ntop.org", s3="ntop.org.example.com"})}
  })
end

print(
  template.gen("modal_confirm_dialog.html", {
    dialog={
      id      = "edit_application_rules",
      action  = "editApplication()",
      title   = i18n("custom_categories.edit_custom_rules"),
      custom_alert_class = "",
      custom_dialog_class = "dialog-body-full-height",
      message = [[<p style='margin-bottom:5px;'>]] ..
        i18n("custom_categories.the_following_is_a_list_of_hosts_app", {application='<i id="selected_application_name"></i>'})..
        [[:</p>]] .. makeApplicationEditor("application-hosts-list"),
      confirm = i18n("save"),
      cancel = i18n("cancel"),
    }
  })
)

print(
  template.gen("modal_confirm_dialog.html", {
    dialog={
      id      = "delete_app_dialog",
      action  = "deleteCustomApp(delete_app_name)",
      title   = i18n("custom_categories.delete_app"),
      message = i18n("custom_categories.delete_app_confirm", {app = "<span id=\"delete_dialog_app_name\"></span>"}),
      confirm = i18n("delete"),
      confirm_button = "btn-danger",
    }
  })
)

-- NOTE: having some rules is required for the application
print[[
  <div id="add-application-dialog" class="modal fade in" role="dialog">
    <div class="modal-dialog">
      <div class="modal-content">
        <div class="modal-header">
          <h5 class="modal-title">]] print(i18n("custom_categories.add_custom_app")) print[[</h5>
          <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
        </div>
        <form id="add-application-form" method="post" data-bs-toggle="validator" onsubmit="return addApplication()">
        <div class="modal-body">
                <input type="hidden" name="csrf" value="]] print(ntop.getRandomCSRFValue()) print[[" />
                <input type="hidden" name="action" value="add">
                <input id="new-custom_hosts" type="hidden" name="custom_hosts">

                <div class="form-group mb-3 has-feedback">
                  <label class="form-label">]] print(i18n("custom_categories.application_name")) print[[</label>
                  <input id="new-application" type="text" name="new_application" class="form-control" required>
                </div>

                <div class="form-group mb-3 has-feedback">
                  <label class="form-label">]] print(i18n("custom_categories.custom_hosts")) print[[</label>
                  ]] print(makeApplicationEditor("new-application-hosts-list", true)) print[[
                </div>

        </div>
        <div class='modal-footer'>
                <button id="new-application-submit" type="submit" class="btn btn-primary">]] print(i18n("custom_categories.add_application")) print[[</button>
        </div>
        </form>
      </div>
    </div>
  </div>
]]

print [[
  <table><tbody><tr>
  <td style="white-space:nowrap; padding-right:1em;">]]
  if catid ~= nil then
    local key = interface.getnDPICategoryName(tonumber(catid))
    print("<h2>"..i18n("users.cat_protocols", {cat=(i18n("ndpi_categories." .. key) or key)}).."</h2>")
  end
  print[[</td>]]

if not isEmptyString(proto_filter) then
  local proto_name = interface.getnDPIProtoName(tonumber(proto_filter))

  print[[<td>
    <form action="]] print(base_url) print [[" method="get">
      <input type="hidden" name="tab" value="protocols" />
      <button type="button" class="btn btn-secondary btn-sm" onclick="$(this).closest('form').submit();">
        <i class="fas fa-times fa-lg" aria-hidden="true" data-original-title="" title=""></i> ]] print(proto_name) print[[
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
      action      = base_url,
      parameters  = {
        ifid = tostring(ifId),
        category = category_filter,
        tab = "protocols",
        custom_hosts = "",
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
  <form id="protos_cat_form" class="w-100 text-end" style="margin-bottom: 0px;" method="post">
    <input type="hidden" name="csrf" value="]] print(ntop.getRandomCSRFValue()) print[[">
    <div id="table-edit-ndpi-applications"></div>
    <button class="btn btn-primary" style="margin-right:1em; margin-left: auto" disabled="disabled" type="submit">]] print(i18n("save_settings")) print[[</button>
  </form>
  ]]

if not has_protos_file then
  print(ui_utils.render_notes({
    {content = i18n("custom_categories.option_needed", {
      option="-p", url="https://www.ntop.org/guides/ntopng/web_gui/categories.html#custom-applications"
    })}
  }))
end

print[[
  <script type="text/javascript">
    aysHandleForm("#protos_cat_form", {
      handle_datatable: true,
    });

  var change_cat_csrf = "]] print(ntop.getRandomCSRFValue()) print[[";
  var selected_application = 0;
  var selected_is_custom = false;
  let delete_app_name = null;

  var select_data = {
]]

for cat_name, cat_id in pairsByKeys(interface.getnDPICategories()) do
   print(cat_id..": '"..cat_name.."', ")
end

print[[

  };

  var url_update = "]] print (ntop.getHttpPrefix()) print [[/lua/admin/get_ndpi_applications.lua?l7proto=]]
  print(proto_filter or "") print("&category=") print(category_filter or "")

  print[[";

  $("#table-edit-ndpi-applications").datatable({
    url: url_update ,
    class: "table table-striped table-bordered table-sm",
    buttons: [ ]]

  if has_protos_file then
    print[['<a id="addApplication" data-bs-target="#add-application-dialog" onclick="showAddApplicationDialog()" role="button" class="add-on btn float-right" data-bs-toggle="modal"><i class="fas fa-plus" aria-hidden="true"></i></a>',]]
  end

  if isEmptyString(proto_filter) then
    graph_utils.printCategoryDropdownButton(true, catid, base_url, page_params, nil,
      true --[[ skip unknown, see get_ndpi_applications.lua ]])
  end
  print[[],
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
              title: "]] print(i18n("category")) print[[",
              field: "column_ndpi_application_category",
              sortable: true,
                css: {
                  textAlign: 'left'
              }
            }, {
              title: "]] print(i18n("custom_categories.custom_hosts")) print[[",
              field: "column_num_hosts",
              hidden: ]] print(ternary(has_protos_file, "false", "true")) print[[,
              sortable: true,
              css: {
                width: '20%',
                textAlign: 'right'
              }
            }, {
              title: "]] print(i18n("actions")) print[[",
              field: "column_actions",
              hidden: ]] print(ternary(has_protos_file, "false", "true")) print[[,
              sortable: false,
                css: {
                  textAlign: 'center',
                  width: '15%',
              }
            }, {
              field: "column_application_hosts",
              hidden: 1,
            }
          ], rowCallback: function(row, data) {
            var actions_td_idx = 6;
            var app_name = data.column_ndpi_application;

            datatableAddActionButtonCallback.bind(row)(actions_td_idx,
            "loadApplications('"+ app_name +"'); $('#selected_application_name').html('"+ app_name +"'); selected_application = '"+ app_name +"'; selected_is_custom = " + data.column_is_custom + "; $('#edit_application_rules').modal('show')", "]] print(i18n("custom_categories.edit_hosts")) print[[");

            if(data.column_is_custom)
              datatableAddDeleteButtonCallback.bind(row)(actions_td_idx, "delete_app_name ='" + app_name + "'; $('#delete_dialog_app_name').html('" + app_name + "'); $('#delete_app_dialog').modal('show');", "]] print(i18n('delete')) print[[");

            return row;
          }
  });

  function getSanitizedHosts(hosts_list) {
    var unique_hosts = [];

    /* Remove duplicate hosts */
    $.each(hosts_list.val().split("\n"), function(i, host) {
      host = NtopUtils.cleanCustomHostUrl(host);

      if(($.inArray(host, unique_hosts) === -1) && host)
        unique_hosts.push(host);
    });

    return(unique_hosts.join(','));
  }

  function editApplication() {
    var params = {};
    params.l7proto = selected_application;
    params.action = "edit";
    params.custom_hosts = getSanitizedHosts($("#application-hosts-list"));
    params.csrf = "]] print(ntop.getRandomCSRFValue()) print[[";

    if(selected_is_custom && !params.custom_hosts) {
      /* Custom applications must have a non-empty rules list as otherwise they
       * would be removed from the protos.txt file. */
      alert("]] print(i18n("custom_categories.non_empty_list_required")) print[[");
      return;
    }

    NtopUtils.paramsToForm('<form method="post"></form>', params).appendTo('body').submit();
  }

  function addApplication() {
    const custom_hosts = getSanitizedHosts($('#new-application-hosts-list'));

    if(!custom_hosts) {
      alert("]] print(i18n("custom_categories.non_empty_list_required")) print[[");
      return(false);
    }

    $('#new-custom_hosts').val(custom_hosts);
  }

  function deleteCustomApp(app_name) {
    var params = {};
    params.l7proto = app_name;
    params.action = "delete";
    params.csrf = "]] print(ntop.getRandomCSRFValue()) print[[";

    NtopUtils.paramsToForm('<form method="post"></form>', params).appendTo('body').submit();
  }

  function loadApplications(app) {
    var data = $("#table-edit-ndpi-applications").data('datatable').resultset;
    var hosts_list = data.data.filter(function(item) {
      return item.column_ndpi_application == app;
    })[0].column_application_hosts;

    $("#application-hosts-list").val(hosts_list.split(",").join("\n"));
  }

  function showAddApplicationDialog() {
    $("#new-application").val("");
    $("#new-application-submit").addClass("disabled");
  }

       </script>

]]

