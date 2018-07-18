--
-- (C) 2017-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
local host_pools_utils = require "host_pools_utils"
local discover = require "discover_utils"
local template = require "template_utils"
local ts_utils = require "ts_utils"

if(ntop.isPro()) then
  package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
  shaper_utils = require "shaper_utils"
end

-- Administrator check
if not isAdministrator() then
  return
end

local pool_add_warnings = {}

if _POST["edit_pools"] ~= nil then
  local config = paramsPairsDecode(_POST, true)

  for pool_id, pool_name in pairs(config) do
    -- Filter pool ids only
    if tonumber(pool_id) ~= nil then
      local children_safe = nil
      if config["_csafe_"..pool_id] ~= nil then
        children_safe = config["_csafe_"..pool_id]
      end

      local enforce_quotas_per_pool_member = nil
      if config["_qts_per_member_"..pool_id] ~= nil then
        enforce_quotas_per_pool_member = config["_qts_per_member_"..pool_id]
      end

      local enforce_shapers_per_pool_member = nil
      if config["_shp_per_member_"..pool_id] ~= nil then
        enforce_shapers_per_pool_member = config["_shp_per_member_"..pool_id]
      end

      host_pools_utils.createPool(ifId, pool_id, pool_name, children_safe,
				  enforce_quotas_per_pool_member, enforce_shapers_per_pool_member, true --[[ create or rename ]])

      if(interface.isBridgeInterface(ifId) == true) then
        -- create default shapers
        shaper_utils.initDefaultShapers(ifid, pool_id)
      end
    end
  end

  -- Reload is required here to load the new metadata
  interface.reloadHostPools()
elseif _POST["pool_to_delete"] ~= nil then
  local pool_id = _POST["pool_to_delete"]
  host_pools_utils.deletePool(ifId, pool_id)

  if(interface.isBridgeInterface(ifId) == true) then
    shaper_utils.flushPoolRules(ifId, pool_id)
  end

  -- Note: this will also reload the shaping rules
  interface.reloadHostPools()
elseif (_POST["edit_members"] ~= nil) then
  local pool_to_edit = _POST["pool"]
  local config = paramsPairsDecode(_POST, true)

  local sanitized = {}

  -- Sanitize parameters
  for new_member, value in pairs(config) do
    if not isValidPoolMember(new_member) then
      http_lint.validationError(_POST, "new_member", new_member, "Invalid pool member")
    end

    local parts = split(value, "|")

    if #parts ~= 3 then
      http_lint.validationError(_POST, "member_values", parts, "Invalid member values")
    end

    local assembled = {
      old_member = parts[1],
      alias = parts[2],
      icon = parts[3],
    }

    -- Convention: use uppercase letters for mac, lowercase for ip
    if isMacAddress(new_member) then
      new_member = string.upper(new_member)
    else
      new_member = string.lower(new_member)
    end

    if (not isEmptyString(old_member)) and (not isValidPoolMember(assembled.old_member)) then
      http_lint.validationError(_POST, "old_member", new_member, "Invalid pool member")
    end

    if not http_lint.validateUnchecked(assembled.alias) then
      http_lint.validationError(_POST, "alias", assembled.alias, "Invalid member alias")
    end

    if not http_lint.validateSingleWord(assembled.icon) then
      http_lint.validationError(_POST, "icon", assembled.icon, "Invalid member icon")
    end

    local hostinfo = hostkey2hostinfo(new_member)
    local network, prefix = splitNetworkPrefix(hostinfo.host)
    local already_added = false

    if prefix ~= nil then
      local masked = ntop.networkPrefix(network, prefix)
      if masked ~= network then
        -- Normalize new networks (extract their prefix)
        local new_key = host2member(masked, hostinfo.vlan, prefix)

        pool_add_warnings[#pool_add_warnings + 1] = i18n("host_pools.network_normalized", {
          network = hostinfo2hostkey(hostkey2hostinfo(new_member)),
          network_normalized = hostinfo2hostkey(hostkey2hostinfo(new_key))
        })

        sanitized[new_key] = assembled
        already_added = true
      end
    end

    if not already_added then
      sanitized[new_member] = assembled
    end
  end

  config = sanitized

  -- This code handles member address changes

  -- delete old addresses
  for k,value in pairs(table.clone(config) --[[ Work on a copy to modify the original while iterating ]]) do
    local old_member = value.old_member

    if((not isEmptyString(old_member)) and (k ~= old_member)) then
      if config[old_member] then
        -- Do not delete and re-add members which have only changed their list key
        config[old_member].old_member = old_member
      else
        host_pools_utils.deletePoolMember(ifId, pool_to_edit, old_member)
      end
    end
  end

  -- add new addresses
  for new_member,value in pairs(config) do
    local k = value.old_member

    local is_new_member = (k ~= new_member)

    if is_new_member then
      local res, info = host_pools_utils.addPoolMember(ifId, pool_to_edit, new_member)

      if (res == false) and (info.existing_member_pool ~= nil) then
        -- remove @0
        local member_to_print = hostinfo2hostkey(hostkey2hostinfo(new_member))
        pool_add_warnings[#pool_add_warnings + 1] = i18n("host_pools.member_exists", {
          member_name = member_to_print,
          member_pool = host_pools_utils.getPoolName(ifId, info.existing_member_pool)
        })
      end
    end

    local host_key, is_network = host_pools_utils.getMemberKey(new_member)

    if not is_network then
      local alias = value.alias
      local skip_alias = false

      if isMacAddress(new_member) then
        local manuf = ntop.getMacManufacturer(new_member)
        if (manuf ~= nil) and (manuf.extended == alias) then
          -- this is not the alias, it is the manufacturer
          skip_alias = true
        end
      end

      if(((not is_new_member) or (not isEmptyString(alias))) and (not skip_alias)) then
        setHostAltName(host_key, alias)
      end

      local icon = tonumber(value.icon)

      if (not isEmptyString(icon))
            and ((not is_new_member) or (icon ~= 0))
            and isMacAddress(new_member)
            and new_member ~= "00:00:00:00:00:00" then
        setCustomDeviceType(new_member, icon)
        interface.setMacDeviceType(new_member, icon, true --[[ overwrite ]])
      end
    end
  end

  interface.reloadHostPools()
