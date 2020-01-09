--
-- (C) 2017-20 - ntop.org
--

local json = require "dkjson"

local telemetry_utils = {}

-- local TELEMETRY_URL = "http://192.168.2.131:8000/phptest.php"
-- local TELEMETRY_URL = "http://192.168.2.131:8000"
local TELEMETRY_URL = "https://telemetry.ntop.org/crash.php"
local TELEMETRY_TIMEOUT = 3
local TELEMETRY_ENABLED_KEY = "ntopng.prefs.send_telemetry_data"
local TELEMETRY_RECORDS_SENT = "ntopng.cache.telemetry_data_sent"
local TELEMETRY_MAX_NUM_RECORDS = 5

function telemetry_utils.telemetry_enabled()
   local tm = ntop.getPref(TELEMETRY_ENABLED_KEY)

   return tm == "1"
end

function telemetry_utils.telemetry_disabled()
   local tm = ntop.getPref(TELEMETRY_ENABLED_KEY)

   return tm == "0"
end

function telemetry_utils.notify(obj)
   if telemetry_utils.telemetry_enabled() then
      local mail = ntop.getPref("ntopng.prefs.telemetry_email")

      if isEmptyString(mail) then
	 mail = nil
      end

      local msg = {data = obj, mail = mail, timestamp = os.time()}
      local encoded_msg = json.encode(msg)

      local res = ntop.httpPost(TELEMETRY_URL, encoded_msg, nil, nil, TELEMETRY_TIMEOUT, true)

      if res and res["RESPONSE_CODE"] == 200 then
	 ntop.rpushCache(TELEMETRY_RECORDS_SENT, encoded_msg, TELEMETRY_MAX_NUM_RECORDS)
      end
   end
end

local function dismiss_notice()
   local dism = ntop.getPref(TELEMETRY_ENABLED_KEY)

   return not isAdministrator() or dism ~= ""
end

function telemetry_utils.notice_msg()
   print(i18n("about.telemetry_data_opt_out_msg", {url=ntop.getHttpPrefix() .. "/lua/admin/prefs.lua?tab=telemetry", tel_url=ntop.getHttpPrefix().."/lua/telemetry.lua", ntop_org="https://www.ntop.org/"}))
end

function telemetry_utils.show_notice()
   if not dismiss_notice() and (not _SERVER or not _SERVER["URI"]:match("/lua/admin/prefs.lua")) then
      print('<br><div id="telemetry-data" class="alert alert-info" role="alert"><i class="fas fa-info-circle"></i> ')
      print[[<button type="button" class="close" data-dismiss="alert" aria-label="Close"><span aria-hidden="true">&times;</span></button>]]

      telemetry_utils.notice_msg()

      print('</div>')
   end
end

function telemetry_utils.print_overview()
   local info = ntop.getInfo()

   print("<table class=\"table table-bordered table-striped\">\n")

   print[[<tr><th>]] print(i18n("telemetry_page.send_telemetry_data")) print [[</th><td>
]]

   if telemetry_utils.telemetry_enabled() then
      print('<span class="badge badge-success">'..i18n('prefs.telemetry_contribute')..'</span>')
   elseif telemetry_utils.telemetry_disabled() then
      print('<span class="badge badge-secondary">'..i18n('prefs.telemetry_do_not_contribute')..'</span>')
   else -- no preference expressed
      print('<i>'..i18n('telemetry_page.telemetry_data_no_consent')..'</i>')
   end

   if isAdministrator() then
      print[[ (]] print(i18n("telemetry_page.telemetry_data_change_preference", {url = ntop.getHttpPrefix().."/lua/admin/prefs.lua?tab=telemetry"})) print[[)]]
   end

   print[[ </td></tr>
]]

   print[[<tr><th>]] print(i18n("telemetry_page.telemetry_data")) print [[</th><td>
<b>]] print(i18n("telemetry_page.crash_report")) print[[</b>. ]] print(i18n("telemetry_page.crash_report_descr", {product=ntop.getInfo()["product"]})) print [[<br><code>{"entity_type":1,"type":20,"when":1558634220,"entity_value":"ntopng","message":"Started after anomalous termination (<a href=\"https://www.ntop.org/support/need-help-2/need-help/\">bug report</a>) ]] print(info.product) print[[ v.]] print(info.version) print[[ (]] print(info.OS) print[[[pid: 28775][options: --interface \"tcp://*:1234c\" --interface \"eno1\" --interface \"view:tcp://*:1234c,eno1\" --local-networks \"192.168.2.0/24\" --disable-login \"1\" ]","severity":2}</code>
</td></tr>
]]

   local transmitted_data = ntop.lrangeCache(TELEMETRY_RECORDS_SENT, 0, -1) or {}

   if table.len(transmitted_data) > 0 then
      print[[<tr><th>]] print(i18n("telemetry_page.last_data_sent")) print[[</th><td><code>]]

      for i, msg in ipairs(transmitted_data) do
	 if msg then
	    print(noHtml(msg).."<br>")
	 end
      end

      print[[</code></td><tr>]]
   end

   print("</table>")
end

return telemetry_utils
