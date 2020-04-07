--
-- (C) 2018 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
local remote_assistance = require("remote_assistance")
local template = require "template_utils"
local page_utils = require("page_utils")

if((not isAdministrator()) or (not remote_assistance.isAvailable())) then
  return
end

local info = ntop.getInfo()
local tab = _GET["tab"] or "config"

if not table.empty(_POST) then
  if tab == "config" then
    local enabled = (_POST["toggle_remote_assistance"] == "1") and (_POST["accept_tos"] == "1")

    if enabled then
      local admin_access = _POST["allow_admin_access"]
      local community = _POST["assistance_community"]
      local key = _POST["assistance_key"]

      if admin_access == "1" then
        remote_assistance.enableTempAdminAccess(key)
      else
        remote_assistance.disableTempAdminAccess()
      end

      ntop.setPref("ntopng.prefs.remote_assistance.community", community)
      ntop.setPref("ntopng.prefs.remote_assistance.key", key)
      ntop.setPref("ntopng.prefs.remote_assistance.admin_access", admin_access or "0")
      remote_assistance.createConfig(community, key)
      remote_assistance.enableAndStart()
    else
      remote_assistance.disableTempAdminAccess()
      remote_assistance.disableAndStop()
    end
  else -- tab == "status"
    if _POST["action"] == "restart" then
      remote_assistance.restart()
    end
  end
elseif _GET["action"] == "get_script" then
  sendHTTPContentTypeHeader('text/x-shellscript', 'attachment; filename="n2n_assistance.sh"')
  print("#!/bin/sh\n")
  print(remote_assistance.getConnectionCommand())
  return
end

sendHTTPContentTypeHeader('text/html')


page_utils.set_active_menu_entry(page_utils.menu_entries.remote_assistance)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

print(template.gen("modal_confirm_dialog.html", {
  dialog = {
    id      = "tos-accept-modal",
    title   = i18n("remote_assistance.enable_remote_assistance"),
    custom_alert_class = "alert alert-danger",
    message = i18n("remote_assistance.tos_notice", {button=i18n("remote_assistance.accept_and_enable")}),
    confirm = i18n("remote_assistance.accept_and_enable"),
    action  = "acceptTos()",
 }
}))

page_utils.print_page_title(i18n("remote_assistance.product_remote_assistance", {product=info.product}))

local assistace_checked = ""
local admin_checked = ""
local assist_enabled = remote_assistance.isEnabled()
local admin_enabled = false

if assist_enabled then
  assistace_checked = "checked"

  if ntop.getPref("ntopng.prefs.remote_assistance.admin_access") == "1" then
    admin_checked = "checked"
    admin_enabled = true
  end
end

if ntop.isGuiAccessRestricted() and admin_enabled then
  printMessageBanners({{
    type = "warning",
    text = i18n("remote_assistance.gui_access_restricted_info", {
      url_acl = ntop.getHttpPrefix() .. "/lua/admin/prefs.lua?tab=misc",
      cli_options = "-w -W",
    }),
  }})
  print("<br>")
end

print [[
<ul id="n2n-nav" class="nav nav-tabs" role="tablist">]]

print('<li class="nav-item '.. ternary(tab == "config", "active", "") ..'"><a class="nav-link '.. ternary(tab == "config", "active", "") ..'" href="?tab=config"><i class="fas fa-cog"></i> '.. i18n("traffic_recording.settings") .. "</a>")

if assist_enabled then
   print('<li class="nav-item '.. ternary(tab == "status", "active", "") ..'"><a class="nav-link '.. ternary(tab == "status", "active", "") ..'" href="?tab=status">'.. i18n("status") .. "</a>")
end

print[[</ul>]]

print('<div class="tab-content">')

if tab == "config" then
print[[
  <form id="remote_assistance_form" method="post">
    <input id="csrf" name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />

    <div id="assistance-config" class="tab-pane in active">
      <table class="table table-striped table-bordered">
        <tr>
          <th width=22%>]] print(i18n("remote_assistance.enable_remote_assistance")) print [[</th>
          <td>
            <div class="form-group">
              <div class="custom-control custom-switch">
                <input class="custom-control-input" id="toggle_remote_assistance" name="toggle_remote_assistance" type="checkbox" value="1" ]] print(assistace_checked) print [[/>
                <label for="toggle_remote_assistance" class="custom-control-label"></label>
              </div>
            </div>
            <div style="margin-left: 0.5em; display:inline">]] print(remote_assistance.statusLabel()) print[[</div>
             <br><small>]]

             if(remote_assistance.getStatus() == "active") then
               print(i18n("remote_assistance.remote_ip_msg", {product=info.product, ip = remote_assistance.getIpAddress()})) 
             end

           print [[</small>

        
          </td>
        </tr>]]

if assist_enabled then
  print[[
        <tr>
          <th>]] print(i18n("remote_assistance.connection_script")) print[[</th>
          <td><a href="?action=get_script"><i class="fas fa-download fa-lg"></i> <i class="fas fa-terminal fa-lg"></i></a><br>
          <small>]] print(i18n("remote_assistance.connection_script_descr")) print[[</small>
          </td>
        </tr>]]
end

