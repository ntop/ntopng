--
-- (C) 2019-21 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local host_pools_utils = require "host_pools_utils"
local discover = require "discover_utils"
local template = require "template_utils"
local graph_utils = require "graph_utils"
local page_utils = require "page_utils"

sendHTTPContentTypeHeader('text/html')

if not isAdministratorOrPrintErr() then
   return
end

page_utils.set_active_menu_entry(page_utils.menu_entries.pools_host)

-- append the menu above the page
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

page_utils.print_page_title(i18n("host_pools.host_pools"))

-- ************************************* ------

local pool_add_warnings = {}

if _POST["edit_pools"] ~= nil then
   local config = paramsPairsDecode(_POST, true)

   for pool_id, pool_name in pairs(config) do
      -- Filter pool ids only
      if tonumber(pool_id) ~= nil then
	 host_pools_utils.createPool(pool_id, pool_name,
				     nil --[[ children_safe ]],
				     nil --[[ enforce_quotas_per_pool_member ]],
				     nil --[[ enforce_shapers_per_pool_member ]],
				     true --[[ create or rename ]])
      end
   end

   -- Reload is required here to load the new metadata
   ntop.reloadHostPools()
elseif _POST["pool_to_delete"] ~= nil then
   local pool_id = _POST["pool_to_delete"]
   host_pools_utils.deletePool(pool_id)

   -- Note: this will also reload the shaping rules
   ntop.reloadHostPools()
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
	    host_pools_utils.deletePoolMember(pool_to_edit, old_member)
	 end
      end
   end

   -- add new addresses
   for new_member,value in pairs(config) do
      local k = value.old_member

      local is_new_member = (k ~= new_member)

      if is_new_member then
	 local res, info = host_pools_utils.addPoolMember(pool_to_edit, new_member)

	 if (res == false) and (info.existing_member_pool ~= nil) then
	    -- remove @0
	    local member_to_print = hostinfo2hostkey(hostkey2hostinfo(new_member))
	    pool_add_warnings[#pool_add_warnings + 1] = i18n("host_pools.member_exists", {
								member_name = member_to_print,
								member_pool = host_pools_utils.getPoolName(info.existing_member_pool)
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
	    ntop.setMacDeviceType(new_member, icon, true --[[ overwrite ]])
	 end
      end
   end

   ntop.reloadHostPools()
elseif _POST["member_to_delete"] ~= nil then
   local pool_to_edit = _POST["pool"]

   host_pools_utils.deletePoolMember(pool_to_edit, _POST["member_to_delete"])
   ntop.reloadHostPools()
elseif _POST["empty_pool"] ~= nil then
   host_pools_utils.emptyPool(_POST["empty_pool"])
   ntop.reloadHostPools()
elseif (_POST["member"] ~= nil) and (_POST["pool"] ~= nil) then
   -- change member pool
   host_pools_utils.changeMemberPool(_POST["member"], _POST["pool"], nil, true --[[do not consider host MAC]])
   ntop.reloadHostPools()
end

function printPoolNameField(pool_id_str)
   print[[<div class="form-group mb-3 has-feedback" style="margin-bottom:0;">]]
   print[[<input name="pool_' + ]] print(pool_id_str) print[[ + '" class="form-control" spellcheck="false" data-unique="unique" placeholder="]] print(i18n("host_pools.specify_pool_name")) print[[" required/>]]
   print[[<div class="help-block with-errors" style="margin-bottom:0;"></div>]]
   print[[</div>]]
end

function printMemberAddressField(member_str, origin_value_str)
   print[[<div class="form-group mb-3 has-feedback" style="margin-bottom:0;">]]
   print[[<input name="member_' + ]] print(member_str) print[[ + '" class="form-control" spellcheck="false" data-address="address" data-member="member" placeholder="]] print(i18n("host_pools.specify_member_address")) print[["]]
   if not isEmptyString(origin_value_str) then
      print[[ data-origin-value="' + ]] print(origin_value_str) print[[ + '"]]
   end
   print[[ required/>]]
   print[[<div class="help-block with-errors" style="margin-bottom:0;"></div>]]
   print[[</div>]]
end

function printMemberVlanField(member_str)
   print[[<div class="form-group mb-3 has-feedback" style="margin-bottom:0;">]]
   print[[<input name="member_' + ]] print(member_str) print[[ + '_vlan" class="form-control text-end" data-member="member" style="width:5em; padding-right:1em; margin: 0 auto;" type="number" min="0" value="0" required/>]]
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
local available_pools = host_pools_utils.getPoolsList()

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
local ifstats = interface.getStats()

--------------------------------------------------------------------------------

print [[

  <ul id="hostPoolsNav" class="nav nav-tabs" role="tablist">
    <li class="nav-item"><a class="nav-link" data-bs-toggle="tab" role="tab" href="#manage">]] print(i18n("host_pools.manage_pools")) print[[</a></li>
    <li class="nav-item"><a class="nav-link" data-bs-toggle="tab" role="tab" href="#create">]] print(i18n("host_pools.create_pools")) print[[</a></li>
  </ul>
  <div class="tab-content">
    <div id="manage" class="tab-pane">
<br/><table><tbody><tr>
]]

print('<td style="white-space:nowrap; padding-right:1em;">') print(i18n("host_pools.pool")) print(': <select id="pool_selector" class="form-select pool-selector" style="display:inline; width:14em;" onchange="document.location.href=\'?ifid=') print(ifId.."") print('&page=pools&pool=\' + $(this).val() + \'#manage\';">')
print(graph_utils.poolDropdown(ifId, selected_pool.id, {[host_pools_utils.DEFAULT_POOL_ID]=true}))
print('</select>')

local no_pools = (#available_pools <= 1)

if selected_pool.id ~= host_pools_utils.DEFAULT_POOL_ID then
   if areHostPoolsTimeseriesEnabled(ifid) then
      print("&nbsp; <a href='"..ntop.getHttpPrefix().."/lua/pool_details.lua?pool="..selected_pool.id.."&page=historical' title='Chart'><i class='fas fa-chart-area'></i></a>")
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
      <button type="button" class="btn btn-secondary btn-sm" onclick="$(this).closest('form').submit();">
	<i class="fas fa-times fa-lg" aria-hidden="true" data-original-title="" title=""></i> ]] print(formatMemberFilter()) print[[
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
    <b>]]..i18n("warning")..[[</b>: ]]..msg..[[
	<button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>
  </div>]])
