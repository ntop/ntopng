--
-- (C) 2014-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path

local json = require "dkjson"
local rest_utils = require "rest_utils"
local checks = require "checks"
local alert_utils = require "alert_utils"
local alert_consts = require "alert_consts"
local auth = require "auth"
local alert_exclusions = require "alert_exclusions"

local alert_rest_utils = {}

-- #################################

-- @brief exclude an alert using the parameters that the POST has
function _exclude_flow_alert(additional_filters, delete_alerts, subdir)
   local success = false
   local script_key = _POST["script_key"]
   local alert_key = tonumber(_POST["alert_key"])
   local alert_addr = _POST["alert_addr"]

   if alert_key and alert_addr then
      success = true
   end

   if success then
      if alert_addr then
	 if alert_addr == "" then
	    -- Disable for "All", so toggle the user script to OFF
	    checks.toggleScript(script_key, subdir, false --[[ turn it off --]])
	 elseif subdir == "flow" then
	    -- Disable for a specific address, need to just turn off the alert
	    alert_exclusions.disable_flow_alert(alert_addr, alert_key)
	 elseif subdir == "host" then
	    -- Disable for a specific address, need to just turn off the alert
	    alert_exclusions.disable_host_alert(alert_addr, alert_key)
	 end

	 -- Check to see if old alerts need to be deleted as well
	 if delete_alerts == "true" then
	    if subdir == "flow" then
	       alert_utils.deleteFlowAlertsMatching(alert_addr, alert_key)
	    elseif subdir == "host" then
	       alert_utils.deleteHostAlertsMatching(alert_addr, alert_key)
	    end
	 end
      end
   end

   if success then
      rc = rest_utils.consts.success.ok
      rest_utils.answer(rc)
   else
      rc = rest_utils.consts.err.invalid_args
      rest_utils.answer(rc)
   end
end

-- #################################

-- @brief exclude an alert using the parameters that the POST has
function alert_rest_utils.exclude_alert()
   -- POST parameters
   local additional_filters = _POST["filters"]
   local subdir = _POST["subdir"]
   local delete_alerts = _POST["delete_alerts"] or "false"
   
   -- Parameters used by the various functions
   local success = ""
   local new_filter  = {}
   local update_err = ""

   -- Parameters used for the rest answer
   local rc = ""
   local res = ""

   if subdir == "flow" or subdir == "host" then
      return _exclude_flow_alert(additional_filters, delete_alerts, subdir)
   end
   
   rest_utils.answer(rest_utils.consts.err.invalid_args)
end

-- #################################

function alert_rest_utils.get_alert_exclusions(subdir, host)
   if not auth.has_capability(auth.capabilities.checks) then
      -- Not allowed to see alert exclusions
      rest_utils.answer(rest_utils.consts.err.not_granted)
      return
   end

   local alerts_get_excluded_hosts

   if subdir == "host" then
      alerts_get_excluded_hosts = alert_exclusions.host_alerts_get_excluded_hosts
   elseif subdir == "flow" then
      alerts_get_excluded_hosts = alert_exclusions.flow_alerts_get_excluded_hosts
   else
      -- Alert exclusions not supported for this subdir
      rest_utils.answer(rest_utils.consts.err.invalid_args)
      return
   end

   local script_type = checks.getScriptType(subdir)
   local config_set = checks.getConfigset()

   -- ################################################

   local scripts = checks.load(getSystemInterfaceId(), script_type, subdir, {return_all = true})
   local result = {}

   for script_name, script in pairs(scripts.modules) do
      if script.gui and script.gui.i18n_title and script.gui.i18n_description and script.alert_id then
	 local excluded_hosts = alerts_get_excluded_hosts(script.alert_id)

	 for excluded_host, _ in pairs(excluded_hosts) do
	    -- Return all excluded hosts if no specific `host` has been requested, or only stuff
	    -- regarding `host`
	    if isEmptyString(host) or excluded_host == host then
	       -- Prepare a name and a label
	       local excluded_host_info = hostkey2hostinfo(excluded_host)
	       local excluded_host_name = hostinfo2label(excluded_host_info)
	       local excluded_host_href =  hostinfo2detailshref(excluded_host_info, {}, excluded_host, excluded_host, true)

	       -- If necessary, add an hyperlink to show alert exclusions only filtered for `host`
	       if isEmptyString(host) then
		  excluded_host_href = string.format('%s <a href="%s/lua/admin/edit_alert_exclusions.lua?subdir=%s&host=%s"><i class="fas fa-bell-slash"></i></a>', excluded_host_href, ntop.getHttpPrefix(), subdir, excluded_host)
	       end

	       result[#result + 1] = {
		  key = script_name,
		  alert_key = script.alert_id,
		  title = i18n(script.gui.i18n_title) or script.gui.i18n_title,
		  excluded_host = excluded_host,
		  excluded_host_label = excluded_host_href,
		  excluded_host_name = excluded_host_name ~= excluded_host and excluded_host_name or '',
		  category_title = i18n(script.category.i18n_title),
		  category_icon = script.category.icon,
		  edit_url = checks.getScriptEditorUrl(script),
	       }
	    end
	 end
      end
   end

   rest_utils.answer(rest_utils.consts.success.ok, result)
end

-- #################################

function alert_rest_utils.delete_alert_exclusions(subdir, host_ip, alert_key)
   if not auth.has_capability(auth.capabilities.checks) then
      -- Not allowed to see alert exclusions
      rest_utils.answer(rest_utils.consts.err.not_granted)
      return
   end

   local alerts_get_excluded_hosts

   if (subdir ~= "host" and subdir ~= "flow") or isEmptyString(host_ip) or isEmptyString(alert_key) then
      rest_utils.answer(rest_utils.consts.err.invalid_args)
      return
   elseif subdir == "flow" then
      alert_exclusions.enable_flow_alert(host_ip, alert_key)
   else
      alert_exclusions.enable_host_alert(host_ip, alert_key)
   end

   rest_utils.answer(rest_utils.consts.success.ok)
end

-- #################################

function alert_rest_utils.delete_all_alert_exclusions(subdir, host)
   if not auth.has_capability(auth.capabilities.checks) then
      -- Not allowed to see alert exclusions
      rest_utils.answer(rest_utils.consts.err.not_granted)
      return
   end

   if subdir == "host" then
      alert_exclusions.enable_all_host_alerts(host)
   elseif subdir == "flow" then
      alert_exclusions.enable_all_flow_alerts(host)
   else
      -- Alert exclusions not supported for this subdir
      rest_utils.answer(rest_utils.consts.err.invalid_args)
      return
   end

   rest_utils.answer(rest_utils.consts.success.ok)
end

-- #################################

return alert_rest_utils
