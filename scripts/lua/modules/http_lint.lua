--
-- (C) 2017 - ntop.org
--

local pragma_once = 1

-- #################################################################

-- UTILITY FUNCTIONS

-- Searches into the keys of the table
function validateChoiceByKeys(defaults, v)
   if defaults[v] ~= nil then
      return true
   else
      return false
   end
end

-- Searches into the value of the table
-- Optional key can be used to access fields of the array element
function validateChoice(defaults, v, key)
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

function validateSingleWord(w)
   if ((string.find(w, "%=") ~= nil) or
       (string.find(w, "% ") ~= nil)) then
      return false
   else
      return true
   end
end

function validateListOfType(l, validate_callback, separator)
   local separator = separator or ","
   local items = split(l, separator)

   for _,item in pairs(items) do
      if not validate_callback(item) then
         return false
      end
   end

   return true
end

-- #################################################################

-- FRONT-END VALIDATORS

function validateNumber(p)
   if tonumber(p) ~= nil then
      return true
   else
      return false
   end
end

function validatePort(p)
   local n = tonumber(p)
   if ((n ~= nil) and (n >= 1) and (n <= 65535)) then
      return true
   else
      return false
   end
end

function validateEmpty(s)
   if s == "" then
      return true
   else
      return false
   end
end

function validateEmptyOr(other_validation)
   return function(s)
      if (validateEmpty(s) or other_validation(s)) then
         return true
      else
         return false
      end
   end
end

function validateUnchecked(p)
   -- base validation is already performed by C side.
   -- you should use this function as last resort
   return true
end

-- #################################################################

function validateMode(mode)
   local modes = {"all", "local", "remote"}

   return validateChoice(modes, mode)
end

function validateHttpMode(mode)
   local modes = {"responses", "queries"}

   return validateChoice(modes, mode)
end

function validatePidMode(mode)
   local modes = {"l4", "l7", "host", "apps"}

   return validateChoice(modes, mode)
end

function validateNdpiStatsMode(mode)
   local modes = {"sinceStartup", "count", "host"}

   return validateChoice(modes, mode)
end

function validateSflowDistroMode(mode)
   local modes = {"host", "process", "user"}

   return validateChoice(modes, mode)
end

function validateSflowDistroType(mode)
   local modes = {"size", "memory", "bytes", "latency", "server"}

   return validateChoice(modes, mode)
end

function validateSflowFilter(mode)
   local modes = {"All", "Client", "Server"}

   return validateChoice(modes, mode)
end

function validateIfaceLocalStatsMode(mode)
   local modes = {"distribution"}

   return validateChoice(modes, mode)
end

function validateProcessesStatsMode(mode)
   local modes = {"table", "timeline"}

   return validateChoice(modes, mode)
end

function validateDirection(mode)
   local modes = {"sent", "recv"}

   return validateChoice(modes, mode)
end

function validateClientOrServer(mode)
   local modes = {"client", "server"}

   return validateChoice(modes, mode)
end

function validateStatsType(mode)
   local modes = {"severity_pie", "type_pie", "count_sparkline", "top_origins",
      "top_targets", "duration_pie", "longest_engaged", "counts_pie",
      "counts_plain", "top_talkers", "top_applications"}

   return validateChoice(modes, mode)
end

function validateAlertStatsType(mode)
   local modes = {"severity_pie", "type_pie", "count_sparkline", "top_origins",
      "top_targets", "duration_pie", "longest_engaged", "counts_pie",
      "counts_plain"}

   return validateChoice(modes, mode)
end

function validateFlowHostsType(mode)
   local modes = {"local_only", "remote_only",
      "local_origin_remote_target", "remote_origin_local_target"}

   return validateChoice(modes, mode)
end

function validateConsolidationFunction(mode)
   local modes = {"average", "max", "min"}

   return validateChoice(modes, mode)
end

function validateAlertStatus(mode)
   local modes = {"engaged", "historical", "historical-flows"}

   return validateChoice(modes, mode)
end

function validateAggregation(mode)
   local modes = {"ndpi", "l4proto", "port"}

   return validateChoice(modes, mode)
end

