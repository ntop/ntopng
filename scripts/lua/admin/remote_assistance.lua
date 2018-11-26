--
-- (C) 2018 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
local remote_assistance = require("remote_assistance")
local template = require "template_utils"

if((not isAdministrator()) or (not remote_assistance.isAvailable())) then
  return
end

local info = ntop.getInfo()

if not table.empty(_POST) then
  local enabled = (_POST["toggle_remote_assistance"] == "1") and (_POST["accept_tos"] == "1")

  if enabled then
    local admin_access = _POST["allow_admin_access"]
    local community = _POST["assistance_key"]
    local key = community

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
end

sendHTTPContentTypeHeader('text/html')
ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

print(template.gen("modal_confirm_dialog.html", {
  dialog = {
    id      = "tos-accept-modal",
    title   = i18n("remote_assistance.enable_remove_assistance"),
    custom_alert_class = "alert alert-danger",
    message = i18n("remote_assistance.tos_notice", {button=i18n("remote_assistance.accept_and_enable")}),
    confirm = i18n("remote_assistance.accept_and_enable"),
    action  = "acceptTos()",
 }
}))

print("<hr>")
print("<h2>") print(i18n("remote_assistance.product_remote_assistance", {product=info.product})) print("</h2>")
print("<br>")

local assistace_checked = ""
local admin_checked = ""
local assist_enabled = remote_assistance.isEnabled()

if assist_enabled then
  assistace_checked = "checked"

  if ntop.getPref("ntopng.prefs.remote_assistance.admin_access") == "1" then
    admin_checked = "checked"
  end
end

print [[
  <form id="remote_assistance_form" class="form-inline" method="post">
    <input id="csrf" name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />

    <div id="assistance-config" class="tab-pane in active">
      <table class="table table-striped table-bordered">
        <tr>
          <th width=22%>]] print(i18n("remote_assistance.enable_remote_assistance")) print [[</th>
          <td>
            <div class="form-group">
              <input id="toggle_remote_assistance" name="toggle_remote_assistance" type="checkbox" value="1" ]] print(assistace_checked) print [[/>
            </div>
            <div style="margin-left: 0.5em; display:inline">]] print(remote_assistance.statusLabel()) print[[</div>
          </td>
        </tr>
        <tr>
          <th>]] print(i18n("key")) print[[</th>
          <td><input id="assistance_key" class="form-control" data-ays-ignore="true" name="assistance_key" value="]] print(ntop.getPref("ntopng.prefs.remote_assistance.key")) print[[" readonly /><br>
          <small>]] print(i18n("remote_assistance.key_descr")) print[[</small>
          </td>
        </tr>
        <tr>
          <th>]] print(i18n("remote_assistance.admin_access")) print[[</th>
          <td><input name="allow_admin_access" type="checkbox" value="1" ]] print(admin_checked) print [[/><br>
          <small>]] print(i18n("remote_assistance.admin_access_descr", {product = info.product})) print[[</small>
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
      <li>]] print(i18n("remote_assistance.note_sensitive")) print[[</li>
      <li>]] print(i18n("remote_assistance.remember_disable")) print[[</li>
      <li>]] print(i18n("remote_assistance.will_create_virtual_network") .. " " .. i18n("remote_assistance.ask_admin")) print[[</li>]]
   print[[
    </ul>
  </span>

  <script>
    aysHandleForm("#remote_assistance_form");

    function genNumericId() {
      // 10 digits
      return Math.random().toString().substring(2,12);
    }

    function generate_credentials() {
      var today = Math.floor($.now() / 1000 / 86400); // days since first epoch

      $("#assistance_key").val(genNumericId());
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

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
