--
-- (C) 2013-24 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local alert_entities = require "alert_entities"

-- ##############################################

-- table containing information about mitre attack matrix
-- keep in sync with en.lua["mitre"]
local mitre_table_utils = {
    tactic = {
        c_and_c = {
          id = 11,
          i18n_label = "mitre.tactic.c_and_c"
        },
        credential_access = {
          id = 6,
          i18n_label = "mitre.tactic.credential_access"
        },
        collection = {
          id = 9,
          i18n_label = "mitre.tatcic.collection"
        },
        defense_evasion = {
          id = 5,
          i18n_label = "mitre.tactic.defense_evasion"
        },
        discovery = {
          id = 7,
          i18n_label = "mitre.tactic.discovery"
        },
        execution = {
          id = 2,
          i18n_label = "mitre.tactic.execution"
        },
        exfiltration = {
          id = 10,
          i18n_label = "mitre.tactic.exfiltration"
        },
        impact = {
          id = 40,
          i18n_label = "mitre.tactic.impact"},
        initial_access = {
          id = 1,
          i18n_label = "mitre.tactic.initial_access"
        },
        lateral_movement = {
          id = 8,
          i18n_label = "mitre.tactic.lateral_movement"
        },
        persistence = {
          id = 3,
          i18n_label = "mitre.tactic.persistence"
        },
        privilege_escalation = {
          id = 4,
          i18n_label = "mitre.tactic.privilege_escalation"
        },
        reconnaissance = {
          id = 43,
          i18n_label = "mitre.tactic.reconnaissance"},
        resource_develop = {
          id = 42,
          i18n_label = "mitre.tactic.resource_develop"
        },
      },
      tecnique = {
        account_manipulation = {
          id = 1098,
          i18n_label = "mitre.tecnique.account_manipulation"
        },
        active_scanning = {
          id = 1595,
          i18n_label = "mitre.tecnique.active_scanning"
        },
        adversary_in_the_middle = {
          id = 1557,
          i18n_label = "mitre.tecnique.adversary_in_the_middle"
        },
        app_layer_proto = {
          id = 1071,
          i18n_label = "mitre.tecnique.app_layer_proto"
        },
        automated_exf = {
          id = 1020,
          i18n_label = "mitre.tecnique.automated_exf"
        },
        content_inj = {
          id = 1659,
          i18n_label = "mitre.tecnique.content_inj"
        },
        data_destruction = {
          id = 1485,
          i18n_label = "mitre.tecnique.data_destruction"
        },
        data_from_conf_repo = {
          id = 1602,
          i18n_label = "mitre.tecnique.data_from_conf_repo"
        },
        data_from_net_shared_driver = {
          id = 1039,
          i18n_label = "mitre.tecnique.data_from_net_shared_driver"
        },
        data_manipulation = {
          id = 1565,
          i18n_label = "mitre.tecnique.data_manipulation"
        },
        data_obfuscation = {
          id = 1001,
          i18n_label = "mitre.tecnique.data_obfuscation"
        },
        drive_by_compr = {
          id = 1189,
          i18n_label = "mitre.tecnique.drive_by_compr"
        },
        dynamic_resolution = {
          id = 1568,
          i18n_label = "mitre.tecnique.dynamic_resolution"
        },
        encrypted_channel = {
          id = 1573,
          i18n_label = "mitre.tecnique.encrypted_channel"
        },
        endpoint_ddos = {
          id = 1499,
          i18n_label = "mitre.tecnique.endpoint_ddos"
        },
        exfiltration_over_alt_proto = {
          id = 1048,
          i18n_label = "mitre.tecnique.exfiltration_over_alt_proto"
        },
        exfiltration_over_c2_channel = {
          id = 1041,
          i18n_label = "mitre.tecnique.exfiltration_over_c2_channel"
        },
        exfiltration_over_web_service = {
          id = 1567,
          i18n_label = "mitre.tecnique.exfiltration_over_web_service"
        },
        exploitatation_client_exec = {
          id = 1203,
          i18n_label = "mitre.tecnique.exploitatation_client_exec"
        },
        expl_privilege_escalation = {
          id = 1068,
          i18n_label = "mitre.tecnique.expl_privilege_escalation"
        },
        exploit_pub_facing_app = {
          id = 1190,
          i18n_label = "mitre.tecnique.exploit_pub_facing_app"
        },
        ext_remote_services = {
          id = 1133,
          i18n_label = "mitre.tecnique.ext_remote_services"
        },
        forced_authentication = {
          id = 1187,
          i18n_label = "mitre.tecnique.forced_authentication"
        },
        gather_victim_net_info = {
          id = 1590,
          i18n_label = "mitre.tecnique.gather_victim_net_info"
        },
        hide_infrastructure = {
          id = 1665,
          i18n_label = "mitre.tecnique.hide_infrastructure"
        },
        impair_defenses = {
          id = 1562,
          i18n_label = "mitre.tecnique.impair_defenses"
        },
        indicator_removal = {
          id = 1070,
          i18n_label = "mitre.tecnique.indicator_removal"
        },
        ingress_tool_tranfer = {
          id = 1105,
          i18n_label = "mitre.tecnique.ingress_tool_tranfer"
        },
        internal_spearphishing = {
          id = 1534,
          i18n_label = "mitre.tecnique.internal_spearphishing"
        },
        lateral_tool_transfer = {
          id = 1570,
          i18n_label = "mitre.tecnique.lateral_tool_transfer"
        },
        network_ddos = {
          id = 1498,
          i18n_label = "mitre.tecnique.network_ddos"
        },
        network_service_discovery = {
          id = 1046,
          i18n_label = "mitre.tecnique.network_service_discovery"
        },
        network_sniffing = {
          id = 1040,
          i18n_label = "mitre.tecnique.Network Sniffing"
        },
        non_app_layer_proto = {
          id = 1095,
          i18n_label = "mitre.tecnique.non_app_layer_proto"
        },
        non_std_port = {
          id = 1571,
          i18n_label = "mitre.tecnique.non_std_port"
        },
        obfuscated_files_info = {
          id = 1027,
          i18n_label = "mitre.tecnique.obfuscated_files_info"
        },
        os_credential_dump = {
          id = 1003,
          i18n_label = "mitre.tecnique.os_credential_dump"
        },
        phishing = {
          id = 1566,
          "mitre.tecnique.phishing"
        },
        phishing_info = {
          id = 1598,
          i18n_label = "mitre.tecnique.phishing_info"
        },
        proxy = {
          id = 1090,
          i18n_label = "mitre.tecnique.proxy"
        },
        remote_services = {
          id = 1021,
          i18n_label = "mitre.tecnique.remote_services"
        },
        remote_system_discovery = {
          id = 1018,
          i18n_label = "mitre.tecnique.remote_system_discovery"
        },
        resource_hijacking = {
          id = 1496,
          i18n_label = "mitre.tecnique.resource_hijacking"
        },
        rogue_domain_controller = {
          id = 1207,
          i18n_label = "mitre.tecnique.rogue_domain_controller"
        },
        scheduled_tranfer = {
          id = 1029,
          i18n_label = "mitre.tecnique.scheduled_tranfer"
        },
        search_open_tech_db = {
          id = 1596,
          i18n_label = "mitre.tecnique.search_open_tech_db"
        },
        server_software_component = {
          id = 1505,
          i18n_label = "mitre.tecnique.server_software_component"
        },
        session_hijacking = {
          id = 1563,
          i18n_label = "mitre.tecnique.session_hijacking"
        },
        steal_web_session_cookie = {
          id = 1539,
          i18n_label = "mitre.tecnique.steal_web_session_cookie"
        },
        system_network_conf_discovery = {
          id = 1016,
          i18n_label = "mitre.tecnique.system_network_conf_discovery"
        },
        traffic_signaling = {
          id = 1205,
          i18n_label = "mitre.tecnique.traffic_signaling"
        },
        user_execution = {
          id = 1204,
          i18n_label = "mitre.tecnique.user_execution"
        },
        valid_accounts = {
          id = 1078,
          i18n_label = "mitre.tecnique.valid_accounts"
        },
        web_service = {
          id = 1102,
          i18n_label = "mitre.tecnique.web_service"
        },
      },
      sub_tecnique = {
        arp_cache_poisoning = {
          id = 155702,
          i18n_label = "mitre.sub_tecnique.sub_tecnique"
        },
        dhcp_spoofing = {
          id = 155703,
          i18n_label = "mitre.sub_tecnique.dhcp_spoofing"
        },
        direct_network_flood = {
          id = 149801,
          i18n_label = "mitre.sub_tecnique.direct_network_flood"
        },
        dns = {
          id = 107104,
          i18n_label = "mitre.sub_tecnique.dns"
        },
        dns_calculation = {
          id = 156803,
          i18n_label = "mitre.sub_tecnique.dns_calculation"
        },
        dns_passive_dns = {
          id = 159601,
          i18n_label = "mitre.sub_tecnique.dns_passive_dns"
        },
        domain_fronting = {
          id = 109004,
          i18n_label = "mitre.sub_tecnique.domain_fronting"
        },
        domain_generation_algorithms = {
          id = 156802,
          i18n_label = "mitre.sub_tecnique.domain_generation_algorithms"
        },
        external_proxy = {
          id = 109002,
          i18n_label = "mitre.sub_tecnique.external_proxy"
        },
        mail_protocol = {
          id = 107103,
          i18n_label = "mitre.sub_tecnique.mail_protocol"
        },
        malicious_link = {
          id = 120401,
          i18n_label = "mitre.sub_tecnique.malicious_link"
        },
        multi_hop_proxy = {
          id = 109003,
          i18n_label = "mitre.sub_tecnique.multi_hop_proxy"
        },
        network_device_config_dump = {
          id = 160202,
          i18n_label = "mitre.sub_tecnique.network_device_config_dump"
        },
        network_topology = {
          id = 159004,
          i18n_label = "mitre.sub_tecnique.network_topology"
        },
        one_way_communication = {
          id = 110203,
          i18n_label = "mitre.sub_tecnique.one_way_communication"
        },
        port_knocking = {
          id = 120501,
          i18n_label = "mitre.sub_tecnique.port_knocking"
        },
        protocol_impersonation = {
          id = 100103,
          i18n_label = "mitre.sub_tecnique.protocol_impersonation"
        },      
        rdp_hijacking = {
          id = 156302,
          i18n_label = "mitre.sub_tecnique.rdp_hijacking"
        },
        reflection_amplification = {
          id = 149802,
          i18n_label = "mitre.sub_tecnique.reflection_amplification"
        },
        remote_desktop_proto = {
          id = 102101,
          i18n_label = "mitre.sub_tecnique.remote_desktop_proto"
        },
        smb_relay = {
          id = 155701,
          i18n_label = "mitre.sub_tecnique.smb_relay"
        },
        smb_windows_admin_share = {
          id = 102102,
          i18n_label = "mitre.sub_tecnique.smb_windows_admin_share"
        },
        spearphishing_link = {
          id = 156602,
          i18n_label = "mitre.sub_tecnique.spearphishing_link"
        },
        spearphishing_service = {
          id = 156603,
          i18n_label = "mitre.sub_tecnique.spearphishing_service"
        },
        ssh = {
          id = 109804,
          i18n_label = "mitre.sub_tecnique.ssh"
        },
        web_protocol = {
          id = 107101,
          i18n_label = "mitre.sub_tecnique.web_protocol"
        },
        wordlist_scanning = {
          id = 159503,
          i18n_label = "mitre.sub_tecnique.wordlist_scanning"
        },
      }
}

