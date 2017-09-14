--
-- (C) 2017 - ntop.org
--

local pragma_once = 1
local http_lint = {}
local json = require "dkjson"

-- #################################################################

-- UTILITY FUNCTIONS

-- Searches into the keys of the table
local function validateChoiceByKeys(defaults, v)
   if defaults[v] ~= nil then
      return true
   else
      return false
   end
end

-- Searches into the value of the table
-- Optional key can be used to access fields of the array element
local function validateChoice(defaults, v, key)
   for _,d in pairs(defaults) do
      if key ~= nil then
         if d[key] == v then
            return true
         end
      else
         if d == v then
            return true
         end
      end
   end

   return false
end

local function validateChoiceInline(choices)
   return function(choice)
      if (validateChoice(choices, choice)) then
         return true
      else
         return false
      end
   end
end

local function validateListOfType(l, validate_callback, separator)
   local separator = separator or ","
   if isEmptyString(l) then
      return true
   end

   local items = split(l, separator)

   for _,item in pairs(items) do
      if item ~= "" then
         if not validate_callback(item) then
            return false
         end
      end
   end

   return true
end

local function validateEmpty(s)
   if s == "" then
      return true
   else
      return false
   end
end

local function validateEmptyOr(other_validation)
   return function(s)
      if (validateEmpty(s) or other_validation(s)) then
         return true
      else
         return false
      end
   end
end

-- #################################################################

-- FRONT-END VALIDATORS

local function validateNumber(p)
   -- integer number validation
   local num = tonumber(p)
   if num == nil then
      return false
   end

   if math.floor(num) == num then
      return true
   else
      -- this is a float number
      return false
   end
end

local function validatePort(p)
   if not validateNumber(p) then
      return false
   end

   local n = tonumber(p)
   if ((n ~= nil) and (n >= 1) and (n <= 65535)) then
      return true
   else
      return false
   end
end

local function validateUnquoted(p)
   -- This function only verifies that value does not contain single quotes, but
   -- does not perform any type validation, so it should be used with care.
   -- Double quotes are already handled by the C side.
   if (string.find(p, "'") ~= nil) then
      return false
   else
      return true
   end
end
http_lint.validateUnquoted = validateUnquoted

local function validateUnchecked(p)
   -- This function does not perform any validation, so only the C side validation takes place.
   -- In particular, single quotes are allowed so they must be handled explicitly by the programmer in
   -- order to avoid injection.
   return true
end
http_lint.validateUnchecked = validateUnchecked

local function validateSingleWord(w)
if (string.find(w, "% ") ~= nil) then
      return false
   else
      return validateUnquoted(w)
   end
end
http_lint.validateSingleWord = validateSingleWord

local function validateAbsolutePath(p)
   -- An absolute path. Let it pass for now
   return validateUnquoted(p)
end

local function validateNumMinutes(m)
   return (m == "custom") or validateNumber(m)
end

local function validateJSON(j)
   return (json.decode(j) ~= nil)
end

-- #################################################################

local function validateOnOff(mode)
   local modes = {"on", "off"}

   return validateChoice(modes, mode)
end

local function validateMode(mode)
   local modes = {"all", "local", "remote", "filtered", "restore"}

   return validateChoice(modes, mode)
end

local function validateNetworkMode(mode)
   local modes = { "router","transparent_bridge"}

   return validateChoice(modes, mode)
end

local function validateOperator(mode)
   local modes = {"gt", "eq", "lt"}

   return validateChoice(modes, mode)
end

local function validateHttpMode(mode)
   local modes = {"responses", "queries"}

   return validateChoice(modes, mode)
end

local function validatePidMode(mode)
   local modes = {"l4", "l7", "host", "apps"}

   return validateChoice(modes, mode)
end

local function validateNdpiStatsMode(mode)
   local modes = {"sinceStartup", "count", "host"}

   return validateChoice(modes, mode)
end

local function validateSflowDistroMode(mode)
   local modes = {"host", "process", "user"}

   return validateChoice(modes, mode)
end

local function validateSflowDistroType(mode)
   local modes = {"size", "memory", "bytes", "latency", "server", "ipver"}

   return validateChoice(modes, mode)
end

local function validateSflowFilter(mode)
   local modes = {"All", "Client", "Server", "recv", "sent"}

   return validateChoice(modes, mode)
end

local function validateIfaceLocalStatsMode(mode)
   local modes = {"distribution"}

   return validateChoice(modes, mode)
end

local function validateProcessesStatsMode(mode)
   local modes = {"table", "timeline"}

   return validateChoice(modes, mode)
end

local function validateDirection(mode)
   local modes = {"sent", "recv"}

   return validateChoice(modes, mode)
end

local function validateSendersReceivers(mode)
   local modes = {"senders", "receivers"}

   return validateChoice(modes, mode)
end

local function validateClientOrServer(mode)
   local modes = {"client", "server"}

   return validateChoice(modes, mode)
end

local function validateBroadcastUnicast(mode)
   local modes = {"unicast", "broadcast_multicast",
		  "one_way_unicast", "one_way_broadcast_multicast"}

   return validateChoice(modes, mode)
end

local function validateFlowStatus(mode)
   local modes = {"normal", "alerted", "filtered"}

   return validateChoice(modes, mode)
