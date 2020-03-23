--
-- (C) 2013-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/pro/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/pro/?.lua;" .. package.path
package.path = dirs.installdir .. "/pro/scripts/callbacks/?.lua;" .. package.path

require "lua_utils"
local template = require "template_utils"
local os_utils = require "os_utils"
local page_utils = require("page_utils")

sendHTTPContentTypeHeader('text/html', nil, nil, getBothViewFlag())

page_utils.set_active_menu_entry(page_utils.menu_entries.profiles)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

local ntop_info = ntop.getInfo()
local max_profiles_num = ntop_info["constants.max_num_profiles"]

print [[
<script>

var MAX_PROFILES_NUM = ]] print(max_profiles_num.."") print[[;

function submitSettings(profile_settings) {
   // reset ays so that we can submit a custom form
   var form = $("#profilesForm");
   aysResetForm(form);

   // now create a custom form with appropriate parameters and submit it
   var params = paramsPairsEncode(profile_settings);
   params.edit_profiles = "";
   params.csrf = "]] print(ntop.getRandomCSRFValue()) print[[";
   paramsToForm('<form method="post"></form>', params).appendTo('body').submit();
}

function checkProfilesForm(ev) {
   var form = $("#profilesForm");

   var profile_settings = {};
   var now_exit = false;

   $('input', form).each(function() {
      var name = $(this). attr("name");
      var parts = name.split("profile_");

      if (parts.length == 2) {
         var profile_name = parts[1];
         var filter_name = "filter_" + profile_name;
         var filter_value = $("input[name='"+filter_name+"']", form).val();

         // Take the profile name directly from the input, since it may be different
         var profile_name = $(this).val();
         profile_settings[profile_name] = filter_value;
      }
   });

   if (now_exit)
      return false;

   for (var filter in filters_to_validate) {
      var status = filters_to_validate[filter];

      // do not allow submit if there are fields checks in progress
      if (status.timer || status.ajax_obj) {
         status.submit_remind = true;
         return false;
      }
   }

   if (! ev.isDefaultPrevented())   // isDefaultPrevented is true when the form is invalid
      submitSettings(profile_settings);
   return false;
}

</script>
<hr>
]]

hashname = "ntopng.prefs.profiles"

function forEachRedisCounter(ifid, callback)
   local key = "ntopng.profiles_counters.ifid_"..ifid
   local counters = ntop.getHashKeysCache(key)
   if counters ~= nil then
      for profile,_ in pairs(counters) do
         if not callback(profile) then
            ntop.delHashCache(key, profile)
         end
      end
   end
end

function forEachRRDCounter(ifid, callback)
   local base = os_utils.fixPath(dirs.workingdir .. "/" .. ifid .. '/profilestats')

   for profile, _ in pairs(ntop.readdir(base)) do
      if not callback(profile) then
         ntop.rmdir(base.."/"..profile)
      end
   end
end

   if _POST["delete_profile"] ~= nil then
      -- delete a single profile
      ntop.delHashCache(hashname, _POST["delete_profile"])

      -- delete the associated counter
      forEachRedisCounter(ifId, function(profile)
         if profile == _POST["delete_profile"] then
            -- remove
            return false
         else
            return true
         end
      end)

      -- delete the associated RRDs
      forEachRRDCounter(ifId, function(profile)
         if profile == _POST["delete_profile"] then
            -- remove
            return false
         else
            return true
         end
      end)

      ntop.reloadProfiles()
   elseif _POST["edit_profiles"] ~= nil then
      local config = paramsPairsDecode(_POST, true)

      -- delete unused counters
      forEachRedisCounter(ifId, function(profile)
         if config[profile] == nil then
            -- remove
            return false
         else
            return true
         end
      end)

      -- delete unused RRDs
      forEachRRDCounter(ifId, function(profile)
         if config[profile] == nil then
            -- remove
            return false
         else
            return true
         end
      end)

      -- Delete existing profiles
      ntop.delCache(hashname)

      local num = 0

      for profile, filter in pairs(config) do
         if http_lint.validateTrafficProfile(profile) and ntop.checkProfileSyntax(filter) then
            ntop.setHashCache(hashname, profile, filter)
            num = num + 1
         end

         if num >= max_profiles_num then
            break
         end
      end

      ntop.reloadProfiles()
   end

print(
  template.gen("modal_confirm_dialog.html", {
    dialog={
      id      = "delete_profile_dialog",
      action  = "deleteProfile(delete_profile_name)",
      title   = i18n("traffic_profiles.delete_profile"),
      message = i18n("traffic_profiles.confirm_delete_profile") .. ' "<span id=\"delete_profile_dialog_profile\"></span>" ',
      confirm = i18n("delete"),
    }
  })
)