function validateReportMode(mode)
   local modes = {"daily", "weekly", "monthly"}

   return validateChoice(modes, mode)
end

function validateNboxAction(mode)
   local modes = {"status", "schedule"}

   return validateChoice(modes, mode)
end

function validateFavouriteAction(mode)
   local modes = {"set", "get", "del", "del_all"}

   return validateChoice(modes, mode)
end

function validateFavouriteType(mode)
   local modes = {"apps_per_host_pair", "top_applications", "talker", "app"}

   return validateChoice(modes, mode)
end

function validateAjaxFormat(mode)
   local modes = {"d3"}

   return validateChoice(modes, mode)
end

function validatePrintFormat(mode)
   local modes = {"txt", "json"}

   return validateChoice(modes, mode)
end

function validateResetStatsMode(mode)
   local modes = {"reset_drops", "reset_all"}

   return validateChoice(modes, mode)
end

function validateSnmpAction(mode)
   local modes = {"delete", "add", "addNewDevice"}

   return validateChoice(modes, mode)
end

function validateUserRole(mode)
   local modes = {"administrator", "unprivileged", "captive_portal"}

   return validateChoice(modes, mode)
end

-- #################################################################

function validateHost(p)
   -- TODO stricter checks, allow @vlan
   if(isIPv4(p) or isIPv6(p) or isMacAddress(p)) then
      return true
   else
      return false
   end
end

function validateMac(p)
   -- TODO stricter checks
   if isMacAddress(p) then
      return true
   else
      return false
   end
end

function validateIpAddress(p)
   if (isIPv4(p) or isIPv6(p)) then
      return true
   else
      return false
   end
end

function validateHTTPHost(p)
   if (validateIpAddress(p) or true --[[ TODO ]]) then
      return true
   else
      return false
   end
end

function validateIpVersion(p)
   if ((p == "4") or (p == "6")) then
      return true
   else
      return false
   end
end

function validateDate(p)
   -- TODO
   if string.find(p, ":") then
      return true
   else
      return false
   end
end

function validateMember(m)
   -- TODO
   return true
end

function validateBpfFilter(filter)
   if ntop.checkProfileSyntax(filter) then
      return true
   else
      return false
   end
end

function validateIdToDelete(i)
   if ((i == "__all__") or validateNumber(i)) then
      return true
   else
      return false
   end
end

function validateBool(p)
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

function validateSortOrder(p)
   local defaults = {"asc", "desc"}
   
   return validateChoice(defaults, p)
end

function validateApplication(app)
   local ndpi_protos = interface.getnDPIProtocols()

   return validateChoiceByKeys(ndpi_protos, app)
end

function validateProtocolId(p)
   -- TODO implement
   return validateUnchecked(p)
end

function validateTrafficProfile(p)
   -- TODO implement
   return validateUnchecked(p)
end

function validateActivityName(p)
   -- TODO implement, read user activities from C
   return validateUnchecked(p)
end

function validateSortColumn(p)
   -- Note: this is also used in some scripts to specify the ordering, so the "column_"
   -- prefix is not honored
   if((validateSingleWord(p)) --[[and (string.starts(p, "column_"))]]) then
      return true
   else
      return false
   end
end

function validateCountry(p)
   if string.len(p) == 2 then
      return true
   else
      return false
   end
end

function validateInterface(i)
   -- TODO
   return validateNumber(i)
end

function validateNetwork(i)
   -- TODO
   return validateSingleWord(i)
end

function validateCategory(i)
   -- TODO
   return validateNumber(i)
end

function validateZoom(zoom)
   if string.match(zoom, "%d+%a") == zoom then
      return true
   else
      return false
   end
end

function validateInterfacesList(l)
   return validateListOfType(l, validateInterface)
end

function validateNetworksList(l)
   return validateListOfType(l, validateNetwork)
end

function validateCategoriesList(mode)
   return validateListOfType(l, validateCategory)
end

function validateApplicationsList(l)
   return validateListOfType(l, validateApplication)
end

function validateHostsList(l)
   return validateListOfType(l, validateHost)
end

function validateIfFilter(i)
   if validateNumber(i) or i == "all" then
      return true
   else
      return false
   end
