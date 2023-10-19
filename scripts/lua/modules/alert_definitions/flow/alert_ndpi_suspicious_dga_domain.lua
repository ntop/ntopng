--
-- (C) 2019-22 - ntop.org
--

-- ##############################################

local flow_alert_keys = require "flow_alert_keys"
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"

-- ##############################################

local alert_ndpi_suspicious_dga_domain = classes.class(alert)

-- ##############################################

alert_ndpi_suspicious_dga_domain.meta = {
   alert_key  = flow_alert_keys.flow_alert_ndpi_suspicious_dga_domain,
   i18n_title = "alerts_dashboard.ndpi_suspicious_dga_domain_title",
   icon = "fas fa-fw fa-exclamation",

   -- A compromised host can do DGA domain requests. A compromised host can be:
   --  1. 'victim' as it is compromised
   --  2. 'attacker' as it can do malicious activities due to the fact that it has been compromised
   -- Since 'attacker' implies 'victim' in this case, the alert is assumed to have the 'attacker'.
   -- The DNS server is not assumed to be the victim as it justs serves the request.
   has_attacker = true,
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @return A table with the alert built
function alert_ndpi_suspicious_dga_domain:init()
   -- Call the parent constructor
   self.super:init()
end

-- #######################################################

function alert_ndpi_suspicious_dga_domain.format(ifid, alert, alert_type_params)
   local domain = alert_type_params.dga_domain
   local href = ''
   local info = ''

   if not isEmptyString(domain) then
    -- URL check
    local url = alert_type_params.dga_domain
    if string.find(url, 'https') then
      url = url:gsub('://', '')
      url = url:gsub('https', '')
    end

    local proto = string.lower(interface.getnDPIProtoName(tonumber(alert["l7_master_proto"])))
    proto = ternary(((proto) and (proto == 'http')), 'http', 'https')
    href = format_external_link(url, url, false, proto)
   end

   return i18n("alert_messages.suspicious_dga_domain", {
	   domain = domain,
      href = href,
      info = info,
   })
end

-- #######################################################

return alert_ndpi_suspicious_dga_domain
