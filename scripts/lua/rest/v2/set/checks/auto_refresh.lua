--
-- (C) 2019-22 - ntop.org
--
dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local rest_utils = require("rest_utils")

-- ################################################

if(_POST["ifid"] == nil or _POST["alert_page_refresh_rate_enabled"] == nil) then
  rest_utils.answer(rest_utils.consts.err.invalid_args)
  return
end

local auto_refresh_enabled = _POST["alert_page_refresh_rate_enabled"] or ""

if auto_refresh_enabled == "true" then
  auto_refresh_enabled = "1"
else
  auto_refresh_enabled = "0"
end

local refresh_rate = ntop.getPref("ntopng.prefs.alert_page_refresh_rate")

ntop.setPref("ntopng.prefs.alert_page_refresh_rate_enabled", auto_refresh_enabled)

-- Alert page refresh rate
if ((refresh_rate) and not isEmptyString(refresh_rate)) and (auto_refresh_enabled) then
  -- The js function that refresh periodically the page needs the time in microseconds
  refresh_rate = tonumber(refresh_rate) * 1000
  -- Refresh rate equals to 0, remove refresh rate
  if refresh_rate == 0 then
      refresh_rate = nil
  end
else
  refresh_rate = nil
end

-- No refresh rate found
if not refresh_rate then
  refresh_rate = 0
end
 
rsp = { 
  refresh_rate = refresh_rate, 
  auto_refresh_enabled = auto_refresh_enabled, 
}

rest_utils.answer(rest_utils.consts.success.ok, rsp)
