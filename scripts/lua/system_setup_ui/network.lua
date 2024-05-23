--
-- (C) 2013-24 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local system_setup_ui_utils = require "system_setup_ui_utils"
local template = require "template_utils"
require "prefs_utils"
require "lua_utils"
prefsSkipRedis(true)

local is_nedge = ntop.isnEdge()
local is_appliance = ntop.isAppliance()

if not (is_nedge or is_appliance) or not isAdministrator() then
   return
end

local sys_config
if is_nedge then
   package.path = dirs.installdir .. "/pro/scripts/lua/nedge/modules/system_config/?.lua;" .. package.path
   sys_config = require("nf_config"):create(true)
else -- ntop.isAppliance()
   package.path = dirs.installdir .. "/scripts/lua/modules/system_config/?.lua;" .. package.path
   sys_config = require("appliance_config"):create(true)
end

local error_msg = nil

local operating_mode = sys_config:getOperatingMode()
system_setup_ui_utils.process_apply_discard_config(sys_config)

if table.len(_POST) > 0 then
  local interfaces_config = sys_config:getInterfacesConfiguration()
  local disabled_wans = sys_config:getDisabledWans()
  local config_found = false
  
  -- Interface id to name mappings
  for k, v in pairs(_POST) do
    if starts(k, "iface_id_") then
      local if_id = split(k, "iface_id_")[2]
      local if_name = v
      local config = interfaces_config[if_name]
      config_found = true

      local fields = {
        ip = "iface_ip_" .. if_id,
        gw = "iface_gw_" .. if_id,
        netmask = "iface_netmask_" .. if_id,
        mode = "iface_mode_" .. if_id,
        upload = "iface_up_" .. if_id,
        download = "iface_down_" .. if_id,
        iface_on = "iface_on_" .. if_id,
        nat_on = "iface_nat_" .. if_id,
        primary_dns = "iface_primary_dns_" .. if_id,
        secondary_dns = "iface_secondary_dns_" .. if_id,
      }

      if _POST[fields.ip] ~= nil then config.network.ip = _POST[fields.ip] end

      if _POST[fields.gw] ~= nil then 
        -- Static gw
        config.network.gateway = _POST[fields.gw]
        -- Add to the list of gateways if not already present
        sys_config:addGateway(if_name, if_name, config.network.gateway)
      end
      if _POST[fields.mode] and _POST[fields.mode] == 'dhcp' then
        -- dhcp: reset static gw ip
        sys_config:updateGateway(if_name, if_name, "0.0.0.0") 
      end

      if _POST[fields.netmask] ~= nil then config.network.netmask = _POST[fields.netmask] end
      if _POST[fields.mode] ~= nil then config.network.mode = _POST[fields.mode] end
      if is_nedge then
         if _POST[fields.upload] ~= nil then config.speed.upload = tonumber(_POST[fields.upload]) end
         if _POST[fields.download] ~= nil then config.speed.download = tonumber(_POST[fields.download]) end
      end
      if _POST[fields.iface_on] ~= nil then disabled_wans[if_name] = ternary(_POST[fields.iface_on] == "1", false, true) end
      if _POST[fields.nat_on] ~= nil then config.masquerade = ternary(_POST[fields.nat_on] == "1", true, false) end
      if _POST[fields.primary_dns] ~= nil then config.network.primary_dns = _POST[fields.primary_dns] end
      if _POST[fields.secondary_dns] ~= nil then config.network.secondary_dns = _POST[fields.secondary_dns] end
    end
  end

  if not isEmptyString(_POST["interface_name"]) and not isEmptyString(_POST["old_interface_name"]) then
    local success = sys_config:setInterfaceAlias(_POST["old_interface_name"], _POST["interface_name"]) 
    if not success then
      error_msg = i18n("nedge.cannot_rename_interface")
    else
      sys_config:save()
    end
  end

  if config_found then
    sys_config:setDisabledWans(disabled_wans)
    sys_config:setInterfacesConfiguration(interfaces_config)
    if is_nedge then
      sys_config:setDhcpFromLan()
    end
    sys_config:save()
  end
end

local disabled_wans = sys_config:getDisabledWans()

