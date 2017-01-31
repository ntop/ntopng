--
-- (C) 2017 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
local host_pools_utils = require "host_pools_utils"
local template = require "template_utils"

if(ntop.isPro()) then
  package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
  shaper_utils = require "shaper_utils"
end

sendHTTPHeader('text/html; charset=iso-8859-1')

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")
active_page = "admin"
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

if not isAdministrator() then
  return
end

if _POST["edit_pools"] ~= nil then
  local config = paramsPairsDecode(_POST, true)

  for pool_id, pool_name in pairs(config) do
    -- create or rename
    host_pools_utils.createPool(ifId, pool_id, pool_name)

    if(interface.isBridgeInterface(ifId) == true) then
      -- create default shapers
      shaper_utils.setProtocolShapers(ifId,
          pool_id,
          shaper_utils.POOL_SHAPER_DEFAULT_PROTO_KEY,
          shaper_utils.DEFAULT_SHAPER_ID --[[ ingress shaper --]],
          shaper_utils.DEFAULT_SHAPER_ID --[[ egress shaper --]],
          true) -- Set only if the key does NOT exist
    end
  end
  -- Note: do not call reload here
elseif _POST["pool_to_delete"] ~= nil then
  local pool_id = _POST["pool_to_delete"]
  host_pools_utils.deletePool(ifId, pool_id)

  if(interface.isBridgeInterface(ifId) == true) then
    shaper_utils.flushPoolRules(ifId, pool_id)
  end

  -- Note: this will also realod the shaping rules
  interface.reloadHostPools()
elseif (_POST["edit_members"] ~= nil) then
  local pool_to_edit = _POST["pool_id"]
  local config = paramsPairsDecode(_POST, true)

  -- This code handles member address changes

  -- delete old addresses
  for k,old_member in pairs(config) do
    if not starts(k, "_") then
      if((not isEmptyString(old_member)) and (k ~= old_member)) then
        host_pools_utils.deleteFromPoll(ifId, pool_to_edit, old_member)
      end
    end
  end

  -- add new addresses
  for new_member,k in pairs(config) do
    if not starts(new_member, "_") then
      local is_new_member = (k ~= new_member)

      if is_new_member then
        host_pools_utils.addToPool(ifId, pool_to_edit, new_member)
      end

      local host_key, is_network = host_pools_utils.getMemberKey(new_member)

      if not is_network then
        local alias = config["_alias_" .. new_member]
        if((not is_new_member) or (not isEmptyString(alias))) then
          setHostAltName(host_key, alias)
        end

        local icon = config["_icon_" .. new_member]
        if((not is_new_member) or (not isEmptyString(icon))) then
          setHostIcon(host_key, icon)
        end
      end
    end
  end

  interface.reloadHostPools()
elseif (_POST["member_to_delete"] ~= nil) then
  local pool_to_edit = _POST["pool_id"]

  host_pools_utils.deleteFromPoll(ifId, pool_to_edit, _POST["member_to_delete"])
  interface.reloadHostPools()
end

function printPoolNameField(pool_id_str)
  print[[<div class="form-group has-feedback" style="margin-bottom:0;">]]
  print[[<input name="pool_' + ]] print(pool_id_str) print[[ + '" class="form-control" spellcheck="false" data-unique="unique" placeholder="]] print(i18n("host_pools.specify_pool_name")) print[[" required/>]]
  print[[<div class="help-block with-errors" style="margin-bottom:0;"></div>]]
  print[[</div>]]
end

function printMemberAddressField(member_str, origin_value_str)
  print[[<div class="form-group has-feedback" style="margin-bottom:0;">]]
  print[[<input name="member_' + ]] print(member_str) print[[ + '" class="form-control" spellcheck="false" data-address="address" data-member="member" placeholder="]] print(i18n("host_pools.specify_member_address")) print[["]]
  if not isEmptyString(origin_value_str) then
    print[[ data-origin-value="' + ]] print(origin_value_str) print[[ + '"]]
  end
  print[[ required/>]]
  print[[<div class="help-block with-errors" style="margin-bottom:0;"></div>]]
  print[[</div>]]