print [[
<form id="profilesForm" method="post">
   <div id="table-profiles"></div>
   <div class="text-right"><button id="profilesSubmit" class="btn btn-primary" style="margin-right:1em;" type="submit" disabled="disabled">]] print(i18n("save_settings")) print[[</button></div>
</form>
<form id="deleteProfileForm" method="post">
   <input type="hidden" name="csrf" value="]] print(ntop.getRandomCSRFValue()) print[["/>
   <input type="hidden" name="delete_profile" />
</form>
<br>

]] print(i18n("traffic_profiles.simple_filter_examples")) print[[:
<ul>
   <li>]] print(i18n("traffic_profiles.http_traffic")) print[[: <i>tcp and port 80</i></li>
   <li>]] print(i18n("traffic_profiles.host_traffic")) print[[: <i>host 192.168.1.2</i></li>
   <li>]] print(i18n("traffic_profiles.facebook_traffic")) print[[: <i>l7proto 119</i> ]] print(i18n("traffic_profiles.see_ndpi_protos", {option="<code>ntopng --print-ndpi-protocols</code>"})) print[[</li>
</ul>
]] print(i18n("traffic_profiles.advanced_filter_examples")) print[[:
<ul>
   <li>]] print(i18n("traffic_profiles.traffic_between")) print[[: <i>ip host 192.168.1.1 and 192.168.1.2</i></li>
   <li>]] print(i18n("traffic_profiles.traffic_from_to")) print[[: <i>ip src 192.168.1.1 and dst 192.168.1.2</i></li>
   <li>]] print(i18n("traffic_profiles.destination_network")) print[[: <i>ip dest net 192.168.1.0/24</i></li>
   <li>]] print(i18n("traffic_profiles.host_http_https")) print[[: <i>ip host 192.168.1.1 and tcp port (80 or 443)</i></li>
   <li>]] print(i18n("traffic_profiles.source_ethernet")) print[[: <i>ether src host 00:11:22:33:44:55</i></li>
</ul>
]] print(i18n("traffic_profiles.note")) print[[:
<ul>
<li>]] print(i18n("traffic_profiles.note_0")) print[[.
<li>]] print(i18n("traffic_profiles.note_1")) print[[.
]]

if not ntop.isEnterprise() then
   print[[<li>]] print(i18n("traffic_profiles.max_profiles_num", {maxnum=max_profiles_num})) print[[.]]
end