print[[
        <input type="hidden" id="assistance_community" class="form-control" data-ays-ignore="true" name="assistance_community" value="]] print(ntop.getPref("ntopng.prefs.remote_assistance.community")) print[[" readonly />
        <input type="hidden" id="assistance_key" class="form-control" data-ays-ignore="true" name="assistance_key" value="]] print(ntop.getPref("ntopng.prefs.remote_assistance.key")) print[[" readonly />

        <tr>
          <th>]] print(i18n("remote_assistance.admin_access")) print[[</th>
          <td>
          <div class="custom-control custom-switch">
          <input class="custom-control-input" id="check-allow_admin_access" name="allow_admin_access" type="checkbox" value="1" ]] print(admin_checked) print [[/>
          <label class="custom-control-label" for="check-allow_admin_access"></label>
          </div>
          <br>
          <small>]] print(i18n("remote_assistance.admin_access_descr", {product = info.product}))

if((admin_checked == "checked") and (remote_assistance.getStatus() == "active")) then
print(i18n("remote_assistance.admin_access_key_descr", {pwd = ntop.getPref("ntopng.prefs.remote_assistance.key")}))
end


          print [[
          </td>
        </tr>
      </table>
    </div>

    <input type="hidden" name="accept_tos" data-ays-ignore="true" value="0" class="hidden" />

    <button class="btn btn-primary" style="float:right; margin-right:1em;" disabled="disabled" type="submit">]] print(i18n("save_settings")) print[[</button>
  </form>
  <br><br>

  <span>]]
print(i18n("notes"))
print[[
    <ul>
      <li>]] print(i18n("remote_assistance.remember_disable")) print[[</li>
      <li>]] print(i18n("remote_assistance.will_create_virtual_network") .. " " .. i18n("remote_assistance.ask_admin")) print[[</li>
      <li>]] print(i18n("remote_assistance.check_out_the_preferences", {url=ntop.getHttpPrefix() .. "/lua/admin/prefs.lua?tab=remote_assistance"})) print[[</li>
    </ul>
  </span>

  <script>
    aysHandleForm("#remote_assistance_form");

    /* Returns random [0-9a-zA-Z] ~10 chars */
    function genRandomString() {
      var uppercase_prob = 0.4;

      /* Note: this returns [0-9a-z] chars */
      var s = Math.random().toString(36).slice(2);
      var res = [];

      for(var i=0; i<s.length; i++)
        res.push((Math.random() <= uppercase_prob) ? s[i].toUpperCase() : s[i]);

      // 10 digits
      return res.join("");
    }

    function generate_credentials() {
      var today = Math.floor($.now() / 1000 / 86400); // days since first epoch

      $("#assistance_community").val(genRandomString());
      $("#assistance_key").val(genRandomString());
    }

    $("#toggle_remote_assistance").change(function() {
      var is_enabled = $("#toggle_remote_assistance").is(":checked");

      if(is_enabled)
        generate_credentials();
    });

    $("#remote_assistance_form").on("submit", function() {
      var is_enabled = $("#toggle_remote_assistance").is(":checked");
      var tos_accepted = ($("input[name='accept_tos']").val() === "1");

      if(is_enabled && !tos_accepted) {
        $("#tos-accept-modal").modal("show");
        return false;
      }
    });

    function acceptTos() {
      $("input[name='accept_tos']").val("1").attr("checked", "checked");
      $("#remote_assistance_form").submit();
    }
  </script>
]]
else -- tab == "status"
  print("<table class=\"table table-bordered table-striped\">\n")
  print("<tr><th width='15%' nowrap>"..i18n("interface").."</th><td>".. remote_assistance.getInterfaceName() .."</td></tr>\n")
  print("<tr><th width='15%' nowrap>"..i18n("ip_address").."</th><td>".. remote_assistance.getIpAddress() .."</td></tr>\n")
  print("<tr><th width='15%' nowrap>"..i18n("prefs.n2n_supernode_title").."</th><td>".. remote_assistance.getSupernode() .." <a href=\"".. ntop.getHttpPrefix() .."/lua/admin/prefs.lua?tab=remote_assistance\"><i class=\"fas fa-cog fa-lg\"></i></a></td></tr>\n")
  print("<tr><th nowrap>"..i18n("status").."</th><td>") print(noHtml(remote_assistance.statusLabel()) .. ". ")
  print[[<form style="display:inline" id="restart-service-form" method="post">
    <input type="hidden" name="csrf" value="]] print(ntop.getRandomCSRFValue()) print[[" />
    <input type="hidden" name="action" value="restart" />
</form>]]
  print(" <small><a href='#' onclick='$(\"#restart-service-form\").submit(); return false;' title='' data-original-title='"..i18n("traffic_recording.restart_service").."'></small>&nbsp;<i class='fas fa-repeat fa-lg' aria-hidden='true' data-original-title='' title=''></i></a>")
  print("</td></tr>")

  print("<tr><th nowrap>"..i18n("about.last_log").."</th><td><code>")
  local log = remote_assistance.log(32)

  local logs = split(log, "\n")
  for i = 1, #logs do
    local row = split(logs[i], "]: ")
    if row[2] ~= nil then
      print(row[2].."<br>\n")
    else
      print(row[1].."<br>\n")
    end
  end

  print("</code></td></tr>")
  print("</table>\n")
end

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
