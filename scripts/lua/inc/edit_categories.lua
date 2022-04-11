--
-- (C) 2022 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local template_utils = require "template_utils"
local ui_utils = require "ui_utils"

local category_filter = _GET["l7proto"] or 0

if not isAdministratorOrPrintErr() then
  return
end

-- category_warnings
local cat_name = interface.getnDPICategoryName(tonumber(category_filter))

local modal_edit_categories = template_utils.gen("modal_confirm_dialog_form.template", {
  dialog={
    id      = "edit-category-rules",
    title   = i18n("custom_categories.edit_custom_rules"),
    custom_alert_class = "",
    custom_dialog_class = "dialog-body-full-height",
    message = [[
      <p style='margin-bottom:5px;'>]] .. i18n("custom_categories.category_name") .. [[:</p>
      <input class="form-control" type="text" id="category-name" spellcheck="false" style='width:100%;'>
      <p style='margin-bottom:5px;'>]] .. i18n("custom_categories.the_following_is_a_list_of_hosts", {category='<i id="selected_category_name"></i>'}) .. [[:</p>
      <textarea class="form-control" id="category-hosts-list" spellcheck="false" style='width:100%; height:14em;'></textarea>
      ]].. ui_utils.render_notes({
        {content = i18n("custom_categories.each_host_separate_line")},
        {content = i18n("custom_categories.host_domain_or_cidr")},
        {content = i18n("custom_categories.domain_names_substrings", {s1="ntop.org", s2="mail.ntop.org", s3="ntop.org.example.com"})}
      }),
    confirm = i18n("save"),
    cancel = i18n("cancel"),
  }
})

template_utils.render("pages/components/edit-categories.template", {
  modals = {
    modal_edit_categories = modal_edit_categories,
  },
  cat_name = cat_name,
  csrf = ntop.getRandomCSRFValue(),
  category_filter = category_filter,
  http_prefix = ntop.getHttpPrefix(),
  ifid = interface.getId()
})




