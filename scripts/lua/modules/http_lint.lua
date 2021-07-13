--
-- (C) 2017-21 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local pragma_once = 1
local http_lint = {}

local json = require "dkjson"
local tracker = require "tracker"
local tag_utils = require "tag_utils"

-- #################################################################

-- TRACKER HOOK (ntop.*, interface.*)

tracker.track_ntop()
tracker.track_interface()

-- #################################################################

-- UTILITY FUNCTIONS

function starts(String,Start)
   if((String == nil) or (Start == nil)) then
      return(false)
   end

   return string.sub(String,1,string.len(Start))==Start
end

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
http_lint.validateChoiceInline = validateChoiceInline

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
http_lint.validateEmptyOr = validateEmptyOr

-- #################################################################

-- FRONT-END VALIDATORS

local function validateNumber(p)
   -- integer number validation
   local num = tonumber(p)

   if(num == nil) then
      return false
   end

   if math.floor(num) == num then
      return true
   else
      -- this is a float number
      return false
   end
end
http_lint.validateNumber = validateNumber

-- ##############################################

local function validateSyslogFormat(p)
   if p == "plaintext" or
      p == "plaintextrfc" or
      p == "json" or
      p == "ecs"
   then
      return true
   end

   return false
end
http_lint.validateSyslogFormat = validateSyslogFormat

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
http_lint.validatePort = validatePort

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

local function validateLuaScriptPath(p)
   local os_utils = require("os_utils")

   if (string.find(p, "'") ~= nil) then return false end
   return(starts(p, os_utils.getPathDivider() .. "plugins"))
end
http_lint.validateLuaScriptPath = validateLuaScriptPath

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

-- ##############################################

-- @brief Returns true if inputstr is inside alert, function used to check
--        if the filter is right or not
local function validateScriptFilter(inputstr)
   inputstr = inputstr:gsub(" ", "")
   return validateListOfType(inputstr, validateSingleWord)
end
http_lint.validateScriptFilter = validateScriptFilter

-- ##############################################

local function validateMessage(w)
   return true
end
http_lint.validateSingleWord = validateMessage

local function validateSingleAlphanumericWord(w)
   if (w:match("%W")) then
     return false
   else
      return validateSingleWord(w)
   end
end

local function validateTrafficRecordingProvider(w)
   if w == "ntopng" or (w:starts("n2disk@") and validateSingleWord(w)) then
      return true
   end

   return false
end

local function validateUsername(p)
   -- A username (e.g. used in ntopng authentication)
   return(validateSingleWord(p) and (string.find(p, "%.") == nil))
end

local function licenseCleanup(p)
   return p -- don't touch passwords (checks against valid fs paths already performed)
end

local function passwordCleanup(p)
   return p -- don't touch passwords (checks against valid fs paths already performed)
end

local function webhookCleanup(p)
   local allowed_prefixes = { "https://", "http://" }

   for _, prefix in pairs(allowed_prefixes) do
      if p and p:match("^"..prefix) then
	 -- Only allow the prefix to go through unpurified
	 local purified = prefix..ntop.httpPurifyParam(p:gsub("^"..prefix, ''))

	 return purified
      end
   end

   -- If there's no matching prefix, purify everything
   return ntop.httpPurifyParam(p)
end
http_lint.webhookCleanup = webhookCleanup

local function jsonCleanup(json_payload)
   -- can't touch the json payload or it could be broken
   return json_payload
end

local function whereCleanup(p)
   -- SQL where
   -- A-Za-z0-9!=<>()
   return(p:gsub('%W><!()','_'))
end

-- NOTE: keep in sync with getLicensePattern()
local function validateLicense(p)
   return string.match(p,"[%l%u%d/+=]+") == p or validateEmpty(p)
end

local function validatePassword(p)
   -- A password (e.g. used in ntopng authentication)
   return true
end

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
   local modes = {"all", "local", "remote", "broadcast_domain", "filtered", "blacklisted",
		  "dhcp", "restore", "client_duration", "server_duration",
		  "client_frequency", "server_frequency"  }

   return validateChoice(modes, mode)
end

local function validateDashboardMode(mode)
   local modes = {"community", "pro", "enterprise"  }

   return validateChoice(modes, mode)
end

local function validateOperator(mode)
   local modes = {"gt", "eq", "lt"}

   return validateChoice(modes, mode)
end

http_lint.validateOperator = validateOperator

local function validateAlertValue(value)
  return validateEmpty(value) or
    validateNumber(value) or
    validateOnOff(value)
end

local function validateHttpMode(mode)
   local modes = {"responses", "queries"}

   return validateChoice(modes, mode)
end

local function validateEBPFData(mode)
   local modes = {"categories", "breeds", "applications", "processes"}

   return validateChoice(modes, mode)
end

local function validateErrorsFilter(mode)
   local modes = {"errors", "discards", "errors_or_discards"}

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

local function validateDeviceResponsiveness(r)
   local modes = {"all", "responsive", "unresponsive"}

   return validateChoice(modes, r)
end

local function validateCounterSince(mode)
   local modes = {"actual", "absolute"}

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

local function validateFingerprintType(ft)
   local fingerprint_types = {"ja3", "hassh"}

   return validateChoice(fingerprint_types, ft)
end

local function validateClientOrServer(mode)
   local modes = {"client", "server"}

   return validateChoice(modes, mode)
end

local function validateBroadcastUnicast(mode)
   local modes = {"unicast", "broadcast_multicast",
		  "one_way",
		  "one_way_unicast", "one_way_broadcast_multicast",
		  "bidirectional"}

   return validateChoice(modes, mode)
end

local function validateAlertTypeNumber(status)
   if not validateNumber(status) then
      return false
   end

   local num = tonumber(status)
   return((num >= 0) and (num < 2^32))
end

local function validateAlertType(mode)
   local modes = {"normal", "alerted", "filtered"}

   if validateAlertTypeNumber(mode) then
      return true
   end

   return validateChoice(modes, mode)
end

local function validateAlertTypeSeverity(mode)
   local modes = {"notice_or_lower", "warning", "error_or_higher"}

   return validateChoice(modes, mode)
end

local function validateTCPFlowState(mode)
   local modes = { "established", "connecting", "closed", "reset" }

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

local function validatenEdgeAction(mode)
   local modes = {"discard", "make_permanent"}

   return validateChoice(modes, mode)
end

local function validateFavouriteAction(mode)
   local modes = {"set", "get", "del", "del_all"}

   return validateChoice(modes, mode)
end

local function validateViewPreferences(view)
   local views = {"simple", "expert"}
   return validateChoice(views, view)
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
   local modes = {"reset_drops", "reset_all", "reset_blacklisted"}

   return validateChoice(modes, mode)
end

local function validateFlowMode(mode)
   local modes = {"topk", "flows"}

   return validateChoice(modes, mode)
end

local function validateDevicesMode(mode)
   local modes = {"source_macs_only", "dhcp_macs_only"}

   return validateChoice(modes, mode)
end

local function validateDeviceType(tp)
   local discover = require("discover_utils")

   return(discover.isValidDevtype(tp))
end

local function validateUnassignedDevicesMode(mode)
   local modes = {"active_only", "inactive_only"}

   return validateChoice(modes, mode)
end

local function validateSnmpAction(mode)
   local modes = {"delete", "delete_all", "add",
		  "addNewDevice", "startPolling", "prune"}

   return validateChoice(modes, mode)
end

local function validateSnmpLevel(level)
   local levels = {"authPriv", "authNoPriv", "noAuthNoPriv"}
   return validateChoice(levels, level)
end

local function validateSnmpAuthProtocol(protocol)
   local protocols = {"md5", "sha"}
   return validateChoice(protocols, protocol)
end

local function validateSnmpPrivacyProtocol(protocol)
   local protocols = {"des", "aes"}
   return validateChoice(protocols, protocol)
end

local function validateExtractionJobAction(mode)
   local modes = {"delete", "stop"}

   return validateChoice(modes, mode)
end

local function validateUserRole(mode)
   local modes = {"administrator", "unprivileged", "captive_portal"}

   return validateChoice(modes, mode)
end

local function validateUserLanguage(code)
   local codes = {}
   for _, c in ipairs(locales_utils.getAvailableLocales()) do
      codes[#codes + 1] = c["code"]
   end

   return validateChoice(codes, code)
end

local function validateTimeZoneName(tz)
   local tz_utils = require("tz_utils")

   local timezones = tz_utils.ListTimeZones()
   if timezones then
      for _, t in ipairs(timezones) do
	 if tz == t then
	    return true
	 end
      end
      return false
   end

   -- never reached as timezones are listed in a text file
   return false
end

local function validateNotificationSeverity(tz)
   return validateChoiceInline({"error","warning","info"})
end

http_lint.validateNotificationSeverity = validateNotificationSeverity

local function validateIPV4(p)
   return isIPv4(p)
end

local function validateTransformation(t)
   return validateChoice({"none", "aggregate"}, t)
end

local function validateIpAddress(p)
   if (isIPv4(p) or isIPv6(p)) then
      return true
   else
      return false
   end
end
http_lint.validateIpAddress = validateIpAddress

local function validateIpRange(p)
   local range = string.split(p, "%-")

   if not range or #range ~= 2 then
      return false
   end

   return validateIpAddress(range[1]) and
      validateIpAddress(range[2])
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

local function validateSMTPServer(v)
   -- thanks to https://stackoverflow.com/questions/35467680/lua-pattern-to-validate-a-dns-address
   if (isEmptyString(v)) then
      return false
   end

   return validateIpAddress(v) or validateSingleWord(v)
end

local function validateDate(p)
   -- TODO this validation function should be removed and dates should always be passed as timestamp
   if string.find(p, ":") ~= nil then
      return true
   else
      return false
   end
end

local function validateMemberRelaxed(m)
   -- This does not actually check the semantic with isValidPoolMember
   -- as this is used in pool deletion to handle bad pool member values
   -- inserted by mistake)
   if validateUnquoted(m) then
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
http_lint.validateBool = validateBool

local function validateSortOrder(p)
   local defaults = {"asc", "desc"}

   return validateChoice(defaults, p)
end