end

local function validatePolicyPreset(mode)
   local modes = {"children", "business", "no_obfuscation", "walled_garden"}

   return validateChoice(modes, mode)
end

local function validateStatsType(mode)
   local modes = {"severity_pie", "type_pie", "count_sparkline", "top_origins",
      "top_targets", "duration_pie", "longest_engaged", "counts_pie",
      "counts_plain", "top_talkers", "top_applications"}

   return validateChoice(modes, mode)
end

local function validateAlertStatsType(mode)
   local modes = {"severity_pie", "type_pie", "count_sparkline", "top_origins",
      "top_targets", "duration_pie", "longest_engaged", "counts_pie",
      "counts_plain"}

   return validateChoice(modes, mode)
end

local function validateFlowHostsType(mode)
   local modes = {"local_only", "remote_only",
      "local_origin_remote_target", "remote_origin_local_target", "all_hosts"}

   return validateChoice(modes, mode)
end

local function validateConsolidationFunction(mode)
   local modes = {"AVERAGE", "MAX", "MIN"}

   return validateChoice(modes, mode)
end

local function validateAlertStatus(mode)
   local modes = {"engaged", "historical", "historical-flows"}

   return validateChoice(modes, mode)
end

local function validateAggregation(mode)
   local modes = {"ndpi", "l4proto", "port"}

   return validateChoice(modes, mode)
end

local function validateReportMode(mode)
   local modes = {"daily", "weekly", "monthly"}

   return validateChoice(modes, mode)
end

local function validateNboxAction(mode)
   local modes = {"status", "schedule"}

   return validateChoice(modes, mode)
end

local function validateFavouriteAction(mode)
   local modes = {"set", "get", "del", "del_all"}

   return validateChoice(modes, mode)
end

local function validateFavouriteType(mode)
   local modes = {"apps_per_host_pair", "top_applications", "talker", "app",
      "host_peers_by_app"}

   return validateChoice(modes, mode)
end

local function validateAjaxFormat(mode)
   local modes = {"d3"}

   return validateChoice(modes, mode)
end

local function validatePrintFormat(mode)
   local modes = {"txt", "json"}

   return validateChoice(modes, mode)
end

local function validateResetStatsMode(mode)
   local modes = {"reset_drops", "reset_all"}

   return validateChoice(modes, mode)
end

local function validateDevicesMode(mode)
   local modes = {"host_macs_only"}

   return validateChoice(modes, mode)
end

local function validateUnassignedDevicesMode(mode)
   local modes = {"active_only", "inactive_only"}

   return validateChoice(modes, mode)
end

local function validateSnmpAction(mode)
   local modes = {"delete", "add", "addNewDevice", "startPolling", "stopPolling"}

   return validateChoice(modes, mode)
end

local function validateUserRole(mode)
   local modes = {"administrator", "unprivileged", "captive_portal"}

   return validateChoice(modes, mode)
end