elseif _POST["member_to_delete"] ~= nil then
  local pool_to_edit = _POST["pool"]

  host_pools_utils.deletePoolMember(ifId, pool_to_edit, _POST["member_to_delete"])
  interface.reloadHostPools()
elseif _POST["empty_pool"] ~= nil then
  host_pools_utils.emptyPool(ifId, _POST["empty_pool"])
  interface.reloadHostPools()
elseif (_POST["member"] ~= nil) and (_POST["pool"] ~= nil) then
  -- change member pool
  host_pools_utils.changeMemberPool(ifId, _POST["member"], _POST["pool"], nil, true --[[do not consider host MAC]])
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
  discover.printDeviceTypeSelector("", "icon_member_' + " .. member_str .. " + '")
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

-- We are passing too much _POST data, no more than 5 members allowed
local perPageMembers = "5"
local perPagePools = "10"

local members_filtering = _GET["members_filter"]
local manage_url = "?ifid="..ifId.."&page=pools&pool="..selected_pool.id.."#manage"

--------------------------------------------------------------------------------

print [[

<br>
  <ul id="hostPoolsNav" class="nav nav-tabs" role="tablist">
    <li><a data-toggle="tab" role="tab" href="#manage">]] print(i18n("host_pools.manage_pools")) print[[</a></li>
    <li><a data-toggle="tab" role="tab" href="#create">]] print(i18n("host_pools.create_pools")) print[[</a></li>
    <li><a data-toggle="tab" role="tab" href="#unassigned">]] print(i18n("unknown_devices.unassigned_devices")) print[[</a></li>
  </ul>
  <div class="tab-content">
    <div id="manage" class="tab-pane">
<br/><table><tbody><tr>
]]

print('<td style="white-space:nowrap; padding-right:1em;">') print(i18n("host_pools.pool")) print(': <select id="pool_selector" class="form-control pool-selector" style="display:inline;" onchange="document.location.href=\'?ifid=') print(ifId.."") print('&page=pools&pool=\' + $(this).val() + \'#manage\';">')
print(poolDropdown(ifId, selected_pool.id))
print('</select>')