print[[
</ul>

<script>
   function deleteProfile(profile_name) {
      // perform the submit
      var delete_form = $("#deleteProfileForm");
      $("input[name='delete_profile']", delete_form).val(profile_name);
      delete_form.submit();
   }

   function makeProfilesRowEditable(tr_obj) {
      var profile_name = $("td:nth-child(1)", $(tr_obj));
      var profile_filter = $("td:nth-child(2)", $(tr_obj));

      // TODO proper escape sequences to support more UTF-8 characters
      var profile_name_input = $('<input class="form-control input-sm" data-unique="unique" autocomplete="off" spellcheck="false" placeholder="]] print(i18n("traffic_profiles.enter_profile_name")) print[["  pattern="^[_a-zA-Z0-9 ]*$" required/>').attr("name", "profile_" + profile_name.html()).val(profile_name.html());
      var profile_filter_input = $('<input class="form-control input-sm" data-bpf="bpf" autocomplete="off" spellcheck="false" placeholder="]] print(i18n("traffic_profiles.enter_profile_filter")) print[[" required/>').attr("name", "filter_" + profile_name.html()).val(profile_filter.html());

      var profile_validation_div = $('<div class="form-group has-feedback" style="margin-bottom:0;"></div>');
      profile_validation_div.html(profile_name_input);
      $('<div class="help-block with-errors" style="margin-bottom:0;"></div>').appendTo(profile_validation_div);

      var filter_validation_div = $('<div class="form-group has-feedback" style="margin-bottom:0;"></div>');
      filter_validation_div.html(profile_filter_input);
      $('<div class="help-block with-errors" style="margin-bottom:0;"></div>').appendTo(filter_validation_div);

      profile_name.html(profile_validation_div);
      profile_filter.html(filter_validation_div);
   }

   function addNewProfile() {
      if (datatableIsEmpty("#table-profiles"))
         datatableRemoveEmptyRow("#table-profiles");
      var tr = $('<tr id="new_added_row"><td></td><td></td><td class="text-center" style="vertical-align: middle;"></td></tr>');
      makeProfilesRowEditable(tr);

      $("#table-profiles table").append(tr);
      datatableAddDeleteButtonCallback.bind(tr)(3, "datatableUndoAddRow('#new_added_row', ']] print(i18n("traffic_profiles.no_profiles")) print[[', '#addNewProfileBtn')", "]] print(i18n("undo")) print[[");

      $("#addNewProfileBtn").attr('disabled', true);
      aysRecheckForm('#profilesForm');
   }

   $("#table-profiles").datatable({
      url: "]]
   print (ntop.getHttpPrefix())
   print [[/lua/get_traffic_profiles.lua",
      showPagination: false,
      perPage: MAX_PROFILES_NUM,
      hidePerPage: true,
      hideDetails: true,
      title: "]] print(i18n("traffic_profiles.edit_traffic_profiles")) print[[",
      forceTable: true,
      buttons: [
         '<a id="addNewProfileBtn" onclick="addNewProfile()" role="button" class="add-on btn" data-toggle="modal"><i class="fas fa-plus" aria-hidden="true"></i></a>'
      ], columns: [
         {
            title: "]] print(i18n("traffic_profiles.profile_name")) print[[",
            field: "column_profile",
            css: {
               width: "18%",
            }
         }, {
            title: "]] print(i18n("traffic_profiles.traffic_filter_bpf")) print[[",
            field: "column_filter",
         }, {
            title: "]] print(i18n("actions")) print[[",
            css: {
               width: "15%",
               textAlign: "center",
               verticalAlign: "middle"
            }
         }
      ], tableCallback: function() {
         /* Only enable add button if we are in the last page */
         var lastpage = $("#dt-bottom-details .pagination li:nth-last-child(3)", $("#table-profiles"));
         var num_profiles = $("#table-profiles tr").length;
         $("#addNewProfileBtn").attr("disabled", (((lastpage.length == 1) && (lastpage.hasClass("active") == false)) || (num_profiles > MAX_PROFILES_NUM)));

         if(datatableIsEmpty("#table-profiles")) {
            datatableAddEmptyRow("#table-profiles", "]] print(i18n("traffic_profiles.no_profiles")) print[[");
         } else {
            datatableForEachRow("#table-profiles", function() {
               makeProfilesRowEditable(this);
               var value = $("td:nth-child(1) input", $(this)).val();
               datatableAddDeleteButtonCallback.bind(this)(3, "delete_profile_name ='" + value + "'; $('#delete_profile_dialog_profile').html('" + value + "'); $('#delete_profile_dialog').modal('show');", "]] print(i18n('delete')) print[[");
            });

            aysResetForm('#profilesForm');
         }

         $("#profilesForm")
            .validator(validatorOptions)
            .on('submit', checkProfilesForm);
      }
   });

   aysHandleForm("#profilesForm", {
      handle_datatable: true,
      ays_options: {addRemoveFieldsMarksDirty: true}
   });

   /*
    * This function performs form validation asyncronously.
    * It requires bootstrap 1000hz validation plugin.
    *
    * The input field should have a name, which is used as an identifier.
    *
    * The timeout parameter is used to limit the number of requests sent. It will
    * delay the ajax request for the specified time.
    */
   var filters_to_validate = {};
   function bpfValidator(filter_field) {
      var filter = filter_field.val();
      var key = filter_field.attr("name");

      // configuration
      var debug = false;
      var timeout = 250;

      if(debug) console.log("Filter: " + filter);

      if (! filters_to_validate[key])
         filters_to_validate[key] = {ajax_obj:null, valid:true, timer:null, submit_remind:false, last_val:null};
      var status = filters_to_validate[key];

      var sendAjax = function () {
         status.timer = null;

         var finally_check = function (valid) {
            status.ajax_obj = null;

            // Update validation status
            status.valid = valid;
            status.last_val = filter;
            $("#profilesForm").validator('validate');

            if(status.submit_remind) {
               status.submit_remind = false;
               $("#profilesForm").submit();
            }
         }

         if (status.last_val !== filter) {
            if (status.ajax_obj)
               status.ajax_obj.abort();

            status.ajax_obj = $.ajax({
               type: "GET",
               url: ']] print(ntop.getHttpPrefix().."/lua/pro/check_profile.lua") print [[',
               data: {
                  query: filter,
               }, error: function() {
                  if(debug) console.log("\tAn error occurred");

                  finally_check(status.valid);
               }, success: function(data) {
                  var valid = data.response ? true : false;
                  if (valid) {
                     if(debug) console.log("\tFilter valid");
                  } else {
                     if(debug) console.log("\tFilter NOT valid");
                  }

                  finally_check(valid);
               }
            });
         } else {
            // possibly process the reminder
            finally_check(status.valid);
         }
      }

      if (status.last_val === filter) {
         if(debug) console.log("\tIgnoring...");
      } else {
         if (status.timer) {
            clearTimeout(status.timer);
            status.submit_remind = false;
         }
         status.timer = setTimeout(sendAjax, timeout);
         if(debug) console.log("\tScheduling in the future...");
      }

      return status.valid;
   }

   var validatorOptions = {
      disable: true, /* This does not troubles ays since it uses css classes instead of "disabled" attribute */
      custom: {
         bpf: bpfValidator,
         unique: makeUniqueValidator(function(field) {
            return $('input[name^="profile_"]', $("#profilesForm"));
         }),
      }, errors: {
         bpf: "]] print(i18n("traffic_profiles.invalid_bpf")) print[[.",
         unique: "]] print(i18n("traffic_profiles.duplicate_profile")) print[[.",
      }
   }

   /* Retrigger the validation every second to clear outdated errors */
    setInterval(function() {
      $("form:data(bs.validator)").each(function(){
        $(this).data("bs.validator").validate();
      });
    }, 1000);
</script>
]]

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
