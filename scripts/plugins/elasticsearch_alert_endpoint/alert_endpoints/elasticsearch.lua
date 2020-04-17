--
-- (C) 2020 - ntop.org
--

require "lua_utils"
local json = require "dkjson"
local alert_consts = require "alert_consts"
local flow_consts = require "flow_consts"
local alert_utils = require "alert_utils"

-- ##############################################

local elasticsearch = {}

-- ##############################################

elasticsearch.EXPORT_FREQUENCY = 60
elasticsearch.API_VERSION = "0.1"
elasticsearch.prio = 400

-- ##############################################

local ITERATION_TIMEOUT = 15
local REQUEST_TIMEOUT = 3
-- Maximum number of alerts to pack into a single _bulk POST
local MAX_ALERTS_PER_REQUEST = 256
-- Index name pattern for Elasticsearch. The leading ! means UTC for the date
local INDEX_NAME = "!alerts-ntopng-%Y.%m.%d"
-- Cache keys used to know when certain periodic checks need to be performed.
local CACHE_PREFIX = "ntopng.cache.elasticsearch_alerts."
-- Key to periodically check for the elasticsearch version
local PERIODIC_CHECK_ELASTICSEARCH_VERSION_KEY = string.format("%s.version", CACHE_PREFIX)

-- ##############################################