local ndpi_protos = interface.getnDPIProtocols()
local ndpi_categories = interface.getnDPICategories()

local function validateApplication(app)
   local modes = {"TCP", "UDP"}
   if validateChoice(modes, app) then
      return true
   end

   local dot = string.find(app, "%.")

   if dot ~= nil then
      local master = string.sub(app, 1, dot-1)
      if not validateChoiceByKeys(ndpi_protos, master) then
	 -- try to see if app is just an app with a dot (e.g., Musical.ly)
	 return validateChoiceByKeys(ndpi_protos, app)
      else
	 -- master is a valid protocol, let's see if the application is valid as well
	 local sub = string.sub(app, dot+1)
	 return validateChoiceByKeys(ndpi_protos, sub)
      end
   else
      return validateChoiceByKeys(ndpi_protos, app)
   end
end

local function validateTagsOperator(p)
   return (tag_utils.tag_operators[p] ~= nil)
end

local function validateFilters(other_validation)
   return function(s)
      local param = split(s, ";")
      if param and #param == 2 then
	 return (other_validation(param[1]) and
		    (validateTagsOperator(param[2])))
      end

      -- Note: comma is deprecated, use ';'
      -- Checking comma for backward compatibility
      param = split(s, ",")
      if param and #param == 2 then
	 return (other_validation(param[1]) and
		    (validateTagsOperator(param[2])))
      end

      return other_validation(s)
   end
end
http_lint.validateFilters = validateFilters
  
local function validateProtocolIdOrName(p)
   -- Lower used because TCP instead of tcp wasn't seen as a l4proto
   local tmp = string.lower(p)
   
   return (validateChoice(ndpi_protos, p) or
	      validateChoiceByKeys(L4_PROTO_KEYS, p) or
	      validateChoiceByKeys(ndpi_protos, p)) or
      (validateChoice(ndpi_protos, tmp) or
	  validateChoiceByKeys(L4_PROTO_KEYS, tmp) or
	  validateChoiceByKeys(ndpi_protos, tmp))
end
http_lint.validateProtocolIdOrName = validateProtocolIdOrName

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
   return interface.isValidIfId(i)
end
http_lint.validateInterface = validateInterface

local function validateNetwork(i)
   if not string.find(i, "/") then
      return validateIpAddress(i)
   else
      -- Mask
      local ip_mask = split(i, "/")
      if #ip_mask ~= 2 then
         return false
      end
      local ip = ip_mask[1]
      local mask = ip_mask[2]

      if not validateNumber(mask) then
         return false
      end

      local prefix = tonumber(mask)
      if prefix >= 0 then
         -- IP
         local is_ipv6 = isIPv6(ip)
         local is_ipv4 = isIPv4(ip)

         if is_ipv6 and prefix <= 128 then
            return true
         elseif is_ipv4 and prefix <= 32 then
            return true
         end
      end

      return false
   end
end
http_lint.validateNetwork = validateNetwork

local function validateHost(p)
   local host = hostkey2hostinfo(p)

   if(host.host ~= nil) and (host.vlan ~= nil)
            and (isIPv4(host.host) or isIPv6(host.host) or isMacAddress(host.host)) then
      return true
   else
      return validateNetwork(p)
   end
end
http_lint.validateHost = validateHost

local function validateNetworkWithVLAN(i)
   if not string.find(i, "/") then
      return validateHost(i)
   else
      -- VLAN
      local net_vlan = split(i, "@")
      local net = net_vlan[1]

      if #net_vlan < 1 then
         return false
      end

      if #net_vlan == 2 then
         local vlan = net_vlan[2]
         if not validateNumber(vlan) then
            return false
         end
      end

      return validateNetwork(net)
   end
end
http_lint.validateNetworkWithVLAN = validateNetworkWithVLAN

local function validateMac(p)
   if isMacAddress(p) then
      return true
   else
      return false
   end
end

local function validateZoom(zoom)
   if string.match(zoom, "%d+%a") == zoom then
      return true
   else
      return false
   end
end

local function validateCategory(cat)
   if starts(cat, "cat_") then
      local id = split(cat, "cat_")[2]
      return validateNumber(id)
   elseif validateChoiceByKeys(ndpi_categories, cat) then
      return true
   else
      return validateNumber(cat)
   end

   return false
end
http_lint.validateCategory = validateCategory

local function validateProtocolOrCategory(p)
   return validateProtocolIdOrName(p) or validateCategory(p)
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
   return(validateSingleWord(d))
end

local function validateInterfacesList(l)
   return validateListOfType(l, validateInterface)
end

local function validateNetworksList(l)
   return validateListOfType(l, validateNetwork)
end

local function validateNetworksWithVLANList(l)
   return validateListOfType(l, validateNetworkWithVLAN)
end

local function validateMacList(l)
   return validateListOfType(l, validateMac)
end

local function validateACLNetworksList(l)
   -- networks in the ACL are preceeded by a + or a - sign
   -- and are (currently) used for the mongoose webserver ACL
   -- Examples:
   -- +0.0.0.0/0,-192.168.0.0/16
   -- +127.0.0.0/8
   if isEmptyString(l) then
      return true
   end

   local items = split(l, ',')

   -- make sure each item has a leading + or -
   for _, i in pairs(items) do
      if not starts(i, '+') and not starts(i, '-') then
	 return false
      end
   end

   -- now we can safely replace + and - and do a normal network validation
   l = l:gsub("+", ""):gsub("-", "")

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

local function validateListOfTypeInline(t)
   return function(l)
      return validateListOfType(l, t)
   end
end

local function validateIfFilter(i)
   if validateNumber(i) or i == "all" then
      return true
   else
      return false
   end
end

local function validateCustomColumn(c)
   local custom_column_utils = require("custom_column_utils")

   if validateChoice(custom_column_utils.available_custom_columns, c, 1) then
      return true
   else
      return false
   end
end

local function validateTopModule(m)
   -- TODO check for existence?
   return validateSingleWord(m)
end

local function validateGatewayName(m)
   -- NOTE: no space allowed right now
   return validateSingleWord(m)
end

local function validateStaticRouteName(m)
   -- NOTE: no space allowed right now
   return validateSingleWord(m)
end

local function validateNetworkInterface(m)
   return validateSingleWord(m)
end

local function validateRoutingPolicyName(m)
   return validateUnquoted(m)
end

local function validateNumberOrUnquoted(p)
   return validateNumber(p) or validateUnquoted(p)
end

function validateRoutingPolicyGateway(m)
   -- this is in the form "policyid_gwid"
   local parts = string.split(m, "_")

   if parts and #parts == 2 then
      local policy_id = parts[1]
      local gw_id = parts[2]

      return validateNumber(policy_id) and validateNumber(gw_id)
   end

   return false
end

-- #################################################################

local function validatePortRange(p)
   local v = string.split(p, "%-") or {p, p}

   if #v ~= 2 then
      return false
   end

   if not validateNumber(v[1]) or not validateNumber(v[2]) then
      return false
   end

   local p0 = tonumber(v[1]) or 0
   local p1 = tonumber(v[2]) or 0

   return(((p0 >= 1) and (p0 <= 65535)) and
      ((p1 >= 1) and (p1 <= 65535) and
      (p1 >= p0)))
end

-- #################################################################

local function validateInterfaceConfMode(m)
   return validateChoice({"dhcp", "static", "vlan_trunk"}, m)
end

-- #################################################################

local function validateAssociations(associations)
   if not associations or not type(associations) == "table" then
      return false
   end

   for k, v in pairs(associations) do
      if not isValidPoolMember(k) then
	 return false
      end
   end

   return true
end

-- #################################################################

local function validateSNMPhost(m)
   return validateIpAddress(m) or validateSingleWord(m)
end

-- #################################################################

local function validateSNMPversion(m)
-- 0 = SNMP v1
-- 1 = SNMP v2c
-- 2 - SNMP v3
  return validateChoice({"0", "1", "2"}, m)
end
http_lint.validateSNMPversion = validateSNMPversion

-- #################################################################

local function validateSNMPstatus(m)
  return validateChoice({"up", "down"}, m) or validateNumber(m)
end

-- #################################################################

local function validatenIndexQueryType(qt)
   return validateChoice({"top_clients", "top_servers", "top_protocols", "top_contacts"}, qt)
end

-- #################################################################

local function validateCIDR(m)
   return validateChoice({"24", "32", "128"}, m)
end

local function validateOperatingMode(m)
   return validateChoice({"single_port_router", "routing", "bridging", "passive"}, m)
end

-- #################################################################

function http_lint.parseConfsetTargets(subdir, param)
   local values = string.split(param, ",") or {param}
   local validator = nil

   if((subdir == "host") or (subdir == "snmp_device") or (subdir == "network")) then
      -- IP addresses/CIDR
      validator = validateNetwork
   elseif((subdir == "interface") or (subdir == "flow") or (subdir == "syslog")) then
      -- interface ID
      validator = validateInterface
   else
      traceError(TRACE_ERROR, TRACE_CONSOLE, "Unsupported subdir: " .. subdir)
      return nil, "Unsupported subdir"
   end

   for _, v in pairs(values) do
      if(not validator(v)) then
         return nil, i18n("configsets.bad_target", {target = v})
      end
   end

   return(values)
end

-- #################################################################

function validateToken(token)

   if (not token) then return false end
   if (string.len(token) ~= 32) then return false end
   -- iterate over each byte of the string
   if (token:match("^%x+$") == nil) then return false end

   return true
end

-- #################################################################

local function validateFieldAlias(key_value_pair)
   -- Validates parameters such as:
   -- packets.sent=tpd
   -- bytes.rcvd=rbd

   local kv = key_value_pair:split("=") or {key_value_pair}

   if #kv == 1 then
      -- Field without alias
      return validateSingleWord(kv[1])
   elseif #kv == 2 then
      -- Field and alias
      return validateSingleWord(kv[1]) and validateSingleWord(kv[2])
   end

   return false
end

-- #################################################################