end

function printMemberVlanField(member_str)
  print[[<div class="form-group has-feedback" style="margin-bottom:0;">]]
  print[[<input name="member_' + ]] print(member_str) print[[ + '_vlan" class="form-control text-right" data-member="member" style="width:5em; padding-right:1em; margin: 0 auto;" type="number" min="0" value="0" required/>]]
  print[[<div class="help-block with-errors" style="margin-bottom:0;"></div>]]
  print[[</div>]]
end

function printIconField(member_str)
  print[[<select name="icon_member_' + ]] print(member_str) print[[ + '" class="form-control">]]
  for k,v in getHostIcons() do
      print[[<option value="]] print(v) print[["]]
      if(v == icon) then print[[ selected]] end
      print[[>]] print(k) print[[</option>]]
  end
  print[[</select>]]
end

function printAliasField(member_str)
  print[[<input name="alias_member_' + ]] print(member_str) print[[ + '" class="form-control" />]]
end

--------------------------------------------------------------------------------

local selected_pool_id = _GET["pool"]

local selected_pool = nil
local available_pools = host_pools_utils.getPoolsList(ifId)

for _, pool in ipairs(available_pools) do
  if pool.id == selected_pool_id then
    selected_pool = pool
  end
end

if selected_pool == nil then
  if #available_pools == 1 then
    -- only the default pool is available
    selected_pool = available_pools[1]
  else
    selected_pool = available_pools[2]
  end
end

local perPageMembers
if tonumber(tablePreferences("hostPoolMembers")) == nil then
  perPageMembers = "10"
else
  perPageMembers = tablePreferences("hostPoolMembers")
end

local member_filtering = _GET["member"]

--------------------------------------------------------------------------------

print [[
<hr>
<h2>]] print(i18n("host_pools.edit_host_pools")) print[[</h2>
<br>
  <ul id="hostPoolsNav" class="nav nav-tabs" role="tablist">
    <li><a data-toggle="tab" role="tab" href="#manage">]] print(i18n("host_pools.manage_pools")) print[[</a></li>
    <li><a data-toggle="tab" role="tab" href="#create">]] print(i18n("host_pools.create_pools")) print[[</a></li>
  </ul>
  <div class="tab-content">
    <div id="manage" class="tab-pane">
<br/><table><tbody><tr>
]]

print('<td style="white-space:nowrap;">') print(i18n("host_pools.pool")) print(': <select id="pool_selector" class="form-control pool-selector" style="display:inline;" onchange="document.location.href=\'?pool=\' + $(this).val() + \'#manage\';">')
local no_pools = true
for _,pool in ipairs(available_pools) do
  if pool.id ~= host_pools_utils.DEFAULT_POOL_ID then
    print('<option value="'..tostring(pool.id)..'"')
    if pool.id == selected_pool.id then
      print(" selected")
    end
    print('>'..(pool.name)..'</option>\n')
    no_pools = false
  end
end
print('</select>')

local ifstats = interface.getStats()
local is_bridge_iface = (ifstats["bridge.device_a"] ~= nil) and (ifstats["bridge.device_b"] ~= nil)
if is_bridge_iface then
  print("<a href='/lua/if_stats.lua?page=filtering&pool="..(selected_pool.id).."#protocols' title='Manage Traffic Policies'><i class='fa fa-exchange fa-lg' aria-hidden='true'></i></a>")
end

print('</td>\n')
if member_filtering ~= nil then
  local member_name = split(member_filtering, "/")[1]
  print[[
  <td>
    <form action="?pool=]] print(selected_pool.id) print[[#manage">
      <button type="button" class="btn btn-default btn-sm" onclick="$(this).closest('form').submit();">
        <i class="fa fa-close fa-lg" aria-hidden="true" data-original-title="" title=""></i> Filter: ]] print(member_name) print[[
      </button>
    </form>
  </td>
  ]]