end

print[[
      <form id="table-manage-form">
	<br/><div id="table-manage"></div>
	<button class="btn btn-primary" style="float:right; margin-right:1em;" disabled="disabled" type="submit">]] print(i18n("save_settings")) print[[</button>
      </form>
      ]]

if not ntop.isEnterpriseM() and not ntop.isnEdgeEnterprise() then
   print[[<span style="float:left;">]]
   print(i18n("notes"))
   print[[<ul>
      <li>]] print(i18n("host_pools.max_members_message", {maxnum = host_pools_utils.LIMITED_NUMBER_POOL_MEMBERS})) print[[</li>
    </ul>
  </span>]]
end

print[[
      <button id="emptyPoolButton" class="btn btn-secondary" onclick="$('#empty_pool_dialog').modal('show');" style="float:right; margin-right:1em;"><i class="fas fa-trash" aria-hidden="true"></i> ]] print(i18n("host_pools.empty_pool")) print[[</button>
]]

print[[
      <br/><br/>
    </div>
    <div id="create" class="tab-pane">
      <form id="table-create-form">
	<br/><div id="table-create"></div>
	<button class="btn btn-primary" style="float:right; margin-right:1em;" disabled="disabled" type="submit">]] print(i18n("save_settings")) print[[</button>
      </form>

      <div style="float:left">
	<form action="/lua/rest/v2/get/pool/config.lua" class="form-inline" method="GET" data-ays-ignore="true">
	  <input type="hidden" name="ifid" value="]] print(tostring(ifId)) print[[" />
	  <input type="hidden" name="download" value="true" />
	  <button type="submit" class="btn btn-secondary"><span>]] print(i18n("host_pools.config_export")) print[[</span></button>
	</form>
	<button id="import-modal-btn" data-bs-toggle="modal" data-target="#import-modal" class="btn btn-secondary"><span>]] print(i18n("host_pools.config_import")) print[[</span></button>
      </div>

      <br/><br/>]]