local function validateListItems(script, conf, key)
   local item_type = script.gui.item_list_type or ""
   local item_validator = validateUnchecked
   local existing_items = {}
   local validated_items = {}
   key = key or "items"
   local conf_items = conf[key]

   if(item_type == "country") then
      item_validator = validateCountry
      err_label = "Bad country"
   elseif(item_type == "proto_or_category") then
      item_validator = validateProtocolOrCategory
      err_label = "Bad protocol/category"
   elseif(item_type == "string") then
      item_validator = validateSingleWord
      err_label = "Bad string"
   elseif(item_type == "device_type") then
      item_validator = validateDeviceType
      err_label = "Bad device type"
   elseif(item_type == "ip_address") then
      item_validator = validateIpAddress
      err_label = "Bad address"
   elseif(item_type == "mac_address") then
      item_validator = validateMac
      err_label = "Bad address"
   end
   

   if(type(conf_items) == "table") then
      for _, item in ipairs(conf_items) do
         if existing_items[item] then
            -- Ignore duplicated items
            goto next_item
         end

         if not item_validator(item) then
            return false, err_label .. ": " .. string.format("%s", item)
         end

         existing_items[item] = true
         validated_items[#validated_items + 1] = item

         ::next_item::
      end

      conf[key] = validated_items
   end

   return true, conf
end

http_lint.validateListItems = validateListItems

-- #################################################################

-- NOTE: Put here all the parameters to validate

local known_parameters = {
-- UNCHECKED (Potentially Dangerous)
   ["custom_name"]             = validateUnchecked,            -- A custom interface/host name
   ["pool_name"]               = validateUnchecked,
   ["query"]                   = validateUnchecked,            -- This field should be used to perform partial queries.
                                                               -- It up to the script to implement proper validation.
                                                               -- In NO case query should be executed directly without validation.
-- UNQUOTED (Not Generally dangerous)
   ["referer"]                 = validateUnquoted,             -- An URL referer
   ["url"]                     = { webhookCleanup, validateUnquoted }, -- An URL
   ["label"]                   = validateUnquoted,             -- A device label
   ["os"]                      = validateNumber,               -- An Operating System id
   ["info"]                    = validateUnquoted,             -- An information message
   ["entity_val"]              = validateUnquoted,             -- An alert entity value
   ["full_name"]               = validateUnquoted,             -- A user full name
   ["manufacturer"]            = validateUnquoted,             -- A MAC manufacturer
   ["slack_sender_username"]   = validateUnquoted,
   ["slack_webhook"]           = { webhookCleanup, validateUnquoted },
   ["bind_dn"]                 = validateUnquoted,
   ["bind_pwd"]                = { passwordCleanup, validatePassword }, -- LDAP Bind Authentication Password
   ["search_path"]             = validateUnquoted,
   ["user_group"]              = validateUnquoted,
   ["admin_group"]             = validateUnquoted,
   ["radius_admin_group"]      = validateUnquoted,
   ["ts_post_data_url"]        = validateUnquoted,             -- URL for influxdb

   ["webhook_url"]             = { webhookCleanup, validateUnquoted },
   ["webhook_sharedsecret"]    = validateEmptyOr(validateSingleWord),
   ["webhook_username"]        = validateEmptyOr(validateSingleWord),
   ["webhook_password"]        = validateEmptyOr(validateSingleWord),

   -- nIndex
   ["select_clause"]           = validateUnquoted,
   ["select_keys_clause"]      = validateUnquoted,
   ["select_values_clause"]    = validateUnquoted,
   ["approx_search"]           = validateBool,

   ["where_clause"]            = { whereCleanup, validateUnquoted },
   ["where_clause_unck"]       = { whereCleanup, validateUnchecked },
   ["begin_time_clause"]       = validateUnquoted,
   ["end_time_clause"]         = validateUnquoted,
   ["flow_clause"]             = validateSingleWord,            -- deprecated (keeping for backward compatibility)
   ["topk_clause"]             = validateSingleWord,
   ["maxhits_clause"]          = validateNumber,
   ["ni_query_type"]           = validatenIndexQueryType,
   ["ni_query_filter"]         = validateListOfTypeInline(validateSingleWord),

-- HOST SPECIFICATION
   ["host"]                    = validateHost,                  -- an IPv4 (optional @vlan), IPv6 (optional @vlan), or MAC address
   ["versus_host"]             = validateHost,                  -- an host for comparison
   ["mac"]                     = validateMac,                   -- a MAC address
   ["tskey"]                   = validateSingleWord,            -- host identifier for timeseries
   ["peer1"]                   = validateHost,                  -- a Peer in a connection
   ["peer2"]                   = validateHost,                  -- another Peer in a connection
   ["origin"]                  = validateHost,                  -- the source of the alert
   ["target"]                  = validateHost,                  -- the target of the alert
   ["member"]                  = validateMember,                -- an IPv4 (optional @vlan, optional /suffix), IPv6 (optional @vlan, optional /suffix), or MAC address
   ["network"]                 = validateNumber,  -- A network ID/name
   ["network_name"]            = validateFilters(validateNetwork),
   ["network_cidr"]            = validateNetwork,               -- A network expressed with the /
   ["ip"]                      = validateEmptyOr(validateListOfTypeInline(validateFilters(validateHost))), -- An IPv4 or IPv6 address
   ["cli_ip"]                  = validateEmptyOr(validateListOfTypeInline(validateFilters(validateHost))), -- An IPv4 or IPv6 address
   ["srv_ip"]                  = validateEmptyOr(validateListOfTypeInline(validateFilters(validateHost))), -- An IPv4 or IPv6 address
   ["cli_port"]                = validateListOfTypeInline(validateFilters(validatePort)),          --Client port
   ["srv_port"]                = validateListOfTypeInline(validateFilters(validatePort)),          --Server port
   ["cli_asn"]                 = validateListOfTypeInline(validateFilters(validateNumber)),
   ["srv_asn"]                 = validateListOfTypeInline(validateFilters(validateNumber)),
   ["subtype"]                 = validateListOfTypeInline(validateFilters(validateUnquoted)),
   ["tot_pkts"]                = validateFilters(validateNumber),                --Total packtes, used by nindex query
   ["observation_point_id"]    = validateFilters(validateNumber),                --Observation point ID, used by nindex query
   ["probe_ip"]                = validateFilters(validateHost),                  --Probe IP, used by nindex query
   ["tot_bytes"]               = validateFilters(validateNumber),                --Total bytes, used by nindex query
   ["src2dst_dscp"]            = validateEmptyOr(validateFilters(validateUnquoted)),                               --Client DSCP, used by nindex query
   ["flow_status_num"]                  = validateEmptyOr(validateFilters(validateUnquoted)),                               --Flow Status, used by nindex query
   ["vhost"]                   = validateHTTPHost,              -- HTTP server name or IP address
   ["version"]                 = validateIpVersion,             -- To specify an IPv4 or IPv6
   ["ip_version"]              = validateListOfTypeInline(validateFilters(validateIpVersion)),             -- To specify an IPv4 or IPv6
   ["vlan"]                    = validateEmptyOr(validateNumber), -- A VLAN id
   ["hosts"]                   = validateHostsList,             -- A list of hosts

-- AUTHENTICATION
   ["username"]                = validateUsername,              -- A ntopng user name, new or existing
   ["password"]                = { passwordCleanup, validatePassword },              -- User password
   ["new_password"]            = { passwordCleanup, validatePassword },              -- The new user password
   ["old_password"]            = { passwordCleanup, validatePassword },              -- The old user password
   ["confirm_password"]        = { passwordCleanup, validatePassword },              -- Confirm user password
   ["user_role"]               = validateUserRole,              -- User role
   ["user_language"]           = validateUserLanguage,          -- User language
   ["allow_pcap_download"]     = validateEmptyOr(validateBool),

-- NDPI
   ["application"]             = validateApplication,           -- An nDPI application protocol name
   ["category"]                = validateCategory,              -- An nDPI protocol category name
   ["breed"]                   = validateBool,                  -- True if nDPI breed should be shown
   ["ndpi_category"]           = validateBool,                  -- True if nDPI category should be shown
   ["ndpistats_mode"]          = validateNdpiStatsMode,         -- A mode for rest/v2/get/interface/l7/stats.lua
   ["l4_proto_id"]             = validateProtocolIdOrName,      -- get_historical_data.lua
   ["l7_proto_id"]             = validateProtocolIdOrName,      -- get_historical_data.lua
   ["l4proto"]                 = validateListOfTypeInline(validateFilters(validateProtocolIdOrName)),      -- An nDPI application protocol ID, layer 4
   ["l7proto"]                 = validateListOfTypeInline(validateFilters(validateProtocolIdOrName)), -- An nDPI application protocol ID, layer 7
   ["l7_proto"]                = validateListOfTypeInline(validateFilters(validateProtocolIdOrName)), -- An nDPI application protocol ID, layer 7
   ["filtered_query"]          = validateBool,            -- Parameter used to download nindex flows
   ["l7cat"]                   = validateListOfTypeInline(validateFilters(validateCategory)), -- An nDPI category, layer 7
   ["flow_risk"]               = validateListOfTypeInline(validateFilters(validateUnquoted)), -- Flow risk   
   ["visible_columns"]         = validateSingleWord,        -- String containing the visible columns used by nindex raw flows   
   ["protocol"]                = validateProtocolIdOrName,      -- An nDPI application protocol ID or name
   ["ndpi"]                    = validateApplicationsList,      -- a list applications
   ["ndpi_new_cat_id"]         = validateNumber,                -- An ndpi category id after change
   ["ndpi_old_cat_id"]         = validateNumber,                -- An ndpi category id before change
   ["new_application"]         = validateSingleWord,            -- A new nDPI application protocol name

-- Wireless
   ["wifi_enabled"]            = validateBool,
   ["wifi_ssid"]               = validateSingleWord,
   ["wpa_passphrase"]          = { passwordCleanup, validatePassword }, -- Wifi password

-- Remote probe
   ["ifIdx"]                   = validateNumber,                -- A generic switch/router port id
   ["inIfIdx"]                 = validateNumber,                -- A switch/router INPUT port id (%INPUT_SNMP)
   ["outIfIdx"]                = validateNumber,                -- A switch/router OUTPUT port id (%OUTPUT_SNMP)
   ["deviceIP"]                = validateIPV4,                  -- The switch/router exporter ip address (%EXPORTER_IPV4_ADDRESS)
   ["ebpf_data"]               = validateEBPFData,              -- mode for get_username_data.lua and get_process_data.lua
   ["uid"]                     = validateNumber,                -- user id
   ["pid_mode"]                = validatePidMode,               -- pid mode for pid_stats.lua
   ["pid_name"]                = validateSingleWord,            -- A process name
   ["pid"]                     = validateNumber,                -- A process ID
   ["procstats_mode"]          = validateProcessesStatsMode,    -- A mode for processes_stats.lua
   ["sflowdistro_mode"]        = validateSflowDistroMode,       -- A mode for host_sflow_distro
   ["distr"]                   = validateSflowDistroType,       -- A type for host_sflow_distro
   ["sflow_filter"]            = validateSflowFilter,           -- sflow host filter
   ["exporter_ifname"]         = validateSingleWord,            -- an interface name on the exporter system

-- TIME SPECIFICATION
   ["epoch"]                   = validateNumber,                -- A timestamp value
   ["epoch_begin"]             = validateNumber,                -- A timestamp value to indicate start time
   ["epoch_end"]               = validateNumber,                -- A timestamp value to indicate end time
   ["period_begin_str"]        = validateDate,                  -- Specifies a start date in JS format
   ["period_end_str"]          = validateDate,                  -- Specifies an end date in JS format
   ["timezone"]                = validateNumber,                -- The timezone of the browser

-- PAGINATION
   ["perPage"]                 = validateNumber,                -- Number of results per page (used for pagination)
   ["sortOrder"]               = validateSortOrder,             -- A sort order
   ["sortColumn"]              = validateSortColumn,            -- A sort column
   ["currentPage"]             = validateNumber,                -- The currently displayed page number (used for pagination)
   ["totalRows"]               = validateNumber,                -- The total number of rows

-- AGGREGATION
   ["grouped_by"]              = validateSingleWord,            -- A group criteria
   ["aggregation"]             = validateAggregation,           -- A mode for graphs aggregation
   ["limit"]                   = validateNumber,                -- To limit results
   ["all"]                     = validateEmpty,                 -- To remove limit on results

-- NAVIGATION
   ["page"]                    = validateSingleWord,            -- Currently active subpage tab
   ["tab"]                     = validateSingleWord,            -- Currently active tab, handled by javascript
   ["system_interface"]        = validateBool,

-- CONFIGSETS
   ["filters"]	       	       = validateScriptFilter,		-- Currently active exclusion list for the alert
   ["delete_alerts"]           = validateBool,
   ["alert_generation"]	       = { jsonCleanup, validateJSON },
   ["script_exclusion_list"]    = validateListOfTypeInline(validateSingleWord),  -- Currently active exclusion list for the alert

-- UI TOASTS
   ["toast_id"]        = validateSingleWord,

-- NOTIFICATIONS ENDPOINT
   ["recipient_name"]         = validateUnquoted,
   ["bind_to_all_pools"]      = validateBool,
   ["recipient_id"]           = validateNumber,
   ["recipient_check_categories"] = validateEmptyOr(validateListOfTypeInline(validateNumber)),
   ["recipient_minimum_severity"]       = validateNumber,
   ["endpoint_conf_name"]     = validateUnquoted,
   ["endpoint_id"]       = validateNumberOrUnquoted,
   ["endpoint_conf_type"]     = validateUnquoted,
   ["cc"]                     = validateEmptyOr(validateSingleWord),

-- POOLS
   ["pool_members"]           = validateEmptyOr(validateListOfTypeInline(validateSingleWord)),
   ["recipients"]             = validateEmptyOr(validateListOfTypeInline(validateNumber)),

-- OTHER
   ["_"]                       = validateEmptyOr(validateNumber), -- jQuery nonce in ajax requests used to prevent browser caching
   ["__"]                      = validateUnquoted,              -- see LDAP prefs page
   ["begin_epoch"]             = validateNumber,
   ["end_epoch"]               = validateNumber,
   ["ifid"]                    = validateInterface,             -- An ntopng interface ID
   ["observationPointId"]      = validateNumber,
   ["ifname"]                  = validateSingleWord,
   ["iffilter"]                = validateIfFilter,              -- An interface ID or 'all'
   ["mode"]                    = validateMode,                  -- Remote or Local users
   ["dashboard_mode"]          = validateDashboardMode,         -- Dashboard mode
   ["device_responsiveness"]   = validateDeviceResponsiveness,  -- Device responsiveness
   ["counters_since"]          = validateCounterSince,          -- Select actual or absolute counters
   ["err_counters_filter"]     = validateErrorsFilter,          -- Filter by errrrs, discards, both
   ["country"]                 = validateCountry,               -- Country code
   ["flow_key"]                = validateNumber,                -- The key of the flow
   ["flow_hash_id"]            = validateNumber,                -- The ID uniquely identifying the flow in the hash table
   ["user"]                    = validateSingleWord,            -- The user ID
   ["pool"]                    = validateNumber,                -- A pool ID
   ["pool_id"]                 = validateNumber,                -- A pool ID
   ["direction"]               = validateDirection,             -- Sent or Received direction
   ["download"]                = validateBool,
   ["item"]                    = validateSingleWord,            -- Used by the Import/Export page to select the item to import/export
   ["stats_type"]              = validateStatsType,             -- A mode for historical stats queries
   ["alertstats_type"]         = validateAlertStatsType,        -- A mode for alerts stats queries
   ["flowhosts_type"]          = validateFlowHostsType,         -- A filter for local/remote hosts in each of the two directions
   ["status"]                  = validateUnquoted,           -- An alert type to filter
   ["enabled_status"]          = validateSingleWord,            -- Can be: All, Enabled, Disabled
   ["hash_table"]              = validateSingleWord,            -- An internal ntopng hash_table
   ["periodic_script"]         = validateSingleWord,            -- A script under callbacks/interface executed by ntopng
   ["periodic_script_issue"]   = validateSingleWord,            -- Script issues under callbacks/interface executed by ntopng
   ["check"]             = validateSingleWord,            -- A user script key
   ["check_target"]      = validateSingleWord,            -- A user script target, e.g., Flow, Host, Interface
   ["subdir"]                  = validateSingleWord,            -- A user script subdir
   ["profile"]                 = http_lint.validateTrafficProfile,        -- Traffic Profile name
   ["delete_profile"]          = http_lint.validateTrafficProfile,        -- A Traffic Profile to delete
   ["alert_id"]                = validateListOfTypeInline(validateFilters(validateNumber)),-- An alert type enum
   ["alert_type"]              = validateNumber,                -- An alert type enum (deprecated: use alert_id)
   ["alert_l7_proto"]          = validateNumber,                -- An alert l7 protocol
   ["alert_subtype"]           = validateSingleWord,            -- An alert subtype string
   ["alert_severity"]          = validateNumber,                -- An alert severity enum
   ["severity"]                = validateListOfTypeInline(validateFilters(validateNumber)), -- Same as alert_severity
   ["alert_granularity"]       = validateNumber,                -- An alert granularity
   ["entity"]                  = validateNumber,                -- An alert entity type
   ["role"]                    = validateListOfTypeInline(validateFilters(validateSingleWord)), -- attacker/victim
   ["role_cli_srv"]            = validateListOfTypeInline(validateFilters(validateSingleWord)), -- client/server
   ["acknowledged"]            = validateListOfTypeInline(validateFilters(validateSingleWord)), -- acknowledged
   ["asn"]                     = validateNumber,                -- An ASN number
   ["module"]                  = validateTopModule,             -- A top script module
   ["step"]                    = validateNumber,                -- A step value
   ["cf"]                      = validateConsolidationFunction, -- An RRD consolidation function
   ["verbose"]                 = validateBool,                  -- True if script should be verbose
   ["num_minutes"]             = validateNumMinutes,            -- number of minutes
   ["zoom"]                    = validateZoom,                  -- a graph zoom specifier
   ["column_key"]              = validateSingleWord,            -- SNMP Column Key
   ["community"]               = validateSingleWord,            -- SNMP community
   ["snmp_read_community"]     = validateSingleWord,            -- SNMP Read community
   ["snmp_write_community"]    = validateSingleWord,            -- SNMP Write community
   ["snmp_level"]              = validateSnmpLevel,             -- SNMP Level
   ["snmp_auth_protocol"]      = validateSnmpAuthProtocol,
   ["snmp_auth_passphrase"]    = validateSingleWord,
   ["snmp_privacy_protocol"]   = validateSnmpPrivacyProtocol,
   ["observation_point"]       = validateNumber,
   ["snmp_privacy_passphrase"] = validateSingleWord,
   ["lldp_mode"]               = validateBool,                  -- LLDP mode
   ["default_snmp_community"]  = validateSingleWord,            -- Default SNMP community for non-SNMP-configured local hosts
   ["snmp_host"]               = validateSNMPhost,              -- Either an IPv4/v6 or a hostname
   ["default_snmp_version"]    = validateSNMPversion,           -- Default SNMP protocol version
   ["snmp_version"]            = validateSNMPversion,           -- 0:v1 1:v2c 2:v3
   ["snmp_username"]           = validateSingleWord,            -- SNMP Username
   ["cidr"]                    = validateCIDR,                  -- /32 or /24
   ["snmp_port_idx"]           = validateNumber,                -- SNMP port index
   ["snmp_recache" ]           = validateBool,                  -- forces SNMP queries to be re-executed and cached
   ["request_discovery" ]      = validateBool,                  -- forces device discovery to be re-cached
   ["intfs"]                   = validateInterfacesList,        -- a list of network interfaces ids
   ["search"]                  = validateBool,                  -- When set, a search should be performed
   ["search_flows"]            = validateBool,                  -- When set, a flow search should be performed
   ["custom_column"]           = validateCustomColumn,
   ["criteria"]                = validateCustomColumn,
   ["row_id"]                  = validateNumber,                -- A number used to identify a record in a database
   ["rrd_file"]                = validateUnquoted,              -- A path or special identifier to read an RRD file
   ["port"]                    = validatePort,                  -- An application port
   ["ntopng_license"]          = {licenseCleanup, validateLicense},          -- ntopng licence string
   ["syn_attacker_threshold"]        = validateEmptyOr(validateNumber),
   ["global_syn_attacker_threshold"] = validateEmptyOr(validateNumber),
   ["syn_victim_threshold"]          = validateEmptyOr(validateNumber),
   ["global_syn_victim_threshold"]   = validateEmptyOr(validateNumber),
   ["flow_attacker_threshold"]         = validateEmptyOr(validateNumber),
   ["global_flow_attacker_threshold"]  = validateEmptyOr(validateNumber),
   ["flow_victim_threshold"]           = validateEmptyOr(validateNumber),
   ["global_flow_victim_threshold"]    = validateEmptyOr(validateNumber),
   ["re_arm_minutes"]          = validateEmptyOr(validateNumber),                -- Number of minute before alert re-arm check
   ["device_type"]             = validateNumber,
   ["ewma_alpha_percent"]      = validateNumber,
   ["sidebar_collapsed"]      = validateNumber,
   ["senders_receivers"]       = validateSendersReceivers,      -- Used in top scripts
   ["fingerprint_type"]        = validateFingerprintType,
   ["granularity"]             = validateSingleWord,
   ["old_granularity"]         = validateSingleWord,
   ["script_type"]             = validateSingleWord,
   ["check_subdir"]           = validateSingleWord,
   ["script_key"]              = validateSingleWord,
   ["alert_key"]               = validateNumber,
   ["alert_addr"]              = validateEmptyOr(validateIpAddress),
   ["search_script"]           = validateSingleWord,
   ["field_alias"]             = validateListOfTypeInline(validateFieldAlias),
   ["dscp_class"]              = validateSingleWord,
   ["host_pool_members"]      = validateUnquoted,

   -- Widget and Datasources
   ["ds_type"]                 = validateSingleWord,
   ["ds_name"]                 = validateSingleWord,
   ["transformation"]          = validateTransformation,

-- Topology SNMP Devices
   ["topology_host"]                   = validateIPV4,

-- Infrastructure Dashboard
   ["alias"]                  = validateUnquoted,
   ["token"]                  = validateToken,
   ["instance_id"]            = validateSingleWord,
   ["stats"]                  = validateBool,
   ["rtt_threshold"]          = validateNumber,
   ["bandwidth_threshold"]    = validateNumber,

-- Service Map
   ["service_id"]            = validateNumber,
   ["service_state"]         = validateNumber,
   ["set_service_state"]    = validateNumber,
   ["service_l7proto"]      = validateSingleWord,
   ["map"]                 = validateUnquoted,
   ["age"]          = validateSingleWord,
   ["first_seen"]    = validateNumber,

-- Script editor
   ["plugin_file_path"]         = validateLuaScriptPath,
   ["plugin_path"]              = validateLuaScriptPath,

-- PREFERENCES - see prefs.lua for details
   -- Toggle Buttons
   ["flow_table_time"]                             = validateBool,
   ["interface_rrd_creation"]                      = validateBool,
   ["interface_one_way_hosts_rrd_creation"]        = validateBool,
   ["interface_top_talkers_creation"]              = validateBool,
   ["interface_flow_dump"]                         = validateBool,
   ["is_mirrored_traffic"]                         = validateBool,
   ["discard_probing_traffic"]                     = validateBool,
   ["show_dyn_iface_traffic"]                      = validateBool,
   ["interface_network_discovery"]                 = validateBool,
   ["dynamic_iface_vlan_creation"]                 = validateBool,
   ["toggle_mysql_check_open_files_limit"]         = validateBool,
   ["disable_alerts_generation"]                   = validateBool,
   ["enable_score"]                                = validateBool,
   ["toggle_alert_probing"]                        = validateBool,
   ["toggle_flow_alerts_iface"]                    = validateBool,
   ["toggle_tls_alerts"]                           = validateBool,
   ["toggle_dns_alerts"]                           = validateBool,
   ["toggle_mining_alerts"]                        = validateBool,
   ["toggle_remote_to_remote_alerts"]              = validateBool,
   ["toggle_dropped_flows_alerts"]                 = validateBool,
   ["toggle_malware_probing"]                      = validateBool,
   ["toggle_potentially_dangerous_protocols_alerts"] = validateBool,
   ["toggle_device_protocols_alerts"]              = validateBool,
   ["toggle_elephant_flows_alerts"]                = validateBool,
   ["toggle_ip_reassignment_alerts"]               = validateBool,
   ["toggle_longlived_flows_alerts"]               = validateBool,
   ["toggle_data_exfiltration"]                    = validateBool,
   ["toggle_enable_runtime_flows_dump"]            = validateBool,
   ["toggle_tiny_flows_dump"]                      = validateBool,
   ["toggle_alert_syslog"]                         = validateBool,
   ["toggle_slack_notification"]                   = validateBool,
   ["toggle_email_notification"]                   = validateBool,
   ["toggle_top_sites"]                            = validateBool,
   ["toggle_captive_portal"]                       = validateBool,
   ["toggle_informative_captive_portal"]           = validateBool,
   ["toggle_autologout"]                           = validateBool,
   ["toggle_autoupdates"]                          = validateBool,
   ["toggle_ldap_anonymous_bind"]                  = validateBool,
   ["toggle_local"]                                = validateBool,
   ["toggle_local_host_cache_enabled"]             = validateBool,
   ["toggle_active_local_host_cache_enabled"]      = validateBool,
   ["toggle_network_discovery"]                    = validateBool,
   ["toggle_interface_traffic_rrd_creation"]       = validateBool,
   ["toggle_local_hosts_traffic_rrd_creation"]     = validateBool,
   ["toggle_local_hosts_stats_rrd_creation"]       = validateBool,
   ["toggle_l2_devices_traffic_rrd_creation"]      = validateBool,
   ["toggle_observation_points_rrd_creation"]     = validateBool,
   ["toggle_system_probes_timeseries"]             = validateBool,
   ["toggle_flow_rrds"]                            = validateBool,
   ["toggle_pools_rrds"]                           = validateBool,
   ["toggle_flow_snmp_ports_rrds"]                 = validateBool,
   ["toggle_access_log"]                           = validateBool,
   ["toggle_host_pools_log"]                       = validateBool,
   ["toggle_log_to_file"]                          = validateBool,
   ["toggle_snmp_rrds"]                            = validateBool,
   ["toggle_tiny_flows_export"]                    = validateBool,
   ["toggle_vlan_rrds"]                            = validateBool,
   ["toggle_asn_rrds"]                             = validateBool,
   ["toggle_country_rrds"]                         = validateBool,
   ["toggle_os_rrds"]                              = validateBool,
   ["toggle_shaping_directions"]                   = validateBool,
   ["toggle_dst_with_post_nat_dst"]                = validateBool,
   ["toggle_src_with_post_nat_src"]                = validateBool,
   ["toggle_behaviour_analysis"]                   = validateBool,
   ["behaviour_analysis_learning_period"]          = validateNumber,
   ["behaviour_analysis_learning_status_during_learning"] = validateNumber,
   ["behaviour_analysis_learning_status_post_learning"]   = validateNumber,
   ["iec60870_learning_period"]                    = validateNumber,
   ["toggle_src_and_dst_using_ports"]              = validateBool,
   ["toggle_device_activation_alert"]              = validateBool,
   ["toggle_device_first_seen_alert"]              = validateBool,
   ["toggle_pool_activation_alert"]                = validateBool,
   ["toggle_quota_exceeded_alert"]                 = validateBool,
   ["toggle_external_alerts"]                      = validateBool,
   ["toggle_influx_auth"]                          = validateBool,
   ["toggle_ldap_auth"]                            = validateBool,
   ["toggle_local_auth"]                           = validateBool,
   ["toggle_radius_auth"]                          = validateBool,
   ["toggle_http_auth"]                            = validateBool,
   ["toggle_ldap_referrals"]                       = validateBool,
   ["toggle_webhook_notification"]                 = validateBool,
   ["toggle_elasticsearch_notification"]           = validateBool,
   ["toggle_auth_session_midnight_expiration"]     = validateBool,
   ["toggle_client_x509_auth"]                     = validateBool,
   ["toggle_snmp_debug"]                           = validateBool,
   ["toggle_snmp_port_admin_status"]               = validateBool,
   ["toggle_snmp_alerts_port_duplexstatus_change"] = validateBool,
   ["toggle_snmp_alerts_port_status_change"]       = validateBool,
   ["toggle_snmp_alerts_port_errors"]              = validateBool,
   ["snmp_port_load_threshold"]                    = validateNumber,
   ["toggle_midnight_stats_reset"]                 = validateBool,
   ["toggle_ndpi_flows_rrds"]                      = validateBool,
   ["toggle_internals_rrds"]                       = validateBool,
   ["toggle_local_hosts_one_way_ts"]               = validateBool,
   ["toggle_dark_theme"]                           = validateBool,

   -- Input fields
   ["companion_interface"]                         = validateEmptyOr(validateInterface),
   ["data_retention_days"]                         = validateNumber,
   ["max_entity_alerts"]                           = validateNumber,
   ["max_num_secs_before_delete_alert"]            = validateNumber,
   ["elephant_flow_remote_to_local_bytes"]         = validateNumber,
   ["elephant_flow_local_to_remote_bytes"]         = validateNumber,
   ["max_num_packets_per_tiny_flow"]               = validateNumber,
   ["max_num_bytes_per_tiny_flow"]                 = validateNumber,
   ["google_apis_browser_key"]                     = validateSingleWord,
   ["ldap_server_address"]                         = validateSingleWord,
   ["radius_server_address"]                       = validateSingleWord,
   ["http_auth_url"]                               = validateSingleWord,
   ["radius_secret"]                               = validateUnquoted,
   ["local_host_max_idle"]                         = validateNumber,
   ["longlived_flow_duration"]                     = validateNumber,
   ["non_local_host_max_idle"]                     = validateNumber,
   ["flow_max_idle"]                               = validateNumber,
   ["active_local_host_cache_interval"]            = validateNumber,
   ["auth_session_duration"]                       = validateNumber,
   ["local_host_cache_duration"]                   = validateNumber,
   ["local_host_cache_duration"]                   = validateNumber,
   ["housekeeping_frequency"]                      = validateNumber,
   ["intf_rrd_raw_days"]                           = validateNumber,
   ["intf_rrd_1min_days"]                          = validateNumber,
   ["intf_rrd_1h_days"]                            = validateNumber,
   ["intf_rrd_1d_days"]                            = validateNumber,
   ["other_rrd_raw_days"]                          = validateNumber,
   ["other_rrd_1min_days"]                         = validateNumber,
   ["other_rrd_1h_days"]                           = validateNumber,
   ["other_rrd_1d_days"]                           = validateNumber,
   ["host_activity_rrd_1h_days"]                   = validateNumber,
   ["host_activity_rrd_1d_days"]                   = validateNumber,
   ["host_activity_rrd_raw_hours"]                 = validateNumber,
   ["max_ui_strlen"]                               = validateNumber,
   ["http_acl_management_port"]                    = validateACLNetworksList,
   ["safe_search_dns"]                             = validateIPV4,
   ["global_dns"]                                  = validateEmptyOr(validateIPV4),
   ["secondary_dns"]                               = validateEmptyOr(validateIPV4),
   ["redirection_url"]                             = validateEmptyOr(validateSingleWord),
   ["email_sender"]                                = validateSingleWord,
   ["email_recipient"]                             = validateSingleWord,
   ["smtp_server"]                                 = validateSMTPServer,
   ["smtp_username"]                               = validateEmptyOr(validateSingleWord),
   ["smtp_password"]                               = validateEmptyOr(validatePassword),
   ["influx_dbname"]                               = validateSingleWord,
   ["influx_username"]                             = validateEmptyOr(validateSingleWord),
   ["influx_password"]                             = validateEmptyOr(validateSingleWord),
   ["influx_query_timeout"]                        = validateNumber,

   -- Multiple Choice
   ["disaggregation_criterion"]                    = validateChoiceInline({"none", "vlan", "probe_ip", "iface_idx", "ingress_iface_idx", "ingress_vrf_id", "probe_ip_and_ingress_iface_idx"}),
   ["ignored_interfaces"]                          = validateEmptyOr(validateListOfTypeInline(validateNumber)),
   ["hosts_ndpi_timeseries_creation"]              = validateChoiceInline({"none", "per_protocol", "per_category", "both"}),
   ["interfaces_ndpi_timeseries_creation"]         = validateChoiceInline({"none", "per_protocol", "per_category", "both"}),
   ["l2_devices_ndpi_timeseries_creation"]         = validateChoiceInline({"none", "per_category"}),
   ["slack_notification_severity_preference"]      = validateNotificationSeverity,
   ["email_notification_severity_preference"]      = validateNotificationSeverity,
   ["webhook_notification_severity_preference"]    = validateNotificationSeverity,
   ["notification_severity_preference"]            = validateNotificationSeverity,
   ["multiple_ldap_authentication"]                = validateChoiceInline({"local","ldap","ldap_local"}),
   ["multiple_ldap_account_type"]                  = validateChoiceInline({"posix","samaccount"}),
   ["toggle_logging_level"]                        = validateChoiceInline({"trace", "debug", "info", "normal", "warning", "error"}),
   ["toggle_thpt_content"]                         = validateChoiceInline({"bps", "pps"}),
   ["toggle_theme"]                                = validateChoiceInline({"default", "light", "dark"}),
   ["toggle_host_mask"]                            = validateChoiceInline({"0", "1", "2"}),
   ["topk_heuristic_precision"]                    = validateChoiceInline({"disabled", "more_accurate", "accurate", "aggressive"}),
   ["bridging_policy_target_type"]                 = validateChoiceInline({"per_protocol", "per_category", "both"}),
   ["timeseries_driver"]                           = validateChoiceInline({"rrd", "influxdb", "prometheus"}),
   ["edition"]                                     = validateEmptyOr(validateChoiceInline({"community", "pro", "enterprise", "enterprise_m", "enterprise_l"})),
   ["hosts_ts_creation"]                           = validateChoiceInline({"off", "light", "full"}),
   ["ts_high_resolution"]                          = validateNumber,
   ["lbd_hosts_as_macs"]                           = validateBool,
   ["toggle_send_telemetry_data"]                  = validateBool,
   ["toggle_emit_flow_alerts"]                     = validateBool,   
   ["toggle_emit_host_alerts"]                     = validateBool,   
   ["telemetry_email"]                             = validateSingleWord,

   -- Other
   ["send_test_email"]                             = validateEmpty,
   ["send_test_slack"]                             = validateEmpty,
   ["send_test_webhook"]                           = validateEmpty,
   ["send_test_elasticsearch"]                     = validateEmpty,
   ["network_discovery_interval"]                  = validateNumber,
   ["blog_notification_id"]                        = validateNumber,
   ["captive_portal_id_method"]                    = validateChoiceInline({"mac", "ip"}),

   -- Error report
   ["message"]                                     = validateSingleWord,
   ["script_path"]                                 = validateLuaScriptPath,
   ["error_message"]                               = validateMessage,
   ["reason"]                                      = validateSingleWord,

--

-- LIVE CAPTURE
   ["capture_id"]              = validateNumber,                -- Live capture id
   ["duration"]                = validateNumber,                --
   ["bpf_filter"]              = validateEmptyOr(validateUnquoted), --

-- TRAFFIC RECORDING
   ["disk_space"]                                  = validateNumber,
   ["file_id"]                                     = validateNumber,
   ["job_action"]                                  = validateExtractionJobAction,
   ["job_id"]                                      = validateNumber,
   ["n2disk_license"]                              = {licenseCleanup, validateLicense},
   ["record_traffic"]                              = validateBool,
   ["max_extracted_pcap_bytes"]                    = validateNumber,
   ["traffic_recording_provider"]                  = validateTrafficRecordingProvider,
   ["dismiss_external_providers_reminder"]         = validateBool,
   ["dismiss_missing_geoip_reminder"]              = validateBool,
--

-- TOP STATS
   ["only_data"]               = validateEmptyOr(validateBool),                  -- Used by top talkers, if true then only important data is returned
--   

-- PAGE SPECIFIC
   ["hour"]                    = validateEmptyOr(validateSingleWord),
   ["unicast_only"]           = validateBool,
   ["iflocalstat_mode"]        = validateIfaceLocalStatsMode,   -- A mode for iface_local_stats.lua
   ["clisrv"]                  = validateClientOrServer,        -- Client or Server filter
   ["report"]                  = validateReportMode,            -- A mode for traffic report
   ["use_server_timezone"]     = validateBool,
   ["report_zoom"]             = validateBool,                  -- True if we are zooming in the report
   ["format"]                  = validatePrintFormat,           -- a print format
   ["nedge_config_action"]     = validatenEdgeAction,           -- system_setup_ui_utils.lua
   ["fav_action"]              = validateFavouriteAction,       -- get_historical_favourites.lua
   ["favourite_type"]          = validateFavouriteType,         -- get_historical_favourites.lua
   ["locale"]                  = validateCountry,               -- locale used in test_locale.lua
   ["render"]                  = validateBool,                  -- True if report should be rendered
   ["printable"]               = validateBool,                  -- True if report should be printable
   ["daily"]                   = validateBool,                  -- used by report.lua
   ["json"]                    = validateBool,                  -- True if json output should be generated
   ["extended"]                = validateBool,                  -- Flag for extended report
   ["tracked"]                 = validateNumber,                --
   ["ajax_format"]             = validateAjaxFormat,            -- iface_hosts_list
   ["host_stats_flows"]        = validateBool,                  -- True if host_get_json should return statistics regarding host flows
   ["showall"]                 = validateBool,                  -- report.lua
   ["addvlan"]                 = validateBool,                  -- True if VLAN must be added to the result
   ["http_mode"]               = validateHttpMode,              -- HTTP mode for host_http_breakdown.lua
   ["refresh"]                 = validateNumber,                -- top flow refresh in seconds, index.lua
   ["always_show_hist"]        = validateBool,                  -- host_details.lua
   ["host_stats"]              = validateBool,                  -- host_get_json
   ["captive_portal_users"]    = validateBool,                  -- to show or hide captive portal users
   ["long_names"]              = validateBool,                  -- get_hosts_data
   ["id_to_delete"]            = validateIdToDelete,            -- alert_utils.lua, alert ID to delete
   ["to_delete"]               = validateLocalGlobal,           -- alert_utils.lua, set if alert configuration should be dropped
   ["SaveAlerts"]              = validateEmpty,                 -- alert_utils.lua, set if alert configuration should change
   ["host_pool_id"]            = validateNumber,                -- change_user_prefs, new pool id for host
   ["old_host_pool_id"]        = validateNumber,                -- change_user_prefs, old pool id for host
   ["del_l7_proto"]            = validateShapedElement,         -- if_stats.lua, ID of the protocol to delete from rule
   ["target_pool"]             = validateNumber,                -- if_stats.lua, ID of the pool to perform the action on
   ["add_shapers"]             = validateEmpty,                 -- if_stats.lua, set when adding shapers
   ["delete_shaper"]           = validateNumber,                -- shaper ID to delete
   ["empty_pool"]              = validateNumber,                -- host_pools.lua, action to empty a pool by ID
   ["pool_to_delete"]          = validateNumber,                -- host_pools.lua, pool ID to delete
   ["edit_pools"]              = validateEmpty,                 -- host_pools.lua, set if pools are being edited
   ["member_to_delete"]        = validateMemberRelaxed,         -- host_pools.lua, member to delete from pool
   ["sampling_rate"]           = validateEmptyOr(validateNumber),            -- if_stats.lua
   ["resetstats_mode"]         = validateResetStatsMode,        -- reset_stats.lua
   ["snmp_action"]             = validateSnmpAction,            -- snmp specific
   ["snmp_status"]             = validateSNMPstatus,            -- snmp specific status (up: 1, down: 2, testing: 3)
   ["snmp_admin_status"]       = validateSNMPstatus,            -- same as snmp_status but for the admin status
   ["snmp_if_type"]            = validateNumber,                -- snmp interface type (see snmp_utils.lua fnmp_iftype)
   ["iftype_filter"]           = validateSingleWord,            -- SNMP iftype filter name
   ["host_quota"]              = validateEmptyOr(validateNumber),            -- max traffi quota for host
   ["allowed_interface"]       = validateEmptyOr(validateInterface),         -- the interface an user is allowed to configure
   ["allowed_networks"]        = validateNetworksList,          -- a list of networks the user is allowed to monitor
   ["switch_interface"]        = validateInterface,             -- a new active ntopng interface
   ["edit_members"]            = validateEmpty,                 -- set if we are editing pool members
   ["trigger_alerts"]          = validateBool,                  -- true if alerts should be active for this entity
   ["show_advanced_prefs"]     = validateBool,                  -- true if advanced preferences should be shown
   ["ifSpeed"]                 = validateEmptyOr(validateNumber), -- interface speed
   ["ifRate"]                  = validateEmptyOr(validateNumber), -- interface refresh rate
   ["scaling_factor"]          = validateEmptyOr(validateNumber), -- interface scaling factor
   ["drop_host_traffic"]       = validateBool,                  -- to drop an host traffic
   ["lifetime_limited"]        = validateEmptyOr(validateOnOff), -- set if user should have a limited lifetime
   ["lifetime_unlimited"]      = validateEmptyOr(validateOnOff), -- set if user should have an unlimited lifetime
   ["edit_profiles"]           = validateEmpty,                 -- set when editing traffic profiles
   ["edit_policy"]             = validateEmpty,                 -- set when editing policy
   ["edit_device_policy"]      = validateEmpty,                 -- set when editing device policy
   ["delete_user"]             = validateSingleWord,
   ["drop_flow_policy"]        = validateBool,                  -- true if target flow should be dropped
   ["traffic_type"]            = validateBroadcastUnicast,      -- flows_stats.lua
   ["alert_type"]              = validateAlertType,            -- flows_stats.lua
   ["flow_status"]             = validateAlertType,            -- flows_stats.lua
   ["alert_type_severity"]     = validateAlertTypeSeverity,    -- flows_stats.lua
   ["alert_type_num"]          = validateAlertTypeNumber,      -- charts
   ["tcp_flow_state"]          = validateTCPFlowState,          -- flows_stats.lua
   ["traffic_profile"]         = http_lint.validateTrafficProfile, -- flows_stats.lua
   ["include_unlimited"]       = validateBool,                  -- pool_details_ndpi.lua
   ["policy_preset"]           = validateEmptyOr(validatePolicyPreset), -- a traffic bridge policy set
   ["members_filter"]          = validateMembersFilter,         -- host_pools.lua
   ["devices_mode"]            = validateDevicesMode,           -- macs_stats.lua
   ["flow_mode"]               = validateFlowMode   ,           -- if_stats.lua
   ["unassigned_devices"]      = validateUnassignedDevicesMode, -- unknown_device.lua
   ["delete_all_policies"]     = validateEmpty,                 -- traffic policies
   ["safe_search"]             = validateBool,                  -- users
   ["device_protocols_policing"] = validateBool,                -- users
   ["forge_global_dns"]        = validateBool,                  -- users
   ["default_policy"]          = validateNumber,                -- users
   ["lan_interfaces"]          = validateListOfTypeInline(validateNetworkInterface),
   ["wan_interfaces"]          = validateListOfTypeInline(validateNetworkInterface),
   ["static_route_name"]       = validateStaticRouteName,
   ["old_static_route_name"]   = validateStaticRouteName,
   ["delete_static_route"]     = validateStaticRouteName,
   ["gateway_name"]            = validateGatewayName,
   ["old_gateway_name"]        = validateGatewayName,
   ["delete_gateway"]          = validateGatewayName,
   ["ping_address"]            = validateIPV4,
   ["policy_name"]             = validateRoutingPolicyName,
   ["old_policy_name"]         = validateRoutingPolicyName,
   ["delete_policy"]           = validateRoutingPolicyName,
   ["policy_id"]               = validateNumber,
   ["timezone_name"]           = validateTimeZoneName,
   ["custom_date_str"]         = validateDate,
   ["custom_date_str_orig"]    = validateDate,
   ["global_dns_preset"]       = validateSingleWord,
   ["child_dns_preset"]        = validateSingleWord,
   ["global_primary_dns"]      = validateIPV4,
   ["global_secondary_dns"]    = validateEmptyOr(validateIPV4),
   ["child_primary_dns"]       = validateIPV4,
   ["child_secondary_dns"]     = validateEmptyOr(validateIPV4),
   ["lan_recovery_ip"]         = validateIPV4,
   ["lan_recovery_netmask"]    = validateIPV4,
   ["dhcp_server_enabled"]     = validateBool,
   ["ntp_sync_enabled"]        = validateBool,
   ["activate_remote_assist"]  = validateBool,
   ["dhcp_first_ip"]           = validateIPV4,
   ["dhcp_last_ip"]            = validateIPV4,
   ["factory"]                 = validateBool,
   ["factory_reset"]           = validateEmpty,
   ["data_reset"]              = validateEmpty,
   ["policy_filter"]           = validateEmptyOr(validateNumber),
   ["hostname"]                = validateSingleWord,
   ["delete"]                  = validateEmpty,
   ["delete_active_if_data"]   = validateEmpty,
   ["delete_inactive_if_data"] = validateEmpty,
   ["delete_inactive_if_data_system"] = validateEmpty,
   ["delete_active_if_data_system"] =   validateEmpty,
   ["reset_quotas"]            = validateEmpty,
   ["bandwidth_allocation"]    = validateChoiceInline({"min_guaranteed", "max_enforced"}),
   ["bind_to"]                 = validateChoiceInline({"lan", "any"}),
   ["slow_pass_shaper_perc"]   = validateNumber,
   ["slower_pass_shaper_perc"] = validateNumber,
   ["skip_critical"]           = validateBool,
   ["reboot"]                  = validateEmpty,
   ["poweroff"]                = validateEmpty,
   ["operating_mode"]          = validateOperatingMode,
   ["per_ip_pass_rate"]        = validateNumber,
   ["per_ip_slow_rate"]        = validateNumber,
   ["per_ip_slower_rate"]      = validateNumber,
   ["user_policy"]             = validateNumber,
   ["hide_from_top"]           = validateNetworksWithVLANList,
   ["gw_macs"]                 = validateMacList,
   ["top_hidden"]              = validateBool,
   ["packets_drops_perc"]      = validateEmptyOr(validateNumber),
   ["operating_system"]        = validateNumber,
   ["action"]                  = validateSingleWord, -- generic
   ["table"]                   = validateSingleWord,
   ["columns"]                 = validateListOfTypeInline(validateNumber),
   ["ts_schema"]               = validateSingleWord,
   ["ts_query"]                = validateListOfTypeInline(validateUnquoted),
   ["ts_compare"]              = validateZoom,
   ["no_fill"]                 = validateBool,
   ["detail_view"]             = validateSingleWord,
   ["initial_point"]           = validateBool,
   ["extract_now"]             = validateBool,
   ["custom_hosts"]            = validateListOfTypeInline(validateSingleWord),
   ["assistance_key"]          = validateUnquoted,
   ["assistance_community"]    = validateUnquoted,
   ["allow_admin_access"]      = validateBool,
   ["accept_tos"]              = validateBool,
   ["no_timeout"]              = validateBool,
   ["bubble_mode"]             = validateNumber,
   ["supernode"]               = validateSingleWord,
   ["ts_aggregation"]          = validateChoiceInline({"raw", "1h", "1d"}),
   ["fw_rule_id"]              = validateSingleWord,
   ["external_port"]           = validatePortRange,
   ["internal_port"]           = validatePortRange,
   ["internal_ip"]             = validateIPV4,
   ["fw_proto"]                = validateChoiceInline({"tcp", "udp", "both"}),
   ["wan_interface"]           = validateNetworkInterface,
   ["list_name"]               = validateUnquoted,
   ["list_enabled"]            = validateOnOff,
   ["list_update"]             = validateNumber,
   ["dhcp_ranges"]             = validateListOfTypeInline(validateIpRange),
   ["old_dhcp_ranges"]         = validateListOfTypeInline(validateIpRange),
   ["icmp_type"]               = validateNumber,
   ["icmp_cod"]                = validateNumber,
   ["dscp"]                    = validateNumber,
   ["snmp_timeout_sec"]        = validateNumber,
   ["hosts_only"]              = validateBool,
   ["referal_url"]             = validateUnquoted,
   ["disabled_status"]         = validateListOfTypeInline(validateNumber),
   ["redis_command"]           = validateSingleWord,
   ["flow_calls_drops"]        = validateOnOff,
   ["global_flow_calls_drops"] = validateOnOff,
   ["syslog_producer"]         = validateSingleWord,
   ["syslog_producer_host"]    = validateSingleWord,
   ["old_syslog_producer"]     = validateSingleWord,
   ["old_syslog_producer_host"]= validateSingleWord,

   -- Containers
   ["pod"]                     = validateSingleWord,
   ["container"]               = validateSingleWord,

   -- Host Pools / users associations
   ["associations"]            = { jsonCleanup, validateAssociations },

   -- json POST DATA
   ["payload"]                 = { jsonCleanup, validateJSON },
   ["JSON"]                    = { jsonCleanup, validateJSON },

   -- See https://github.com/ntop/ntopng/issues/4275
   ["csrf"]               = validateSingleWord,

   -- server side Datatables 
   ["start"]              = validateNumber,
   ["sort"]               = validateSingleWord,
   ["order"]              = validateSortOrder,
   ["length"]             = validateNumber,
   ["draw"]               = validateNumber,
   ["visible_columns"]          = validateEmptyOr(validateListOfTypeInline(validateSingleWord))
}

-- A special parameter is formed by a prefix, followed by a variable suffix
local special_parameters = {   --[[Suffix validator]]     --[[Value Validator]]
-- The following parameter is *not* used inside ntopng
-- It allows third-party users to write their own scripts with custom
-- (unverified) parameters
   ["p_"]                      = { validateUnquoted,         validateUnquoted },

-- SHAPING
   ["shaper_"]                 = { validateNumber,            validateNumber },      -- key: a shaper ID, value: max rate
   ["ishaper_"]                = { validateShapedElement,     validateNumber },      -- key: category or protocol ID, value: ingress shaper ID
   ["eshaper_"]                = { validateShapedElement,     validateNumber },      -- key: category or protocol ID, value: egress shaper ID
   ["qtraffic_"]               = { validateShapedElement,     validateNumber },      -- key: category or protocol ID, value: traffic quota
   ["qtime_"]                  = { validateShapedElement,     validateNumber },      -- key: category or protocol ID, value: time quota
   ["oldrule_"]                = { validateShapedElement,     validateEmpty },       -- key: category or protocol ID, value: empty
   ["policy_"]                 = { validateShapedElement,     validateListOfTypeInline(validateNumber) },      -- key: category or protocol ID, value: shaper,bytes_quota,secs_quota
   ["client_policy_"]          = { validateShapedElement,     validateListOfTypeInline(validateNumber) },      -- key: category or protocol ID, value: shaper,bytes_quota,secs_quota
   ["server_policy_"]          = { validateShapedElement,     validateListOfTypeInline(validateNumber) },      -- key: category or protocol ID, value: shaper,bytes_quota,secs_quota

-- ALERTS (see alert_utils.lua)
   ["op_"]                     = { validateAlertDescriptor,   validateOperator },    -- key: an alert descriptor, value: alert operator
   ["value_"]                  = { validateAlertDescriptor,   validateAlertValue },  -- key: an alert descriptor, value: alert value
   ["slack_ch_"]               = { validateNumber, validateSingleWord },             -- slack channel name
   ["enabled_"]                = { validateAlertDescriptor,   validateAlertValue },  -- key: a check module key, value: alert value

-- Protocol to categories match
   ["proto_"]                  = { validateProtocolIdOrName, validateCategory },

--
   ["static_route_address_"]        = { validateStaticRouteName, validateIPV4 },
   ["static_route_netmask_"]        = { validateStaticRouteName, validateIPV4 },
   ["static_route_via_"]            = { validateStaticRouteName, validateIPV4 },
   ["static_route_is_local_"]       = { validateStaticRouteName, validateBool },

-- Gateways
   ["gateway_address_"]        = { validateGatewayName, validateIPV4 },
   ["gateway_ping_"]           = { validateGatewayName, validateIPV4 },
   ["gw_rtt_"]                 = { validateGatewayName, validateNumber },
   ["gw_id_"]                  = { validateNumber, validateGatewayName },
   ["pol_id_"]                 = { validateNumber, validateRoutingPolicyName },
   ["routing_"]                = { validateRoutingPolicyGateway, validateEmptyOr(validateNumber) }, -- a routing policy

-- Network Configuration
   ["iface_mode_"]             = { validateNetworkInterface, validateInterfaceConfMode },
   ["iface_ip_"]               = { validateNetworkInterface, validateIPV4 },
   ["iface_on_"]               = { validateNetworkInterface, validateBool },
   ["iface_gw_"]               = { validateNetworkInterface, validateIPV4 },
   ["iface_netmask_"]          = { validateNetworkInterface, validateIPV4 },
   ["iface_primary_dns_"]      = { validateNetworkInterface, validateIPV4 },
   ["iface_secondary_dns_"]    = { validateNetworkInterface, validateIPV4 },
   ["iface_nat_"]              = { validateNetworkInterface, validateBool },
   ["iface_id_"]               = { validateNumber, validateNetworkInterface },
   ["iface_up_"]               = { validateNumber, validateNumber },
   ["iface_down_"]             = { validateNumber, validateNumber },

   -- paramsPairsDecode: NOTE NOTE NOTE the "val_" value must explicitly be checked by the end application
   ["key_"]                    = { validateNumber,   validateUnchecked },      -- key: an index, value: the pair key
   ["val_"]                    = { validateNumber,   validateUnchecked },      -- key: an index, value: the pair value

   -- server side Datatables
   ["columns_"]                = { validateNumber, validateBool },
   ["search_"]                 = { validateNumber, validateSingleWord },
   ["order_"]                  = { validateNumber, validateSingleWord },
}

-- #################################################################

local function validateParameter(k, v)
   if(known_parameters[k] == nil) then
      -- Attempt at recursively validate tables
      if(type(v) == "table") then
	 for table_key, table_value in pairs(v) do
	    local success, message, purified = validateParameter(table_key, table_value)

	    -- Stop, if any of the table value fails the validation against
	    -- the expected table key
	    if not success then
	       return success, message, nil
	    end
	 end

	 -- Success, all the table keys have been validated successfully
         return true, "OK", v
      else
	 error("[LINT] Validation error: Unknown key "..k.." [value: "..v.."]: missing validation perhaps?\n")
	 return false, nil
      end
   else
      local ret
      local f = known_parameters[k]

      if(type(f) == "function") then
	 -- We apply the default parameter cleanup
	 v = ntop.httpPurifyParam(tostring(v))
	 ret = known_parameters[k](v)
      else
	 -- We apply the custom cleanup
	 v = known_parameters[k][1](v)
	 ret = known_parameters[k][2](v)
      end

      if ret then
         return true, "OK", v
      else
	 -- io.write(debug.traceback())
         return false, "Validation error", nil
      end
   end
end

local function validateSpecialParameter(param, value)
   -- These parameters are made up of one string prefix plus a string suffix
   for k, v in pairs(special_parameters) do
      if starts(param, k) and not known_parameters[param] --[[ make sure this is not a known, non-special param --]] then
	 local suffix = split(param, k)[2]
	 value = ntop.httpPurifyParam(value)

	 if not v[1](suffix) then
	    return false, "Special Validation, parameter key", nil
	 elseif not v[2](value) then
	    return false, "Special Validation, parameter value", nil
	 else
	    return true, "OK", value
	 end
      end
   end

   return false
end

-- ##############################################

function http_lint.validationError(t, param, value, message)
   -- TODO graceful exit
   local s_id
   if t == _GET then
      s_id = "_GET"
   else
      s_id = "_POST"
   end

   -- Remove the param which failed the validation
   t[param] = nil

   -- Must use urlencode to print these values or an attacker could perform XSS.
   -- Indeed, the web page returned by mongoose will show the error below and
   -- one could place something like '><script>alert(1)</script> in the value
   -- to close the html and execute a script

   -- Print of errors has been disabled to avoid logs to be flooded. Lint validation must be handled
   -- as part of HTTP responses, not printed in ntopng logs

   --error("[LINT] " .. s_id .. "[\"" .. urlencode(param) .. "\"] = \"" .. urlencode(value or 'nil') .. "\" parameter error: " .. message.."")
end

-- #################################################################

local function lintParams()
   local plugins_utils = require("plugins_utils")
   local params_to_validate = { _GET, _POST }
   local id, _, k, v

   -- VALIDATION SETTINGS
   local enableValidation    = true                --[[ To enable validation ]]
   local relaxGetValidation  = true                --[[ To consider empty fields as valid in _GET parameters ]]
   local relaxPostValidation = false               --[[ To consider empty fields as valid in _POST parameters ]]
   local debug = false                             --[[ To enable validation debug messages ]]

   -- Extend the parameters with validators from the plugins
   local additional_params = plugins_utils.extendLintParams(http_lint, known_parameters)

   for _,id in pairs(params_to_validate) do
      for k, v in pairs(id) do
         if(debug) then io.write("[LINT] Validating ["..k.."]["..v.."]\n") end

         if enableValidation then
            if ((v == "") and
                (((id == _GET) and relaxGetValidation) or
                 ((id == _POST) and relaxPostValidation))) then
               if(debug) then io.write("[LINT] Parameter "..k.." is empty but we are in relax mode, so it can pass\n") end
            else
               local success, message, purified = validateSpecialParameter(k, v)

	       if success then
		  id[k] = purified
	       else
                  if message ~= nil then
		     -- tprint("k: "..k.. " v: "..v.. " success: "..tostring(success).. " message: "..message)
                     http_lint.validationError(id, k, v, message)
                  else
                     success, message, purified = validateParameter(k, v)

		     if success then
			id[k] = purified
		     else
                        if message ~= nil then
                           http_lint.validationError(id, k, v, message)
                        else
                           -- Here we have an unhandled parameter
                           http_lint.validationError(id, k, v, "Missing validation")
                        end
                     end
                  end
               end
            end
         end
      end
   end
end

-- #################################################################

--
-- In case of forms submitted as "application/x-www-form-urlencoded" the received JSON is
-- stored in _POST["payload"] unverified. The function below, parses JSON and puts it
-- in the corresponding _GET/_POST parameters
-- See also https://github.com/ntop/ntopng/issues/4113
--
local function parsePOSTpayload()
   if((_POST ~= nil) and (_POST["payload"] ~= nil)) then
      local info, pos, err = json.decode(_POST["payload"], 1, nil)

      if(info ~= nil) then
	 for k,v in pairs(info) do
	    _GET[k] = v -- TODO: remove as soon as REST API is clean (https://github.com/ntop/ntopng/issues/4113)
	    _POST[k] = v
	 end
      end
   end
end

-- #################################################################

local function clearNotAllowedParams()
   if ntop.isnEdge() then
      -- Captive portal urls that can be clobbered with unrecognized
      -- and unvalid params as devices could have http requests open that are redirected
      -- to the captive portal.
      -- This function removes all the params except a minimum allowed set.
      local not_allowed_uris = {"/lua/info_portal.lua", "/lua/captive_portal.lua"}
      -- the referer must go through or the captive portal won't be able to do
      -- a proper redirect
      local allowed_params = {referer = 1,}

      if (table.len(_GET) > 0 or table.len(_POST) > 0) and _SERVER["URI"] then
	 for _, uri in pairs(not_allowed_uris) do
	    if string.ends(uri, _SERVER["URI"]) then
	       local param_tables = {_GET or {}, _POST or {}}

	       for _, param_table in pairs(param_tables) do
		  for param_key, param_value in pairs(param_table) do
		     if not allowed_params[param_key] then
			param_table[param_key] = nil
		     end
		  end
	       end

	       break
	    end
	 end
      end
   end
end

-- #################################################################

if(pragma_once) then
   if(ignore_post_payload_parse == nil) then
    parsePOSTpayload()
   end

   clearNotAllowedParams()
   lintParams()
   pragma_once = 0
end

return http_lint