end
print('<div style="float:right;">')
print(
  template.gen("typeahead_input.html", {
    typeahead={
      base_id     = "t_member",
      action      = "/lua/admin/host_pools.lua#manage",
      parameters  = {pool=selected_pool.id},
      json_key    = "key",
      query_field = "member",
      query_url   = ntop.getHttpPrefix() .. "/lua/find_member.lua",
      query_title = i18n("host_pools.search_member"),
      style       = "margin-left:1em; width:25em;",
    }
  })
)
print('</div>')
print('</tr></tbody></table>')

if no_pools then
  print[[<script>$("#pool_selector").attr("disabled", "disabled");</script>]]
end

  print[[
      <form id="table-manage-form">
        <br/><div id="table-manage"></div>
        <button class="btn btn-primary" style="float:right; margin-right:1em;" disabled="disabled" type="submit">]] print(i18n("save_settings")) print[[</button>
      </form>
]]

print[[
      <br/><br/>
    </div>
    <div id="create" class="tab-pane">
      <form id="table-create-form">
        <br/><div id="table-create"></div>
        <button class="btn btn-primary" style="float:right; margin-right:1em;" disabled="disabled" type="submit">]] print(i18n("save_settings")) print[[</button>
      </form>
      <br/><br/>]]

if isCaptivePortalActive() then
  print[[
      NOTES:
      <ul>
        <li>A pool cannot be deleted if there is any Captive Portal user associated. Manage Captive Portal users <a href="]] print(ntop.getHttpPrefix()) print[[/lua/admin/users.lua?captive_portal_users=1">here</a>.</li>
      </ul>
  ]]
end

print[[
    </div>
  </div>
]]

-- Create delete dialogs

print(
  template.gen("modal_confirm_dialog.html", {
    dialog={
      id      = "delete_pool_dialog",
      action  = "deletePool(delete_pool_id)",
      title   = i18n("host_pools.delete_pool"),
      message = i18n("host_pools.confirm_delete_pool") .. ' "<span id=\"delete_pool_dialog_pool\"></span>", ' .. i18n("host_pools.and_associated_members"),
      confirm = i18n("delete"),
    }
  })
)

print(
  template.gen("modal_confirm_dialog.html", {
    dialog={
      id      = "delete_member_dialog",
      action  = "deletePoolMember(delete_member_id)",
      title   = i18n("host_pools.remove_member"),
      message = i18n("host_pools.confirm_remove_member") .. ' "<span id=\"delete_member_dialog_member\"></span>" ' .. i18n("host_pools.from_pool") .. ' "' .. selected_pool.name .. '" ',
      confirm = i18n("remove"),
    }
  })
)

--------------------------------------------------------------------------------