-- ##############################################

local mitre_info_table = {}

-- ##############################################

local function createTableMitreInfo(mitre_info, alert_id, entity_id)
  if mitre_info.mitre_sub_tecnique_id ~= nil then
      if mitre_info_table[mitre_info.mitre_id] == nil then
          mitre_info_table[mitre_info.mitre_id] = {
              alert_array = {},
              tactic = mitre_info.mitre_tactic_id,
              tecnique = mitre_info.mitre_tecnique_id,
              sub_tecnique = mitre_info.mitre_sub_tecnique_id
          }
          mitre_info_table[mitre_info.mitre_id].alert_array[1] = {alert_id, entity_id}
      else
          local alert_array_len = #mitre_info_table[mitre_info.mitre_id].alert_array
          mitre_info_table[mitre_info.mitre_id].alert_array[alert_array_len + 1] = {alert_id, entity_id}
      end
  elseif mitre_info.mitre_tecnique_id ~= nil then
      if mitre_info_table[mitre_info.mitre_id] == nil then
          mitre_info_table[mitre_info.mitre_id] = {
              alert_array = {},
              tactic = mitre_info.mitre_tactic_id,
              tecnique = mitre_info.mitre_tecnique_id
          }
          mitre_info_table[mitre_info.mitre_id].alert_array[1] = {alert_id, entity_id}
      else
          local alert_array_len = #mitre_info_table[mitre_info.mitre_id].alert_array
          mitre_info_table[mitre_info.mitre_id].alert_array[alert_array_len + 1] = {alert_id, entity_id}
      end
  elseif mitre_info.mitre_tactic_id ~= nil then
      if mitre_info_table[mitre_info.mitre_id] == nil then
          mitre_info_table[mitre_info.mitre_id] = {
              alert_array = {},
              tactic = mitre_info.mitre_tactic_id
          }
          mitre_info_table[mitre_info.mitre_id].alert_array[1] = {alert_id, entity_id}
      else
          local alert_array_len = #mitre_info_table[mitre_info.mitre_id].alert_array
          mitre_info_table[mitre_info.mitre_id].alert_array[alert_array_len + 1] = {alert_id, entity_id}
      end
  end