end

function validateLookingGlassCriteria(c)
   if validateChoice(looking_glass_criteria, c, 1) then
      return true
   else
      return false
   end
end

function validateTopModule(m)
   -- TODO check for existance
   return validateSingleWord(m)
end

-- #################################################################

-- NOTE: Put here al the parameters to validate

local known_parameters = {
-- UNCHECKED (Potentially Dangerous)
   ["referer"]                 =  validateUnchecked,             -- An URL referer
   ["url"]                     =  validateUnchecked,             -- An URL
   ["label"]                   =  validateUnchecked,             -- A device label
   ["os"]                      =  validateUnchecked,             -- An Operating System string
   ["info"]                    =  validateUnchecked,             -- An information message
   ["entity_val"]              =  validateUnchecked,             -- An alert entity value
   ["custom_name"]             =  validateUnchecked,             -- A custom interface name
   ["full_name"]               =  validateUnchecked,             -- A user full name
   ["query"]                   =  validateUnchecked,             -- This field should be used to perform partial queries.
                                                                 -- It up to the script to implement proper validation.
                                                                 -- In NO case query should be executed directly without validation.

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
   ["ip"]                      =  validateIpAddress,             -- An IPv4 or IPv6 address
   ["vhost"]                   =  validateHTTPHost,              -- HTTP server name or IP address
   ["version"]                 =  validateIpVersion,             -- To specify an IPv4 or IPv6
   ["vlan"]                    =  validateNumber,                -- A VLAN id
   ["hosts"]                   =  validateHostsList,             -- A list of hosts

-- AUTHENTICATION
   ["username"]                =  validateSingleWord,            -- A ntopng user name, new or existing
   ["password"]                =  validateSingleWord,            -- User password
   ["new_password"]            =  validateSingleWord,            -- The new user password
   ["old_password"]            =  validateSingleWord,            -- The old user password
   ["confirm_password"]        =  validateSingleWord,            -- Confirm user password
   ["user_role"]               =  validateUserRole,              -- User role

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
   ["ifIdx"]                   =  validateNumber,                -- A switch port id
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
   ["_"]                       =  validateNumber,                -- jQuery nonce in ajax requests used to prevent browser caching
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
   ["profile"]                 =  validateTrafficProfile,        -- Traffic Profile name
   ["delete_profile"]          =  validateTrafficProfile,        -- A Traffic Profile to delete
   ["activity"]                =  validateActivityName,          -- User Activity name
   ["alert_type"]              =  validateNumber,                -- An alert type enum
   ["alert_severity"]          =  validateNumber,                -- An alert severity enum
   ["entity"]                  =  validateNumber,                -- An alert entity type
   ["asn"]                     =  validateNumber,                -- An ASN number
   ["module"]                  =  validateTopModule,             -- A top script module
   ["step"]                    =  validateNumber,                -- A step value
   ["cf"]                      =  validateConsolidationFunction, -- An RRD consolidation function
   ["verbose"]                 =  validateBool,                  -- True if script should be verbose
   ["num_minutes"]             =  validateNumber,                -- number of minutes
   ["zoom"]                    =  validateZoom,                  -- a graph zoom specifier
   ["community"]               =  validateSingleWord,            -- SNMP community
   ["intfs"]                   =  validateInterfacesList,        -- a list of network interfaces ids
   ["search"]                  =  validateEmpty,                 -- When set, a search should be performed
   ["criteria"]                =  validateLookingGlassCriteria,  -- A looking glass criteria
   ["row_id"]                  =  validateNumber,                -- A number used to identify a record in a database
   ["rrd_file"]                =  validateSingleWord,            -- A path or special identifier to read an RRD file
   ["port"]                    =  validatePort,                  -- An application port
   ["ntopng_license"]          =  validateSingleWord,            -- ntopng licence string
   ["syn_alert_threshold"]     =  validateNumber,                -- Threashold to trigger a syn alert
   ["flows_alert_threshold"]   =  validateNumber,                --
   ["flow_rate_alert_threshold"] =  validateNumber,              --
   ["re_arm_minutes"]          =  validateNumber,                -- Number of minute before alert re-arm check
   ["custom_icon"]             =  validateSingleWord,            -- A custom icon for the host
   ["bpf_filter"]              =  validateBpfFilter,             -- A valid BPF filter

-- PAGE SPECIFIC
   ["iflocalstat_mode"]        =  validateIfaceLocalStatsMode,   -- A mode for iface_local_stats.lua
   ["clisrv"]                  =  validateClientOrServer,        -- Client or Server filter
   ["report"]                  =  validateReportMode,            -- A mode for traffic report
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
   ["include_special_macs"]    =  validateBool,                  --
   ["host_macs_only"]          =  validateBool,                  --
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
   ["to_delete"]               =  validateBool,                  -- alert_utils.lua, set if alert configuration should be dropped
   ["SaveAlerts"]              =  validateBool,                  -- alert_utils.lua, set if alert configuration should change
   ["host_pool_id"]            =  validateNumber,                -- change_user_prefs, new pool id for host
   ["old_host_pool_id"]        =  validateNumber,                -- change_user_prefs, old pool id for host
   ["del_l7_proto"]            =  validateProtocolId,            -- if_stats.lua, ID of the protocol to delete from rule
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
   ["host_quota"]              =  validateEmptyOr(validateNumber),         -- max traffi quota for host
   ["allowed_interface"]       =  validateEmptyOr(validateInterface),      -- the interface an user is allowed to configure
   ["allowed_networks"]        =  validateNetworksList,          -- a list of networks the user is allowed to monitor
   ["switch_interface"]        =  validateInterface,             -- a new active ntopng interface
   ["edit_members"]            =  validateEmpty,                 -- set if we are editing pool members
   ["trigger_alerts"]          =  validateBool,                  -- true if alerts should be active for this entity
   ["show_advanced_prefs"]     =  validateBool,                  -- true if advanced preferences should be shown
   ["ifSpeed"]                 =  validateNumber,                -- interface speed
   ["scaling_factor"]          =  validateNumber,                -- interface scaling factor
   ["drop_host_traffic"]       =  validateBool,                  -- to drop an host traffic
   ["lifetime_limited"]        =  validateEmpty,                 -- set if user should have a limited lifetime
   ["lifetime_unlimited"]      =  validateEmpty,                 -- set if user should have an unlimited lifetime
   ["lifetime_secs"]           =  validateNumber,                -- user lifetime in seconds
   ["edit_profiles"]           =  validateEmpty,                 -- set when editing traffic profiles
   ["drop_flow_policy"]        =  validateBool,                  -- true if target flow should be dropped
   ["export"]                  =  validateEmpty,                 -- set if data has to be exported
   ["blocked_categories"]      =  validateCategoriesList,        -- if_stats.lua
}