print[[
  <script>
    function recheckFields(input) {
      var member = input.val();
      var tr = input.closest("tr");
      var vlan_field = tr.find("td:nth-child(2) input");
      var icon_field = tr.find("td:nth-child(3) input");
      var select_field = tr.find("td:nth-child(4) select");
      var vlanicon_disabled = null;

      if (is_mac_address(member)) {
        vlan_field.attr("disabled", true);
        vlanicon_disabled = false;
      } else {
        var is_cidr = is_network_mask(member, true);

        if (is_cidr) {
          vlan_field.removeAttr("disabled");

          if ((is_cidr.type == "ipv4" && is_cidr.mask != 32) ||
             ((is_cidr.type == "ipv6" && is_cidr.mask != 128)))
            vlanicon_disabled = true
          else
            vlanicon_disabled = false;
        }
      }

      if (vlanicon_disabled != null) {
        icon_field.attr("disabled", vlanicon_disabled);
        select_field.attr("disabled", vlanicon_disabled);
      }
    }
    
    /* Make the pair address,vlan unique */
    function addressValidator(input) {
      var member = input.val();

      /* this will be checked separately */
      if (! member)
        return true;

      recheckFields(input);
      return is_mac_address(member) || is_network_mask(member, true);
    }
  
    function memberValidator(input) {
      var member = input.val();

      /* this will be checked separately */
      if (! member)
        return true;

      var is_mac = is_mac_address(member);
      var identifier;

      if(is_mac) {
        identifier = member;
      } else {
        var address_value;
        var vlan_value;
        
        if (input.attr("name").endsWith("_vlan")) {
          var name = input.attr("name").split("_vlan")[0];
          address_value = $("input[name='" + name + "']", $("#table-manage-form")).val();
          vlan_value = member;
        } else {
          var name = input.attr("name") + "_vlan";
          address_value = member;
          vlan_value = $("input[name='" + name + "']", $("#table-manage-form")).val();
        }

        is_cidr = is_network_mask(address_value, true);
        if (! is_cidr)
           /* this will be handled by addressValidator */
          return true;
        identifier = is_cidr.address + "/" + is_cidr.mask + "@" + vlan_value;
      }

      identifier = identifier.toLowerCase();
      var count = 0;

      $('input[name^="member_"]:not([name$="_vlan"])', $("#table-manage-form")).each(function() {
        var address_value = $(this).val();
        var is_cidr = is_network_mask(address_value, true);

        var aggregated;
        if (! is_cidr) {
          aggregated = address_value;
        } else {
          var name = $(this).attr("name") + "_vlan";
          vlan_value = $("input[name='" + name + "']", $("#table-manage-form")).val();
          aggregated = is_cidr.address + "/" + is_cidr.mask + "@" + vlan_value;
        }
        aggregated = aggregated.toLowerCase()

        if (aggregated === identifier)
          count++;
      });

      return count == 1;
    }
]]
if member_filtering ~= nil then
  print[[$("#pool_selector").attr("disabled", true);]]
end
print[[
  </script>
]]

-- ==== Manage tab ====