-- @brief Check and cache Elasticsearch version. Minimum required version is 7.
-- @return true if the version is greater than or equal to 7, false othervise. Version is in the second returned value
local function check_version()
   local version = ntop.getCache(PERIODIC_CHECK_ELASTICSEARCH_VERSION_KEY)
   version = tonumber(version)

   if version then
      -- A cached value exists, nothing to do...
   else
      local conn = ntop.elasticsearchConnection()
      local res = ntop.httpGet(conn.host, conn.user, conn.password, REQUEST_TIMEOUT, true)

      if res and res["RESPONSE_CODE"] == 200 then
	 local res_json = json.decode(res["CONTENT"])
	 -- Response is a JSON with the follofing keys
	 -- ...
	 -- "version" : {
	 --        "number" : "7.6.2",
	 -- ...
	 -- So let's parse the version number
	 if res_json and res_json["version"] and res_json["version"]["number"] then
	    local version_string = res_json["version"]["number"]
	    local major, minor, patch = version_string:match("(%d+)%.(%d+)%.(%d+)")

	    version = tonumber(major)
	 end
      else
	 traceError(TRACE_ERROR, TRACE_CONSOLE, "Unable to fetch Elasticsearch version")
	 if res then
	    traceError(TRACE_ERROR, TRACE_CONSOLE, res and res["CONTENT"] or "")
	 end
      end

      -- Set the key and keep it for an hour...
      -- In case there has been an error when getting the version, we set it at zero
      ntop.setCache(PERIODIC_CHECK_ELASTICSEARCH_VERSION_KEY, tostring(version or 0), 3600)
   end

   -- Support version at least 7
   return version and version >= 7, version or 0
end

-- ##############################################

function elasticsearch.onLoad()
   -- Clear all periodic checks keys
   ntop.delCache(PERIODIC_CHECK_ELASTICSEARCH_VERSION_KEY)
end

-- ##############################################

function elasticsearch.isAvailable()
   -- Currently, this endpoint is available only
   -- if ntopng has been started with -F "es;"
   local conn = ntop.elasticsearchConnection()

   return conn
end

-- ##############################################

-- @brief Prepare a lua table with keys in common between flow and non-flow alerts
-- @param alert_json A lua table created by decoding an ntopng JSON-alert
-- @return The prepared lua table
local function formatCommonPart(alert_json)
   local res = {}

   -- Add a @timestamp which is compatible and friendly with elasticsearch
   --
   -- The `!` at the beginning of the date string format: this is to tell the time is UTC.
   -- Elasticsearch will adjust the UTC time according to the client time.
   --
   -- Alerts should always have an `alert_tstamp`, but in case they don't have it, `now` is chosen as @timestamp
   res["@timestamp"] = os.date("!%Y-%m-%dT%H:%M:%S.0Z", alert_json["alert_tstamp"] or now)

   res["alert_tstamp"] = alert_json["alert_tstamp"]
   res["alert_tstamp_end"] = alert_json["alert_tstamp_end"]
   res["alert_type"] = alert_consts.alertTypeRaw(alert_json["alert_type"])
   res["alert_subtype"] = alert_json["alert_subtype"]
   res["alert_severity"] = alert_consts.alertSeverityRaw(alert_json["alert_severity"])
   res["alert_entity"] = alert_consts.alertEntityRaw(alert_json["alert_entity"])
   res["alert_entity_val"] = alert_json["alert_entity_val"]
   res["alert_granularity"] = alert_consts.sec2granularity(alert_json["alert_granularity"])
   res["alert_json"] = alert_json["alert_json"]
   res["alert_msg"] = alert_utils.formatAlertNotification(alert_json, {nohtml = true,
								       show_severity = true,
								       show_entity = true})

   res["ifid"] = alert_json["ifid"]
   res["if_name"] = getInterfaceName(alert_json["ifid"])
   res["instance_name"] = ntop.getInstanceName()

   return res
end

-- ##############################################

-- @brief Prepare a lua table with flow alert data
-- @param alert_json A lua table created by decoding an ntopng JSON-alert
-- @return The prepared lua table
local function formatFlowAlert(alert_json)
   local res = formatCommonPart(alert_json)

   res["cli_addr"] = alert_json["cli_addr"]
   res["srv_addr"] = alert_json["srv_addr"]

   res["score"] = alert_json["score"]

   res["flow_status"] = flow_consts.getStatusType(alert_json["flow_status"])
   res["l7_proto"] = alert_json["proto.ndpi"]
   res["cli_port"] = alert_json["cli_port"]
   res["srv_port"] = alert_json["srv_port"]
   res["vlan_id"] = alert_json["vlan_id"]

   res["srv2cli_bytes"] = alert_json["srv2cli_bytes"]
   res["cli2srv_bytes"] = alert_json["cli2srv_bytes"]
   res["srv2cli_packets"] = alert_json["srv2cli_packets"]
   res["cli2srv_packets"] = alert_json["cli2srv_packets"]

   if not isEmptyString(alert_json["cli_asn"]) then res["cli_asn"] = alert_json["cli_asn"] end
   if not isEmptyString(alert_json["srv_asn"]) then res["srv_asn"] = alert_json["srv_asn"] end
   if not isEmptyString(alert_json["cli_country"]) then res["cli_country"] = alert_json["cli_country"] end
   if not isEmptyString(alert_json["srv_country"]) then res["srv_country"] = alert_json["srv_country"] end
   if not isEmptyString(alert_json["cli_os"]) then res["cli_os"] = alert_json["cli_os"] end
   if not isEmptyString(alert_json["srv_os"]) then res["srv_os"] = alert_json["srv_os"] end

   return res
end

-- ##############################################

-- @brief Prepare a lua table with non-flow alert data
-- @return The prepared lua table
local function formatAlert(alert_json)
   local res = formatCommonPart(alert_json)

   res["engaged"] = alert_json["action"] == "engage"

   return res
end

-- ##############################################

-- @brief Prepare a lua table with alert data to be sent to Elasticsearch
-- @param alert_json A lua table created by decoding an ntopng JSON-alert
-- @return The prepared lua table
local function format(alert_json)
   if alert_json["is_flow_alert"] then
      return formatFlowAlert(alert_json)
   else
      return formatAlert(alert_json)
   end
end

-- ##############################################

-- @brief Send alerts to Elasticsearch using the _bulk API
-- @return True if sending the alerts has succeded, false otherwise
local function sendMessage(alerts)
   local conn = ntop.elasticsearchConnection()
   local now = os.time()

   if isEmptyString(conn.url) then
      -- No url is known, cannot export
      return false
   end

   if not alerts or #alerts == 0 then
      -- Nothing to do
      return true
   end

   -- The header requested by _bulk API
   -- https://www.elastic.co/guide/en/elasticsearch/reference/current/docs-bulk.html
   local header = {
      index = {
	 _type = nil, -- Elasticsearch 7.0 complains with "Specifying types in bulk requests is deprecated" -- "_doc",
	 _index = os.date(INDEX_NAME, now)
      }
   }
   local header_json = json.encode(header)

   -- Build the payload
   local payload_table = {}
   for _, alert in ipairs(alerts) do
      local alert_json = json.decode(alert)

      if alert_json then
	 -- Each alert must have the header repeated
	 payload_table[#payload_table + 1] = header_json
	 payload_table[#payload_table + 1] = json.encode(format(alert_json))
      end
   end

   if #payload_table == 0 then
      -- Nothing to do
      return true
   end

   -- Elasticsearch _bulk API wants a newline-delimited JSON (NDJSON)
   -- Must also contains a newline at the end
   local payload = table.concat(payload_table, "\n").."\n"

   local rc = false
   local retry_attempts = 3
   while retry_attempts > 0 do
      if ntop.postHTTPJsonData(conn.user or '', conn.password or '', conn.url, payload, REQUEST_TIMEOUT) then
	 rc = true
	 break
      end
      retry_attempts = retry_attempts - 1
   end

   return rc
end

-- ##############################################

function elasticsearch.dequeueAlerts(queue)
   local start_time = os.time()
   local alerts = {}

   -- Read the version and make sure it is correct and supported
   local version_ok, version_number = check_version()
   if not version_ok then
      return {
	 success = false,
	 error_message = i18n("prefs.elasticsearch_unsupported_version", {version = version_number}),
      }
   end

   while true do
      local diff = os.time() - start_time

      if diff >= ITERATION_TIMEOUT then
	 break
      end

      local alerts = ntop.lrangeCache(queue, 0, MAX_ALERTS_PER_REQUEST - 1)

      if not alerts or #alerts == 0 then
	 break
      end

      if not sendMessage(alerts) then
	 return {
	    success = false,
	    error_message = i18n("prefs.elasticsearch_unable_to_send_alerts"),
	 }
      end

      -- Remove processed messages from the queue
      ntop.ltrimCache(queue, #alerts, -1)
   end

   return {success = true}
end

-- ##############################################

-- @brief Callback triggered when the user clicks test connection on the alert endpoint page
--        this function peforms a GET to the Elasticsearch host and make sure the connection is working
function elasticsearch.handlePost()
   local message_info, message_severity = '', ''
   local conn = ntop.elasticsearchConnection()

   if _POST["send_test_elasticsearch"] then
      -- GET the base host which returns version number
      -- Test connectivity
      local res = ntop.httpGet(conn.host, conn.user, conn.password, REQUEST_TIMEOUT, true)

      if res and res["RESPONSE_CODE"] == 200 then
	 -- Now that connectivity is ok, test the version as well
	 local version_ok, version_number = check_version()
	 if version_ok then
	    message_info = i18n("prefs.elasticsearch_sent_successfully")
	    message_severity = "alert-success"
	 else
	    message_info = i18n("prefs.elasticsearch_unsupported_version", {version = version_number})
	    message_severity = "alert-danger"
	 end
      else
	 message_info = i18n("prefs.elasticsearch_send_error", {
				code = res and res["RESPONSE_CODE"] or 0,
				resp = res and res["CONTENT"] or ""})
	 message_severity = "alert-danger"
      end
   end

   return message_info, message_severity
end

-- ##############################################

function elasticsearch.printPrefs(alert_endpoints, subpage_active, showElements)
   print('<thead class="thead-light"><tr><th colspan="2" class="info">'..i18n("prefs.elasticsearch_notification")..'</th></tr></thead>')

   local elementToSwitchElasticsearch = {"row_elasticsearch_notification_severity_preference", "elasticsearch_url", "elasticsearch_sharedsecret", "elasticsearch_test", "elasticsearch_username", "elasticsearch_password"}

   prefsToggleButton(subpage_active, {
			field = "toggle_elasticsearch_notification",
			pref = alert_endpoints.getAlertNotificationModuleEnableKey("elasticsearch", true),
			default = "0",
			disabled = showElements==false,
			to_switch = elementToSwitchElasticsearch,
   })


   local showElasticsearchNotificationPrefs = false
   if ntop.getPref(alert_endpoints.getAlertNotificationModuleEnableKey("elasticsearch")) == "1" then
      showElasticsearchNotificationPrefs = true
   else
      showElasticsearchNotificationPrefs = false
   end

   print('<tr id="elasticsearch_test" style="' .. ternary(showElasticsearchNotificationPrefs, "", "display:none;").. '"><td><button class="btn btn-secondary disable-on-dirty" type="button" onclick="sendTestElasticsearch();" style="width:230px; float:left;">'..i18n("prefs.send_test_elasticsearch")..'</button></td></tr>')

   print[[<script>
  function sendTestElasticsearch() {
    var params = {};

    params.send_test_elasticsearch = "";
    params.csrf = "]] print(ntop.getRandomCSRFValue()) print[[";

    var form = paramsToForm('<form method="post"></form>', params);
    form.appendTo('body').submit();
  }
</script>]]
end

-- ##############################################

return elasticsearch