local notes = {}

if ntop.isnEdge() then
   notes[#notes + 1] = "<li>"..i18n("host_pools.cannot_delete_cp")..".</li>"
end

if not ntop.isEnterpriseM() and not ntop.isnEdgeEnterprise() then
   notes[#notes + 1] = "<li>"..i18n("host_pools.max_pools_message", {maxnum=host_pools_utils.LIMITED_NUMBER_USER_HOST_POOLS}).."</li>"
end

if #notes > 0 then
   print(i18n("notes"))
   print[[<ul>]]

   for _, note in ipairs(notes) do
      print(note)
   end

   print[[</ul>]]
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
			 '<br><br><select class="form-select" id="changed_host_pool" style="width:15em;">'..
			 graph_utils.poolDropdown(ifId, "", {[selected_pool.id]=true, [host_pools_utils.DEFAULT_POOL_ID]=true})..
			 '</select>',
		      custom_alert_class = "",
		      confirm = i18n("host_pools.change_pool"),
		   }
   })
)

-- Create import dialog

print(
   template.gen("import_modal.html", {
		   dialog={
		      title   = i18n("host_pools.config_import"),
		      label   = "",
		      message = i18n("host_pools.config_import_message"),
		      cancel  = i18n("cancel"),
		      apply   = i18n("apply"),
		   }
   })
)