local function printInterfaceTitle(if_name, if_alias, if_role)
  local title = 
    "<span>" .. 
      i18n("nedge.network_conf_iface_title", {ifrole = i18n("nedge."..if_role), ifname=if_alias .. (if_name and (if_name ~= if_alias) and (" (" .. if_name .. ")") or "") }) .. 
    '</span>' .. 
    '<span class="float-right">' ..
      [[<a class="btn disable-on-dirty" href="#editInterfaceAliasModal" onclick="]] ..
      [[$('.real_interface_name').val(']] .. if_name .. [['); ]] .. 
      [[$('.current_interface_name').val(']] .. if_alias .. [['); ]] .. 
      [[aysResetForm('#editInterfaceAliasForm');" role="button" data-bs-toggle="modal" style="padding-top:0; padding-bottom:0; border:0"><i class="fas fa-lg fa-edit"></i></a>]] ..
    '</span>'

  printPageSection(title)
end

-- Static ip configuration
local function printLanLikeConfig(if_name, if_id, ifconf)
  local if_alias = sys_config:getInterfaceAlias(if_name)

  printInterfaceTitle(if_name, if_alias, 'lan')

  print[[<input type="hidden" name="iface_id_]] print(if_id) print[[" value="]] print(if_name) print[[" />]]

  prefsInputFieldPrefs(i18n("ip_address"), i18n("nedge.network_conf_iface_ip"),
          "", "iface_ip_"..if_id, ifconf.network.ip or "192.168.1.1", nil, nil, nil, nil,
          {required=true, pattern=getIPv4Pattern()})

  prefsInputFieldPrefs(i18n("netmask"), i18n("nedge.network_conf_iface_nmask"),
          "", "iface_netmask_"..if_id, ifconf.network.netmask or "255.255.255.0", nil, nil, nil, nil,
          {required=true, pattern=getIPv4Pattern()})
end

-- Static/Dynamic ip configuration, with gateway and speed
local function printWanLikeConfig(if_name, if_id, ifconf, bridge_interface, routing_interface)
  local mode = ifconf.network.mode or "static"
  local show_static = ternary(mode == "static", true, false)
  local title
  local mode_values = {"static", "dhcp"}
  local mode_labels = {i18n("nedge.network_conf_static"), i18n("nedge.network_conf_dhcp")}

  if bridge_interface then
    title = i18n("bridge")
  elseif routing_interface then
    title = i18n("nedge.network_conf_iface_title", {ifname = if_name, ifrole = i18n("nedge.wan")})
  else
    title = i18n("appliance.management")
  end

  printPageSection("<span id='" .. if_name .. "_interface'>" .. title  .. "</span>")

  print[[<input type="hidden" name="iface_id_]] print(if_id) print[[" value="]] print(if_name) print[[" />]]

  if routing_interface then
    prefsToggleButton(subpage_active, {
      title = i18n("nedge.enable_interface"),
      description = i18n("nedge.enable_interface_descr"),
      content = "",
      field = "iface_on_" .. if_id,
      default = ternary(not disabled_wans[if_name], "1", "0"),
      to_switch = nil,
      local_store = true, -- do not store on redis
    })
  end

  if is_nedge and bridge_interface then
     -- in bridge mode, we allow the bridge to be on a VLAN trunk
     mode_values[#mode_values + 1] = "vlan_trunk"
     mode_labels[#mode_labels + 1] = i18n("nedge.network_conf_vlan_trunk")
  end

  local elementToSwitch = {"iface_ip_"..if_id, "iface_gw_"..if_id, "iface_netmask_"..if_id}
  local showElementArray = {true, false, false}
  if not is_nedge then
    table.insert(elementToSwitch, "iface_primary_dns_"..if_id)
    table.insert(showElementArray, false)
    table.insert(elementToSwitch, "iface_secondary_dns_"..if_id)
    table.insert(showElementArray, false)
  end

  multipleTableButtonPrefs(i18n("nedge.mode"),
          i18n("nedge.network_conf_iface_descr"),
          mode_labels, mode_values,
          mode,
          "primary",
          "iface_mode_"..if_id,
          "", nil,
          elementToSwitch, showElementArray, nil, true, mode)

  -- Static mode only
  prefsInputFieldPrefs(i18n("ip_address"), i18n("nedge.network_conf_iface_ip"),
          "", "iface_ip_"..if_id, ifconf.network.ip or "0.0.0.0", nil, show_static, nil, nil,
          {required=true, pattern=getIPv4Pattern()})

  prefsInputFieldPrefs(i18n("netmask"), i18n("nedge.network_conf_iface_nmask"),
          "", "iface_netmask_"..if_id, ifconf.network.netmask or "255.255.255.0", nil, show_static, nil, nil,
          {required=true, pattern=getIPv4Pattern()})

  prefsInputFieldPrefs(i18n("nedge.default_gateway"), i18n("nedge.network_conf_iface_gw"),
          "", "iface_gw_"..if_id, ifconf.network.gateway or "0.0.0.0", nil, show_static, nil, nil,
          {required=true, pattern=getIPv4Pattern()})

  if not is_nedge then
    prefsInputFieldPrefs(i18n("prefs.primary_dns"), i18n("nedge.the_primary_dns_server"),
            "", "iface_primary_dns_"..if_id, ifconf.network.primary_dns or "0.0.0.0", nil, show_static, nil, nil,
            {required=true, pattern=getIPv4Pattern()})

    prefsInputFieldPrefs(i18n("prefs.secondary_dns"), i18n("nedge.the_secondary_dns_server"),
            "", "iface_secondary_dns_"..if_id, ifconf.network.secondary_dns or "0.0.0.0", nil, show_static, nil, nil,
            {required=false, pattern=getIPv4Pattern()})
  end

  if is_nedge then
    -- Speed (kbps)
    local fifty_six_kbits = 56
    local ten_megabits = 1000 * 10
    local one_hundred_gbits = 1000 * 1000 * 100

    prefsInputFieldPrefs(i18n("nedge.download_speed"), i18n("nedge.download_description"),
      "", "iface_down_"..if_id, ifconf.speed.download or ten_megabits, "number", true, nil, nil,
      {min=fifty_six_kbits, max=one_hundred_gbits, tformat="kmg", format_spec=FMT_TO_DATA_RATES_KBPS})

    prefsInputFieldPrefs(i18n("nedge.upload_speed"), i18n("nedge.upload_description"),
      "", "iface_up_"..if_id, ifconf.speed.upload or ten_megabits, "number", true, nil, nil,
      {min=fifty_six_kbits, max=one_hundred_gbits, tformat="kmg", format_spec=FMT_TO_DATA_RATES_KBPS})

    if routing_interface then
      prefsToggleButton(subpage_active, {
        title = i18n("nedge.enable_nat"),
        description = i18n("nedge.enable_nat_descr"),
        content = "",
        field = "iface_nat_" .. if_id,
        default = ternary(ifconf.masquerade, "1", "0"),
        to_switch = nil,
        local_store = true, -- do not store on redis
      })
    end
  end
end

local function print_passive_page_body()
  local if_name = sys_config:getPassiveInterfaceName()
  local interfaces_config = sys_config:getInterfacesConfiguration()

  printWanLikeConfig(if_name, "0", interfaces_config[if_name], false, false)
  printSaveButton()
end

local function print_bridging_page_body()
  local if_name = sys_config:getBridgeInterfaceName()
  local interfaces_config = sys_config:getInterfacesConfiguration()

  printWanLikeConfig(if_name, "0", interfaces_config[if_name], true, false)
  printSaveButton()
end

local function print_routing_page_body()
  local all_interfaces = sys_config:getAllInterfaces()
  local interfaces_config = sys_config:getInterfacesConfiguration()

  if table.len(all_interfaces) > 0 then
    -- Assign an unique id to the interface
    local ifname_to_id = {}
    local ctr = 0

    for if_name in pairsByKeys(all_interfaces, asc_insensitive) do
      ifname_to_id[if_name] = tostring(ctr)
      ctr = ctr + 1
    end

    -- Lan first
    for if_name, role in pairsByKeys(all_interfaces, asc_insensitive) do
      if (role == "lan") and (interfaces_config[if_name] ~= nil) then
        printLanLikeConfig(if_name, ifname_to_id[if_name], interfaces_config[if_name])
      end
    end

    -- Wan after
    for if_name, role in pairsByKeys(all_interfaces, asc_insensitive) do
      if (role == "wan") and (interfaces_config[if_name] ~= nil) then
        printWanLikeConfig(if_name, ifname_to_id[if_name], interfaces_config[if_name], false, true)
      end
    end
  else
    prefsInformativeField("", i18n("nedge.no_interfaces_available"), true)
  end

  printSaveButton()
end

local print_page_body_callback
if operating_mode == "passive" then
  print_page_body_callback = print_passive_page_body
elseif operating_mode == "bridging" then
  print_page_body_callback = print_bridging_page_body
else -- operating_mode == "routing"
  print_page_body_callback = print_routing_page_body
end

system_setup_ui_utils.print_setup_page(print_page_body_callback, sys_config)


-- Edit interface alias modal
  local interface_name_pattern = "^[a-zA-Z0-9_]+$"
  print[[
  <!-- Modal -->
  <div id="editInterfaceAliasModal" class="modal fade in" role="dialog">
    <form method="post" data-bs-toggle="validator" id="editInterfaceAliasForm">
      <div class="modal-dialog">

	<!-- Modal content-->
	<div class="modal-content">
	  <div class="modal-header">
	    <h5 class="modal-title">]] print(i18n("nedge.edit_interface")) print[[</h3>
	    <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
	  </div>

	  <div class="modal-body container-fluid">
	    <input type="hidden" name="csrf" value="]] print(ntop.getRandomCSRFValue()) print[[" />
	    <input type="hidden" name="old_interface_name" class="real_interface_name">

	    <div class="row form-group mb-3 has-feedback">
	      <label class="form-label">]] print(i18n("nedge.interface_name")) print[[</label>
	      <input type="text" name="interface_name" class="form-control current_interface_name" pattern="]] print(interface_name_pattern) print[[" required>
	    </div>
	  </div>

	  <div class="modal-footer">
	    <button type="submit" class="btn btn-primary btn-block" disabled="disabled">]] print(i18n("nedge.edit_interface")) print[[</button>

	  </div>
	</div>
      </form>
    </div>
  </div>
  <script>
    $("#editInterfaceAliasModal").on("hidden.bs.modal", function() {
      $(this).find('[name="interface_name"]').val("");
      aysResetForm('#editInterfaceAliasForm');
    })
  </script>]]


