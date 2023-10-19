--
-- (C) 2013-23 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
-- io.write ("Session:".._SESSION["session"].."\n")
require "lua_utils"

sendHTTPContentTypeHeader('text/html')

local info = ntop.getInfo()

local referer = _GET["referer"]
local reason = _GET["reason"]
local favicon_path
local page_title = i18n("welcome_to", { product=info.product })
local http_prefix = ntop.getHttpPrefix()

print[[
  <!DOCTYPE html>
  <html>
  <head>
   <title>]] print(page_title) print[[</title>
   <meta name="viewport" content="width=device-width, initial-scale=1">
   <meta http-equiv="X-UA-Compatible" content="IE=edge">

   <link href="]] print(http_prefix) print[[/dist/third-party.css" rel="stylesheet">
   <link href="]] print(http_prefix) print[[/dist/white-mode.css" rel="stylesheet">
   <link href="]] print(http_prefix) print[[/dist/ntopng.css" rel="stylesheet">
]]

  if (ntop.isPro() or ntop.isnEdge()) and ntop.exists(dirs.installdir .. "/httpdocs/img/custom_favicon.ico") then
    favicon_path = ntop.getHttpPrefix().."/img/custom_favicon.ico"
  end
  if (favicon_path ~= nil) then
    print[[<link href="]] print(favicon_path) print[[" rel="icon">]]
  else
    print[[<link href="]] print(http_prefix) print[[/favicon.ico" rel="icon">]]
  end

print[[
  <script type="text/javascript" src="]] print(http_prefix) print[[/dist/third-party.js"></script>
  <script type="text/javascript" src="]] print(http_prefix) print[[/dist/login.js"></script>
  <style>
    html, body {
      height: 100vh;
    }

    body {
      background-color: #f5f5f5;
      display: flex;
      align-items: center;
      padding-top: 40px;
      padding-bottom: 40px;
      background-color: #f5f5f5;
      padding-top: 0 !important;
      text-align: center;
    }

    .form-signin {
      width: 100%;
      max-width: 450px;
      padding: 15px;
      margin: auto;
      z-index: 1000;
    }
  </style>    
</head>
<body class="body">
  <div id="particles-js"></div>
  <main class='form-signin'>
	<form id="form_add_user" role="form" data-bs-toggle="validator" onsubmit="return makeUsernameLowercase();" action="]] print(ntop.getHttpPrefix()) print[[/authorize.html" method="POST" accept-charset="UTF-8">

    <input type="hidden" class="form-control" name="user">
    <input type="hidden" class="form-control" name="referer" value="]] print(referer or "") print [[">

    <h1 class="h3 mb-3 fw-normal">]] print(i18n("login.welcome_to", {product=info["product"]})) print[[</h1>
    <div class="form-group mb-3 has-feedback mb-3">
      <div class='form-floating'>
        <input placeholder='admin' id='input-username' type="text" class="form-control" name="_username" required]] print(ternary(ntop.isLoginBlacklisted(), " disabled", "")) print[[>
        <label for="input-username">]] print(i18n("login.username_ph")) print[[
      </div>
      <div class='form-floating'>
        <input placeholder='admin' id='input-password' type="password" class="form-control" name="password" pattern="]] print(getPasswordInputPattern()) print[[" required]] print(ternary(ntop.isLoginBlacklisted(), " disabled", "")) print[[>
        <label for="input-password">]] print(i18n("login.password_ph")) print[[
      </div>
]]

if ntop.isLoginBlacklisted() then
  print[[
      <span class="text-danger">]] print(i18n("login.blacklisted_ip_notice")) print[[</span>
]]
end

if not isEmptyString(reason) then
  print[[
      <span class="text-danger">]] print(i18n("login."..reason)) print[[</span>
]]
end

print[[
    </div> <!-- Close .form-group mb-3 -->
    <button class="w-100 btn btn-lg btn-primary" type="submit">]] print(i18n("login.login")) print[[</button>
  	<div class="row">

      <div >&nbsp;</div>
      <div class="col-lg-12"><small><center> <i class="fas fa-lock"></i> <A target="_blank" HREF="https://www.ntop.org/guides/ntopng/faq.html#cannot-login-into-the-gui">]]
      print(i18n("login.unable_to_login"))
   print [[</A> </center></small></div>
      <div >&nbsp;</div>
      <div class="col-lg-12">
]]

      if not info.oem then

if(info["product"] == "ntopng") then
        print[[<small>
      <p>]] print(i18n("login.links", {product=info["product"], donation_url="http://shop.ntop.org"})) print[[
          </p>

      <p class='text-muted'>]] print(info["copyright"]) print [[<br> ]] print(i18n("login.license", {product=info["product"], license="GPLv3", license_url="http://www.gnu.org/copyleft/gpl.html"})) print[[</p>
        </small>]]
else
   print("<small>"..info["copyright"].."</small>")
end

end
      print[[<div id="unsupported-browser" style="display:none">
        <b>]] print(i18n("traffic_profiles.note")) print[[</b>: <small>]] print(i18n("login.unsupported_browser")) print[[</small>
       </div>
      </div>
    </div>
  </form>
</main>
</body>

<script>
$("input:text:visible:first").focus();

function makeUsernameLowercase() {
  var target = $('#form_add_user input[name="user"]');
  var origin = $('#form_add_user input[name="_username"]');
  target.val(origin.val().toLowerCase());
  origin.removeAttr("name");
  return true;
}

$('form_add_user').on('submit', function() {
  let tmp =  makeUsernameLowercase()
})

function isIeBrowser() {
  var ua = window.navigator.userAgent;
  var msie = ua.indexOf("MSIE ");

  if (msie > 0 || navigator.userAgent.match(/Trident.*rv\:11\./))
    return true;

  return false;
}

if(isIeBrowser()) $("#unsupported-browser").show();

particlesJS("particles-js", {"particles":{"number":{"value":20,"density":{"enable":true,"value_area":500}},"color":{"value":"#ccc"},"shape":{"type":"circle","stroke":{"width":0,"color":"#000000"},"polygon":{"nb_sides":5},"image":{"src":"img/github.svg","width":100,"height":100}},"opacity":{"value":1,"random":false,"anim":{"enable":false,"speed":1,"opacity_min":0.1,"sync":false}},"size":{"value":3,"random":true,"anim":{"enable":false,"speed":40,"size_min":0.1,"sync":false}},"line_linked":{"enable":true,"distance":150,"color":"#6e6e6e","opacity":0.4,"width":1},"move":{"enable":true,"speed":1,"direction":"none","random":false,"straight":false,"out_mode":"out","bounce":false,"attract":{"enable":false,"rotateX":600,"rotateY":1200}}},"interactivity":{"detect_on":"canvas","events":{"onhover":{"enable":false,"mode":"repulse"},"onclick":{"enable":false,"mode":"push"},"resize":true},"modes":{"grab":{"distance":400,"line_linked":{"opacity":1}},"bubble":{"distance":400,"size":40,"duration":2,"opacity":8,"speed":3},"repulse":{"distance":200,"duration":0.4},"push":{"particles_nb":4},"remove":{"particles_nb":2}}},"retina_detect":true});
/* This is done in order to be sure that jQuery is correctly loaded */
</script>
</html>
]]