local no_pools = (#available_pools <= 1)

local ifstats = interface.getStats()
local is_bridge_iface = isBridgeInterface(ifstats)

if is_bridge_iface and selected_pool.id ~= host_pools_utils.DEFAULT_POOL_ID then
  print("<a href='"..ntop.getHttpPrefix().."/lua/if_stats.lua?ifid=") print(ifId.."") print("&page=filtering&pool="..(selected_pool.id).."#protocols' title='Manage Traffic Policies'><i class='fa fa-cog' aria-hidden='true'></i></a>")
end

if selected_pool.id ~= host_pools_utils.DEFAULT_POOL_ID then
    if ntop.getCache("ntopng.prefs.host_pools_rrd_creation") == "1" and ts_utils.exists("host_pool:traffic", {ifid=ifId, pool=selected_pool.id}) then
      print("&nbsp; <a href='"..ntop.getHttpPrefix().."/lua/pool_details.lua?pool="..selected_pool.id.."&page=historical' title='Chart'><i class='fa fa-area-chart'></i></a>")
    end
end

print('</td>\n')

local function formatMemberFilter()
  if starts(members_filtering, "manuf:") then
    return i18n("host_pools.manufacturer_filter", {manufacturer=string.sub(members_filtering, string.len("manuf:")+1)})
  else
    return i18n("host_pools.member_filter", {member=split(members_filtering, "/")[1]})
  end
end

if members_filtering ~= nil then
  print[[
  <td>
    <form action="#manage">
      <input type="hidden" name="ifid" value="]] print(ifId.."") print[[" />
      <input type="hidden" name="page" value="pools" />
      <input type="hidden" name="pool" value="]] print(selected_pool.id) print[[" />
      <button type="button" class="btn btn-default btn-sm" onclick="$(this).closest('form').submit();">
        <i class="fa fa-close fa-lg" aria-hidden="true" data-original-title="" title=""></i> ]] print(formatMemberFilter()) print[[
      </button>
    </form>
  </td>
  ]]
end
print('<td style="width:100%"></td><td>')
print(
  template.gen("typeahead_input.html", {
    typeahead={
      base_id     = "t_member",
      action      = ntop.getHttpPrefix() .. "/lua/if_stats.lua#manage",
      parameters  = {
                      pool = selected_pool.id,
                      ifid = tostring(ifId),
                      page = "pools",
                    },
      json_key    = "key",
      query_field = "members_filter",
      query_url   = ntop.getHttpPrefix() .. "/lua/find_member.lua",
      query_title = i18n("host_pools.search_member"),
      style       = "margin-left:1em; width:25em;",
    }
  })
)
print('</td>')
print('</tr></tbody></table>')

if no_pools then
  print[[<script>$("#pool_selector").attr("disabled", "disabled");</script>]]
end

for _, msg in ipairs(pool_add_warnings) do
  print([[
  <div class="alert alert-warning alert-dismissible" style="margin-top:2em; margin-bottom:0em;">
    <button type="button" class="close" data-dismiss="alert" aria-label="]]..i18n("close")..[[">
      <span aria-hidden="true">&times;</span>
    </button><b>]]..i18n("warning")..[[</b>: ]]..msg..[[
  </div>]])
end

  print[[
      <form id="table-manage-form">
        <br/><div id="table-manage"></div>
        <button class="btn btn-primary" style="float:right; margin-right:1em;" disabled="disabled" type="submit">]] print(i18n("save_settings")) print[[</button>
      </form>
      ]]

if not ntop.isEnterprise() then
  print[[<span style="float:left;">]]
  print(i18n("notes"))
  print[[<ul>
      <li>]] print(i18n("host_pools.max_members_message", {maxnum=host_pools_utils.LIMITED_NUMBER_POOL_MEMBERS})) print[[</li>
    </ul>
  </span>]]
end

print[[
      <button id="emptyPoolButton" class="btn btn-default" onclick="$('#empty_pool_dialog').modal('show');" style="float:right; margin-right:1em;"><i class="fa fa-trash" aria-hidden="true"></i> ]] print(i18n("host_pools.empty_pool")) print[[</button>
]]

print[[
      <br/><br/>
    </div>
    <div id="create" class="tab-pane">
      <form id="table-create-form">
        <br/><div id="table-create"></div>
        <button class="btn btn-primary" style="float:right; margin-right:1em;" disabled="disabled" type="submit">]] print(i18n("save_settings")) print[[</button>
      </form>
      <br/><br/>
      ]] print(i18n("notes")) print[[
      <ul>
        <li>]] print(i18n("host_pools.cannot_delete_cp")) print[[.</li>]]

if is_bridge_iface and ntop.isEnterprise() then
   print[[<li>]] print(i18n("host_pools.per_member_quotas")) print[[.</li>]]
   print[[<li>]] print(i18n("host_pools.per_member_shapers")) print[[.</li>]]
end

if isCaptivePortalActive() then
  print [[Manage Captive Portal users <a href="]] print(ntop.getHttpPrefix()) print[[/lua/admin/users.lua?captive_portal_users=1">here</a>.</li>]]
end

if not ntop.isEnterprise() then
  print("<li>"..i18n("host_pools.max_pools_message", {maxnum=host_pools_utils.LIMITED_NUMBER_USER_HOST_POOLS}).."</li>")
end

print[[
      </ul>
    </div>
    <div id="unassigned" class="tab-pane">
]]

dofile(dirs.installdir .. "/scripts/lua/unknown_devices.lua")

print [[
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
      message = i18n("host_pools.confirm_delete_pool") .. ' "<span id=\"delete_pool_dialog_pool\"></span>", ' .. i18n("host_pools.and_associated_members").."?",
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
      message = i18n("host_pools.confirm_remove_member") .. ' "<span id=\"delete_member_dialog_member\"></span>" ' .. i18n("host_pools.from_pool") .. ' "' .. selected_pool.name .. '"?',
      confirm = i18n("remove"),
    }
  })
)

