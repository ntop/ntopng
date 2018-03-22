--
-- (C) 2013-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
-- io.write ("Session:".._SESSION["session"].."\n")
require "lua_utils"

sendHTTPContentTypeHeader('text/html')

local prefs = ntop.getPrefs()

local dbname = (prefs.mysql_dbname or '')

-- read the db activities to notify the user about what is going on in the database
-- local res = interface.execSQLQuery("show full processlist", false, false) -- CAREFUL, this can introudce a deadlock

print [[
  <div class="container-narrow">



 <style type="text/css">
      body {
        padding-top: 40px;
        padding-bottom: 40px;
        background-color: #f5f5f5;
   }

      .please-wait {
        max-width: 600px;
        padding: 9px 29px 29px;
        margin: 0 auto 20px;
        background-color: #fff;
        border: 1px solid #e5e5e5;
        -webkit-border-radius: 5px;
           -moz-border-radius: 5px;
                border-radius: 5px;
          -webkit-box-shadow: 0 1px 2px rgba(0,0,0,.05);
       -moz-box-shadow: 0 1px 2px rgba(0,0,0,.05);
      box-shadow: 0 1px 2px rgba(0,0,0,.05);
   }
      .please-wait .please-wait-heading,

    </style>

<div class="container please-wait">
  <div style="text-align: center; vertical-align: middle">
]]

addLogoSvg()

print[[
  </div>
  <div>
<br>
]]

print(" "..i18n("please_wait_page.waiting_for_db_msg", {dbname=dbname}))
print[[
  </div>
<br>
  <div>]]

if res == nil then res = {} end
if #res >= 1 then
   print[[
<br>
]] print(i18n("please_wait_page.operations_on_database_msg")) print [[
<small>
<table class="table  table-striped" width=100% height=100%>
  <thead>
    <tr>
      <th>]] print(i18n("please_wait_page.database")) print[[</th><th>]] print(i18n("please_wait_page.state")) print[[</th><th>]] print(i18n("please_wait_page.command")) print[[</th><th>]] print(i18n("please_wait_page.id")) print[[</th><th>]] print(i18n("please_wait_page.user")) print[[</th><th>]] print(i18n("please_wait_page.time")) print[[</th><th>]] print(i18n("please_wait_page.info")) print[[</th><th>]] print(i18n("please_wait_page.host")) print[[</th>
    </tr>
  </thead>
  <tbody>
]]
   for i,p in ipairs(res) do
      print('<tr>')
      print('<td>'..(p["db"] or '')..'</td><td>'..(p["State"] or '')..'</td><td>'..(p["Command"] or '')..'</td><td>'..(p["Id"] or '')..'</td>')
      print('<td>'..(p["User"] or '')..'</td><td>'..secondsToTime(tonumber((p["Time"] or '')))..'</td>')
      print('<td title="'..(p["Info"] or '')..'">'..shortenString((p["Info"] or ''))..'</td><td>'..(p["Host"] or '')..'</td>')
      print('</tr>')
      local msg = ""
      for k, v in pairs(p) do
	 msg = msg..k..": "..v.." "
      end
   end

   print[[
  </tbody>
</table>
</small>
]]
end

print[[</div>
</div> <!-- /container -->

<script type="text/javascript">
var intervalID = setInterval(
  function() {
   window.location.replace("]] print(ntop.getHttpPrefix().._GET["referer"]) print[[");
  },
  5000);
</script>
</body>
</html>
]]