local function validateUserLanguage(code)
   local codes = {}
   for _, c in pairs(locales_utils.getAvailableLocales()) do
      codes[#codes + 1] = c["code"]
   end

   return validateChoice(codes, code)
end

-- #################################################################

local function validateHost(p)
   -- TODO stricter checks, allow @vlan
   if(isIPv4(p) or isIPv6(p) or isMacAddress(p)) then
      return true
   else
      return false
   end
end

local function validateMac(p)
   if isMacAddress(p) then
      return true
   else
      return false
   end
end

local function validateIPV4(p)
   return isIPv4(p)
end

local function validateIpAddress(p)
   if (isIPv4(p) or isIPv6(p)) then
      return true
   else
      return false
   end
end

local function validateHTTPHost(p)
   -- TODO maybe stricter check?
   if validateSingleWord(p) then
      return true
   else
      return false
   end
end

local function validateIpVersion(p)
   if ((p == "4") or (p == "6")) then
      return true
   else
      return false
   end
end

local function validateDate(p)
   -- TODO this validation function should be removed and dates should always be passed as timestamp
   if string.find(p, ":") ~= nil then
      return true
   else
      return false
   end
end

local function validateMember(m)
   if isValidPoolMember(m) then
      return true
   else
      return false
   end
end

local function validateMembersFilter(m)
   if starts(m, "manuf:") then
      m = string.sub(m, string.len("manuf:") + 1)
      return validateUnquoted(m)
   end

   return validateMember(m)
end

local function validateIdToDelete(i)
   if ((i == "__all__") or validateNumber(i)) then
      return true
   else
      return false
   end
end

local function validateLocalGlobal(p)
   local values = {"local", "global"}
   
   return validateChoice(values, p)
end

local function validateBool(p)
   if((p == "true") or (p == "false")) then
      return true
   else
      local n = tonumber(p)
      if ((n == 0) or (n == 1)) then
         return true
      else
         return false
      end
   end
end

local function validateSortOrder(p)
   local defaults = {"asc", "desc"}
   
   return validateChoice(defaults, p)
end

local ndpi_protos = interface.getnDPIProtocols()
local ndpi_categories = interface.getnDPICategories()
local site_categories = ntop.getSiteCategories()

local function validateApplication(app)
   local modes = {"TCP", "UDP"}
   if validateChoice(modes, app) then
      return true
   end

   local dot = string.find(app, "%.")

   if dot ~= nil then
      local master = string.sub(app, 1, dot-1)
      local sub = string.sub(app, dot+1)
      return validateChoiceByKeys(ndpi_protos, master) and validateChoiceByKeys(ndpi_protos, sub)
   else
      return validateChoiceByKeys(ndpi_protos, app)
   end
end

local function validateProtocolId(p)
   return validateChoice(ndpi_protos, p)
end

local function validateCategory(cat)
   return validateChoiceByKeys(site_categories, cat)
end

function http_lint.validateTrafficProfile(p)
   return validateUnquoted(p)
end

local function validateSortColumn(p)
   -- Note: this is also used in some scripts to specify the ordering, so the "column_"
   -- prefix is not honored
   if((validateSingleWord(p)) --[[and (string.starts(p, "column_"))]]) then
      return true
   else
      return false
   end
end

local function validateCountry(p)
   if string.len(p) == 2 then
      return true
   else
      return false
   end
end

local function validateInterface(i)
   -- TODO
   return validateNumber(i)
end

local function validateNetwork(i)
   -- TODO
   return validateSingleWord(i)
end

local function validateZoom(zoom)
   if string.match(zoom, "%d+%a") == zoom then
      return true
   else
      return false
   end
end

local function validateShapedElement(elem_id)
   local id
   if starts(elem_id, "cat_") then
      id = split(elem_id, "cat_")[2]
   else
      id = elem_id
   end

   if ((elem_id == "default") or validateNumber(id)) then
      return true
   else
      return false
   end
end

local function validateAlertDescriptor(d)
   if starts(d, "global_") then
      d = split(d, "global_")[2]
   end

   if ((validateChoiceByKeys(alert_functions_description, d)) or
       (validateChoiceByKeys(network_alert_functions_description, d))) then
      return true
   else
      return false
   end
end

local function validateInterfacesList(l)
   return validateListOfType(l, validateInterface)
end

local function validateNetworksList(l)
   return validateListOfType(l, validateNetwork)
end

local function validateCategoriesList(mode)
   return validateListOfType(l, validateCategory)
end

local function validateApplicationsList(l)
   return validateListOfType(l, validateApplication)
end

local function validateHostsList(l)
   return validateListOfType(l, validateHost)
end

local function validateIfFilter(i)
   if validateNumber(i) or i == "all" then
      return true
   else
      return false
   end
end

local function validateLookingGlassCriteria(c)
   if validateChoice(looking_glass_criteria, c, 1) then
      return true
   else
      return false
   end
end

local function validateTopModule(m)
   -- TODO check for existence?
   return validateSingleWord(m)
end

-- #################################################################

-- NOTE: Put here al the parameters to validate

local known_parameters = {
-- UNCHECKED (Potentially Dangerous)
   ["custom_name"]             =  validateUnchecked,            -- A custom interface/host name
   ["pool_name"]               =  validateUnchecked,
   ["query"]                   =  validateUnchecked,           -- This field should be used to perform partial queries.
                                                               -- It up to the script to implement proper validation.
                                                               -- In NO case query should be executed directly without validation.

-- UNQUOTED (Not Generally dangerous)
   ["referer"]                 =  validateUnquoted,             -- An URL referer
   ["url"]                     =  validateUnquoted,             -- An URL
   ["label"]                   =  validateUnquoted,             -- A device label
   ["os"]                      =  validateUnquoted,             -- An Operating System string
   ["info"]                    =  validateUnquoted,             -- An information message
   ["entity_val"]              =  validateUnquoted,             -- An alert entity value
   ["full_name"]               =  validateUnquoted,             -- A user full name
   ["manufacturer"]            =  validateUnquoted,             -- A MAC manufacturer
   ["sender_username"]         =  validateUnquoted,
   ["slack_webhook"]           =  validateUnquoted,
   ["nagios_nsca_host"]        =  validateUnquoted,
   ["nagios_host_name"]        =  validateUnquoted,
   ["nagios_service_name"]     =  validateUnquoted,
   ["bind_dn"]                 =  validateUnquoted,
   ["bind_pwd"]                =  validateUnquoted,
   ["search_path"]             =  validateUnquoted,
   ["user_group"]              =  validateUnquoted,
   ["admin_group"]             =  validateUnquoted,

-- HOST SPECIFICATION
   ["host"]                    =  validateHost,                  -- an IPv4 (optional @vlan), IPv6 (optional @vlan), or MAC address
   ["versus_host"]             =  validateHost,                  -- an host for comparison
   ["mac"]                     =  validateMac,                   -- a MAC address
   ["peer1"]                   =  validateHost,                  -- a Peer in a connection
   ["peer2"]                   =  validateHost,                  -- another Peer in a connection
   ["origin"]                  =  validateHost,                  -- the source of the alert
   ["target"]                  =  validateHost,                  -- the target of the alert
   ["member"]                  =  validateMember,                -- an IPv4 (optional @vlan, optional /suffix), IPv6 (optional @vlan, optional /suffix), or MAC address
   ["network"]                 =  validateNumber,                -- A network ID
   ["ip"]                      =  validateEmptyOr(validateIpAddress), -- An IPv4 or IPv6 address
   ["vhost"]                   =  validateHTTPHost,              -- HTTP server name or IP address
   ["version"]                 =  validateIpVersion,             -- To specify an IPv4 or IPv6
   ["vlan"]                    =  validateEmptyOr(validateNumber), -- A VLAN id
   ["hosts"]                   =  validateHostsList,             -- A list of hosts

-- AUTHENTICATION
   ["username"]                =  validateSingleWord,            -- A ntopng user name, new or existing
   ["password"]                =  validateSingleWord,            -- User password
   ["new_password"]            =  validateSingleWord,            -- The new user password
   ["old_password"]            =  validateSingleWord,            -- The old user password
   ["confirm_password"]        =  validateSingleWord,            -- Confirm user password
   ["user_role"]               =  validateUserRole,              -- User role
   ["user_language"]           =  validateUserLanguage,          -- User language

-- NDPI
   ["application"]             =  validateApplication,           -- An nDPI application protocol name
   ["breed"]                   =  validateBool,                  -- True if nDPI breed should be shown
   ["ndpistats_mode"]          =  validateNdpiStatsMode,         -- A mode for iface_ndpi_stats.lua
   ["l4_proto_id"]             =  validateProtocolId,            -- get_historical_data.lua
   ["l7_proto_id"]             =  validateProtocolId,            -- get_historical_data.lua
   ["l4proto"]                 =  validateProtocolId,            -- An nDPI application protocol ID, layer 4
   ["l7proto"]                 =  validateProtocolId,            -- An nDPI application protocol ID, layer 7
   ["protocol"]                =  validateProtocolId,            -- An nDPI application protocol ID, (layer 7? Duplicate?)
   ["ndpi"]                    =  validateApplicationsList,      -- a list applications

-- Remote probe
   ["ifIdx"]                   =  validateNumber,                -- A generic switch/router port id
   ["inIfIdx"]                 =  validateNumber,                -- A switch/router INPUT port id (%INPUT_SNMP)
   ["outIfIdx"]                =  validateNumber,                -- A switch/router OUTPUT port id (%OUTPUT_SNMP)
   ["deviceIP"]                =  validateIPV4,                  -- The switch/router exporter ip address (%EXPORTER_IPV4_ADDRESS)
   ["pid_mode"]                =  validatePidMode,               -- pid mode for pid_stats.lua
   ["pid_name"]                =  validateSingleWord,            -- A process name
   ["pid"]                     =  validateNumber,                -- A process ID
   ["procstats_mode"]          =  validateProcessesStatsMode,    -- A mode for processes_stats.lua
   ["sflowdistro_mode"]        =  validateSflowDistroMode,       -- A mode for host_sflow_distro
   ["distr"]                   =  validateSflowDistroType,       -- A type for host_sflow_distro
   ["sflow_filter"]            =  validateSflowFilter,           -- sflow host filter

-- TIME SPECIFICATION
   ["epoch"]                   =  validateNumber,                -- A timestamp value
   ["epoch_begin"]             =  validateNumber,                -- A timestamp value to indicate start time
   ["epoch_end"]               =  validateNumber,                -- A timestamp value to indicate end time
   ["period_begin_str"]        =  validateDate,                  -- Specifies a start date in JS format
   ["period_end_str"]          =  validateDate,                  -- Specifies an end date in JS format
   ["timezone"]                =  validateNumber,                -- The timezone of the browser

-- PAGINATION
   ["perPage"]                 =  validateNumber,                -- Number of results per page (used for pagination)
   ["sortOrder"]               =  validateSortOrder,             -- A sort order
   ["sortColumn"]              =  validateSortColumn,            -- A sort column
   ["currentPage"]             =  validateNumber,                -- The currently displayed page number (used for pagination)
   ["totalRows"]               =  validateNumber,                -- The total number of rows

-- AGGREGATION
   ["grouped_by"]              =  validateSingleWord,            -- A group criteria
   ["aggregation"]             =  validateAggregation,           -- A mode for graphs aggregation
   ["limit"]                   =  validateNumber,                -- To limit results
   ["all"]                     =  validateEmpty,                 -- To remove limit on results

-- NAVIGATION
   ["page"]                    =  validateSingleWord,            -- Currently active subpage tab
   ["tab"]                     =  validateSingleWord,            -- Currently active tab, handled by javascript

-- TRAFFIC DUMP
   ["dump_flow_to_disk"]       =  validateBool,                  -- true if target flow should be dumped to disk
   ["dump_traffic"]            =  validateBool,                  -- true if target host traffic should be dumped to disk
   ["dump_all_traffic"]        =  validateBool,                  -- true if interface traffic should be dumped to disk
   ["dump_traffic_to_tap"]     =  validateBool,                  --
   ["dump_traffic_to_disk"]    =  validateBool,                  --
   ["dump_unknown_to_disk"]    =  validateBool,                  --
   ["dump_security_to_disk"]   =  validateBool,                  --
   ["max_pkts_file"]           =  validateNumber,                --
   ["max_sec_file"]            =  validateNumber,                --
   ["max_files"]               =  validateNumber,                --

-- OTHER
   ["_"]                       =  validateEmptyOr(validateNumber), -- jQuery nonce in ajax requests used to prevent browser caching
   ["ifid"]                    =  validateInterface,             -- An ntopng interface ID
   ["iffilter"]                =  validateIfFilter,              -- An interface ID or 'all'
   ["mode"]                    =  validateMode,                  -- Remote or Local users
   ["country"]                 =  validateCountry,               -- Country code
   ["flow_key"]                =  validateNumber,                -- The ID of a flow hash
   ["pool"]                    =  validateNumber,                -- A pool ID
   ["direction"]               =  validateDirection,             -- Sent or Received direction
   ["stats_type"]              =  validateStatsType,             -- A mode for historical stats queries
   ["alertstats_type"]         =  validateAlertStatsType,        -- A mode for alerts stats queries
   ["flowhosts_type"]          =  validateFlowHostsType,         -- A filter for local/remote hosts in each of the two directions
   ["status"]                  =  validateAlertStatus,           -- An alert type to filter
   ["profile"]                 =  http_lint.validateTrafficProfile,        -- Traffic Profile name
   ["delete_profile"]          =  http_lint.validateTrafficProfile,        -- A Traffic Profile to delete
   ["alert_type"]              =  validateNumber,                -- An alert type enum
   ["alert_severity"]          =  validateNumber,                -- An alert severity enum
   ["entity"]                  =  validateNumber,                -- An alert entity type
   ["asn"]                     =  validateNumber,                -- An ASN number
   ["module"]                  =  validateTopModule,             -- A top script module
   ["step"]                    =  validateNumber,                -- A step value
   ["cf"]                      =  validateConsolidationFunction, -- An RRD consolidation function
   ["verbose"]                 =  validateBool,                  -- True if script should be verbose
   ["num_minutes"]             =  validateNumMinutes,            -- number of minutes
   ["zoom"]                    =  validateZoom,                  -- a graph zoom specifier
   ["community"]               =  validateSingleWord,            -- SNMP community
   ["default_snmp_community"]  =  validateSingleWord,            -- Default SNMP community for non-SNMP-configured local hosts
   ["snmp_port_idx"]           =  validateNumber,                -- SNMP port index
   ["snmp_recache" ]           =  validateBool,                  -- forces SNMP queries to be re-executed and cached
   ["discovery_recache" ]      =  validateBool,                  -- forces device discovery to be re-cached
   ["intfs"]                   =  validateInterfacesList,        -- a list of network interfaces ids
   ["search"]                  =  validateBool,                  -- When set, a search should be performed
   ["search_flows"]            =  validateBool,                  -- When set, a flow search should be performed
   ["criteria"]                =  validateLookingGlassCriteria,  -- A looking glass criteria
   ["row_id"]                  =  validateNumber,                -- A number used to identify a record in a database
   ["rrd_file"]                =  validateUnquoted,              -- A path or special identifier to read an RRD file
   ["port"]                    =  validatePort,                  -- An application port
   ["ntopng_license"]          =  validateSingleWord,            -- ntopng licence string
   ["syn_attacker_threshold"]        = validateEmptyOr(validateNumber),
   ["global_syn_attacker_threshold"] = validateEmptyOr(validateNumber),
   ["syn_victim_threshold"]          = validateEmptyOr(validateNumber),
   ["global_syn_victim_threshold"]   = validateEmptyOr(validateNumber),
   ["flow_attacker_threshold"]         = validateEmptyOr(validateNumber),
   ["global_flow_attacker_threshold"]  =  validateEmptyOr(validateNumber),
   ["flow_victim_threshold"]           = validateEmptyOr(validateNumber),
   ["global_flow_victim_threshold"]    =  validateEmptyOr(validateNumber),
   ["re_arm_minutes"]          =  validateEmptyOr(validateNumber),                -- Number of minute before alert re-arm check
   ["device_type"]             =  validateNumber,
   ["senders_receivers"]       =  validateSendersReceivers,      -- Used in top scripts

-- PREFERENCES - see prefs.lua for details
   -- Toggle Buttons
   ["interface_rrd_creation"]                      =  validateBool,
   ["dynamic_iface_vlan_creation"]                 =  validateBool,
   ["toggle_mysql_check_open_files_limit"]         =  validateBool,
   ["disable_alerts_generation"]                   =  validateBool,
   ["toggle_alert_probing"]                        =  validateBool,
   ["toggle_flow_alerts_iface"]                    =  validateBool,
   ["toggle_ssl_alerts"]                           =  validateBool,
   ["toggle_malware_probing"]                      =  validateBool,
   ["toggle_flow_db_dump_export"]                  =  validateBool,
   ["toggle_alert_syslog"]                         =  validateBool,
   ["toggle_slack_notification"]                   =  validateBool,
   ["toggle_alert_nagios"]                         =  validateBool,
   ["toggle_top_sites"]                            =  validateBool,
   ["toggle_captive_portal"]                       =  validateBool,
   ["toggle_nbox_integration"]                     =  validateBool,
   ["toggle_autologout"]                           =  validateBool,
   ["toggle_ldap_anonymous_bind"]                  =  validateBool,
   ["toggle_local_host_cache_enabled"]             =  validateBool,
   ["toggle_active_local_host_cache_enabled"]      =  validateBool,
   ["toggle_network_discovery"]                    =  validateBool,
   ["toggle_local"]                                =  validateBool,
   ["toggle_local_ndpi"]                           =  validateBool,
   ["toggle_flow_rrds"]                            =  validateBool,
   ["toggle_pools_rrds"]                           =  validateBool,
   ["toggle_local_categorization"]                 =  validateBool,
   ["toggle_flow_snmp_ports_rrds"]                 =  validateBool,
   ["toggle_access_log"]                           =  validateBool,
   ["toggle_snmp_rrds"]                            =  validateBool,
   ["toggle_tiny_flows_export"]                    =  validateBool,
   ["toggle_vlan_rrds"]                            =  validateBool,
   ["toggle_asn_rrds"]                             =  validateBool,
   ["toggle_shaping_directions"]                   =  validateBool,
   ["toggle_tcp_flags_rrds"]                       =  validateBool,
   ["toggle_tcp_retr_ooo_lost_rrds"]               =  validateBool,
   ["toggle_dst_with_post_nat_dst"]                =  validateBool,
   ["toggle_src_with_post_nat_src"]                =  validateBool,

   -- Input fields
   ["minute_top_talkers_retention"]                =  validateNumber,
   ["mysql_retention"]                             =  validateNumber,
   ["minute_top_talkers_retention"]                =  validateNumber,
   ["max_num_alerts_per_entity"]                   =  validateNumber,
   ["max_num_flow_alerts"]                         =  validateNumber,
   ["max_num_packets_per_tiny_flow"]               =  validateNumber,
   ["max_num_bytes_per_tiny_flow"]                 =  validateNumber,
   ["nagios_nsca_port"]                            =  validateEmptyOr(validatePort),
   ["nagios_send_nsca_executable"]                 =  validateAbsolutePath,
   ["nagios_send_nsca_config"]                     =  validateAbsolutePath,
   ["nbox_user"]                                   =  validateSingleWord,
   ["nbox_password"]                               =  validateSingleWord,
   ["google_apis_browser_key"]                     =  validateSingleWord,
   ["ldap_server_address"]                         =  validateSingleWord,
   ["local_host_max_idle"]                         =  validateNumber,
   ["non_local_host_max_idle"]                     =  validateNumber,
   ["flow_max_idle"]                               =  validateNumber,
   ["active_local_host_cache_interval"]            =  validateNumber,
   ["local_host_cache_duration"]                   =  validateNumber,
   ["housekeeping_frequency"]                      =  validateNumber,
   ["intf_rrd_raw_days"]                           =  validateNumber,
   ["intf_rrd_1min_days"]                          =  validateNumber,
   ["intf_rrd_1h_days"]                            =  validateNumber,
   ["intf_rrd_1d_days"]                            =  validateNumber,
   ["other_rrd_raw_days"]                          =  validateNumber,
   ["other_rrd_1min_days"]                         =  validateNumber,
   ["other_rrd_1h_days"]                           =  validateNumber,
   ["other_rrd_1d_days"]                           =  validateNumber,
   ["host_activity_rrd_1h_days"]                   =  validateNumber,
   ["host_activity_rrd_1d_days"]                   =  validateNumber,
   ["host_activity_rrd_raw_hours"]                 =  validateNumber,
   ["max_ui_strlen"]                               =  validateNumber,
   ["safe_search_dns"]                             =  validateIPV4,
   ["global_dns"]                                  =  validateEmptyOr(validateIPV4),
   ["secondary_dns"]                               =  validateEmptyOr(validateIPV4),
   ["redirection_url"]                             =  validateEmptyOr(validateSingleWord),

   -- Multiple Choice
   ["disaggregation_criterion"]                    =  validateChoiceInline({"none", "vlan", "probe_ip", "ingress_iface_idx", "ingress_vrf_id"}),
   ["slack_notification_severity_preference"]      =  validateChoiceInline({"only_errors","errors_and_warnings","all_alerts"}),
   ["multiple_ldap_authentication"]                =  validateChoiceInline({"local","ldap","ldap_local"}),
   ["multiple_ldap_account_type"]                  =  validateChoiceInline({"posix","samaccount"}),
   ["toggle_logging_level"]                        =  validateChoiceInline({"trace", "debug", "info", "normal", "warning", "error"}),
   ["toggle_thpt_content"]                         =  validateChoiceInline({"bps", "pps"}),
   ["toggle_host_mask"]                            =  validateChoiceInline({"0", "1", "2"}),
   ["topk_heuristic_precision"]                    =  validateChoiceInline({"disabled", "more_accurate", "accurate", "aggressive"}),

   -- Other
   ["flush_alerts_data"]                           =  validateEmpty,
   ["network_discovery_interval"]                  =  validateNumber,
--

-- PAGE SPECIFIC
   ["iflocalstat_mode"]        =  validateIfaceLocalStatsMode,   -- A mode for iface_local_stats.lua
   ["clisrv"]                  =  validateClientOrServer,        -- Client or Server filter
   ["report"]                  =  validateReportMode,            -- A mode for traffic report
   ["report_zoom"]             =  validateBool,                  -- True if we are zooming in the report
   ["format"]                  =  validatePrintFormat,           -- a print format
   ["nbox_action"]             =  validateNboxAction,            -- get_nbox_data.lua
   ["fav_action"]              =  validateFavouriteAction,       -- get_historical_favourites.lua
   ["favourite_type"]          =  validateFavouriteType,         -- get_historical_favourites.lua
   ["locale"]                  =  validateCountry,               -- locale used in test_locale.lua
   ["render"]                  =  validateBool,                  -- True if report should be rendered
   ["printable"]               =  validateBool,                  -- True if report should be printable
   ["daily"]                   =  validateBool,                  -- used by report.lua
   ["json"]                    =  validateBool,                  -- True if json output should be generated
   ["extended"]                =  validateBool,                  -- Flag for extended report
   ["tracked"]                 =  validateNumber,                --
   ["ajax_format"]             =  validateAjaxFormat,            -- iface_hosts_list
   ["host_stats_flows"]        =  validateBool,                  -- True if host_get_json should return statistics regarding host flows
   ["showall"]                 =  validateBool,                  -- report.lua
   ["addvlan"]                 =  validateBool,                  -- True if VLAN must be added to the result
   ["http_mode"]               =  validateHttpMode,              -- HTTP mode for host_http_breakdown.lua
   ["refresh"]                 =  validateNumber,                -- top flow refresh in seconds, index.lua
   ["sprobe"]                  =  validateEmpty,                 -- sankey.lua
   ["always_show_hist"]        =  validateBool,                  -- host_details.lua
   ["task_id"]                 =  validateSingleWord,            -- get_nbox_data
   ["host_stats"]              =  validateBool,                  -- host_get_json
   ["captive_portal_users"]    =  validateBool,                  -- to show or hide captive portal users
   ["long_names"]              =  validateBool,                  -- get_hosts_data
   ["id_to_delete"]            =  validateIdToDelete,            -- alert_utils.lua, alert ID to delete
   ["to_delete"]               =  validateLocalGlobal,           -- alert_utils.lua, set if alert configuration should be dropped
   ["SaveAlerts"]              =  validateEmpty,                 -- alert_utils.lua, set if alert configuration should change
   ["host_pool_id"]            =  validateNumber,                -- change_user_prefs, new pool id for host
   ["old_host_pool_id"]        =  validateNumber,                -- change_user_prefs, old pool id for host
   ["del_l7_proto"]            =  validateShapedElement,         -- if_stats.lua, ID of the protocol to delete from rule
   ["target_pool"]             =  validateNumber,                -- if_stats.lua, ID of the pool to perform the action on
   ["add_shapers"]             =  validateEmpty,                 -- if_stats.lua, set when adding shapers
   ["delete_shaper"]           =  validateNumber,                -- shaper ID to delete
   ["empty_pool"]              =  validateNumber,                -- host_pools.lua, action to empty a pool by ID
   ["pool_to_delete"]          =  validateNumber,                -- host_pools.lua, pool ID to delete
   ["edit_pools"]              =  validateEmpty,                 -- host_pools.lua, set if pools are being edited
   ["member_to_delete"]        =  validateMember,                -- host_pools.lua, member to delete from pool
   ["sampling_rate"]           =  validateNumber,                -- if_stats.lua
   ["resetstats_mode"]         =  validateResetStatsMode,        -- reset_stats.lua
   ["snmp_action"]             =  validateSnmpAction,            -- snmp specific
   ["iftype_filter"]           =  validateSingleWord,            -- SNMP iftype filter name
   ["host_quota"]              =  validateEmptyOr(validateNumber),            -- max traffi quota for host
   ["allowed_interface"]       =  validateEmptyOr(validateInterface),         -- the interface an user is allowed to configure
   ["allowed_networks"]        =  validateNetworksList,          -- a list of networks the user is allowed to monitor
   ["switch_interface"]        =  validateInterface,             -- a new active ntopng interface
   ["edit_members"]            =  validateEmpty,                 -- set if we are editing pool members
   ["trigger_alerts"]          =  validateBool,                  -- true if alerts should be active for this entity
   ["show_advanced_prefs"]     =  validateBool,                  -- true if advanced preferences should be shown
   ["ifSpeed"]                 =  validateEmptyOr(validateNumber), -- interface speed
   ["ifRate"]                  =  validateEmptyOr(validateNumber), -- interface refresh rate
   ["scaling_factor"]          =  validateEmptyOr(validateNumber), -- interface scaling factor
   ["drop_host_traffic"]       =  validateBool,                  -- to drop an host traffic
   ["lifetime_limited"]        =  validateEmptyOr(validateOnOff), -- set if user should have a limited lifetime
   ["lifetime_unlimited"]      =  validateEmptyOr(validateOnOff), -- set if user should have an unlimited lifetime
   ["lifetime_secs"]           =  validateNumber,                -- user lifetime in seconds
   ["edit_profiles"]           =  validateEmpty,                 -- set when editing traffic profiles
   ["drop_flow_policy"]        =  validateBool,                  -- true if target flow should be dropped
   ["blocked_categories"]      =  validateCategoriesList,        -- if_stats.lua
   ["traffic_type"]            =  validateBroadcastUnicast,      -- flows_stats.lua
   ["flow_status"]             =  validateFlowStatus,            -- flows_stats.lua
   ["include_unlimited"]       =  validateBool,                  -- pool_details_ndpi.lua
   ["policy_preset"]           =  validateEmptyOr(validatePolicyPreset), -- a traffic bridge policy set
   ["members_filter"]          =  validateMembersFilter,         -- host_pools.lua
   ["devices_mode"]            =  validateDevicesMode,           -- macs_stats.lua
   ["unassigned_devices"]      =  validateUnassignedDevicesMode, -- unknown_device.lua
   ["create_guests_pool"]      =  validateOnOff,                 -- bridge wizard
   ["show_wizard"]             =  validateEmpty,                 -- bridge wizard

   -- ntopng Box
   ["nbox_network_mode"]       =  validateNetworkMode,           -- bridge wizard

   -- json POST DATA
   ["payload"]                 =  validateJSON
}

-- A special parameter is formed by a prefix, followed by a variable suffix
local special_parameters = {   --[[Suffix validator]]     --[[Value Validator]]
-- The following parameter is *not* used inside ntopng
-- It allows third-party users to write their own scripts with custom
-- (unverified) parameters
   ["p_"]                      =  {validateUnquoted,         validateUnquoted},

-- SHAPING
   ["shaper_"]                 =  {validateNumber,            validateNumber},      -- key: a shaper ID, value: max rate
   ["ishaper_"]                =  {validateShapedElement,     validateNumber},      -- key: category or protocol ID, value: ingress shaper ID
   ["eshaper_"]                =  {validateShapedElement,     validateNumber},      -- key: category or protocol ID, value: egress shaper ID
   ["qtraffic_"]               =  {validateShapedElement,     validateNumber},      -- key: category or protocol ID, value: traffic quota
   ["qtime_"]                  =  {validateShapedElement,     validateNumber},      -- key: category or protocol ID, value: time quota
   ["oldrule_"]                =  {validateShapedElement,     validateEmpty},       -- key: category or protocol ID, value: empty

-- ALERTS (see alert_utils.lua)
   ["op_"]                     =  {validateAlertDescriptor,   validateOperator},    -- key: an alert descriptor, value: alert operator
   ["value_"]                  =  {validateAlertDescriptor,   validateEmptyOr(validateNumber)}, -- key: an alert descriptor, value: alert value

-- paramsPairsDecode: NOTE NOTE NOTE the "val_" value must explicitly be checked by the end application
   ["key_"]                    =  {validateNumber,   validateSingleWord},      -- key: an index, value: the pair key
   ["val_"]                    =  {validateNumber,   validateUnchecked},       -- key: an index, value: the pair value
}

-- #################################################################

local function validateParameter(k, v)
   if(known_parameters[k] == nil) then
      return false
   else
      if known_parameters[k](v) then
         return true
      else
         return false, "Validation error"
      end
   end
end

local function validateSpecialParameter(param, value)
   -- These parameters are made up of one string prefix plus a string suffix
   for k, v in pairs(special_parameters) do
      if starts(param, k) then
         local suffix = split(param, k)[2]

         if not v[1](suffix) then
            return false, "Special Validation, parameter key"
         elseif not v[2](value) then
            return false, "Special Validation, parameter value"
         else
            return true
         end
      end
   end

   return false
end

function http_lint.validationError(t, param, value, message)
   -- TODO graceful exit
   local s_id
   if t == _GET then s_id = "_GET" else s_id = "_POST" end
   error("[LINT] " .. s_id .. "[\"" .. param .. "\"] = \"" .. value .. "\" parameter error: " .. message)
end

-- #################################################################

local function lintParams()
   local params_to_validate = { _GET, _POST }
   local id, _, k, v

   -- VALIDATION SETTINGS
   local enableValidation = true                   --[[ To enable validation ]]
   local relaxGetValidation = true                 --[[ To consider empty fields as valid in _GET parameters ]]
   local relaxPostValidation = false               --[[ To consider empty fields as valid in _POST parameters ]]
   local debug = false                             --[[ To enable validation debug messages ]]

   for _,id in pairs(params_to_validate) do
      for k,v in pairs(id) do
         if(debug) then io.write("[LINT] Validating ["..k.."]["..v.."]\n") end

         if enableValidation then
            if ((v == "") and
                (((id == _GET) and relaxGetValidation) or
                 ((id == _POST) and relaxPostValidation))) then
               if(debug) then io.write("[LINT] Parameter "..k.." is empty but we are in relax mode, so it can pass\n") end
            else
               local success, message = validateParameter(k, v)
               if not success then
                  if message ~= nil then
                     http_lint.validationError(id, k, v, message)
                  else
                     success, message = validateSpecialParameter(k, v)

                     if not success then
                        if message ~= nil then
                           http_lint.validationError(id, k, v, message)
                        else
                           -- Here we have an unhandled parameter
                           http_lint.validationError(id, k, v, "Missing validation")
                        end
                     end
                  end
               else
                  if(debug) then io.write("[LINT] Special Parameter "..k.." validated successfully\n") end
               end
            end
         end
      end
   end
end

-- #################################################################

if(pragma_once) then
   lintParams()
   pragma_once = 0
end

return http_lint
