--
-- (C) 2019-20 - ntop.org
--

-- This script defines additional parameters validators for use in the
-- GET/POST requests. In ntopng any GET/POST parameter must be validated
-- via a validation function. The validation function returns true if the
-- parameter is valid, false otherwise. In the latter case, the POST request
-- is aborted with an error.

local script = {}

-- ##############################################

local function validateMeasurement(p)
  local plugins_utils = require("plugins_utils")
  local am_utils = plugins_utils.loadModule("active_monitoring", "am_utils")

  if(am_utils) then
    local available_measurements = am_utils.getMeasurementsInfo()

    return(available_measurements[p] ~= nil)
  end

  return(false)
end

-- ##############################################

-- @brief Called by the main http_lint module to load additional parameters.
-- @params http_lint a reference to the scripts/lua/modules/http_lint.lua module
-- @return a (possibly empty) table with parameter_name -> validator mappings
function script.getAdditionalParameters(http_lint)
  return {
    -- The toggle_example_notification parameter will be validated using the
    -- 'validateBool' validator.
    ["am_host"]                = http_lint.validateSingleWord,
    ["old_am_host"]            = http_lint.validateSingleWord,
    ["threshold"]              = http_lint.validateEmptyOr(http_lint.validateNumber),
    ["measurement"]            = validateMeasurement,
    ["old_measurement"]        = validateMeasurement,
  }
end

-- ##############################################

return(script)