end  

-- ##############################################

local function mitreTableInfo() 
    local checks = require "checks"
    local alert_consts = require "alert_consts"

    local subdirs = {}

    for _, subdir in pairs(checks.listSubdirs()) do
      subdirs[#subdirs + 1] = subdir.id
    end
   
    for _, subdir in ipairs(subdirs) do
      local script_type = checks.getScriptType(subdir)
      local scripts = checks.load(getSystemInterfaceId(), script_type, subdir, {return_all = false})
  
      for script_name, script in pairs(scripts.modules) do
          if  alert_entities[subdir] then
            local entity_id = alert_entities[subdir].entity_id
            if entity_id ~= nil then
                local alert_key = alert_consts.getAlertType(script.alert_id, entity_id)
                if alert_key ~= nil then
                  local mitre_info = alert_consts.getAlertMitreInfoIDs(alert_key)
                  if mitre_info ~= nil then
                    createTableMitreInfo(mitre_info, script.alert_id, entity_id)
                  end
                end
            end
          end
      end 
    end
    
    return mitre_info_table
  end
  
-- ##############################################

function mitre_table_utils.insertDBMitreInfo()
  local value_to_add = ""
  local table_name = "mitre_table_info"
  local table_name_with_values = string.format("%s (alert_id, entity_id, tactic, tecnique, sub_tecnique, mitre_id)", table_name)
  local mitre_table = mitreTableInfo()

  for mitre_id, value in pairs(mitre_table) do
    local current_values = ""
    for _, alert_key in pairs(value.alert_array) do
      if value.tactic == nil then
        value.tactic = 0
      end
      if value.tecnique == nil then
        value.tecnique = 0
      end
      if value.sub_tecnique == nil then
        value.sub_tecnique = 0
      end
        current_values = current_values.."("..alert_key[1]..","..alert_key[2]..","..value.tactic..","..value.tecnique
                        ..","..value.sub_tecnique..",'"..mitre_id.."'),"
    end
    value_to_add = value_to_add .. current_values
  end

  -- replace the last ',' character with ';' in order to push all value in one into the DB 
  value_to_add = value_to_add:sub(1, -2)..";"
  local sql
  if hasClickHouseSupport() then
    table_name_with_values = "mitre_table_info (ALERT_ID, ENTITY_ID, TACTIC, TECNIQUE, SUB_TECNIQUE, MITRE_ID)"
    sql = "INSERT INTO "..table_name_with_values.." VALUES "..value_to_add
  else
    sql = "INSERT OR REPLACE INTO "..table_name_with_values.." VALUES "..value_to_add
  end
  interface.alert_store_query(sql)
  
  if hasClickHouseSupport() then
    interface.alert_store_query("OPTIMIZE TABLE ".. table_name .. " FINAL;")
  end
end

-- ##############################################

return mitre_table_utils