print(
  template.gen("modal_confirm_dialog.html", {
    dialog={
      id      = "empty_pool_dialog",
      action  = "emptyCurrentPool()",
      title   = i18n("host_pools.empty_pool"),
      message = i18n("host_pools.confirm_empty_pool") .. " " .. selected_pool.name.."?",
      confirm = i18n("host_pools.empty_pool"),
    }
  })
)

print(
  template.gen("modal_confirm_dialog.html", {
    dialog={
      id      = "change_member_pool_dialog",
      action  = "changeMemberPool(change_member_id)",
      title   = i18n("host_pools.change_member_pool"),
      message = i18n("host_pools.select_new_pool", {member='<span id="change_member_pool_dialog_member"></span>'}) ..
        '<br><br><select class="form-control" id="changed_host_pool" style="width:15em;">'..
        poolDropdown(ifId, "", {[selected_pool.id]=true, [host_pools_utils.DEFAULT_POOL_ID]=true})..
        '</select>',
      custom_alert_class = "",
      confirm = i18n("host_pools.change_pool"),
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
        var cidr = is_network_mask(member, true);

        if (cidr) {
          vlan_field.removeAttr("disabled");
          select_field.attr("disabled", true);

          if((cidr.type == "ipv6" && cidr.mask == 128)
              || (cidr.type == "ipv4" && cidr.mask == 32)) {
            /* Custom alias only allowed for IP addresses */
            vlanicon_disabled = false;
          } else {
            vlanicon_disabled = true;
          }
        }
      }

      if (vlanicon_disabled != null) {
        icon_field.attr("disabled", vlanicon_disabled);
        select_field.attr("disabled", vlanicon_disabled);
      }

      if (]] print(ternary(ifstats.has_macs, "false", "true")) print[[)
        select_field.attr("disabled", true);
    }
    
    /* Make the pair address,vlan unique */
    function addressValidator(input) {
      var member = input.val();

      /* this will be checked separately */
      if (! member)
        return true;

      recheckFields(input);
      return memberValueValidator(input);
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

    function poolNameUnique(input) {
      /* First update the host_pools names */
      datatableForEachRow("#table-create", function() {
        var pool_id = $("td:nth-child(1)", $(this)).html();
        var pool_name = $("td:nth-child(2) input", $(this)).val();

        for (var i=0; i<host_pools.length; i++)
          if (host_pools[i].id == pool_id)
            host_pools[i].name = pool_name;
      });

      var name = input.val();
      var count = 0;

      for (i=0; i<host_pools.length; i++) {
        if (host_pools[i].name === name)
          count++;
      }

      return count == 1;
    }
]]
if members_filtering ~= nil then
  print[[$("#pool_selector").attr("disabled", true);]]
end
print[[
  </script>
]]

-- ==== Manage tab ====

print [[

  <script>
    var addedMemberCtr = 0;
    var curDisplayedMembers = 0;
    var numPoolMembers = 0;

    var validator_options = {
      disable: true,
      custom: {
         member: memberValidator,
         address: addressValidator,
         unique: poolNameUnique,
      }, errors: {
         member: "]] print(i18n("host_pools.duplicate_member")) print[[.",
         address: "]] print(i18n("host_pools.invalid_member")) print[[.",
         unique: "]] print(i18n("host_pools.duplicate_pool")) print[[.",
      }
    }

    function decPoolMembers() { curDisplayedMembers--; numPoolMembers--; }

    function addPoolMember() {
      if (datatableIsEmpty("#table-manage"))
         datatableRemoveEmptyRow("#table-manage");

      var member_id = addedMemberCtr++;
      var newid = "member_" + member_id;
      numPoolMembers++;

      var tr = $('<tr id=' + newid + '><td>]] printMemberAddressField('member_id') print[[</td><td class="text-center">]] printMemberVlanField('member_id') print[[</td><td>]] printAliasField('member_id') print[[</td><td>]] printIconField('member_id') print[[</td><td class="text-center ]] if not (isCaptivePortalActive()) then print(" hidden") end print[[">Persistent</td><td class="text-center"></td></tr>');
      datatableAddDeleteButtonCallback.bind(tr)(6, "datatableUndoAddRow('#" + newid + "', ']] print(i18n("host_pools.empty_pool")) print[[', '#addPoolMemberBtn', 'decPoolMembers')", "]] print(i18n('undo')) print[[");
      $("#table-manage table").append(tr);
      $("input", tr).first().focus();

      var icon = $("td:nth-child(4)", tr);
      var icon_input = $("select", icon).first();
      curDisplayedMembers++;
      $("#addPoolMemberBtn").attr("disabled", ((curDisplayedMembers > ]] print(perPageMembers) print[[)
       || (numPoolMembers >= ]] print(host_pools_utils.LIMITED_NUMBER_POOL_MEMBERS.."") print[[)));

      aysRecheckForm("#table-manage-form");
    }

    function deletePoolMember(member_id) {
      var form = $("#table-manage-form");
      var field = form.find("input[name='member_" + member_id + "']");

      if (field.attr("data-origin-value")) {
        var params = {};
        params.pool = ]] print(selected_pool.id) print[[;
        params.member_to_delete = field.attr("data-origin-value");
        params.csrf = "]] print(ntop.getRandomCSRFValue()) print[[";
        paramsToForm('<form method="post" action="]] print(manage_url) print[["></form>', params).appendTo('body').submit();
      }
    }

    function emptyCurrentPool() {
      var params = {};
      params.empty_pool = ]] print(selected_pool.id) print[[;
      params.csrf = "]] print(ntop.getRandomCSRFValue()) print[[";
      paramsToForm('<form method="post"></form>', params).appendTo('body').submit();
    }

    function changeMemberPool(member_id) {
      var form = $("#table-manage-form");
      var field = form.find("input[name='member_" + member_id + "']");

      if (field.attr("data-origin-value")) {
        var params = {};
        params.pool = $("#changed_host_pool").val();
        params.member = field.attr("data-origin-value");
        params.csrf = "]] print(ntop.getRandomCSRFValue()) print[[";
        paramsToForm('<form method="post" action="]] print(manage_url) print[["></form>', params).appendTo('body').submit();
      }
    }

    $("#table-manage").datatable({
      url: "]]
   print (ntop.getHttpPrefix())
   print [[/lua/get_host_pools.lua?ifid=]] print(ifId.."") print[[&pool=]] print(selected_pool.id) print[[&members_filter=]] print(members_filtering or "") print[[",
      title: "",
      perPage: ]] print(perPageMembers) print[[,
      forceTable: true,
      hidePerPage: true,
      
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
            title: "]] print(i18n("host_pools.alias_or_manufacturer")) print[[",
            field: "column_alias",
            css: {
              width: '25%',
              textAlign: 'center',
              whiteSpace: 'nowrap',
            }
         }, {
            title: "Device Type",
            field: "column_icon",
            css: {
              width: '12%',
              textAlign: 'center',
              whiteSpace: 'nowrap',
            }
         }, {
            title: "Residual Lifetime",
            field: "column_residual",
]] if not (isCaptivePortalActive()) then
  print[[   hidden: true,]]
end
print[[            css : {
               width: '10%',
               textAlign: 'center',
            }
         }, {
            title: "]] print(i18n("actions")) print[[",
            css : {
               width: '20%',
               textAlign: 'center',
            }
         }, {
            field: "column_link",
            hidden: true,
         }, {
            field: "column_editable",
            hidden: true,
         }
      ], tableCallback: function() {
        var no_pools = false;
        curDisplayedMembers = 0;

        if (]] print(selected_pool.id) print[[ == ]] print(host_pools_utils.DEFAULT_POOL_ID) print[[) {
          datatableAddEmptyRow("#table-manage", "]] print(i18n("host_pools.no_pools_defined") .. " " .. i18n("host_pools.create_pool_hint")) print[[");
          no_pools = true;
        } else if(datatableIsEmpty("#table-manage")) {
          datatableAddEmptyRow("#table-manage", "]] print(i18n("host_pools.empty_pool")) print[[");
          $("#emptyPoolButton").attr("disabled", "disabled");
        } else {
          datatableForEachRow("#table-manage", function() {
            var member_address = $("td:nth-child(1)", $(this));
            var vlan = $("td:nth-child(2)", $(this));
            var alias = $("td:nth-child(3)", $(this));
            var icon = $("td:nth-child(4)", $(this));
            var link_value = $("td:nth-child(7)", $(this)).html().replace(/&nbsp;/gi,'');
            var editable = $("td:nth-child(8)", $(this)).html() == "true";

            var member_id = addedMemberCtr++;
            curDisplayedMembers++;

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
            var div = $(']] printIconField('member_id') print[[');
            input = $("select", div);
            input.val(icon.html().replace(/&nbsp;/gi,''));
            icon.html(div);

            /* Make vlan editable */
            var input = $(']] printMemberVlanField('member_id') print[[');
            var vlan_value = parseInt(vlan.html());
            var vlan_input = $("input", input).first()
            vlan_input.val(vlan_value);
            vlan.html(input);

            recheckFields(address_input);

            if (! editable) {
              address_input.attr("disabled", "disabled");
              vlan_input.attr("disabled", "disabled");
            }

            if ((vlan_value > 0) && (is_cidr))
              value = value + " [VLAN " + vlan_value + "]";
]]

if #available_pools > 2 then
  print[[   datatableAddActionButtonCallback.bind(this)(6, "change_member_id ='" + member_id + "'; $('#change_member_pool_dialog_member').html('" + value +"'); $('#change_member_pool_dialog').modal('show');", "]] print(i18n("host_pools.change_pool")) print[[");]]
end

print[[
            datatableAddLinkButtonCallback.bind(this)(6, link_value, "]] print(i18n("host_pools.view")) print[[");
            if (!link_value) $("td:nth(5) a:nth(1)", this).css("visibility", "hidden");
            datatableAddDeleteButtonCallback.bind(this)(6, "delete_member_id ='" + member_id + "'; $('#delete_member_dialog_member').html('" + value +"'); $('#delete_member_dialog').modal('show');", "]] print(i18n('delete')) print[[");
          });

          if(numPoolMembers === 0)
            numPoolMembers = datatableGetTotalItems('#table-manage-form');
          aysResetForm('#table-manage-form');
        }

        $("#addPoolMemberBtn").attr("disabled", ((! datatableIsLastPage("#table-manage-form"))
                                              || (no_pools))
                                              || (]] if members_filtering ~= nil then print("true") else print("false") end print[[)
                                              || (curDisplayedMembers > ]] print(perPageMembers) print[[)
                                              || (numPoolMembers >= ]] print(host_pools_utils.LIMITED_NUMBER_POOL_MEMBERS.."") print[[));

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

          settings[address] = [original, alias, icon].join("|");
        }
      });

      // reset ays so that we can submit a custom form
      aysResetForm(form);

      // create a form with key-values encoded
      var params = paramsPairsEncode(settings);
      params.edit_members = "";
      params.pool = ]] print(selected_pool.id) print[[;
      params.csrf = "]] print(ntop.getRandomCSRFValue()) print[[";
      paramsToForm('<form method="post" action="]] print(manage_url) print[["></form>', params).appendTo('body').submit();
      return false;
    }
  </script>
]]

