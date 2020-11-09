--
-- (C) 2019-20 - ntop.org
--
--

-- Place here the checks for parameters used by this plugins
-- In essence it extends (and references) checks present in
-- scripts/lua/modules/http_lint.lua
--

local script = {}

-- ##############################################

-- @brief Called by the main http_lint module to load additional parameters.
-- @params http_lint a reference to the scripts/lua/modules/http_lint.lua module
-- @return a (possibly empty) table with parameter_name -> validator mappings
function script.getAdditionalParameters(http_lint)
   return {
      ["syslog_alert_format"] = http_lint.validateEmptyOr(http_lint.validateSyslogFormat),
      ["syslog_protocol"]  = http_lint.validateEmptyOr(http_lint.validateChoiceInline({"tcp", "udp", ""})),
      ["syslog_host"]  = http_lint.validateEmptyOr(http_lint.validateHost),
      ["syslog_port"]  = http_lint.validateEmptyOr(http_lint.validatePort),
   }
end

-- ##############################################

return(script)
