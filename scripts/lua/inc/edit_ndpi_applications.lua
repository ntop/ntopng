--
-- (C) 2017-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "graph_utils"
local template = require "template_utils"

local proto_filter = _GET["l7proto"]
local category_filter = _GET["category"]
local protos_utils = require("protos_utils")
local info = ntop.getInfo()
local has_protos_file = protos_utils.hasProtosFile()

local ifId = getInterfaceId(ifname)

if not haveAdminPrivileges() then
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

if (_POST["action"] == "add") or (_POST["action"] == "edit") then
  local action = _POST["action"]
  local hosts_list = _POST["custom_hosts"]
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
  <textarea id="]] .. area_id .. [[" spellcheck="false" style='width:100%; height:14em;' ]] .. ternary(required, "required", "") .. [[></textarea><br><br>
  ]].. i18n("notes") ..[[
  <ul>
  <li>]].. i18n("custom_categories.each_host_separate_line") .. [[</li>
  <li>]].. i18n("custom_categories.host_domain_or_port") .. [[</li>
  <li>]].. i18n("custom_categories.example_port_range", {example1="udp:443", example2="tcp:1230-1235"}) .. [[</li>
  <li>]].. i18n("custom_categories.domain_names_substrings", {s1="ntop.org", s2="mail.ntop.org", s3="ntop.org.example.com"}) ..[[</li>
  </ul>]]
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

-- NOTE: having some rules is required for the application
print[[
  <div id="add-application-dialog" class="modal fade in" role="dialog">
    <div class="modal-dialog">
      <div class="modal-content">
        <div class="modal-header">
          <h3 class="modal-title">]] print(i18n("custom_categories.add_custom_app")) print[[</h3>
          <button type="button" class="close" data-dismiss="modal">&times;</button>
        </div>
        <div class="modal-body">
          <div class="container-fluid">
            <form id="add-application-form" method="post" data-toggle="validator" onsubmit="$('#new-custom_hosts').val(getSanitizedHosts($('#new-application-hosts-list')))">
              <input type="hidden" name="csrf" value="]] print(ntop.getRandomCSRFValue()) print[[" />
              <input type="hidden" name="action" value="add">
              <input id="new-custom_hosts" type="hidden" name="custom_hosts">

              <div class="row form-group has-feedback">
                <label class="form-label">]] print(i18n("custom_categories.application_name")) print[[</label>
                <input id="new-application" type="text" name="new_application" class="form-control" required>
              </div>

              <div class="row form-group has-feedback">
                <label class="form-label">]] print(i18n("custom_categories.custom_hosts")) print[[</label>
                ]] print(makeApplicationEditor("new-application-hosts-list", true)) print[[
              </div>

              <div class="form-group">
                <button id="new-application-submit" type="submit" class="btn btn-primary btn-block">]] print(i18n("custom_categories.add_application")) print[[</button>
              </div>
            </div>
          </form>
        </div>
      </div>
    </div>
  </div>
]]

print [[<br>
<table><tbody><tr>
  <td style="white-space:nowrap; padding-right:1em;">]]
  if catid ~= nil then
    print("<h2>"..i18n("users.cat_protocols", {cat=interface.getnDPICategoryName(tonumber(catid))}).."</h2>")
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
  <form id="protos_cat_form" lass="form-inline" style="margin-bottom: 0px;" method="post">
    <input type="hidden" name="csrf" value="]] print(ntop.getRandomCSRFValue()) print[[">
    <div id="table-edit-ndpi-applications"></div>
    <button class="btn btn-primary" style="float:right; margin-right:1em; margin-left: auto" disabled="disabled" type="submit">]] print(i18n("save_settings")) print[[</button>
  </form>
  ]]

print(i18n("notes"))
print[[<ul>]]
if has_protos_file then
  print[[<li>]] print(i18n("custom_categories.delete_note")) print[[</li>]]
else
  print[[<li>]] print(i18n("custom_categories.option_needed", {
    option="-p", url="https://www.ntop.org/guides/ntopng/web_gui/categories.html#custom-applications"
  })) print[[</li>]]
end
print[[</ul>]]

print[[
  <br/><br/>
  <script type="text/javascript">
    aysHandleForm("#protos_cat_form", {
      handle_datatable: true,
    });

  var change_cat_csrf = "]] print(ntop.getRandomCSRFValue()) print[[";
  var selected_application = 0;

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
    print[['<a id="addApplication" onclick="showAddApplicationDialog()" role="button" class="add-on btn float-right" data-toggle="modal"><i class="fas fa-plus" aria-hidden="true"></i></a>',]]
  end

  if isEmptyString(proto_filter) then
    printCategoryDropdownButton(true, catid, base_url, page_params, nil,
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
            "loadApplications('"+ app_name +"'); $('#selected_application_name').html('"+ app_name +"'); selected_application = '"+ app_name +"'; $('#edit_application_rules').modal('show')", "]] print(i18n("custom_categories.edit_hosts")) print[[");

            return row;
          }
  });

  function getSanitizedHosts(hosts_list) {
    var unique_hosts = [];

    /* Remove duplicate hosts */
    $.each(hosts_list.val().split("\n"), function(i, host) {
      host = cleanCustomHostUrl(host);

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

    paramsToForm('<form method="post"></form>', params).appendTo('body').submit();
  }

  function loadApplications(app) {
    var data = $("#table-edit-ndpi-applications").data('datatable').resultset;
    var hosts_list = data.data.filter(function(item) {
      return item.column_ndpi_application == app;
    })[0].column_application_hosts;

    $("#application-hosts-list").val(hosts_list.split(",").join("\n"));
  }

  function showAddApplicationDialog() {
    $("#add-application-dialog").modal("show");
    $("#new-application").val("");
    $("#new-application-submit").addClass("disabled");
  }

       </script>

]]

