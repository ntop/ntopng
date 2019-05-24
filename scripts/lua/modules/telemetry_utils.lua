--
-- (C) 2017-19 - ntop.org
--

local json = require "dkjson"

local telemetry_utils = {}

-- local TELEMETRY_URL = "http://192.168.2.131:8000/phptest.php"
-- local TELEMETRY_URL = "http://192.168.2.131:8000"
local TELEMETRY_URL = "https://telemetry.ntop.org/crash.php"
local TELEMETRY_TIMEOUT = 3
local TELEMETRY_NOTICE_KEY = "ntopng.prefs.disable_telemetry_data_message"
local TELEMETRY_ENABLED_KEY = "ntopng.prefs.send_telemetry_data"

local function telemetry_enabled()
   local tm = ntop.getPref(TELEMETRY_ENABLED_KEY)

   return false -- TEMPORARILY DISABLED to ask explicit consent
   -- return tm == "" or tm == "1"
end

function telemetry_utils.notify(obj)
   if telemetry_enabled() then
      local res = ntop.httpPost(TELEMETRY_URL, json.encode(obj), nil, nil, TELEMETRY_TIMEOUT, true)
   end
end

local function dismiss_notice()
   local dism = ntop.getPref(TELEMETRY_NOTICE_KEY)

   return true -- TEMPORARILY HIDDEN to ask explicit consent
   -- return dism == "1"
end


function telemetry_utils.show_notice()
   if not dismiss_notice() then
      print('<br><div id="telemetry-data" class="alert alert-info" role="alert"><i class="fa fa-info-circle"></i> ')
      print[[<button type="button" class="close" data-dismiss="alert" aria-label="Close"><span aria-hidden="true">&times;</span></button>]]
      print(i18n("prefs.toggle_send_telemetry_data_description", {url="https://www.ntop.org/ntopng/ntopng-and-time-series-from-rrd-to-influxdb-new-charts-with-time-shift/", product = ntop.getInfo().product, url="https://www.ntop.org/"}).." "..i18n("about.telemetry_data_opt_out_msg", {url=ntop.getHttpPrefix() .. "/lua/admin/prefs.lua?tab=misc"}))
      print('</div>')

      print[[
<script type="text/javascript">

$("#telemetry-data").on("close.bs.alert", function() {
  $.ajax({
      type: 'POST',
        url: ']]
      print (ntop.getHttpPrefix())
      print [[/lua/update_prefs.lua',
        data: {
	  csrf: ']] print(ntop.getRandomCSRFValue()) print[[',
	  action: 'disable-telemetry-data',
	}
    });
});
</script>
]]
   end
end

return telemetry_utils
