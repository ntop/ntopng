--
-- (C) 2013-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/pro/scripts/lua/nedge/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/pro/scripts/lua/nedge/modules/system_config/?.lua;" .. package.path

local system_setup_ui_utils = require "system_setup_ui_utils"
local template = require "template_utils"
require "prefs_utils"
require "lua_utils"
prefsSkipRedis(true)

local nf_config = require("nf_config"):create(true)
local operating_mode = nf_config:getOperatingMode()
system_setup_ui_utils.process_apply_discard_config(nf_config)

if table.len(_POST) > 0 then
  local interfaces_config = nf_config:getInterfacesConfiguration()
  local disabled_wans = nf_config:getDisabledWans()
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
      }

      if _POST[fields.ip] ~= nil then config.network.ip = _POST[fields.ip] end
      if _POST[fields.gw] ~= nil then config.network.gateway = _POST[fields.gw] end
      if _POST[fields.netmask] ~= nil then config.network.netmask = _POST[fields.netmask] end
      if _POST[fields.mode] ~= nil then config.network.mode = _POST[fields.mode] end
      if _POST[fields.upload] ~= nil then config.speed.upload = tonumber(_POST[fields.upload]) end
      if _POST[fields.download] ~= nil then config.speed.download = tonumber(_POST[fields.download]) end
      if _POST[fields.iface_on] ~= nil then disabled_wans[if_name] = ternary(_POST[fields.iface_on] == "1", false, true) end
      if _POST[fields.nat_on] ~= nil then config.masquerade = ternary(_POST[fields.nat_on] == "1", true, false) end
    end
  end

  if config_found then
    nf_config:setDisabledWans(disabled_wans)
    nf_config:setInterfacesConfiguration(interfaces_config)
    nf_config:setDhcpFromLan()
    nf_config:save()
  end
end

local disabled_wans = nf_config:getDisabledWans()

-- Static ip configuration
local function printLanLikeConfig(if_name, if_id, ifconf)
  printPageSection(i18n("nedge.network_conf_iface_title", {ifname = if_name, ifrole = i18n("nedge.lan")}))

  print[[<input type="hidden" name="iface_id_]] print(if_id) print[[" value="]] print(if_name) print[[" />]]

  --system_setup_ui_utils.printPrivateAddressSelector(i18n("nedge.lan_ip_addr"), i18n("nedge.lan_ip_addr_descr"), "iface_ip_"..if_id, "iface_netmask_"..if_id, ifconf.network.ip, showEnabled)
  prefsInputFieldPrefs(i18n("ip_address"), i18n("nedge.network_conf_iface_ip"),
          "", "iface_ip_"..if_id, ifconf.network.ip or "192.168.1.1", nil, nil, nil, nil,
          {required=true, pattern=getIPv4Pattern()})

  prefsInputFieldPrefs(i18n("netmask"), i18n("nedge.network_conf_iface_nmask"),
          "", "iface_netmask_"..if_id, ifconf.network.netmask or "255.255.255.0", nil, nil, nil, nil,
          {required=true, pattern=getIPv4Pattern()})
end

-- Static/Dynamic ip configuration, with gateway and speed
local function printWanLikeConfig(if_name, if_id, ifconf, bridge_interface)
  local mode = ifconf.network.mode or "static"
  local show_static = ternary(mode == "static", true, false)
  local title = ternary(bridge_interface, i18n("bridge"), i18n("nedge.network_conf_iface_title", {ifname = if_name, ifrole = i18n("nedge.wan")}))
  local mode_values = {"static", "dhcp"}
  local mode_labels = {i18n("nedge.network_conf_static"), i18n("nedge.network_conf_dhcp")}

  printPageSection("<span id='" .. if_name .. "_interface'>" .. title  .. "</span>")

  print[[<input type="hidden" name="iface_id_]] print(if_id) print[[" value="]] print(if_name) print[[" />]]

  if not bridge_interface then
    prefsToggleButton(subpage_active, {
      title = i18n("nedge.enable_interface"),
      description = i18n("nedge.enable_interface_descr"),
      content = "",
      field = "iface_on_" .. if_id,
      pref = "",
      redis_prefix = "",
      default = ternary(not disabled_wans[if_name], "1", "0"),
      to_switch = nil,
    })
  else
     -- in bridge mode, we allow the bridge to be on a VLAN trunk
     mode_values[#mode_values + 1] = "vlan_trunk"
     mode_labels[#mode_labels + 1] = i18n("nedge.network_conf_vlan_trunk")
  end


  local elementToSwitch = {"iface_ip_"..if_id, "iface_gw_"..if_id, "iface_netmask_"..if_id}
  local showElementArray = {true, false, false}

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

  if not bridge_interface then
    prefsToggleButton(subpage_active, {
      title = i18n("nedge.enable_nat"),
      description = i18n("nedge.enable_nat_descr"),
      content = "",
      field = "iface_nat_" .. if_id,
      pref = "",
      redis_prefix = "",
      default = ternary(ifconf.masquerade, "1", "0"),
      to_switch = nil,
    })
  end
end

local function print_routing_page_body()
  local all_interfaces = nf_config:getAllInterfaces()
  local interfaces_config = nf_config:getInterfacesConfiguration()

  if table.len(all_interfaces) > 0 then
    -- Assign an unique id to the interface
    local ifname_to_id = {}
    local ctr = 0

    for if_name in pairs(all_interfaces) do
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
        printWanLikeConfig(if_name, ifname_to_id[if_name], interfaces_config[if_name])
      end
    end
  else
    prefsInformativeField("", i18n("nedge.no_interfaces_available"), true)
  end

  printSaveButton()
end

local function print_bridging_page_body()
  local if_name = nf_config:getBridgeInterfaceName()
  local interfaces_config = nf_config:getInterfacesConfiguration()

  printWanLikeConfig(if_name, "0", interfaces_config[if_name], true)
  printSaveButton()
end

system_setup_ui_utils.print_setup_page(ternary(operating_mode == "bridging", print_bridging_page_body, print_routing_page_body), nf_config)

