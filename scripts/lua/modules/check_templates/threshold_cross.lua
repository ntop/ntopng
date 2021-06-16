--
-- (C) 2019-21 - ntop.org
--

-- ##############################################

package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/check_templates/?.lua;" .. package.path

-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local check_template = require "check_template"
local http_lint = require "http_lint"
local format_utils = require "format_utils"

-- ##############################################

local threshold_cross = classes.class(check_template)

-- ##############################################

threshold_cross.meta = {
}

-- ##############################################

-- @brief Prepare an instance of the template
-- @return A table with the template built
function threshold_cross:init(check)
   -- Call the parent constructor
   self.super:init(check)
end

-- #######################################################

function threshold_cross:parseConfig(conf)
  if(not http_lint.validateOperator(conf.operator)) then
    return false, "bad operator"
  end

  if(tonumber(conf.threshold) == nil) then
    return false, "bad threshold"
  end

  return true, conf
end

-- #######################################################

function threshold_cross:describeConfig(hooks_conf)
  local alert_consts = require("alert_consts")
  local granularities_order = {"min", "5mins", "hour", "day"}
  local items = {}

  -- E.g. "> 50 Sec (Minute), > 300 Sec (Hourly)"
  for _, granularity in ipairs(granularities_order) do
    local hook = hooks_conf[granularity]
    local granularity = alert_consts.alerts_granularities[granularity]

    if granularity and hook and hook.script_conf.threshold then
      local unit = ""
      local op = ternary(hook.script_conf.operator == "gt", ">", "<")

      if(self._check.gui and self._check.gui.i18n_field_unit) then
        unit = " " .. i18n(self._check.gui.i18n_field_unit)
      end

      -- Note: it would be desirable to export a 'self._check.unit' field
      -- instead of 'self._check.gui.i18n_field_unit' to properly format
      -- numeri values as with bytes below.
      if self._check.gui.i18n_field_unit == 'field_units.bytes' then
        local formatted_threshold = format_utils.bytesToSize(hook.script_conf.threshold)
        items[#items + 1] = string.format("%s  (%s)", op,
          formatted_threshold, i18n(granularity.i18n_title) or granularity.i18n_title)
      else
        items[#items + 1] = string.format("%s %s%s (%s)", op,
          hook.script_conf.threshold, unit, i18n(granularity.i18n_title) or granularity.i18n_title)
      end
    end
  end

  return table.concat(items, ", ")
end

-- #######################################################

return threshold_cross