print [[

  <script>
    var addedMemberCtr = 0;

    function addPoolMember() {
      if (datatableIsEmpty("#table-manage"))
         datatableRemoveEmptyRow("#table-manage");

      var member_id = addedMemberCtr++;
      var newid = "member_" + member_id;

      var tr = $('<tr id=' + newid + '><td>]] printMemberAddressField('member_id') print[[</td><td class="text-center">]] printMemberVlanField('member_id') print[[</td><td>]] printAliasField('member_id') print[[</td><td>]] printIconField('member_id') print[[</td><td class="text-center"></td></tr>');
      datatableAddDeleteButtonCallback.bind(tr)(5, "datatableUndoAddRow('#" + newid + "', ']] print(i18n("host_pools.empty_pool")) print[[', '#addPoolMemberBtn')", "]] print(i18n('undo')) print[[");
      $("#table-manage table").append(tr);
      $("input", tr).first().focus();

      var icon = $("td:nth-child(4)", tr);
      var icon_input = $("select", icon).first();

      aysRecheckForm("#table-manage-form");
    }

    function deletePoolMember(member_id) {
      var form = $("#table-manage-form");
      var field = form.find("input[name='member_" + member_id + "']");

      if (field.attr("data-origin-value")) {
        var params = {};
        params.pool_id = ]] print(selected_pool.id) print[[;
        params.member_to_delete = field.attr("data-origin-value");
        params.csrf = "]] print(ntop.getRandomCSRFValue()) print[[";
        paramsToForm('<form method="post" action="?pool=]] print(selected_pool.id) print[["></form>', params).appendTo('body').submit();
      }
    }

    $("#table-manage").datatable({
      url: "]]
   print (ntop.getHttpPrefix())
   print [[/lua/get_host_pools.lua?ifid=]] print(ifId.."") print[[&pool=]] print(selected_pool.id) print[[&member=]] print(_GET["member"] or "") print[[",
      title: "",
      perPage: ]] print(perPageMembers) print[[,
      forceTable: true,
      
      buttons: [
         '<a id="addPoolMemberBtn" onclick="addPoolMember()" role="button" class="add-on btn" data-toggle="modal"><i class="fa fa-plus" aria-hidden="true"></i></a>'
      ], columns: [
         {
            title: "]] print(i18n("host_pools.member_address")) print[[",
            field: "column_member",
            css: {
               textAlign: 'left',
            }
         }, {
            title: "VLAN",
            field: "column_vlan",
            css: {
               width: '1%',
               textAlign: 'center',
            }
         }, {
            title: "Alias",
            field: "column_alias",
            css: {
              width: '25%',
              textAlign: 'center',
            }
         }, {
            title: "Device Type",
            field: "column_icon",
            css: {
              width: '12%',
              textAlign: 'center',
            }
         }, {
            title: "]] print(i18n("actions")) print[[",
            css : {
               width: '20%',
               textAlign: 'center',
            }
         } , {
            field: "column_link",
            hidden: true,
         }
      ], tableCallback: function() {
        var no_pools = false;

        if (]] print(selected_pool.id) print[[ == ]] print(host_pools_utils.DEFAULT_POOL_ID) print[[) {
          datatableAddEmptyRow("#table-manage", "]] print(i18n("host_pools.no_pools_defined") .. " " .. i18n("host_pools.create_pool_hint")) print[[");
          no_pools = true;
        } else if(datatableIsEmpty("#table-manage")) {
          datatableAddEmptyRow("#table-manage", "]] print(i18n("host_pools.empty_pool")) print[[");
        } else {
          datatableForEachRow("#table-manage", function() {
            var member_address = $("td:nth-child(1)", $(this));
            var vlan = $("td:nth-child(2)", $(this));
            var alias = $("td:nth-child(3)", $(this));
            var icon = $("td:nth-child(4)", $(this));
            var link_value = $("td:nth-child(6)", $(this)).html().replace(/&nbsp;/gi,'');

            var member_id = addedMemberCtr++;

            /* Make member name editable */
            var value = member_address.html();
            var is_cidr = is_network_mask(value);
            if (is_cidr) {
              old_value = member_address.html() + '@' + vlan.html();
              if (((is_cidr.type == "ipv4" && is_cidr.mask == 32)) ||
                 ((is_cidr.type == "ipv6" && is_cidr.mask == 128)))
                value = is_cidr.address;
            } else {
              old_value = member_address.html();
            }
            var input = $(']] printMemberAddressField('member_id', 'old_value') print[[');
            var address_input = $("input", input).first();
            address_input.val(value);
            member_address.html(input);

            /* Alias field */
            var input = $(']] printAliasField('member_id') print[[');
            input.val(alias.html().replace(/&nbsp;/gi,''));
            alias.html(input);

            /* Icon field */
            var input = $(']] printIconField('member_id') print[[');
            input.val(icon.html().replace(/&nbsp;/gi,''));
            icon.html(input);

            /* Make vlan editable */
            var input = $(']] printMemberVlanField('member_id') print[[');
            var vlan_value = parseInt(vlan.html());
            $("input", input).first().val(vlan_value);
            vlan.html(input);

            recheckFields(address_input);

            if ((vlan_value > 0) && (is_cidr))
              value = value + " [VLAN " + vlan_value + "]";

            if (link_value)
              datatableAddLinkButtonCallback.bind(this)(5, link_value, "View");
            datatableAddDeleteButtonCallback.bind(this)(5, "delete_member_id ='" + member_id + "'; $('#delete_member_dialog_member').html('" + value +"'); $('#delete_member_dialog').modal('show');", "]] print(i18n('delete')) print[[");
          });

          aysResetForm('#table-manage-form');
        }

        $("#addPoolMemberBtn").attr("disabled", ((! datatableIsLastPage("#table-manage-form")) || (no_pools)) || (]] if member_filtering ~= nil then print("true") else print("false") end print[[));

        $("#table-manage-form")
            .validator(validator_options)
            .on('submit', checkManagePoolForm);
      }
    });

    function checkManagePoolForm(event) {
      if (event.isDefaultPrevented())
        return false;

      var form = $("#table-manage-form");
      
      // build the settings object
      var settings = {};
      $('input[name^="member_"]:not([name$="_vlan"])', form).each(function() {
        var address = null;

        if((member = is_network_mask($(this).val(), true))) {
          /* this is a network */
          var vlan_name = $(this).attr("name") + "_vlan";
          var vlan_field = $("input[name=" + vlan_name + "]", form);
          if (vlan_field.length == 1)
            address = member.address + "/" + member.mask + "@" + vlan_field.val();
        } else {
          /* this is a mac */
          address = $(this).val();
        }

        var original;
        if($(this).attr("data-origin-value"))
          original = $(this).attr("data-origin-value");
        else
          original = "";

        if (address !== null) {
          var alias_name = "alias_" + $(this).attr("name");
          var alias_field = $("input[name=" + alias_name + "]", form);
          var alias = alias_field.val();

          var icon_name = "icon_" + $(this).attr("name");
          var icon_field = $("select[name=" + icon_name + "]", form);
          var icon = icon_field.val();

          settings[address] = original;
          settings["_alias_" + address] = alias;
          settings["_icon_" + address] = icon;
        }
      });

      // reset ays so that we can submit a custom form
      aysResetForm(form);

      // create a form with key-values encoded
      var params = paramsPairsEncode(settings);
      params.edit_members = "";
      params.pool_id = ]] print(selected_pool.id) print[[;
      params.csrf = "]] print(ntop.getRandomCSRFValue()) print[[";
      paramsToForm('<form method="post"></form>', params).appendTo('body').submit();
      return false;
    }
  </script>
]]

-- ==== Create tab ====

print [[
  <script>
    var nextPoolId = 1;
    var maxPoolNum = ]] print(tostring(host_pools_utils.MAX_NUM_POOLS)) print[[;

    function deletePool(pool_id) {
      var params = {};
      params.pool_to_delete = pool_id;
      params.csrf = "]] print(ntop.getRandomCSRFValue()) print[[";

      var form = paramsToForm('<form method="post"></form>', params);
      if (pool_id == ]] print(selected_pool.id) print[[)
        form.attr("action", "?#create");

      form.appendTo('body').submit();
    }

    function onPoolAddUndo(newid) {
      var pool_id = parseInt(newid.split("added_pool_")[1]);
      if (pool_id)
        nextPoolId = Math.min(nextPoolId, pool_id);
    }

    function addPool() {
      var pool_id = nextPoolId;

      while (nextPoolId < maxPoolNum) {
        nextPoolId = nextPoolId+1;

        // find a new gap
        if ($("#table-create input[name='pool_" + nextPoolId +"']").length == 0)
          break;
      }

      if (datatableIsEmpty("#table-create"))
         datatableRemoveEmptyRow("#table-create");

      if (pool_id < maxPoolNum) {
        var newid = "added_pool_" + pool_id;

        var tr = $('<tr id=' + newid + '><td class="text-center hidden">' + pool_id + '</td><td>]] printPoolNameField('pool_id') print[[</td><td class="hidden"></td><td class="text-center"></td></tr>');
        datatableAddDeleteButtonCallback.bind(tr)(4, "datatableUndoAddRow('#" + newid + "', ']] print(i18n("host_pools.no_pools_defined")) print[[', '#addNewPoolBtn', 'onPoolAddUndo')", "]] print(i18n('undo')) print[[");
        datatableOrderedInsert("#table-create table", 1, tr, pool_id);
        $("input", tr).focus();

        aysRecheckForm("#table-create-form");
      }

      recheckPoolAddButton();
    }

    function recheckPoolAddButton() {
      if(nextPoolId >= maxPoolNum)
        $("#addNewPoolBtn").attr("disabled", "disabled");
    }

    $("#table-create").datatable({
      url: "]]
   print (ntop.getHttpPrefix())
   print [[/lua/get_host_pools.lua?ifid=]] print(ifId.."") print[[",
      title: "",
      perPage: 5,
      hidePerPage: true,
      hideDetails: true,
      showPagination: false,
      perPage: maxPoolNum,
      forceTable: true,

      buttons: [
         '<a id="addNewPoolBtn" onclick="addPool()" role="button" class="add-on btn" data-toggle="modal"><i class="fa fa-plus" aria-hidden="true"></i></a>'
      ], columns: [
         {
            field: "column_pool_id",
            hidden: true,
         }, {
            title: "]] print(i18n("host_pools.pool_name")) print[[",
            field: "column_pool_name",
            css: {
               textAlign: 'left',
               width: '50%',
            }
         }, {
            field: "column_pool_undeletable",
            hidden: true,
         }, {
            title: "]] print(i18n("actions")) print[[",
            css : {
               width: '15%',
               textAlign: 'center',
            }
         }, {
           field: "column_pool_link",
           hidden: true,
         }
      ], tableCallback: function() {
        if(datatableIsEmpty("#table-create")) {
          datatableAddEmptyRow("#table-create", "]] print(i18n("host_pools.no_pools_defined")) print[[");
        } else {
         datatableForEachRow("#table-create", function() {
            var pool_id = $("td:nth-child(1)", $(this)).html();
            var pool_name = $("td:nth-child(2)", $(this));
            var pool_undeletable = $("td:nth-child(3)", $(this)).html() === "true";
            var pool_link = $("td:nth-child(5)", $(this)).html();

            /* Make pool name editable */
            var input = $(']] printPoolNameField('pool_id') print[[');
            var value = pool_name.html();
            $("input", input).first().val(value);
            pool_name.html(input);

            if (pool_id == ]]  print(host_pools_utils.DEFAULT_POOL_ID) print[[) {
              $("input", input).first().attr("disabled", "disabled");
            } else {
              datatableAddLinkButtonCallback.bind(this)(4, pool_link, "View");
              datatableAddDeleteButtonCallback.bind(this)(4, "delete_pool_id ='" + pool_id + "'; $('#delete_pool_dialog_pool').html('" + value + "'); $('#delete_pool_dialog').modal('show');", "]] print(i18n('delete')) print[[");

              if (pool_undeletable)
                $("td:nth-child(4) a", $(this)).last().attr("disabled", "disabled");
            }
         });

         /* pick the first unused pool ID */
         $("#table-create td:nth-child(1)").each(function() {
            var this_pool_id = parseInt($(this).html());
            if(nextPoolId == this_pool_id)
               nextPoolId += 1;
         });

         aysResetForm('#table-create-form');
        }

        recheckPoolAddButton();
        $("#table-create-form")
          .validator(validator_options)
          .on('submit', checkCreatePoolForm);
      }
    });

    function checkCreatePoolForm(event) {
      if (event.isDefaultPrevented())
        return false;

      var form = $("#table-create-form");
      
      // build the settings object
      var settings = {};
      $("input[name^='pool_']", form).each(function() {
        var pool_id = $(this).attr("name").split("pool_")[1];
        settings[pool_id] = $(this).val();
      });

      // reset ays so that we can submit a custom form
      aysResetForm(form);

      // create a form with key-values encoded
      var params = paramsPairsEncode(settings);
      params.edit_pools = "";
      params.csrf = "]] print(ntop.getRandomCSRFValue()) print[[";
      paramsToForm('<form method="post"></form>', params).appendTo('body').submit();

      return false;
    }

    var validator_options = {
      disable: true,
      custom: {
         member: memberValidator,
         address: addressValidator,
         unique: makeUniqueValidator(function(field) {
            return $('input[name^="pool_"]', $("#table-create-form"));
         }),
      }, errors: {
         member: "]] print(i18n("host_pools.duplicate_member")) print[[.",
         address: "]] print(i18n("host_pools.invalid_member")) print[[.",
         unique: "]] print(i18n("host_pools.duplicate_pool")) print[[.",
      }
    }
  </script>
]]

print[[
  <script>
    handle_tab_state($("#hostPoolsNav"), "manage");

    aysHandleForm("form", {
      handle_datatable: true,
      handle_tabs: true,
      ays_options: {addRemoveFieldsMarksDirty: true}
    });

    /* Retrigger the validation every second to clear outdated errors */
    setInterval(function() {
      $("form:data(bs.validator)").each(function(){
        $(this).data("bs.validator").validate();
      });
    }, 1000);
  </script>
]]

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