-- #################################################################

function validateParameter(k, v)
   if(known_parameters[k] == nil) then
      io.write("[LINT] Missing validation for ["..k.."]["..v.."]\n")
      return false
   else
      return known_parameters[k](v)
   end
end

-- #################################################################

function lintParams()
   local params_to_validate = { _GET, _POST }
   local id, _, k, v

   -- VALIDATION SETTINGS
   local enableValidation = true                   --[[ To enable validation ]]
   local relaxGetValidation = true                 --[[ To consider empty fields as valid in _GET parameters ]]
   local relaxPostValidation = false               --[[ To consider empty fields as valid in _POST parameters ]]
   local debug = false                             --[[ To enable validation debug messages ]]

   for _,id in pairs(params_to_validate) do
      for k,v in pairs(id) do
         if(debug) then io.write("[LINT] Validating ["..k.."]["..p[k].."]\n") end

         if enableValidation then
            if ((v == "") and
                (((id == _GET) and relaxGetValidation) or
                 ((id == _POST) and relaxPostValidation))) then
               if(debug) then io.write("[LINT] Parameter "..k.." is empty but we are in relax mode, so it can pass\n") end
            elseif not validateParameter(k, v) then
               -- TODO gracefull error
               local s_id
               if id == _GET then s_id = "_GET" else s_id = "_POST" end
               error("BAD " .. s_id .. " parameter " .. k .. " [" .. v .. "]")
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
