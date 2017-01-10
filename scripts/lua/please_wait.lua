--
-- (C) 2013-17 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
-- io.write ("Session:".._SESSION["session"].."\n")
require "lua_utils"

sendHTTPHeader('text/html; charset=iso-8859-1')

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")

local prefs = ntop.getPrefs()

local dbname = (prefs.mysql_dbname or '')

-- read the db activities to notify the user about what is going on in the database
local res = interface.execSQLQuery("show full processlist", false, false)

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
]]

print[[
Waiting for database <b>]] print(dbname) print[[</b> to become operational. You will be redirected as soon as the database is ready.
  </div>
<br>
Operations currently performed on the database are the following:
<br></br>
  <div><small>]]


if res == nil then res = {} end
if #res >= 1 then
   print[[
<table class="table  table-striped" width=100% height=100%>
  <thead>
    <tr>
      <th>Database</th><th>State</th><th>Command</th><th>Id</th><th>User</th><th>Time</th><th>Info</th><th>Host</th>
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
]]
end

print[[</small></div>
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
