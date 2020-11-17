--
-- (C) 2013-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/pro/scripts/lua/nedge/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/pro/scripts/lua/nedge/modules/system_config/?.lua;" .. package.path

local system_setup_ui_utils = require "system_setup_ui_utils"
local json = require("dkjson")
require "lua_utils"
require "prefs_utils"
prefsSkipRedis(true)

local nf_config = require("nf_config"):create(true)

system_setup_ui_utils.process_apply_discard_config(nf_config)

local function findDnsPreset(preset_name)
  for _, preset in pairs(DNS_PRESETS) do
    if preset.id == preset_name then
      return preset
    end
  end

  return nil
end

if table.len(_POST) > 0 then
  local dns_config = nf_config:getDnsConfig()
  local changed = false

  if _POST["global_dns_preset"] ~= nil then
    local primary_dns = _POST["global_primary_dns"]
    local secondary_dns = _POST["global_secondary_dns"]
    local preset = findDnsPreset(_POST["global_dns_preset"])

    if preset ~= nil then
      primary_dns = preset.primary_dns
      secondary_dns = preset.secondary_dns
    end

    if not isEmptyString(primary_dns) and (secondary_dns ~= nil) then
      dns_config.global_preset = ternary(preset ~= nil, _POST["global_dns_preset"], "custom")
      dns_config.global = primary_dns
      dns_config.secondary = secondary_dns
      changed = true
    end
  end

  if _POST["child_dns_preset"] ~= nil then
    local child_dns = _POST["child_primary_dns"]
    local preset = findDnsPreset(_POST["child_dns_preset"])

    if preset ~= nil then
      child_dns = preset.primary_dns
    end

    if not isEmptyString(child_dns) then
      dns_config.child_preset = ternary(preset ~= nil, _POST["child_dns_preset"], "custom")
      dns_config.child_safe = child_dns
      changed = true
    end
  end

  if _POST["forge_global_dns"] ~= nil then
    dns_config.forge_global = _POST["forge_global_dns"] == "1"
    changed = true
  end

  if changed then
    nf_config:setDnsConfig(dns_config)
    nf_config:save()
  end
end

local function getDnsPresets(childsafe)
  -- Init dns dropdown
  local dns_keys = {}
  local dns_values = {}

  for _, dns in ipairs(DNS_PRESETS) do
    if (childsafe and dns.child_safe) or (not childsafe and not dns.child_safe) then
      dns_keys[#dns_keys + 1] = dns.id
      dns_values[#dns_values + 1] = dns.label
    end
  end

  dns_keys[#dns_keys + 1] = "custom"
  dns_values[#dns_values + 1] = i18n("nedge.custom")

  return dns_keys, dns_values
end

local print_page_body = function()
  local dns_config = nf_config:getDnsConfig()

  -- Global DNS
  local dns_forging = nf_config:isGlobalDnsForgingEnabled()

  printPageSection(i18n("nedge.global_dns"))
  prefsToggleButton(subpage_active, {
    title = i18n("nedge.enforce_global_dns"),
    description = i18n("nedge.enforce_global_dns_description"),
    content = "",
    field = "forge_global_dns",
    pref = "",
    redis_prefix = "",
    default = ternary(dns_forging, "1", "0"),
    to_switch = nil,
  })

  local dns_keys, dns_values = getDnsPresets(false)
  prefsDropdownFieldPrefs(i18n("nedge.dns_server_preset"), i18n("nedge.dns_server_preset_descr"), "global_dns_preset", dns_values, dns_config.global_preset or "custom", true, {keys=dns_keys})

  prefsInputFieldPrefs(i18n("prefs.primary_dns"), i18n("nedge.the_primary_dns_server"),
          "", "global_primary_dns", dns_config.global or "0.0.0.0", nil, true, nil, nil,
          {required=true, pattern=getIPv4Pattern()})

  prefsInputFieldPrefs(i18n("prefs.secondary_dns"), i18n("nedge.the_secondary_dns_server"),
          "", "global_secondary_dns", dns_config.secondary or "0.0.0.0", nil, true, nil, nil,
          {required=false, pattern=getIPv4Pattern()})

  -- Child Safe DNS
  local dns_keys, dns_values = getDnsPresets(true)

  printPageSection(i18n("prefs.safe_search_dns_title"))
  prefsDropdownFieldPrefs(i18n("nedge.dns_server_preset"), i18n("nedge.dns_server_preset_descr"), "child_dns_preset", dns_values, dns_config.child_preset or "custom", true, {keys=dns_keys})

  prefsInputFieldPrefs(i18n("prefs.safe_search_dns_title"), i18n("nedge.the_primary_dns_server"),
          "", "child_primary_dns", dns_config.child_safe or "0.0.0.0", nil, true, nil, nil,
          {required=true, pattern=getIPv4Pattern()})

  printSaveButton()

  print[[
    <script>
      var dns_presets = ]] print(json.encode(DNS_PRESETS)) print[[;

      function handlePreset(key) {
        var selector = $("#" + key + "_dns_preset");
        var checkDns = function() {
          var selection = $(selector).val();

          for (var i=0; i<dns_presets.length; i++) {
            if (dns_presets[i].id == selection) {
              $("#" + key + "_primary_dns")
                .attr("disabled", "disabled")
                .val(dns_presets[i].primary_dns);

              $("#" + key + "_secondary_dns")
                .attr("disabled", "disabled")
                .val(dns_presets[i].secondary_dns);
              return;
            }
          }

          // not found, assuming custom
          $("#" + key + "_primary_dns").removeAttr("disabled");
          $("#" + key + "_secondary_dns").removeAttr("disabled");
        }

        selector.change(checkDns);
        checkDns();
      }

      handlePreset("id_input_global");
      handlePreset("id_input_child");
    </script>
  ]]
end

system_setup_ui_utils.print_setup_page(print_page_body, nf_config)