print[[
  <script>
    const import_csrf = ']] print(ntop.getRandomCSRFValue()) print[[';

    $('#import-modal-btn').on("click", function(e) {

	// hide previous errors
	$("#import-error").hide();

	$("#import-modal form").off("submit");

	$('#btn-confirm-import').off('click').click(function(e) {
	    const $button = $(this);

	    let applied_value = null;

	    $button.attr("disabled", "");

	    // Read configuration file file
	    var file = $('#import-input')[0].files[0];

	    if (!file) {
		 $("#import-error").text(`${i18n.no_file}`).show();

		 // re-enable button
		 $button.removeAttr("disabled");
	     } else {
		var reader = new FileReader();
		reader.onload = function () {
		    // Client-side configuration file format check
		    let json_conf = null
		    try { json_conf = JSON.parse(reader.result); } catch (e) {}

		    if (!json_conf || !json_conf['0']) {
			$("#import-error").text(`${i18n.invalid_file}`).show();
			// re-enable button
			$button.removeAttr("disabled");
		    } else {
			// Submit configuration file
			$.post(`${http_prefix}/lua/rest/v2/set/pool/config.lua`, {
			    csrf: import_csrf,
			    JSON: JSON.stringify(json_conf)
			})
			.done((d, status, xhr) => {
			    if(xhr.status != 200) {
			      $("#import-error").text("]] print(i18n("request_failed_message")) print [[" + xhr.statusText).show();
			    } else if(d["rc_str"] != "OK") {
				$("#import-error").text(d.rc_str).show();
			    } else {
				location.reload();
			    }
			})
			.fail(({ status, statusText }) => {
			    $("#import-error").text(status + ": " + statusText).show();

			    // re-enable button
			    $button.removeAttr("disabled");
			});

		     };
		 }
		 reader.readAsText(file, "UTF-8");
	     }
	});

	$("#import-modal").on("submit", "form", function (e) {
	    e.preventDefault();
	    $("#btn-import").trigger("click");
	});
    });
  </script>
]]

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

      if (NtopUtils.is_mac_address(member)) {
	vlan_field.attr("disabled", true);
	vlanicon_disabled = false;
	select_field.attr("disabled", false);
      } else {
	var cidr = NtopUtils.is_network_mask(member, true);
	select_field.attr("disabled", true);

	if (cidr) {
	  vlan_field.removeAttr("disabled");

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

      var is_mac = NtopUtils.is_mac_address(member);
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

	is_cidr = NtopUtils.is_network_mask(address_value, true);
	if (! is_cidr)
	   /* this will be handled by addressValidator */
	  return true;
	identifier = is_cidr.address + "/" + is_cidr.mask + "@" + vlan_value;
      }

      identifier = identifier.toLowerCase();
      var count = 0;

      $('input[name^="member_"]:not([name$="_vlan"])', $("#table-manage-form")).each(function() {
	var address_value = $(this).val();
	var is_cidr = NtopUtils.is_network_mask(address_value, true);

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
      if($("#addPoolMemberBtn").attr("disabled"))
	return;

      if (datatableIsEmpty("#table-manage"))
	 datatableRemoveEmptyRow("#table-manage");

      var member_id = addedMemberCtr++;
      var newid = "member_" + member_id;
      numPoolMembers++;

      var tr = $('<tr id=' + newid + '><td>]] printMemberAddressField('member_id') print[[</td><td class="text-center">]] printMemberVlanField('member_id') print[[</td><td>]] printAliasField('member_id') print[[</td><td>]] printIconField('member_id') print[[</td><td class="text-center"></td></tr>');
      datatableAddDeleteButtonCallback.bind(tr)(5, "datatableUndoAddRow('#" + newid + "', ']] print(i18n("host_pools.empty_pool")) print[[', '#addPoolMemberBtn', 'decPoolMembers')", "]] print(i18n('undo')) print[[");
      $("#table-manage table").append(tr);
      $("input", tr).first().focus();

      var icon = $("td:nth-child(4)", tr);
      var icon_input = $("select", icon).first();
      curDisplayedMembers++;

      var is_disabled = ((curDisplayedMembers > ]] print(perPageMembers) print[[)
       || (numPoolMembers >= ]] print(host_pools_utils.LIMITED_NUMBER_POOL_MEMBERS.."") print[[));

      if(is_disabled)
	  $("#addPoolMemberBtn").addClass("disabled").attr("disabled", "disabled");
	else
	  $("#addPoolMemberBtn").removeClass("disabled").removeAttr("disabled");

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
	NtopUtils.paramsToForm('<form method="post" action="]] print(manage_url) print[["></form>', params).appendTo('body').submit();
      }
    }

    function emptyCurrentPool() {
      var params = {};
      params.empty_pool = ]] print(selected_pool.id) print[[;
      params.csrf = "]] print(ntop.getRandomCSRFValue()) print[[";
      NtopUtils.paramsToForm('<form method="post"></form>', params).appendTo('body').submit();
    }

    function changeMemberPool(member_id) {
      var form = $("#table-manage-form");
      var field = form.find("input[name='member_" + member_id + "']");

      if (field.attr("data-origin-value")) {
	var params = {};
	params.pool = $("#changed_host_pool").val();
	params.member = field.attr("data-origin-value");
	params.csrf = "]] print(ntop.getRandomCSRFValue()) print[[";
	NtopUtils.paramsToForm('<form method="post" action="]] print(manage_url) print[["></form>', params).appendTo('body').submit();
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
	 '<a id="addPoolMemberBtn" onclick="addPoolMember()" role="button" class="add-on btn" data-bs-toggle="modal"><i class="fas fa-plus" aria-hidden="true"></i></a>'
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
	    var link_value = $("td:nth-child(6)", $(this)).html().replace(/&nbsp;/gi,'');
	    var editable = $("td:nth-child(7)", $(this)).html() == "true";

	    var member_id = addedMemberCtr++;
	    curDisplayedMembers++;

	    /* Make member name editable */
	    var value = member_address.html();
	    var is_cidr = NtopUtils.is_network_mask(value);
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
   print[[   datatableAddActionButtonCallback.bind(this)(5, "change_member_id ='" + member_id + "'; $('#change_member_pool_dialog_member').html('" + value +"'); $('#change_member_pool_dialog').modal('show');", "]] print(i18n("host_pools.change_pool")) print[[");]]
end

print[[
	    datatableAddLinkButtonCallback.bind(this)(5, link_value, "]] print(i18n("host_pools.view")) print[[");
	    if (!link_value) $("td:nth(5) a:nth(1)", this).css("visibility", "hidden");
	    datatableAddDeleteButtonCallback.bind(this)(5, "delete_member_id ='" + member_id + "'; $('#delete_member_dialog_member').html('" + value +"'); $('#delete_member_dialog').modal('show');", "]] print(i18n('delete')) print[[");
	  });

	  if(numPoolMembers === 0)
	    numPoolMembers = $("#table-manage").data("datatable").resultset.num_pool_members || 0;
	  aysResetForm('#table-manage-form');
	}

	var is_disabled = (((! datatableIsLastPage("#table-manage-form"))
					      || (no_pools))
					      || (]] if members_filtering ~= nil then print("true") else print("false") end print[[)
					      || (curDisplayedMembers > ]] print(perPageMembers) print[[)
					      || (numPoolMembers >= ]] print(host_pools_utils.LIMITED_NUMBER_POOL_MEMBERS.."") print[[));

	if(is_disabled)
	  $("#addPoolMemberBtn").addClass("disabled").attr("disabled", "disabled");
	else
	  $("#addPoolMemberBtn").removeClass("disabled").removeAttr("disabled");

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

	if((member = NtopUtils.is_network_mask($(this).val(), true))) {
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
      var params = NtopUtils.paramsPairsEncode(settings);
      params.edit_members = "";
      params.pool = ]] print(selected_pool.id) print[[;
      params.csrf = "]] print(ntop.getRandomCSRFValue()) print[[";
      NtopUtils.paramsToForm('<form method="post" action="]] print(manage_url) print[["></form>', params).appendTo('body').submit();
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

      var form = NtopUtils.paramsToForm('<form method="post"></form>', params);
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

    function addPool() {
      if($("#addNewPoolBtn").attr("disabled"))
	return;

      var pool_id = nextPoolId();

      if (pool_id < maxPoolsNum) {
	if (datatableIsEmpty("#table-create"))
	  datatableRemoveEmptyRow("#table-create");

	var newid = "added_pool_" + pool_id;

	/* Add at 'pool_id' position */
	host_pools.splice(pool_id, 0, {id:pool_id});

	var tr = $('<tr id=' + newid + '><td class="text-center" style="display:none;">' + pool_id + '</td><td>]]
printPoolNameField('pool_id') print[[</td><td align="center"></td></tr>');

	datatableAddDeleteButtonCallback.bind(tr)(3, "datatableUndoAddRow('#" + newid + "', ']] print(i18n("host_pools.no_pools_defined")) print[[', '#addNewPoolBtn', 'onPoolAddUndo')", "]] print(i18n('undo')) print[[");
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
	$("#addNewPoolBtn").attr("disabled", "disabled").addClass("disabled");
      else
	$("#addNewPoolBtn").removeAttr("disabled").removeClass("disabled");
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
	 '<a id="addNewPoolBtn" onclick="addPool()" role="button" class="add-on btn" data-bs-toggle="modal"><i class="fas fa-plus" aria-hidden="true"></i></a>'
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
	var pools_ctr = 0;

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
	      value = value.replace("'", "\\'");
	      datatableAddDeleteButtonCallback.bind(this)(4, "delete_pool_id ='" + pool_id + "'; $('#delete_pool_dialog_pool').html('" + value + "'); $('#delete_pool_dialog').modal('show');", "]] print(i18n('delete')) print[[");

	      if (pool_undeletable)
		$("td:nth-child(4) a", $(this)).last().attr("disabled", "disabled");
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

	settings[pool_id] = $(this).val();
      });

      // reset ays so that we can submit a custom form
      aysResetForm(form);

      // create a form with key-values encoded
      var params = NtopUtils.paramsPairsEncode(settings);
      params.edit_pools = "";
      params.csrf = "]] print(ntop.getRandomCSRFValue()) print[[";
      NtopUtils.paramsToForm('<form method="post"></form>', params).appendTo('body').submit();

      return false;
    }
  </script>
]]

print[[
  <script>
    NtopUtils.handle_tab_state($("#hostPoolsNav"), "manage");

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

-- ************************************* ------

-- append the menu below the page
dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