-- ==== Create tab ====

print [[
  <script>
    /* Assumption: this is sorted by pool id with possible gaps */
    var host_pools = ]] print(tableToJsObject(available_pools)) print[[;
    var maxPoolsNum = ]] print(tostring(host_pools_utils.LIMITED_NUMBER_TOTAL_HOST_POOLS)) print[[;

    function nextPoolId() {
      for (var i=0; i<host_pools.length-1; i++)
        if (parseInt(host_pools[i].id) + 1 < parseInt(host_pools[i+1].id))
          return parseInt(host_pools[i].id) + 1;

      return parseInt(host_pools[host_pools.length-1].id) + 1;
    }

    function deletePool(pool_id) {
      var params = {};
      params.pool_to_delete = pool_id;
      params.csrf = "]] print(ntop.getRandomCSRFValue()) print[[";

      var form = paramsToForm('<form method="post"></form>', params);
      if (pool_id == ]] print(selected_pool.id) print[[)
        form.attr("action", "?ifid=]] print(tostring(ifId)) print[[&page=pools#create");

      form.appendTo('body').submit();
    }

    function onPoolAddUndo(newid) {
      var pool_id = newid.split("added_pool_")[1];
      if (pool_id) {
        for (var i=0; i<host_pools.length; i++) {
          if (parseInt(host_pools[i].id) == pool_id) {
            /* Remove the element at index i */
            host_pools.splice(i, 1);
            break;
          }
        }
      }
    }

    function makeChildrenSafeInput(value) {
      return $('<input name="children_safe" type="checkbox"' + ((value == true) ? " checked" : "") + '/>');
    }

    function makeEnforceQuotasPerPoolMemberInput(value) {
      return $('<input name="enforce_quotas_per_pool_member" type="checkbox"' + ((value == true) ? " checked" : "") + '/>');
    }

    function makeEnforceShapersPerPoolMemberInput(value) {
      return $('<input name="enforce_shapers_per_pool_member" type="checkbox"' + ((value == true) ? " checked" : "") + '/>');
    }

    function addPool() {
      var pool_id = nextPoolId();

      if (pool_id < maxPoolsNum) {
        if (datatableIsEmpty("#table-create"))
          datatableRemoveEmptyRow("#table-create");

        var newid = "added_pool_" + pool_id;

        /* Add at 'pool_id' position */
        host_pools.splice(pool_id, 0, {id:pool_id});

        var tr = $('<tr id=' + newid + '><td class="text-center hidden">' + pool_id + '</td><td>]]
printPoolNameField('pool_id') print[[</td><td class="hidden"></td>]]

print[[<td class="text-center]]
if not is_bridge_iface then print(" hidden") end
print[["></td>]]

print[[<td class="text-center]] if not is_bridge_iface or not ntop.isEnterprise() then print(" hidden") end
print[["></td>]]

print[[<td class="text-center]] if not is_bridge_iface or not ntop.isEnterprise() then print(" hidden") end
print[["></td><td class="text-center"></td></tr>');

        var children_safe = $("td:nth-child(4)", tr);
        children_safe.html(makeChildrenSafeInput());

        var enforce_quotas_per_pool_member = $("td:nth-child(5)", tr);
	enforce_quotas_per_pool_member.html(makeEnforceQuotasPerPoolMemberInput());

        var enforce_shapers_per_pool_member = $("td:nth-child(6)", tr);
	enforce_shapers_per_pool_member.html(makeEnforceShapersPerPoolMemberInput());

        datatableAddDeleteButtonCallback.bind(tr)(7, "datatableUndoAddRow('#" + newid + "', ']] print(i18n("host_pools.no_pools_defined")) print[[', '#addNewPoolBtn', 'onPoolAddUndo')", "]] print(i18n('undo')) print[[");
        $("#table-create table").append(tr);
        $("input", tr).focus();

        aysRecheckForm("#table-create-form");
      }

      recheckPoolAddButton();
    }

    function recheckPoolAddButton() {
      /* TODO use array size and perPage */
      var displayed_items = datatableGetNumDisplayedItems("#table-create");
      var numPools = host_pools.length;

      if ((numPools >= maxPoolsNum)
          || (displayed_items > ]] print(perPagePools) print[[)
          || (! datatableIsLastPage("#table-create-form")))
        $("#addNewPoolBtn").attr("disabled", "disabled");
      else
        $("#addNewPoolBtn").removeAttr("disabled");
    }

    $("#table-create").datatable({
      url: "]]
   print (ntop.getHttpPrefix())
   print [[/lua/get_host_pools.lua?ifid=]] print(ifId.."") print[[",
      title: "",
      showPagination: true,
      forceTable: true,
      hidePerPage: true,
      perPage: ]] print(perPagePools) print[[,

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
            title: "]] print(i18n("host_pools.children_safe")) print[[",
            field: "column_children_safe",
            ]]
     if not is_bridge_iface then
        print("hidden: true,")
     end
     print[[
            css : {
               width: '7%',
               textAlign: 'center',
               whiteSpace: 'nowrap',
            }
         }, {
            title: "]] print(i18n("host_pools.enforce_quotas_per_pool_member")) print[[",
            field: "column_enforce_quotas_per_pool_member",
            ]]
     if not is_bridge_iface or not ntop.isEnterprise() then
        print("hidden: true,")
     end
     print[[
            css : {
               width: '7%',
               textAlign: 'center',
	       whiteSpace: 'nowrap',
            }
         }, {
            title: "]] print(i18n("host_pools.enforce_shapers_per_pool_member")) print[[",
            field: "column_enforce_shapers_per_pool_member",
            ]]
     if not is_bridge_iface or not ntop.isEnterprise() then
        print("hidden: true,")
     end
     print[[
            css : {
               width: '7%',
               textAlign: 'center',
	       whiteSpace: 'nowrap',
            }
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
        var pools_ctr = 0;

        if(datatableIsEmpty("#table-create")) {
          datatableAddEmptyRow("#table-create", "]] print(i18n("host_pools.no_pools_defined")) print[[");
        } else {
         datatableForEachRow("#table-create", function() {
            var pool_id = $("td:nth-child(1)", $(this)).html();
            var pool_name = $("td:nth-child(2)", $(this));
            var pool_undeletable = $("td:nth-child(3)", $(this)).html() === "true";
            var children_safe = $("td:nth-child(4)", $(this));
            var enforce_quotas_per_pool_member = $("td:nth-child(5)", $(this));
            var enforce_shapers_per_pool_member = $("td:nth-child(6)", $(this));
            var pool_link = $("td:nth-child(8)", $(this)).html();

            /* Make pool name editable */
            var input = $(']] printPoolNameField('pool_id') print[[');
            var value = pool_name.html();
            $("input", input).first().val(value);
            pool_name.html(input);

            /* Make children safe and per-member pool quotas editable */
            children_safe.html(makeChildrenSafeInput(children_safe.html() === "true"));
            enforce_quotas_per_pool_member.html(makeEnforceQuotasPerPoolMemberInput(enforce_quotas_per_pool_member.html() === "true"));
            enforce_shapers_per_pool_member.html(makeEnforceShapersPerPoolMemberInput(enforce_shapers_per_pool_member.html() === "true"));

            if (pool_id == ]]  print(host_pools_utils.DEFAULT_POOL_ID) print[[) {
              $("input", input).first().attr("disabled", "disabled");
            } else {
              datatableAddLinkButtonCallback.bind(this)(7, pool_link, "View");
              value = value.replace("'", "\\'");
              datatableAddDeleteButtonCallback.bind(this)(7, "delete_pool_id ='" + pool_id + "'; $('#delete_pool_dialog_pool').html('" + value + "'); $('#delete_pool_dialog').modal('show');", "]] print(i18n('delete')) print[[");

              if (pool_undeletable)
                $("td:nth-child(7) a", $(this)).last().attr("disabled", "disabled");
            }

            pools_ctr++;
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

        var children_safe = $("input[name='children_safe']", $(this).closest("tr")).is(':checked');
	var enforce_quotas_per_pool_member = $("input[name='enforce_quotas_per_pool_member']", $(this).closest("tr")).is(':checked');
	var enforce_shapers_per_pool_member = $("input[name='enforce_shapers_per_pool_member']", $(this).closest("tr")).is(':checked');

        settings[pool_id] = $(this).val();
        settings["_csafe_" + pool_id] = children_safe;
        settings["_qts_per_member_" + pool_id] = enforce_quotas_per_pool_member;
        settings["_shp_per_member_" + pool_id] = enforce_shapers_per_pool_member;
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

