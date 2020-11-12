--
-- (C) 2019-20 - ntop.org
--

local status_keys = require "flow_keys"

local alert_consts = require("alert_consts")

-- #################################################################

local function formatBATFlow(info)
   local res = i18n("alerts_dashboard.suspicious_file_transfer")

   if info and info["protos.http.last_url"] then
      local type_icon = ''

      local extn = info["protos.http.last_url"]:sub(-4):lower()

      if extn == ".php" or extn == ".js" or extn == ".html" or extn == ".xml" or extn == ".cgi" then
	 type_icon = '<i class="fas fa-file-code"></i>'
      elseif extn == ".png" or extn == ".jpg" then
	 type_icon = '<i class="fas fa-file-image"></i>'
      end

      res = i18n("alerts_dashboard.suspicious_file_transfer_url",
		 {url = info["protos.http.last_url"],
		  type_icon = type_icon})
   end

   return res
end

-- #################################################################

return {
  status_key = status_keys.ntopng.status_suspicious_file_transfer,
  -- scripts/lua/modules/alert_keys.lua
  alert_type = alert_consts.alert_types.alert_suspicious_file_transfer,
  -- scripts/locales/en.lua
  i18n_title = "alerts_dashboard.suspicious_file_transfer",
  i18n_description = formatBATFlow,
}
