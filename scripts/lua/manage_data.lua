--
-- (C) 2013-20 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local delete_data_utils = require "delete_data_utils"
local template_utils = require "template_utils"
local ui_utils = require "ui_utils"
local page_utils = require("page_utils")

local page = _GET["page"] or _POST["page"] or 'export'
local info = ntop.getInfo()

local delete_data_utils = require "delete_data_utils"

sendHTTPContentTypeHeader('text/html')

page_utils.set_active_menu_entry(page_utils.menu_entries.manage_data)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

if _POST and table.len(_POST) > 0 and isAdministrator() then

    if _POST["delete_active_if_data"] then

        -- Data for the active interface can't be hot-deleted.
        -- a restart of ntopng is required so we just mark the deletion.
        delete_data_utils.request_delete_active_interface_data(_POST["ifid"])

        print(
            '<div class="alert alert-success alert-dismissable"><a href="" class="close" data-dismiss="alert" aria-label="close">&times;</a>' ..
                i18n('delete_data.delete_active_interface_data_ok',
                     {ifname = ifname, product = ntop.getInfo().product}) ..
                '</div>')

    else -- we're deleting an host

        local host_info = url2hostinfo(_POST)
        local parts = split(host_info["host"], "/")
        local res

        if (#parts == 2) and (tonumber(parts[2]) ~= nil) then
            res = delete_data_utils.delete_network(_POST["ifid"], parts[1],
                                                   parts[2],
                                                   host_info["vlan"] or 0)
        else
            res = delete_data_utils.delete_host(_POST["ifid"], host_info)
        end

        local err_msgs = {}

        for what, what_res in pairs(res) do
            if what_res["status"] ~= "OK" then
                err_msgs[#err_msgs + 1] =
                    i18n(delete_data_utils.status_to_i18n(what_res["status"]))
            end
        end

        if #err_msgs == 0 then
            print(
                '<div class="alert alert-success alert-dismissable"><a href="" class="close" data-dismiss="alert" aria-label="close">&times;</a>' ..
                    i18n('delete_data.delete_ok',
                         {host = hostinfo2hostkey(host_info)}) .. '</div>')
        else
            print(
                '<div class="alert alert-danger alert-dismissable"><a href="" class="close" data-dismiss="alert" aria-label="close">&times;</a>' ..
                    i18n('delete_data.delete_failed',
                         {host = hostinfo2hostkey(host_info)}) .. ' ' ..
                    table.concat(err_msgs, ' ') .. '</div>')
        end

    end
end

local delete_active_interface_requested =
    delete_data_utils.delete_active_interface_data_requested(ifname)

page_utils.print_page_title(i18n("manage_data.manage_data"))

local menu = {
  entries = {
    { key = 'export', title = i18n("manage_data.export_tab"), url = "?page=export" },
    { key = 'delete', title = i18n("manage_data.delete_tab"), url = "?page=delete", hidden = not isAdministrator() },
  },
  current_page = page
}

local notes = {
  export = {
    {content = i18n('export_data.note_maximum_number')},
    {content = i18n('export_data.note_active_hosts')}
  },
  delete = {
    {content = i18n('delete_data.note_persistent_data')},
    {content = i18n('manage_data.system_interface_note')},
    {content = i18n('delete_data.node_nindex_flows'), hidden = not interfaceHasNindexSupport() }
  }
}

print(template_utils.gen("pages/manage_data.template", {
  menu = menu,
  template_utils = template_utils,
  ui_utils = ui_utils,
  manage_data = {
    page = page,
    note = notes[page],
    delete_active_interface_requested = delete_active_interface_requested
  }
}))

if not delete_active_interface_requested then
    print(template_utils.gen("modal_confirm_dialog.html", {
        dialog = {
            id = "delete_active_interface_data",
            action = "delete_interfaces_data('delete_active_if_data')",
            title = i18n("manage_data.delete_active_interface"),
            message = i18n("delete_data.delete_active_interface_confirmation", {
                ifname = "<span id='interface-name-to-delete'></span>",
                product = ntop.getInfo().product
            }),
            confirm = i18n("delete"),
            confirm_button = "btn-danger"
        }
    }))
end

print(template_utils.gen("modal_confirm_dialog.html", {
    dialog = {
        id = "delete_data",
        action = "delete_data()",
        title = i18n("manage_data.delete"),
        message = i18n("delete_data.delete_confirmation", {
            host = '<span id="modal_host"></span><span id="modal_vlan"></span>'
        }),
        confirm = i18n("delete"),
        confirm_button = "btn-danger"
    }
}))

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
