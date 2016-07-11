--
-- (C) 2013-16 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
-- io.write ("Session:".._SESSION["session"].."\n")
require "lua_utils"

sendHTTPHeader('text/html; charset=iso-8859-1')

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")

print [[
  <div class="container-narrow">



 <style type="text/css">
      body {
        padding-top: 40px;
        padding-bottom: 40px;
        background-color: #f5f5f5;
   }

      .please-wait {
        max-width: 350px;
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
The database schema is being updated to include the most recent changes:<br>please wait, this is normal. You will be redirected as soon as the changes take effect.
  </div>
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
